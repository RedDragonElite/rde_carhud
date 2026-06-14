-- ════════════════════════════════════════════════════════════════
-- REPAIR KIT SYSTEM - CLIENT (OX_CORE + STATEBAG SYNC)
-- Modern vehicle repair system with realtime multiplayer sync
-- ════════════════════════════════════════════════════════════════

local Ox = require '@ox_core/lib/init'

-- ════════════════════════════════════════════════════════════════
-- CONFIG
-- ════════════════════════════════════════════════════════════════
Config = Config or {}
Config.RepairKit = {
    InfiniteRepairs = false,    -- Should one repairkit last forever?
    RepairTime = 15000,         -- In milliseconds
    SearchRadius = 5.0,         -- Distance to search for vehicles
    AllowMechanics = false,     -- Allow mechanics to use without consuming kit?
    MechanicJob = 'mechanic',   -- Job name for mechanics
    
    -- Repair amounts (0-100%)
    BodyRepair = 100,           -- Body damage repair %
    EngineRepair = 100,         -- Engine damage repair %
    
    -- Visual settings
    UseAnimation = true,
    AnimDict = 'mini@repair',
    AnimName = 'fixing_a_player',
    
    -- Sound settings
    RepairSound = true,
    SoundName = 'CHECKPOINT_PERFECT',
    SoundSet = 'HUD_MINI_GAME_SOUNDSET'
}

-- ════════════════════════════════════════════════════════════════
-- STATE
-- ════════════════════════════════════════════════════════════════
local isRepairing = false
local currentRepairVehicle = nil

-- ════════════════════════════════════════════════════════════════
-- HELPER FUNCTIONS
-- ════════════════════════════════════════════════════════════════

local function GetClosestVehicle()
    local ped = cache.ped
    local coords = GetEntityCoords(ped)
    
    -- If in vehicle, repair current vehicle
    if cache.vehicle and cache.vehicle ~= 0 then
        return cache.vehicle, 0.0
    end
    
    -- Search nearby vehicles
    local vehicles = GetGamePool('CVehicle')
    local closestVehicle = nil
    local closestDistance = Config.RepairKit.SearchRadius
    
    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) then
            local vehCoords = GetEntityCoords(vehicle)
            local distance = #(coords - vehCoords)
            
            if distance < closestDistance then
                closestVehicle = vehicle
                closestDistance = distance
            end
        end
    end
    
    return closestVehicle, closestDistance
end

local function GetVehicleRepairState(vehicle)
    if not DoesEntityExist(vehicle) then return nil end
    
    local bodyHealth = GetVehicleBodyHealth(vehicle)
    local engineHealth = GetVehicleEngineHealth(vehicle)
    
    return {
        bodyHealth = bodyHealth,
        engineHealth = engineHealth,
        maxBody = 1000.0,
        maxEngine = 1000.0
    }
end

local function SetVehicleRepairState(vehicle, state)
    if not DoesEntityExist(vehicle) then return end
    
    -- Set health values
    SetVehicleBodyHealth(vehicle, state.bodyHealth)
    SetVehicleEngineHealth(vehicle, state.engineHealth)
    
    -- Visual fixes
    SetVehicleFixed(vehicle)
    SetVehicleDeformationFixed(vehicle)
    SetVehicleUndriveable(vehicle, false)
    
    -- Dirt/petrol tank
    SetVehicleDirtLevel(vehicle, 0.0)
    SetVehiclePetrolTankHealth(vehicle, 1000.0)
    
    -- Wheels
    for i = 0, 7 do
        if not IsVehicleTyreBurst(vehicle, i, false) then
            SetVehicleTyreFixed(vehicle, i)
        end
    end
    
    -- Windows
    for i = 0, 7 do
        if not IsVehicleWindowIntact(vehicle, i) then
            FixVehicleWindow(vehicle, i)
        end
    end
    
    -- Engine
    SetVehicleEngineOn(vehicle, true, true, false)
end

local function SyncVehicleRepair(vehicle, plate)
    if not DoesEntityExist(vehicle) then return end
    
    local state = GetVehicleRepairState(vehicle)
    if not state then return end
    
    -- Sync via statebag
    Entity(vehicle).state:set('repairState', {
        bodyHealth = state.bodyHealth,
        engineHealth = state.engineHealth,
        timestamp = GetGameTimer()
    }, true)
    
    if Config.Debug then
        print(('[Repair Kit] Synced repair for vehicle %s'):format(plate))
    end
end

-- ════════════════════════════════════════════════════════════════
-- REPAIR FUNCTION
-- ════════════════════════════════════════════════════════════════
local function RepairVehicle(vehicle)
    if isRepairing then
        lib.notify({
            title = 'Repair Kit',
            description = 'Already repairing a vehicle!',
            type = 'error',
            icon = '🔧'
        })
        return
    end
    
    if not vehicle or not DoesEntityExist(vehicle) then
        lib.notify({
            title = 'Repair Kit',
            description = 'No vehicle nearby!',
            type = 'error',
            icon = '🔧'
        })
        return
    end
    
    local ped = cache.ped
    local plate = GetVehicleNumberPlateText(vehicle):gsub("%s+", "")
    
    -- Get current state
    local startState = GetVehicleRepairState(vehicle)
    if not startState then return end
    
    isRepairing = true
    currentRepairVehicle = vehicle
    
    -- Load animation
    if Config.RepairKit.UseAnimation then
        lib.requestAnimDict(Config.RepairKit.AnimDict)
        TaskPlayAnim(ped, Config.RepairKit.AnimDict, Config.RepairKit.AnimName, 8.0, -8.0, -1, 1, 0, false, false, false)
    end
    
    -- Progress bar
    local success = lib.progressBar({
        duration = Config.RepairKit.RepairTime,
        label = 'Repairing vehicle...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
            mouse = false
        },
        anim = not Config.RepairKit.UseAnimation and {
            dict = 'mini@repair',
            clip = 'fixing_a_player'
        } or nil
    })
    
    -- Stop animation
    if Config.RepairKit.UseAnimation then
        ClearPedTasks(ped)
    end
    
    isRepairing = false
    currentRepairVehicle = nil
    
    if success then
        -- Calculate repair amounts
        local bodyRepairAmount = (1000.0 - startState.bodyHealth) * (Config.RepairKit.BodyRepair / 100)
        local engineRepairAmount = (1000.0 - startState.engineHealth) * (Config.RepairKit.EngineRepair / 100)
        
        -- Apply repairs
        local newState = {
            bodyHealth = math.min(1000.0, startState.bodyHealth + bodyRepairAmount),
            engineHealth = math.min(1000.0, startState.engineHealth + engineRepairAmount)
        }
        
        SetVehicleRepairState(vehicle, newState)
        
        -- Sync to all players
        SyncVehicleRepair(vehicle, plate)
        
        -- Play sound
        if Config.RepairKit.RepairSound then
            PlaySoundFrontend(-1, Config.RepairKit.SoundName, Config.RepairKit.SoundSet, true)
        end
        
        -- Notify
        lib.notify({
            title = 'Repair Kit',
            description = 'Vehicle repaired successfully!',
            type = 'success',
            icon = '🔧',
            duration = 3000
        })
        
        -- Notify server (to remove item if needed)
        TriggerServerEvent('repairkit:notifyRepair', NetworkGetNetworkIdFromEntity(vehicle))
        
        return true
    else
        lib.notify({
            title = 'Repair Kit',
            description = 'Repair cancelled!',
            type = 'error',
            icon = '🔧'
        })
        
        return false
    end
end

-- ════════════════════════════════════════════════════════════════
-- USE REPAIR KIT EVENT
-- ════════════════════════════════════════════════════════════════
RegisterNetEvent('repairkit:use', function()
    local vehicle, distance = GetClosestVehicle()
    
    if not vehicle then
        lib.notify({
            title = 'Repair Kit',
            description = 'No vehicle nearby!',
            type = 'error',
            icon = '🔧'
        })
        return
    end
    
    if distance > Config.RepairKit.SearchRadius then
        lib.notify({
            title = 'Repair Kit',
            description = ('Vehicle too far away! (%.1fm)'):format(distance),
            type = 'error',
            icon = '🔧'
        })
        return
    end
    
    -- Check if vehicle needs repair
    local state = GetVehicleRepairState(vehicle)
    if state.bodyHealth >= 999 and state.engineHealth >= 999 then
        lib.notify({
            title = 'Repair Kit',
            description = 'Vehicle doesn\'t need repairs!',
            type = 'info',
            icon = '🔧'
        })
        return
    end
    
    -- Start repair
    RepairVehicle(vehicle)
end)

-- ════════════════════════════════════════════════════════════════
-- STATEBAG SYNC - LISTEN FOR REMOTE REPAIRS
-- ════════════════════════════════════════════════════════════════
AddStateBagChangeHandler('repairState', nil, function(bagName, key, value)
    if not value then return end
    
    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 or not DoesEntityExist(entity) then return end
    
    -- Don't apply if we're the one repairing
    if entity == currentRepairVehicle then return end
    
    -- Apply repair state from other player
    SetVehicleRepairState(entity, value)
    
    if Config.Debug then
        local plate = GetVehicleNumberPlateText(entity):gsub("%s+", "")
        print(('[Repair Kit] Received repair sync for vehicle %s'):format(plate))
    end
end)

-- ════════════════════════════════════════════════════════════════
-- DAMAGE SYNC SYSTEM (OPTIONAL ENHANCEMENT)
-- ════════════════════════════════════════════════════════════════
if Config.SyncDamage then
    CreateThread(function()
        local lastSync = {}
        
        while true do
            Wait(1000)
            
            local ped = cache.ped
            local vehicle = cache.vehicle
            
            if vehicle and vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
                local plate = GetVehicleNumberPlateText(vehicle):gsub("%s+", "")
                local state = GetVehicleRepairState(vehicle)
                
                if state then
                    local lastState = lastSync[plate]
                    
                    -- Only sync if damage changed significantly
                    if not lastState or 
                       math.abs(state.bodyHealth - lastState.bodyHealth) > 50 or
                       math.abs(state.engineHealth - lastState.engineHealth) > 50 then
                        
                        Entity(vehicle).state:set('damageState', {
                            bodyHealth = state.bodyHealth,
                            engineHealth = state.engineHealth
                        }, true)
                        
                        lastSync[plate] = state
                    end
                end
            end
        end
    end)
end

-- ════════════════════════════════════════════════════════════════
-- EXPORTS
-- ════════════════════════════════════════════════════════════════

-- Export handler for ox_inventory item use
exports('useRepairKit', function(data, slot)
    TriggerEvent('repairkit:use')
end)

exports('repairVehicle', function(vehicle)
    return RepairVehicle(vehicle or GetClosestVehicle())
end)

exports('getVehicleHealth', function(vehicle)
    return GetVehicleRepairState(vehicle or cache.vehicle)
end)

exports('isRepairing', function()
    return isRepairing
end)

if Config.Debug then
    print('^2[Repair Kit System]^0 Client initialized successfully')
end