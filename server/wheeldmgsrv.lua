-- ════════════════════════════════════════════════════════════════
-- RDE | VEHICLE COCKPIT v1.0.0 — SERVER/WHEELDMG
-- Authoritative statebag sync for wheel damage state.
-- Merged from rde_realcardamage server.lua
-- ════════════════════════════════════════════════════════════════

local Ox = require '@ox_core/lib/init'

local function Debug(msg, ...)
    if not Config.Debug then return end
    print(('^5[RDE WHEELDMG SRV]^7 ' .. tostring(msg)):format(...))
end

-- ════════════════════════════════════════════════════════════════
-- WHEEL STATE — rde_wheeldamage_broken
-- ════════════════════════════════════════════════════════════════

RegisterNetEvent('rde_wheeldamage:setState', function(vehicleNetId, broken)
    local veh = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not DoesEntityExist(veh) then return end
    Entity(veh).state.rde_wheeldamage_broken = broken
    Debug('setState veh=%d broken=%s', vehicleNetId, tostring(broken))
end)

-- ════════════════════════════════════════════════════════════════
-- PER-WHEEL BROKEN STATE — rde_wheeldamage_broken_N
-- ════════════════════════════════════════════════════════════════

RegisterNetEvent('rde_wheeldamage:setBroken', function(vehicleNetId, wheelIdx, broken)
    local veh = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not DoesEntityExist(veh) then return end
    Entity(veh).state['rde_wheeldamage_broken_' .. tostring(wheelIdx)] = broken
    Debug('setBroken veh=%d wheel=%d broken=%s', vehicleNetId, wheelIdx, tostring(broken))
end)

-- ════════════════════════════════════════════════════════════════
-- SPARE TIRE — server validates item, removes it, authorises client
-- ════════════════════════════════════════════════════════════════

RegisterNetEvent('rde_carhud:requestSpareTire', function(vehicleNetId, wheelIdx)
    local src    = source
    local player = Ox.GetPlayer(src)
    if not player then return end

    -- Validate item ownership
    local count = exports.ox_inventory:Search(src, 'count', Config.SpareTire.item)
    if not count or count < 1 then
        TriggerClientEvent('ox_lib:notify', src, {
            title       = '🔧 Spare Tire',
            description = locale and locale['spare_no_item'] or 'No spare tire in inventory!',
            type        = 'error',
            duration    = 4000,
        })
        return
    end

    -- Validate vehicle still exists server-side
    local veh = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not DoesEntityExist(veh) then return end

    -- Remove item
    local ok = exports.ox_inventory:RemoveItem(src, Config.SpareTire.item, 1)
    if not ok then return end

    -- Authorise client to perform the repair
    TriggerClientEvent('rde_carhud:doSpareTire', src, vehicleNetId, wheelIdx)

    Debug('SpareTire: player %d repairing wheel %d on veh netid=%d', src, wheelIdx, vehicleNetId)
end)

-- ════════════════════════════════════════════════════════════════
-- EXPORTS
-- ════════════════════════════════════════════════════════════════

exports('isWheelBroken', function(vehicleNetId, wheelIdx)
    local veh = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not DoesEntityExist(veh) then return false end
    if wheelIdx then
        return Entity(veh).state['rde_wheeldamage_broken_' .. tostring(wheelIdx)] == true
    end
    return Entity(veh).state.rde_wheeldamage_broken == true
end)

exports('fixAllWheels', function(vehicleNetId)
    local veh = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not DoesEntityExist(veh) then return false end
    Entity(veh).state.rde_wheeldamage_broken = false
    for i = 0, 3 do
        Entity(veh).state['rde_wheeldamage_broken_' .. i] = false
    end
    TriggerClientEvent('rde_wheeldamage:fixCar', -1, veh)
    return true
end)

print('^2[RDE | Cockpit v1.0.0]^0 wheeldmgsrv.lua loaded — WheelDamage + SpareTire active')
