-- ════════════════════════════════════════════════════════════════
-- RDE | VEHICLE COCKPIT v1.0.0 — DATA/ITEMS
-- ox_inventory item use export handlers
-- ════════════════════════════════════════════════════════════════

local function L(key, ...)
    local t = locale and locale[key]
    if not t then return '[' .. key .. ']' end
    if select('#', ...) > 0 then return string.format(t, ...) end
    return t
end

-- ════════════════════════════════════════════════════════════════
-- SPARE TIRE (rde_ersatzreifen)
-- Finds the most damaged/missing wheel on nearby vehicle and fixes it.
-- ════════════════════════════════════════════════════════════════

local isChanagingTire = false

local function GetWorstWheel(veh)
    -- Priority: missing (broken statebag) > burst > damaged
    -- Returns: wheelIdx, severity ('missing'|'burst'|'damaged'|nil)
    local bestIdx      = nil
    local bestSeverity = nil
    local priority     = { missing = 1, burst = 2, damaged = 3 }

    for i = 0, GetVehicleNumberOfWheels(veh) - 1 do
        local isMissing = Entity(veh).state['rde_wheeldamage_broken_' .. i] == true
        local isBurst   = IsVehicleTyreBurst(veh, i, false)
        local health    = GetVehicleWheelHealth(veh, i)

        local sev = nil
        if isMissing or health <= 0 then
            sev = 'missing'
        elseif isBurst then
            sev = 'burst'
        elseif health < 600 then
            sev = 'damaged'
        end

        if sev and (bestSeverity == nil or priority[sev] < priority[bestSeverity]) then
            bestIdx      = i
            bestSeverity = sev
        end
    end

    return bestIdx, bestSeverity
end

local function FindNearbyVehicle()
    -- If player is in a vehicle, use that
    if cache.vehicle and cache.vehicle ~= 0 then
        return cache.vehicle, 0.0
    end

    -- Search nearby
    local ped    = cache.ped
    local coords = GetEntityCoords(ped)
    local best   = nil
    local bestD  = Config.SpareTire.searchRadius

    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(veh) then
            local d = #(coords - GetEntityCoords(veh))
            if d < bestD then
                best  = veh
                bestD = d
            end
        end
    end

    return best, bestD
end

local function UseSpareTire(data, slot)
    if isChanagingTire then return end

    -- Must be stopped
    if cache.vehicle and cache.vehicle ~= 0 then
        if GetEntitySpeed(cache.vehicle) > 1.0 then
            lib.notify({
                title       = '🔧 Spare Tire',
                description = L('spare_must_stop'),
                type        = 'error',
                duration    = 3000,
            })
            return
        end
    end

    local veh, dist = FindNearbyVehicle()
    if not veh then
        lib.notify({
            title       = '🔧 Spare Tire',
            description = L('spare_no_vehicle'),
            type        = 'error',
            duration    = 3000,
        })
        return
    end

    local wheelIdx, severity = GetWorstWheel(veh)
    if not wheelIdx then
        lib.notify({
            title       = '🔧 Spare Tire',
            description = L('spare_no_damage'),
            type        = 'info',
            duration    = 3000,
        })
        return
    end

    isChanagingTire = true

    -- Animation
    local ped = cache.ped
    lib.requestAnimDict(Config.SpareTire.animDict)
    TaskPlayAnim(ped, Config.SpareTire.animDict, Config.SpareTire.animName,
        8.0, -8.0, -1, 1, 0, false, false, false)

    -- Progress bar
    local success = lib.progressBar({
        duration     = Config.SpareTire.repairTime,
        label        = L('spare_repairing'),
        useWhileDead = false,
        canCancel    = true,
        disable      = { move = true, car = true, combat = true },
    })

    ClearPedTasks(ped)
    isChanagingTire = false

    if not success then
        lib.notify({
            title       = '🔧 Spare Tire',
            description = L('spare_cancelled'),
            type        = 'error',
            duration    = 2000,
        })
        return
    end

    -- Ask server to validate item and authorise the repair
    TriggerServerEvent('rde_carhud:requestSpareTire',
        NetworkGetNetworkIdFromEntity(veh),
        wheelIdx
    )
end

-- Server sends authorisation → client applies the fix
RegisterNetEvent('rde_carhud:doSpareTire', function(vehicleNetId, wheelIdx)
    local veh = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not DoesEntityExist(veh) then return end

    -- Apply repair
    SetVehicleTyreFixed(veh, wheelIdx)
    SetVehicleWheelHealth(veh, wheelIdx, 1000.0)
    Entity(veh).state:set('rde_wheeldamage_broken_' .. wheelIdx, false, true)
    TriggerServerEvent('rde_wheeldamage:setBroken',
        NetworkGetNetworkIdFromEntity(veh), wheelIdx, false)

    if Config.SpareTire.sound then
        PlaySoundFrontend(-1, Config.SpareTire.sound, Config.SpareTire.soundSet, true)
    end

    lib.notify({
        title       = '✅ Spare Tire',
        description = locale and locale['spare_done'] or 'Tire changed!',
        type        = 'success',
        duration    = 3000,
        icon        = Config.Icons.sparetire,
    })
end)

-- ox_inventory export: use_rde_ersatzreifen
exports('use_rde_ersatzreifen', function(data, slot)
    UseSpareTire(data, slot)
end)

if Config.Debug then
    print('^2[RDE | Cockpit v1.0.0]^0 data/items.lua loaded — ersatzreifen + nitro + fixkit')
end
