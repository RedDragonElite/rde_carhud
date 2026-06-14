-- ════════════════════════════════════════════════════════════════
-- NITRO SYSTEM - SERVER (OX_CORE)
-- Modern nitro system with ox_inventory integration
-- ════════════════════════════════════════════════════════════════

local Ox = require '@ox_core/lib/init'

-- ════════════════════════════════════════════════════════════════
-- CONFIG
-- ════════════════════════════════════════════════════════════════
Config = Config or {}
Config.Nitro = Config.Nitro or {
    Power = 100.0,
    Torque = 100.0,
    Consumption = 50
}

Config.Debug = false

-- ════════════════════════════════════════════════════════════════
-- NITRO INSTALLATION
-- ════════════════════════════════════════════════════════════════
RegisterNetEvent('nitro:requestInstall', function()
    local source = source
    local player = Ox.GetPlayer(source)
    
    if not player then return end

    -- Check if player has nitro item
    local hasItem = exports.ox_inventory:Search(source, 'count', 'nitro')
    
    if not hasItem or hasItem < 1 then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Nitro',
            description = 'You don\'t have a nitrous system!',
            type = 'error',
            icon = '⚡'
        })
        return
    end

    -- Remove item from inventory
    local success = exports.ox_inventory:RemoveItem(source, 'nitro', 1)
    
    if success then
        -- Trigger installation on client
        TriggerClientEvent('nitro:install', source)
        
        if Config.Debug then
            print(('[Nitro] Player %s installed nitro'):format(player.charId or source))
        end
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Nitro',
            description = 'Failed to remove nitro item!',
            type = 'error',
            icon = '⚡'
        })
    end
end)

-- ════════════════════════════════════════════════════════════════
-- EXPORTS
-- ════════════════════════════════════════════════════════════════
exports('giveNitro', function(source, amount)
    return exports.ox_inventory:AddItem(source, 'nitro', amount or 1)
end)

exports('removeNitro', function(source, amount)
    return exports.ox_inventory:RemoveItem(source, 'nitro', amount or 1)
end)

exports('hasNitro', function(source)
    return exports.ox_inventory:Search(source, 'count', 'nitro') or 0
end)

-- ════════════════════════════════════════════════════════════════
-- STARTUP
-- ════════════════════════════════════════════════════════════════
print('^2[RDE | Nitro System]^0 Server initialized successfully')
print('^2[RDE | Nitro System]^0 Using ox_inventory for item management')