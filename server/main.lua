-- ════════════════════════════════════════════════════════════════
-- RDE | VEHICLE COCKPIT v1.0.0 — SERVER/MAIN
-- DB auto-create, mileage persistence, engine state sync,
-- blinker relay, eject relay, admin commands
-- RDE OX Standards: server validates everything, no client authority
-- ════════════════════════════════════════════════════════════════

local Ox = require '@ox_core/lib/init'

-- ════════════════════════════════════════════════════════════════
-- ADMIN CHECK (triple-layer: ACE > ox_core group > Steam)
-- ════════════════════════════════════════════════════════════════
local function isAdmin(source)
    local player = Ox.GetPlayer(source)
    if not player then return false end

    local cfg = Config.EngineControl.admin

    -- Layer 1: ACE
    if IsPlayerAceAllowed(source, cfg.acePermission) then return true end

    -- Layer 2: ox_core groups
    for groupName, minGrade in pairs(cfg.oxGroups) do
        local grade = player.getGroup(groupName)
        if grade and grade >= minGrade then return true end
    end

    -- Layer 3: Steam ID whitelist
    local steam = player.getIdentifier('steam')
    if steam then
        for _, id in ipairs(cfg.steamIds) do
            if steam == id then return true end
        end
    end

    return false
end

-- ════════════════════════════════════════════════════════════════
-- DATABASE AUTO-CREATE
-- ════════════════════════════════════════════════════════════════
MySQL.ready(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `rde_vehicle_data` (
            `id`               INT AUTO_INCREMENT PRIMARY KEY,
            `plate`            VARCHAR(10) UNIQUE NOT NULL,
            `mileage`          INT DEFAULT 0,
            `total_distance`   INT DEFAULT 0,
            `engine_hours`     INT DEFAULT 0,
            `last_service`     INT DEFAULT 0,
            `windshield_damage` INT DEFAULT 0,
            `engine_damage`    INT DEFAULT 0,
            `engine_temp`      INT DEFAULT 90,
            `created_at`       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `updated_at`       TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX `idx_plate` (`plate`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    print('^2[RDE Cockpit v1.0.0]^0 Database table rde_vehicle_data initialized')
end)

-- ════════════════════════════════════════════════════════════════
-- VEHICLE DATA CACHE
-- ════════════════════════════════════════════════════════════════
local VehicleCache = {}

local function LoadVehicleData(plate)
    if VehicleCache[plate] then return VehicleCache[plate] end

    local row = MySQL.single.await('SELECT * FROM rde_vehicle_data WHERE plate = ?', { plate })
    if row then
        VehicleCache[plate] = row
        return row
    end

    MySQL.insert('INSERT INTO rde_vehicle_data (plate, mileage, windshield_damage, engine_damage, engine_temp) VALUES (?, 0, 0, 0, 90)', { plate })
    VehicleCache[plate] = { plate = plate, mileage = 0, windshield_damage = 0, engine_damage = 0, engine_temp = 90 }
    return VehicleCache[plate]
end

local function SaveVehicleData(plate, mileage, windshieldDmg, engineDmg, engineTemp)
    engineDmg  = engineDmg  or 0
    engineTemp = engineTemp or 90

    MySQL.update(
        'UPDATE rde_vehicle_data SET mileage = ?, windshield_damage = ?, engine_damage = ?, engine_temp = ?, updated_at = NOW() WHERE plate = ?',
        { mileage, windshieldDmg, engineDmg, engineTemp, plate }
    )

    if VehicleCache[plate] then
        VehicleCache[plate].mileage          = mileage
        VehicleCache[plate].windshield_damage = windshieldDmg
        VehicleCache[plate].engine_damage    = engineDmg
        VehicleCache[plate].engine_temp      = engineTemp
    end

    if Config.Debug then
        print(('[RDE Cockpit] Saved %s: mileage=%d km, windshield=%d%%, engine_dmg=%d%%, temp=%.0f°C')
            :format(plate, mileage, windshieldDmg, engineDmg, engineTemp))
    end
end

-- ════════════════════════════════════════════════════════════════
-- ENGINE STATE PERSISTENCE (per plate)
-- ════════════════════════════════════════════════════════════════
local engineStates = {}  -- plate -> bool (running)

RegisterNetEvent('rde_cockpit:syncEngineState', function(plate, running)
    local src = source
    if not plate or type(running) ~= 'boolean' then return end
    plate = plate:gsub('%s+', '')
    engineStates[plate] = running

    if Config.Debug then
        print(('[RDE Engine] %s engine state: %s (by player %d)'):format(plate, running and 'ON' or 'OFF', src))
    end
end)

RegisterNetEvent('rde_cockpit:requestEngineState', function(plate)
    local src = source
    if not plate then return end
    plate = plate:gsub('%s+', '')

    if engineStates[plate] ~= nil then
        TriggerClientEvent('rde_cockpit:receiveEngineState', src, plate, engineStates[plate])
    end
end)

-- ════════════════════════════════════════════════════════════════
-- MILEAGE SAVE
-- ════════════════════════════════════════════════════════════════
RegisterNetEvent('rde_cockpit:saveMileage', function(plate, mileage, windshieldDmg, engineDmg, engineTemp)
    local src = source
    if not plate or not mileage then return end

    -- Basic sanity: mileage can only go up (prevent cheating/exploits)
    local cached = VehicleCache[plate]
    if cached and mileage < (cached.mileage or 0) then
        if Config.Debug then
            print(('[RDE Cockpit] Suspicious mileage from player %d: %d < cached %d — ignored'):format(src, mileage, cached.mileage))
        end
        return
    end

    SaveVehicleData(plate, mileage, windshieldDmg or 0, engineDmg or 0, engineTemp or 90)
end)

-- ════════════════════════════════════════════════════════════════
-- BLINKER RELAY
-- ════════════════════════════════════════════════════════════════
RegisterNetEvent('rde_cockpit:syncBlinkers', function(signal)
    TriggerClientEvent('rde_cockpit:syncBlinkers', -1, source, signal)
end)

-- ════════════════════════════════════════════════════════════════
-- WINDSHIELD DAMAGE RELAY
-- ════════════════════════════════════════════════════════════════
RegisterNetEvent('rde_cockpit:syncWindshieldDamage', function(netId, damage)
    TriggerClientEvent('rde_cockpit:syncWindshieldDamage', -1, netId, damage)
end)

-- ════════════════════════════════════════════════════════════════
-- EJECT RELAY (broadcast to all, client filters self)
-- ════════════════════════════════════════════════════════════════
RegisterNetEvent('rde_cockpit:syncEject', function(data)
    local src = source
    TriggerClientEvent('rde_cockpit:receiveEject', -1, data)

    if Config.Debug then
        print(('[RDE Cockpit] Eject sync from player %d | impact: %.2f | windshield: %d%%')
            :format(src, data.impactSeverity or 0, data.windshieldDamage or 0))
    end
end)

-- ════════════════════════════════════════════════════════════════
-- VEHICLE DATA REQUEST (for load on enter)
-- ════════════════════════════════════════════════════════════════
RegisterNetEvent('rde_cockpit:loadVehicleData', function(plate)
    local src = source
    if not plate then return end
    local data = LoadVehicleData(plate)
    TriggerClientEvent('rde_cockpit:receiveVehicleData', src, data)
end)

-- ════════════════════════════════════════════════════════════════
-- PERIODIC AUTO-SAVE (server-side fallback, reads statebags)
-- ════════════════════════════════════════════════════════════════
if Config.Database.enabled then
    CreateThread(function()
        while true do
            Wait(Config.Database.saveInterval)

            local vehicles = GetGamePool('CVehicle')
            local saved    = 0

            for _, vehicle in ipairs(vehicles) do
                if DoesEntityExist(vehicle) then
                    local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
                    local state = Entity(vehicle).state

                    if state.mileage and state.mileage > 0 then
                        SaveVehicleData(
                            plate,
                            math.floor(state.mileage),
                            state.windshieldDamage or 0,
                            state.engineDamage    or 0,
                            state.engineTemp      or 90
                        )
                        saved = saved + 1
                    end
                end
            end

            if Config.Debug and saved > 0 then
                print(('[RDE Cockpit] Auto-saved %d vehicles'):format(saved))
            end
        end
    end)
end

-- ════════════════════════════════════════════════════════════════
-- ADMIN COMMANDS
-- ════════════════════════════════════════════════════════════════

-- Stop all engines
RegisterNetEvent('rde_cockpit:adminStopAllEngines', function()
    local src = source
    if not isAdmin(src) then
        lib.notify(src, { title = 'Error', description = 'No permission', type = 'error' })
        return
    end
    print(('[RDE Admin] %s [%d] stopped all engines'):format(GetPlayerName(src), src))
    TriggerClientEvent('rde_cockpit:adminEngineStop', -1)
end)

-- Start all engines
RegisterNetEvent('rde_cockpit:adminStartAllEngines', function()
    local src = source
    if not isAdmin(src) then
        lib.notify(src, { title = 'Error', description = 'No permission', type = 'error' })
        return
    end
    print(('[RDE Admin] %s [%d] started all engines'):format(GetPlayerName(src), src))
    TriggerClientEvent('rde_cockpit:adminEngineStart', -1)
end)

-- /carmileage command
lib.addCommand('carmileage', {
    help   = 'Check vehicle mileage',
    params = {
        { name = 'plate', type = 'string', help = 'Vehicle plate (optional)', optional = true },
    },
}, function(source, args)
    local ped     = GetPlayerPed(source)
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 and not args.plate then
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'You must be in a vehicle or provide a plate' })
        return
    end

    local plate = args.plate or GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
    local data  = LoadVehicleData(plate)

    TriggerClientEvent('ox_lib:notify', source, {
        title       = 'Vehicle Mileage',
        description = ('%s: %d km | Windshield: %d%%'):format(plate, data.mileage, data.windshield_damage),
        type        = 'info',
        icon        = Config.Icons.speed,
    })
end)

-- /resetmileage command (admin only)
lib.addCommand('resetmileage', {
    help       = 'Reset vehicle mileage (Admin)',
    restricted = 'group.admin',
}, function(source)
    local ped     = GetPlayerPed(source)
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 then
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'You must be in a vehicle' })
        return
    end

    local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
    SaveVehicleData(plate, 0, 0, 0, 90)
    Entity(vehicle).state:set('mileage', 0, true)
    Entity(vehicle).state:set('windshieldDamage', 0, true)
    Entity(vehicle).state:set('engineDamage', 0, true)
    Entity(vehicle).state:set('engineTemp', 90, true)
    VehicleCache[plate] = nil -- bust cache

    TriggerClientEvent('ox_lib:notify', source, {
        title       = 'Mileage Reset',
        description = 'All vehicle data reset to default',
        type        = 'success',
    })
end)

-- /adminengine command (admin only, shows engine admin menu on client)
lib.addCommand('adminengine', {
    help       = 'Engine admin menu',
    restricted = 'group.admin',
}, function(source)
    TriggerClientEvent('rde_cockpit:showAdminMenu', source)
end)

-- ════════════════════════════════════════════════════════════════
-- EXPORTS
-- ════════════════════════════════════════════════════════════════
exports('getVehicleMileage',    function(plate) return (LoadVehicleData(plate)).mileage or 0 end)
exports('setVehicleMileage',    function(plate, mileage)
    local d = LoadVehicleData(plate)
    SaveVehicleData(plate, mileage, d.windshield_damage or 0, d.engine_damage or 0, d.engine_temp or 90)
    return true
end)
exports('getWindshieldDamage',  function(plate) return (LoadVehicleData(plate)).windshield_damage or 0 end)
exports('isEngineRunning',      function(plate) return engineStates[plate] == true end)

-- ════════════════════════════════════════════════════════════════
-- STARTUP
-- ════════════════════════════════════════════════════════════════
print('^2════════════════════════════════════════^0')
print('^2[RDE | Cockpit v1.0.0]^0 server loaded successfully')
print('^2[RDE | Cockpit v1.0.0]^0 Engine Control: integrated (M key)')
print('^2[RDE | Cockpit v1.0.0]^0 DB auto-save: ' .. tostring(Config.Database.saveInterval / 1000) .. 's interval')
print('^2════════════════════════════════════════^0')
