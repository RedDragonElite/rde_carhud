-- ════════════════════════════════════════════════════════════════
-- RDE | VEHICLE COCKPIT v1.0.0 — CLIENT/MAIN
-- HUD data loop, seatbelt, cruise control, signals, statebag sync
-- Engine on/off logic is in client/engine.lua
-- ════════════════════════════════════════════════════════════════

local function L(key, ...)
    local t = locale and locale[key]
    if not t then return '[' .. key .. ']' end
    if select('#', ...) > 0 then return string.format(t, ...) end
    return t
end

-- ════════════════════════════════════════════════════════════════
-- STATE
-- ════════════════════════════════════════════════════════════════
local seatbeltOn  = false
local PlayerState = {
    seatbelt      = false,
    cruiseControl = false,
    cruiseSpeed   = 0,
    signals       = 'off',
    inVehicle     = false,
    isDriver      = false,
}
local VehicleData = {
    plate            = '',
    mileage          = 0,
    tripMeter        = 0,
    engineTemp       = 90,
    oilPressure      = 45,
    windshieldDamage = 0,
    engineDamage     = 0,
    lastUpdate       = 0,
}

-- EngineState is populated by client/engine.lua (loaded after this file)
EngineState = EngineState or {
    temperature          = 90,
    phase                = 'normal',
    isPermanentlyDamaged = false,
    damageLevel          = 0,
    performanceLoss      = 0.0,
    lastWarningTime      = 0,
    coolingDownSince     = 0,
    particleHandle       = nil,
    steamHandle          = nil,
    soundId              = nil,
}

-- ════════════════════════════════════════════════════════════════
-- HELPERS
-- ════════════════════════════════════════════════════════════════

local function LoadVehicleData(veh)
    if not DoesEntityExist(veh) then return end
    local plate = GetVehicleNumberPlateText(veh):gsub('%s+', '')
    local state = Entity(veh).state

    VehicleData = {
        plate            = plate,
        mileage          = state.mileage or 0,
        tripMeter        = state.tripMeter or 0,
        engineTemp       = state.engineTemp or 90,
        oilPressure      = state.oilPressure or 45,
        windshieldDamage = state.windshieldDamage or 0,
        engineDamage     = state.engineDamage or 0,
        lastUpdate       = GetGameTimer(),
    }
    EngineState.temperature          = VehicleData.engineTemp
    EngineState.isPermanentlyDamaged = (VehicleData.engineDamage or 0) > 0
    EngineState.damageLevel          = VehicleData.engineDamage or 0
end

local function ApplyBlinkers(veh, signal)
    if not DoesEntityExist(veh) then return end
    local inv      = Config.Keys.indicatorInverted
    local leftIdx  = inv and 1 or 0
    local rightIdx = inv and 0 or 1
    SetVehicleIndicatorLights(veh, leftIdx,  signal == 'left'  or signal == 'both')
    SetVehicleIndicatorLights(veh, rightIdx, signal == 'right' or signal == 'both')
    if Config.Debug then
        print(('[RDE HUD] Blinker: signal=%s leftIdx=%d rightIdx=%d'):format(signal, leftIdx, rightIdx))
    end
    if Config.Vehicle.statebagSync then
        Entity(veh).state:set('blinkerSignal', signal, true)
    end
end

local function GetGameTime()
    return string.format('%02d:%02d', GetClockHours(), GetClockMinutes())
end

-- Build tire status table for NUI (4 entries: FL, FR, RL, RR)
local function GetTireStatus(veh)
    if not DoesEntityExist(veh) then
        return { 'none', 'none', 'none', 'none' }
    end
    local wheelCount = GetVehicleNumberOfWheels(veh)
    local tires = {}
    for i = 0, 3 do
        if i < wheelCount then
            local isMissing = Entity(veh).state['rde_wheeldamage_broken_' .. i] == true
            local isBurst   = IsVehicleTyreBurst(veh, i, false)
            local health    = GetVehicleWheelHealth(veh, i)
            if isMissing or health <= 0 then
                tires[i + 1] = 'missing'
            elseif isBurst or health < 200 then
                tires[i + 1] = 'burst'
            elseif health < 700 then
                -- damaged: shows amber in HUD (health 200-700 = visibly worn)
                tires[i + 1] = 'damaged'
            else
                tires[i + 1] = 'ok'
            end
        else
            tires[i + 1] = 'none'
        end
    end
    return tires
end

-- ════════════════════════════════════════════════════════════════
-- MAIN HUD UPDATE THREAD
-- 50ms while driving, 500ms idle
-- ════════════════════════════════════════════════════════════════
CreateThread(function()
    while true do
        local sleep    = 500
        local ped      = cache.ped
        local vehicle  = cache.vehicle
        local isDriver = vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped

        if vehicle ~= 0 and isDriver then
            sleep = Config.Vehicle.updateInterval

            if not PlayerState.inVehicle then
                PlayerState.inVehicle = true
                PlayerState.isDriver  = true
                LoadVehicleData(vehicle)
            end

            local engineOn   = GetIsVehicleEngineRunning(vehicle)
            local speedMs    = engineOn and GetEntitySpeed(vehicle) or 0
            local speed      = Config.Vehicle.speedUnit == 'MPH' and (speedMs * 2.237) or (speedMs * 3.6)
            local speedPct   = math.min((speed / Config.Vehicle.maxSpeed) * 100, 100)

            local rpm    = engineOn and (GetVehicleCurrentRpm(vehicle) * 10000) or 0
            local rpmPct = math.min((rpm / 10000) * 100, 100)

            local gear = GetVehicleCurrentGear(vehicle)
            if not engineOn or (speed < 1 and gear == 0) then
                gear = 'N'
            elseif speed > 1 and gear == 0 then
                gear = 'R'
            end

            local fuel         = GetVehicleFuelLevel(vehicle)
            local engineHealth = GetVehicleEngineHealth(vehicle)
            local damagePct    = math.max(0, (engineHealth / 1000) * 100)

            -- Lights state (handle both 2-return and 3-return native variants)
            local r1, r2, r3 = GetVehicleLightsState(vehicle)
            local lightsOn, highBeamsOn
            if type(r1) == 'boolean' then
                lightsOn    = r2 == 1 or r2 == true
                highBeamsOn = r3 == 1 or r3 == true
            else
                lightsOn    = r1 == 1 or r1 == true
                highBeamsOn = r2 == 1 or r2 == true
            end
            local lightsState = highBeamsOn and 'high' or lightsOn and 'normal' or 'off'

            -- Turbo
            local hasTurbo   = IsToggleModOn(vehicle, 18)
            local turboBoost = 0
            if engineOn and hasTurbo then
                turboBoost = GetVehicleTurboPressure(vehicle) * 2.5
            end
            local turboPct = hasTurbo
                and math.floor(math.min(100, (turboBoost / Config.Engine.turbo.maxBoost) * 100))
                or 0

            -- Nitro level (set by nitrocl.lua via statebag)
            local nitroLevel = DoesEntityExist(vehicle)
                and math.floor(Entity(vehicle).state.nitro or 0)
                or 0

            -- Tire status
            local tires = GetTireStatus(vehicle)

            -- Mileage tracking
            if Config.Vehicle.showMileage and engineOn and speedMs > 0.1 then
                local dt     = (GetGameTimer() - VehicleData.lastUpdate) / 1000
                local distKm = speedMs * dt / 1000

                VehicleData.mileage   = (VehicleData.mileage   or 0) + distKm
                VehicleData.tripMeter = (VehicleData.tripMeter or 0) + distKm

                local flooredMileage = math.floor(VehicleData.mileage)
                local stateMileage   = Entity(vehicle).state.mileage or 0
                if flooredMileage ~= stateMileage then
                    Entity(vehicle).state:set('mileage', flooredMileage, true)
                end

                if flooredMileage > 0
                    and flooredMileage % 5 == 0
                    and flooredMileage ~= (VehicleData._lastSaved or -1)
                then
                    VehicleData._lastSaved = flooredMileage
                    TriggerServerEvent('rde_cockpit:saveMileage',
                        VehicleData.plate,
                        flooredMileage,
                        VehicleData.windshieldDamage or 0,
                        EngineState.damageLevel,
                        EngineState.temperature
                    )
                end
            end
            VehicleData.lastUpdate = GetGameTimer()

            SendNUIMessage({
                action          = 'updateCockpit',
                status          = true,
                engineRunning   = engineOn,
                speed           = math.floor(speed),
                speedPercent    = speedPct,
                speedUnit       = Config.Vehicle.speedUnit,
                rpm             = math.floor(rpm),
                rpmPercent      = rpmPct,
                gear            = gear,
                fuel            = fuel,
                damage          = damagePct,
                lights          = lightsState,
                signals         = PlayerState.signals,
                seatbelt        = seatbeltOn,
                cruiser         = PlayerState.cruiseControl,
                turbo           = turboBoost,
                hasTurbo        = hasTurbo,
                turboPercent    = turboPct,
                nitro           = nitroLevel,
                tires           = tires,
                temperature     = math.floor(EngineState.temperature),
                enginePhase     = EngineState.phase,
                engineDamage    = EngineState.damageLevel,
                performanceLoss = math.floor(EngineState.performanceLoss * 100),
                oilPressure     = VehicleData.oilPressure or 45,
                mileage         = math.floor(VehicleData.mileage or 0),
                tripMeter       = tonumber(string.format('%.1f', VehicleData.tripMeter or 0)),
                windshieldDamage = VehicleData.windshieldDamage or 0,
                gameTime        = GetGameTime(),
            })

            DisplayRadar(true)

        else
            if PlayerState.inVehicle then
                PlayerState.inVehicle     = false
                PlayerState.isDriver      = false
                PlayerState.seatbelt      = false
                PlayerState.cruiseControl = false
                PlayerState.signals       = 'off'
                seatbeltOn                = false

                if vehicle ~= 0 and DoesEntityExist(vehicle) then
                    SetVehicleEnginePowerMultiplier(vehicle, 1.0)
                    SetVehicleEngineTorqueMultiplier(vehicle, 1.0)
                end

                SendNUIMessage({ action = 'updateCockpit', status = false })
                DisplayRadar(false)
            end
        end

        Wait(sleep)
    end
end)

-- ════════════════════════════════════════════════════════════════
-- SEATBELT EJECT THREAD (frame-rate for accurate crash detection)
-- ════════════════════════════════════════════════════════════════
CreateThread(function()
    local prevVelocity = vector3(0, 0, 0)
    local prevSpeed    = 0.0

    while true do
        Wait(0)

        local ped     = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle ~= 0 then
            local vehClass = GetVehicleClass(vehicle)
            if vehClass ~= 8 and Config.Vehicle.allowedClasses[vehClass] then
                local cfg = Config.Vehicle.seatbelt
                SetPedConfigFlag(ped, 32, true)

                if not seatbeltOn then
                    local currSpeed = GetEntitySpeed(vehicle)
                    local vehAcc    = (prevSpeed - currSpeed) / GetFrameTime()

                    if GetEntitySpeedVector(vehicle, true).y > 1.0
                        and prevSpeed > (45.0 / 3.6)
                        and vehAcc > (100 * 9.81)
                    then
                        local impactSeverity = math.min(vehAcc / (150 * 9.81), 1.0)
                        local pos            = GetEntityCoords(ped)

                        SetEntityCoords(ped, pos.x, pos.y, pos.z - 0.47, true, true, true)
                        Wait(10)
                        SetPedToRagdoll(ped, cfg.ragdollTime, cfg.ragdollTime, 0, false, false, false)
                        Wait(50)
                        SetEntityVelocity(ped,
                            2.2 * prevVelocity.x,
                            2.2 * prevVelocity.y,
                            2.2 * prevVelocity.z
                        )

                        SetPedMoveRateOverride(ped, 0.2)
                        CreateThread(function()
                            Wait(cfg.limpDuration)
                            SetPedMoveRateOverride(ped, 1.0)
                        end)

                        if cfg.damageOnEject then
                            local dmg = math.floor(cfg.damageAmount * (1 + impactSeverity))
                            SetEntityHealth(ped, math.max(100, GetEntityHealth(ped) - dmg))
                        end

                        VehicleData.windshieldDamage = math.min(
                            (VehicleData.windshieldDamage or 0) + (Config.Windshield.damagePerCrash or 10),
                            Config.Windshield.maxDamage or 100
                        )
                        if Config.Vehicle.statebagSync then
                            Entity(vehicle).state:set('windshieldDamage', VehicleData.windshieldDamage, true)
                        end

                        if NetworkIsPlayerActive(PlayerId()) then
                            TriggerServerEvent('rde_cockpit:syncEject', {
                                pedNetId         = NetworkGetNetworkIdFromEntity(ped),
                                vehicleNetId     = NetworkGetNetworkIdFromEntity(vehicle),
                                coords           = GetEntityCoords(ped),
                                velocity         = vector3(2.2*prevVelocity.x, 2.2*prevVelocity.y, 2.2*prevVelocity.z),
                                impactSeverity   = impactSeverity,
                                windshieldDamage = VehicleData.windshieldDamage,
                            })
                        end

                        if Config.Notifications.enabled then
                            lib.notify({
                                title       = L('warning'),
                                description = L('crash_ejected'),
                                type        = 'error',
                                duration    = 5000,
                                icon        = Config.Icons.windshield,
                            })
                        end

                        if Config.Sounds.enabled then
                            PlaySoundFrontend(-1, 'Car_Crash', 'Wanted_Sounds', true)
                        end
                    else
                        prevVelocity = GetEntityVelocity(vehicle)
                    end

                    prevSpeed = currSpeed
                else
                    if GetEntitySpeed(vehicle) * 3.6 > 5 then
                        DisableControlAction(0, 75, true)
                    end
                    prevVelocity = GetEntityVelocity(vehicle)
                    prevSpeed    = GetEntitySpeed(vehicle)
                end
            end
        else
            Wait(500)
        end
    end
end)

-- ════════════════════════════════════════════════════════════════
-- SEATBELT TOGGLE
-- ════════════════════════════════════════════════════════════════
RegisterNetEvent('rde_cockpit:toggleSeatbelt', function()
    if not Config.Vehicle.seatbelt.enabled then return end
    local vehicle = cache.vehicle
    if not vehicle or vehicle == 0 then return end
    if GetVehicleClass(vehicle) == 8 then return end

    seatbeltOn = not seatbeltOn

    if Config.Sounds.enabled then
        SendNUIMessage({
            action = 'playSound',
            sound  = seatbeltOn and 'buckle' or 'unbuckle',
            volume = Config.Sounds.volume,
        })
    end

    lib.notify({
        title       = 'Seatbelt',
        description = seatbeltOn and L('seatbelt_on') or L('seatbelt_off'),
        type        = seatbeltOn and 'success' or 'warning',
        duration    = 2000,
        icon        = Config.Icons.seatbelt,
    })

    PlayerState.seatbelt = seatbeltOn
end)

-- ════════════════════════════════════════════════════════════════
-- CRUISE CONTROL THREAD
-- ════════════════════════════════════════════════════════════════
if Config.CruiseControl.enabled then
    CreateThread(function()
        while true do
            if PlayerState.cruiseControl and PlayerState.inVehicle then
                Wait(100)
                local vehicle = cache.vehicle
                if vehicle ~= 0 then
                    local spd = GetEntitySpeed(vehicle) * 3.6
                    if spd < PlayerState.cruiseSpeed - 5 then
                        SetVehicleForwardSpeed(vehicle, PlayerState.cruiseSpeed / 3.6)
                    end
                    if IsControlPressed(0, 72) then
                        PlayerState.cruiseControl = false
                        PlayerState.cruiseSpeed   = 0
                        SetEntityMaxSpeed(vehicle, 500.0)
                        lib.notify({
                            title       = 'Cruise Control',
                            description = L('cruise_deactivated'),
                            type        = 'info',
                            icon        = Config.Icons.cruise,
                        })
                    end
                end
            else
                Wait(400)
            end
        end
    end)
end

-- ════════════════════════════════════════════════════════════════
-- KEY BINDINGS THREAD
-- Handles driver controls + passenger seatbelt (B key for both)
-- ════════════════════════════════════════════════════════════════
CreateThread(function()
    while true do
        Wait(0)

        local vehicle  = cache.vehicle
        local ped      = cache.ped
        local isDriver = vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped

        if vehicle ~= 0 and isDriver then
            -- ── Driver controls ─────────────────────────────
            -- Seatbelt (B)
            if IsControlJustReleased(0, 29) then
                TriggerEvent('rde_cockpit:toggleSeatbelt')
            end

            -- Cruise Control (X)
            if IsControlJustPressed(0, 73) then
                local spd = GetEntitySpeed(vehicle) * 3.6
                if spd >= Config.CruiseControl.minSpeed and spd <= Config.CruiseControl.maxSpeed then
                    PlayerState.cruiseControl = not PlayerState.cruiseControl
                    if PlayerState.cruiseControl then
                        PlayerState.cruiseSpeed = spd
                        SetEntityMaxSpeed(vehicle, spd / 3.6)
                        lib.notify({
                            title       = 'Cruise Control',
                            description = L('cruise_activated', math.floor(spd), Config.Vehicle.speedUnit),
                            type        = 'success',
                            icon        = Config.Icons.cruise,
                        })
                    else
                        SetEntityMaxSpeed(vehicle, 500.0)
                        lib.notify({
                            title       = 'Cruise Control',
                            description = L('cruise_deactivated'),
                            type        = 'info',
                            icon        = Config.Icons.cruise,
                        })
                    end
                end
            end

            -- Signals
            if IsControlJustPressed(0, Config.Keys.signalLeft) then
                PlayerState.signals = PlayerState.signals == 'left' and 'off' or 'left'
                ApplyBlinkers(vehicle, PlayerState.signals)
                TriggerServerEvent('rde_cockpit:syncBlinkers', PlayerState.signals)
            end
            if IsControlJustPressed(0, Config.Keys.signalRight) then
                PlayerState.signals = PlayerState.signals == 'right' and 'off' or 'right'
                ApplyBlinkers(vehicle, PlayerState.signals)
                TriggerServerEvent('rde_cockpit:syncBlinkers', PlayerState.signals)
            end
            if IsControlJustPressed(0, Config.Keys.signalBoth) then
                PlayerState.signals = PlayerState.signals == 'both' and 'off' or 'both'
                ApplyBlinkers(vehicle, PlayerState.signals)
                TriggerServerEvent('rde_cockpit:syncBlinkers', PlayerState.signals)
            end

            PlayerState.inVehicle = true
            PlayerState.isDriver  = true

        elseif vehicle ~= 0 and not isDriver then
            -- ── Passenger: seatbelt key only ────────────────
            if not PlayerState.inVehicle then
                PlayerState.inVehicle = true
                PlayerState.isDriver  = false
            end

            if IsControlJustReleased(0, 29) then
                TriggerEvent('rde_cockpit:toggleSeatbelt')
            end

            Wait(50)

        else
            -- ── Not in vehicle ───────────────────────────────
            if PlayerState.inVehicle then
                PlayerState.inVehicle     = false
                PlayerState.isDriver      = false
                PlayerState.cruiseControl = false
                PlayerState.signals       = 'off'
                seatbeltOn                = false
            end
            Wait(200)
        end
    end
end)

-- ════════════════════════════════════════════════════════════════
-- STATEBAG LISTENERS
-- ════════════════════════════════════════════════════════════════
AddStateBagChangeHandler('mileage', nil, function(bagName, _, value)
    if not value or not PlayerState.inVehicle then return end
    if GetEntityFromStateBagName(bagName) == cache.vehicle then
        VehicleData.mileage = value
    end
end)

AddStateBagChangeHandler('windshieldDamage', nil, function(bagName, _, value)
    if not value or not PlayerState.inVehicle then return end
    if GetEntityFromStateBagName(bagName) == cache.vehicle then
        VehicleData.windshieldDamage = value
    end
end)

AddStateBagChangeHandler('blinkerSignal', nil, function(bagName, _, value)
    if not value then return end
    local entity = GetEntityFromStateBagName(bagName)
    if entity ~= 0 and entity ~= cache.vehicle then
        ApplyBlinkers(entity, value)
    end
end)

-- ════════════════════════════════════════════════════════════════
-- NETWORK EVENTS
-- ════════════════════════════════════════════════════════════════
RegisterNetEvent('rde_cockpit:syncBlinkers', function(playerId, signal)
    if playerId == GetPlayerServerId(PlayerId()) then return end
    local player = GetPlayerFromServerId(playerId)
    if player == -1 then return end
    local ped = GetPlayerPed(player)
    if not DoesEntityExist(ped) then return end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then ApplyBlinkers(veh, signal) end
end)

RegisterNetEvent('rde_cockpit:syncWindshieldDamage', function(netId, damage)
    local veh = NetToVeh(netId)
    if DoesEntityExist(veh) then
        Entity(veh).state:set('windshieldDamage', damage, true)
    end
end)

RegisterNetEvent('rde_cockpit:receiveEject', function(data)
    local ped       = PlayerPedId()
    local remotePed = NetworkGetEntityFromNetworkId(data.pedNetId)
    if remotePed == ped or not DoesEntityExist(remotePed) then return end

    CreateThread(function()
        SetEntityCoords(remotePed, data.coords.x, data.coords.y, data.coords.z, true, true, true)
        SetEntityVelocity(remotePed, data.velocity.x, data.velocity.y, data.velocity.z)
        SetPedToRagdollWithFall(remotePed, 5000, 5000, 0, data.velocity, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
    end)

    local vehicle = NetworkGetEntityFromNetworkId(data.vehicleNetId)
    if DoesEntityExist(vehicle) then
        Entity(vehicle).state:set('windshieldDamage', data.windshieldDamage, true)
    end
end)

-- ════════════════════════════════════════════════════════════════
-- EXPORTS
-- ════════════════════════════════════════════════════════════════
exports('getVehicleData',       function() return VehicleData end)
exports('getPlayerState',       function() return PlayerState end)
exports('getMileage',           function() return math.floor(VehicleData.mileage or 0) end)
exports('isSeatbeltOn',         function() return seatbeltOn end)
exports('getEngineState',       function() return EngineState end)
exports('getEngineTemperature', function() return EngineState.temperature end)
exports('getEnginePhase',       function() return EngineState.phase end)
exports('isEngineDamaged',      function() return EngineState.isPermanentlyDamaged end)

-- ════════════════════════════════════════════════════════════════
-- CLEANUP ON LOGOUT
-- ════════════════════════════════════════════════════════════════
AddEventHandler('ox:playerLogout', function()
    seatbeltOn    = false
    PlayerState   = {
        seatbelt      = false,
        cruiseControl = false,
        cruiseSpeed   = 0,
        signals       = 'off',
        inVehicle     = false,
        isDriver      = false,
    }
end)

-- ════════════════════════════════════════════════════════════════
-- PASSENGER SEATBELT INDICATOR — single source of truth
-- One thread, no shared state with other threads, no flickering.
-- Visible ONLY when genuinely seated as passenger in a vehicle.
-- Hides immediately on foot, as driver, or during transitions.
-- ════════════════════════════════════════════════════════════════
CreateThread(function()
    local shown    = false
    local lastBelt = false

    while true do
        local veh = cache.vehicle
        local ped = cache.ped

        -- Strictly: must be in a real vehicle AND not in driver seat
        local inVeh       = veh ~= 0 and DoesEntityExist(veh)
        local isPassenger = inVeh and (GetPedInVehicleSeat(veh, -1) ~= ped)

        if isPassenger then
            -- Show or refresh when belt state changes
            if not shown or seatbeltOn ~= lastBelt then
                shown    = true
                lastBelt = seatbeltOn
                SendNUIMessage({
                    action   = 'updatePassengerSeatbelt',
                    visible  = true,
                    seatbelt = seatbeltOn,
                })
            end
            Wait(120)
        else
            -- Hide once, then sleep longer
            if shown then
                shown = false
                SendNUIMessage({ action = 'updatePassengerSeatbelt', visible = false })
            end
            -- Poll faster during vehicle transitions (just entered/exiting)
            Wait(inVeh and 50 or 500)
        end
    end
end)

if Config.Debug then
    print('^2[RDE | Cockpit v1.0.0]^0 client/main.lua loaded')
end
