-- ════════════════════════════════════════════════════════════════
-- RDE | VEHICLE COCKPIT v1.0.0 — CLIENT/NITRO
-- Nitro boost system with statebag sync + exhaust flames.
-- Display is now handled by the NUI cockpit (no more 2D text).
-- ════════════════════════════════════════════════════════════════

-- Config.Nitro is defined in config.lua — no fallback needed here

-- ════════════════════════════════════════════════════════════════
-- STATE
-- ════════════════════════════════════════════════════════════════
local currentVehicle = nil
local exhausts       = {}
local soundofnitro   = nil
local soundActive    = false

-- ════════════════════════════════════════════════════════════════
-- HELPERS
-- ════════════════════════════════════════════════════════════════

local function CreateFlameEffect(veh, count)
    if not veh or not DoesEntityExist(veh) or not exhausts or #exhausts == 0 then return end
    if not HasNamedPtfxAssetLoaded('core') then
        RequestNamedPtfxAsset('core')
        local timeout = 0
        while not HasNamedPtfxAssetLoaded('core') and timeout < 100 do
            Wait(1); timeout = timeout + 1
        end
        if timeout >= 100 then return end
    end
    local fires = {}
    for i = 1, math.min(count, 4) do
        if exhausts[i] then
            UseParticleFxAssetNextCall('core')
            local fire = StartParticleFxLoopedOnEntityBone_2(
                'veh_backfire', veh, 0,0,0, 0,0,0, exhausts[i], 1.0, 0,0,0)
            table.insert(fires, fire)
        end
    end
    Wait(0)
    for _, fire in ipairs(fires) do
        StopParticleFxLooped(fire, false)
    end
end

local function UpdateExhausts(veh)
    if not DoesEntityExist(veh) then return end
    if not IsThisModelACar(GetEntityModel(veh)) then return end
    exhausts = {}
    local main = GetEntityBoneIndexByName(veh, 'exhaust')
    if main ~= -1 then table.insert(exhausts, main) end
    for i = 1, 12 do
        local ex = GetEntityBoneIndexByName(veh, 'exhaust_' .. i)
        if ex ~= -1 then table.insert(exhausts, ex) end
    end
end

local function GetVehicleNitro(veh)
    if not DoesEntityExist(veh) then return 0 end
    return Entity(veh).state.nitro or 0
end

local function SetVehicleNitro(veh, amount)
    if not DoesEntityExist(veh) then return end
    Entity(veh).state:set('nitro', math.max(0, math.min(100, amount)), true)
end

local function IsVehicleNitroActive(veh)
    if not DoesEntityExist(veh) then return false end
    return Entity(veh).state.nitroActive or false
end

local function SetVehicleNitroActive(veh, active)
    if not DoesEntityExist(veh) then return end
    Entity(veh).state:set('nitroActive', active, true)
end

-- ════════════════════════════════════════════════════════════════
-- MAIN NITRO CONTROL THREAD
-- Wait(0) is required: boost must be frame-accurate
-- ════════════════════════════════════════════════════════════════
CreateThread(function()
    while true do
        Wait(0)

        local ped = cache.ped
        local veh = cache.vehicle

        if not veh or veh == 0 then
            if soundActive then
                StopSound(soundofnitro)
                ReleaseSoundId(soundofnitro)
                soundActive = false
            end
            Wait(500)
            goto continue
        end

        if veh ~= currentVehicle then
            currentVehicle = veh
            UpdateExhausts(veh)
        end

        local isDriver   = GetPedInVehicleSeat(veh, -1) == ped
        local nitroLevel = GetVehicleNitro(veh)

        -- Nitro boost logic (driver only)
        if IsControlPressed(0, 36) and isDriver and nitroLevel > 0 then
            SetVehicleEnginePowerMultiplier(veh, Config.Nitro.Power)
            SetVehicleEngineTorqueMultiplier(veh, Config.Nitro.Torque)
            if not IsVehicleNitroActive(veh) then
                SetVehicleNitroActive(veh, true)
            end
            if not soundActive then
                soundofnitro = PlaySoundFromEntity(GetSoundId(), 'Flare', veh,
                    'DLC_HEISTS_BIOLAB_FINALE_SOUNDS', 0, 0)
                soundActive = true
            end
        else
            if veh ~= 0 then
                SetVehicleEnginePowerMultiplier(veh, 1.0)
                SetVehicleEngineTorqueMultiplier(veh, 1.0)
            end
            if IsVehicleNitroActive(veh) then
                SetVehicleNitroActive(veh, false)
            end
            if soundActive then
                StopSound(soundofnitro)
                ReleaseSoundId(soundofnitro)
                soundActive = false
            end
        end

        ::continue::
    end
end)

-- ════════════════════════════════════════════════════════════════
-- NITRO CONSUMPTION THREAD
-- ════════════════════════════════════════════════════════════════
CreateThread(function()
    while true do
        Wait(Config.Nitro.Consumption)
        local ped = cache.ped
        local veh = cache.vehicle
        if veh and veh ~= 0 then
            if GetPedInVehicleSeat(veh, -1) == ped and IsVehicleNitroActive(veh) then
                local cur = GetVehicleNitro(veh)
                if cur > 0 then SetVehicleNitro(veh, cur - 1) end
            end
        end
    end
end)

-- ════════════════════════════════════════════════════════════════
-- EXHAUST FLAME THREAD (all nearby vehicles)
-- ════════════════════════════════════════════════════════════════
CreateThread(function()
    while true do
        Wait(Config.Nitro.FlameInterval)
        local myPos   = GetEntityCoords(cache.ped)
        local vehicles = GetGamePool('CVehicle')
        for _, veh in ipairs(vehicles) do
            if DoesEntityExist(veh) then
                local d = #(myPos - GetEntityCoords(veh))
                if d < 100.0 and IsVehicleNitroActive(veh) then
                    if veh ~= currentVehicle then
                        local temp = {}
                        if IsThisModelACar(GetEntityModel(veh)) then
                            local m = GetEntityBoneIndexByName(veh, 'exhaust')
                            if m ~= -1 then table.insert(temp, m) end
                            for i = 1, 12 do
                                local ex = GetEntityBoneIndexByName(veh, 'exhaust_' .. i)
                                if ex ~= -1 then table.insert(temp, ex) end
                            end
                            if #temp > 0 then
                                -- temporarily swap exhausts for effect
                                local saved = exhausts
                                exhausts = temp
                                CreateFlameEffect(veh, #temp)
                                exhausts = saved
                            end
                        end
                    else
                        if #exhausts > 0 then
                            CreateFlameEffect(veh, #exhausts)
                        end
                    end
                end
            end
        end
    end
end)

-- ════════════════════════════════════════════════════════════════
-- STATEBAG LISTENERS
-- ════════════════════════════════════════════════════════════════
AddStateBagChangeHandler('nitro', nil, function(bagName, _, value)
    if not value then return end
    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 or not DoesEntityExist(entity) then return end
    -- Nitro depleted notification (driver only)
    if value == 0 and entity == cache.vehicle then
        lib.notify({
            title       = '⚡ Nitro',
            description = 'Nitro depleted!',
            type        = 'error',
            duration    = 2000,
        })
    end
end)

AddStateBagChangeHandler('nitroActive', nil, function(bagName, _, value)
    if value == nil then return end
    if Config.Debug then
        local entity = GetEntityFromStateBagName(bagName)
        if DoesEntityExist(entity) then
            local plate = GetVehicleNumberPlateText(entity):gsub('%s+', '')
            print(('[Nitro] Vehicle %s nitroActive: %s'):format(plate, tostring(value)))
        end
    end
end)

-- ════════════════════════════════════════════════════════════════
-- INSTALLATION EVENT
-- ════════════════════════════════════════════════════════════════
RegisterNetEvent('nitro:install', function()
    local ped = cache.ped
    local veh = cache.vehicle
    if not veh or veh == 0 then
        lib.notify({ title = 'Nitro', description = 'You need to be in a vehicle!', type = 'error' })
        return
    end
    if GetEntitySpeed(veh) > 0.1 then
        lib.notify({ title = 'Nitro', description = 'Vehicle must be stopped!', type = 'error' })
        return
    end
    if not IsThisModelACar(GetEntityModel(veh)) then
        lib.notify({ title = 'Nitro', description = 'This vehicle cannot have nitro!', type = 'error' })
        return
    end

    FreezeEntityPosition(veh, true)

    if lib.progressBar({
        duration     = 10000,
        label        = 'Installing Nitrous System...',
        useWhileDead = false,
        canCancel    = false,
        disable      = { move = true, car = true, combat = true },
    }) then
        Wait(3000)
        PlaySoundFromEntity(-1, 'Bar_Unlock_And_Raise', veh, 'DLC_IND_ROLLERCOASTER_SOUNDS', 0, 0)
        Wait(1000)
        SetAudioFlag('LoadMPData', true)
        PlaySoundFrontend(-1, 'Lowrider_Upgrade', 'Lowrider_Super_Mod_Garage_Sounds', 1)
        Wait(2000)

        FreezeEntityPosition(veh, false)
        SetVehicleNitro(veh, 100)

        lib.notify({
            title       = '⚡ Nitro',
            description = 'Nitrous system installed!',
            type        = 'success',
            duration    = 5000,
        })
    end
end)

-- ════════════════════════════════════════════════════════════════
-- EXPORTS
-- ════════════════════════════════════════════════════════════════
-- ox_inventory item use handler (name must match what ox_inventory is configured with)
exports('useNitro', function(data, slot)
    TriggerServerEvent('nitro:requestInstall')
end)

exports('getNitroLevel', function(veh) return GetVehicleNitro(veh or cache.vehicle) end)
exports('setNitroLevel', function(veh, amount) SetVehicleNitro(veh or cache.vehicle, amount) end)
exports('isNitroActive', function(veh) return IsVehicleNitroActive(veh or cache.vehicle) end)

if Config.Debug then
    print('^2[RDE | Nitro System]^0 Client initialized — display via NUI cockpit')
end
