-- ════════════════════════════════════════════════════════════════
-- REPAIR KIT SYSTEM - SERVER (OX_CORE)
-- Modern vehicle repair system with ox_inventory integration
-- ════════════════════════════════════════════════════════════════

local Ox = require '@ox_core/lib/init'

-- ════════════════════════════════════════════════════════════════
-- CONFIG
-- ════════════════════════════════════════════════════════════════
Config = Config or {}
Config.RepairKit = Config.RepairKit or {
    InfiniteRepairs = true,
    AllowMechanics = false,
    MechanicJob = 'mechanic'
}

Config.Debug = false

-- ════════════════════════════════════════════════════════════════
-- ACTIVE REPAIRS TRACKING
-- ════════════════════════════════════════════════════════════════
local activeRepairs = {}

-- ════════════════════════════════════════════════════════════════
-- HELPER FUNCTIONS
-- ════════════════════════════════════════════════════════════════
local function IsMechanic(source)
    local player = Ox.GetPlayer(source)
    if not player then return false end
    
    -- Check if player has mechanic job
    local groups = player.getGroups()
    if groups and groups[Config.RepairKit.MechanicJob] then
        return true
    end
    
    return false
end

local function HasRepairKit(source)
    local count = exports.ox_inventory:Search(source, 'count', 'fixkit')
    return count and count > 0
end

local function RemoveRepairKit(source)
    if Config.RepairKit.InfiniteRepairs then
        return true
    end
    
    -- Check if mechanic (free repairs if allowed)
    if Config.RepairKit.AllowMechanics and IsMechanic(source) then
        return true
    end
    
    -- Remove item
    local success = exports.ox_inventory:RemoveItem(source, 'fixkit', 1)
    
    if success then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Repair Kit',
            description = 'Used repair kit',
            type = 'info',
            icon = '🔧'
        })
        
        if Config.Debug then
            local player = Ox.GetPlayer(source)
            print(('[Repair Kit] Player %s used repair kit'):format(player.charId or source))
        end
    end
    
    return success
end

-- ════════════════════════════════════════════════════════════════
-- REPAIR NOTIFICATION
-- ════════════════════════════════════════════════════════════════
RegisterNetEvent('repairkit:notifyRepair', function(vehicleNetId)
    local source = source
    
    -- Verify vehicle exists
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not DoesEntityExist(vehicle) then return end
    
    -- Track repair
    local plate = GetVehicleNumberPlateText(vehicle)
    activeRepairs[source] = {
        vehicle = vehicle,
        plate = plate,
        timestamp = os.time()
    }
    
    -- Remove repair kit
    RemoveRepairKit(source)
    
    if Config.Debug then
        print(('[Repair Kit] Player %d repaired vehicle %s'):format(source, plate))
    end
end)

-- ════════════════════════════════════════════════════════════════
-- REQUEST REPAIR (ALTERNATIVE METHOD)
-- ════════════════════════════════════════════════════════════════
RegisterNetEvent('repairkit:requestRepair', function(vehicleNetId)
    local source = source
    
    -- Check if player has repair kit
    if not HasRepairKit(source) and not (Config.RepairKit.AllowMechanics and IsMechanic(source)) then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Repair Kit',
            description = 'You don\'t have a repair kit!',
            type = 'error',
            icon = '🔧'
        })
        return
    end
    
    -- Allow repair
    TriggerClientEvent('repairkit:use', source)
end)

-- ════════════════════════════════════════════════════════════════
-- CLEANUP OLD REPAIRS
-- ════════════════════════════════════════════════════════════════
CreateThread(function()
    while true do
        Wait(60000) -- Every minute
        
        local now = os.time()
        for source, data in pairs(activeRepairs) do
            if now - data.timestamp > 300 then -- 5 minutes
                activeRepairs[source] = nil
            end
        end
    end
end)

-- ════════════════════════════════════════════════════════════════
-- ADMIN COMMANDS
-- ════════════════════════════════════════════════════════════════
lib.addCommand('giverepairkit', {
    help = 'Give a repair kit to a player',
    params = {
        {name = 'target', type = 'playerId', help = 'Target player ID'},
        {name = 'amount', type = 'number', help = 'Amount (optional)', optional = true}
    },
    restricted = 'group.admin'
}, function(source, args)
    local target = args.target
    local amount = args.amount or 1
    
    if not GetPlayerPed(target) then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Repair Kit',
            description = 'Player not found!',
            type = 'error',
            icon = '🔧'
        })
        return
    end
    
    local success = exports.ox_inventory:AddItem(target, 'fixkit', amount)
    
    if success then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Repair Kit',
            description = ('Gave %d repair kit(s) to player %d'):format(amount, target),
            type = 'success',
            icon = '🔧'
        })
        
        TriggerClientEvent('ox_lib:notify', target, {
            title = 'Repair Kit',
            description = ('Received %d repair kit(s)'):format(amount),
            type = 'success',
            icon = '🔧'
        })
    end
end)

lib.addCommand('repairvehicle', {
    help = 'Admin repair nearby vehicle',
    restricted = 'group.admin'
}, function(source, args)
    TriggerClientEvent('repairkit:use', source)
end)

-- ════════════════════════════════════════════════════════════════
-- EXPORTS
-- ════════════════════════════════════════════════════════════════
exports('giveRepairKit', function(source, amount)
    return exports.ox_inventory:AddItem(source, 'fixkit', amount or 1)
end)

exports('removeRepairKit', function(source, amount)
    return exports.ox_inventory:RemoveItem(source, 'fixkit', amount or 1)
end)

exports('hasRepairKit', function(source)
    return HasRepairKit(source)
end)

exports('isMechanic', function(source)
    return IsMechanic(source)
end)

exports('getActiveRepairs', function()
    return activeRepairs
end)

-- ════════════════════════════════════════════════════════════════
-- STARTUP
-- ════════════════════════════════════════════════════════════════
print('^2[RDE | Repair Kit System]^0 Server initialized successfully')
print('^2[RDE | Repair Kit System]^0 Using ox_inventory for item management')
print('^2[RDE | Repair Kit System]^0 Infinite repairs: ' .. tostring(Config.RepairKit.InfiniteRepairs))
print('^2[RDE | Repair Kit System]^0 Allow mechanics: ' .. tostring(Config.RepairKit.AllowMechanics))