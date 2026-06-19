-- ════════════════════════════════════════════════════════════════
-- RDE | VEHICLE COCKPIT v1.0.1 — CLIENT/ENGINE
-- FIXES v4.1 (legacy, predates rde_carhud merge):
--   - GTA stoppt Motor intern nicht mehr via SetVehicleEngineOn false/true Loops
--   - W-Taste wird via DisableControlAction(0,71) blockiert SOLANGE Motor aus
--   - SetVehicleEngineOn(veh, false, true, false) = instant+force, verhindert
--     dass GTA den Motor selbst wieder anschmeißt wenn man Gas gibt
--   - keepRunningOnExit: korrekte Referenz auf zuletzt benutztes Fahrzeug
--   - Statebag-Handler blockiert eigene Updates (source filter)
--   - Engine-State Machine: STOPPED / STARTING / RUNNING / STOPPING
-- FIXES v1.0.1 (2026-06-19):
--   - vehState[plate] defaulted unknown plates to 'stopped' → jacking a
--     running NPC vehicle force-killed the engine instantly. Now mirrors
--     GetIsVehicleEngineRunning() when no StateBag record exists at all.
--   - Vehicle-exit race condition: the delayed (Wait(200)) engine-restore
--     thread read the shared `currentVehicle` upvalue, which the separate
--     ENTER-detection thread could reset to 0 in the same window —
--     "engine stays on" worked maybe 50% of the time depending on poll
--     timing. Now snapshots the vehicle handle locally before scheduling
--     the delayed thread, and explicitly re-syncs via SetState() so every
--     client + the server's persisted cache agree.
-- ════════════════════════════════════════════════════════════════

local function L(key, ...)
    local t = locale and locale[key]
    if not t then return '[' .. key .. ']' end
    if select('#', ...) > 0 then return string.format(t, ...) end
    return t
end

-- ════════════════════════════════════════════════════════════════
-- GLOBAL ENGINE STATE (read by client/main.lua)
-- ════════════════════════════════════════════════════════════════
EngineState = {
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
-- PER-VEHICLE STATE
-- States: 'stopped' | 'starting' | 'running' | 'stopping'
-- ════════════════════════════════════════════════════════════════
local vehState        = {}   -- plate -> 'stopped'|'starting'|'running'|'stopping'
local vehicleNeonState = {}
local vehicleWindows   = {}

local currentVehicle   = 0
local lastKnownPlate   = nil
local selfSetting      = false  -- guard: prevents statebag echo loop

-- Notification cooldown
local notifCooldown = {}
local function CanNotify(key, cd)
    local now = GetGameTimer()
    if not notifCooldown[key] or (now - notifCooldown[key]) > (cd or 10000) then
        notifCooldown[key] = now
        return true
    end
    return false
end

-- ════════════════════════════════════════════════════════════════
-- HELPERS
-- ════════════════════════════════════════════════════════════════
local function GetPlate(veh)
    if not DoesEntityExist(veh) then return nil end
    return GetVehicleNumberPlateText(veh):gsub('%s+', '')
end

-- The ONLY place we call SetVehicleEngineOn
-- instant=true prevents GTA from applying a delay and re-triggering
-- forceStart=false means we're in full control
local function ForceEngineOn(veh)
    if not DoesEntityExist(veh) then return end
    SetVehicleEngineOn(veh, true, true, true)
end

local function ForceEngineOff(veh)
    if not DoesEntityExist(veh) then return end
    -- true,true = instant off; last true = script override (prevents auto-restart)
    SetVehicleEngineOn(veh, false, true, true)
    -- Belt-and-suspenders: also kill ignition state
    SetVehicleUndriveable(veh, false)
end

local function GetState(plate)
    return vehState[plate] or 'stopped'
end

local function SetState(veh, plate, state)
    vehState[plate] = state
    selfSetting = true
    Entity(veh).state:set('rde_engineRunning', state == 'running', true)
    selfSetting = false
    TriggerServerEvent('rde_cockpit:syncEngineState', plate, state == 'running')
end

-- ════════════════════════════════════════════════════════════════
-- ENGINE EFFECTS / SOUNDS
-- ════════════════════════════════════════════════════════════════
local function StopEngineEffects()
    if EngineState.particleHandle then
        StopParticleFxLooped(EngineState.particleHandle, false)
        EngineState.particleHandle = nil
    end
    if EngineState.steamHandle then
        StopParticleFxLooped(EngineState.steamHandle, false)
        EngineState.steamHandle = nil
    end
    if EngineState.soundId then
        StopSound(EngineState.soundId)
        ReleaseScriptAudioId(EngineState.soundId)
        EngineState.soundId = nil
    end
end

local function GetEngineBonePos(veh)
    local bone = GetEntityBoneIndexByName(veh, 'engine')
    if bone ~= -1 then return GetWorldPositionOfEntityBone(veh, bone) end
    local p = GetEntityCoords(veh)
    return p + GetEntityForwardVector(veh) * 2.0 + vec3(0,0,0.5)
end

local function UpdateEngineEffects(veh, phase, temp)
    if not Config.Engine.temperature.effects.enabled then return end
    if not DoesEntityExist(veh) then return end
    local eff = Config.Engine.temperature.effects
    local pos = GetEngineBonePos(veh)

    local function StartLooped(particle, asset, scale)
        lib.requestNamedPtfxAsset(particle)
        UseParticleFxAsset(particle)
        return StartParticleFxLoopedAtCoord(asset, pos.x, pos.y, pos.z, 0,0,0, scale, false,false,false,false)
    end

    if temp >= eff.darkSmoke.startTemp or EngineState.isPermanentlyDamaged then
        if not EngineState.particleHandle or not DoesParticleFxLoopedExist(EngineState.particleHandle) then
            StopEngineEffects()
            EngineState.particleHandle = StartLooped(eff.darkSmoke.particle, eff.darkSmoke.asset, eff.darkSmoke.scale)
        end
    elseif temp >= eff.lightSmoke.startTemp then
        if not EngineState.particleHandle or not DoesParticleFxLoopedExist(EngineState.particleHandle) then
            StopEngineEffects()
            EngineState.particleHandle = StartLooped(eff.lightSmoke.particle, eff.lightSmoke.asset, eff.lightSmoke.scale)
        end
    else
        if EngineState.particleHandle then
            StopParticleFxLooped(EngineState.particleHandle, false)
            EngineState.particleHandle = nil
        end
    end

    if eff.steam.enabled and temp > eff.steam.temp and phase == 'hot' then
        if not EngineState.steamHandle or not DoesParticleFxLoopedExist(EngineState.steamHandle) then
            EngineState.steamHandle = StartLooped(eff.steam.particle, eff.steam.asset, eff.steam.scale)
        end
    else
        if EngineState.steamHandle then
            StopParticleFxLooped(EngineState.steamHandle, false)
            EngineState.steamHandle = nil
        end
    end
end

local function UpdateEngineSounds(phase, temp)
    if not Config.Engine.temperature.sounds.enabled then return end
    local cfg = Config.Engine.temperature.sounds
    local now = GetGameTimer()

    if phase == 'hot' and temp >= cfg.warningBeep.temp then
        if not EngineState.soundId and (now - (EngineState.lastWarningTime or 0)) > 5000 then
            EngineState.soundId = GetSoundId()
            PlaySoundFrontend(EngineState.soundId, cfg.warningBeep.sound, cfg.warningBeep.soundSet, true)
            EngineState.lastWarningTime = now
        end
    elseif (phase == 'critical' or phase == 'overheating') and temp >= cfg.criticalAlarm.temp then
        if not EngineState.soundId then
            EngineState.soundId = GetSoundId()
            PlaySoundFrontend(EngineState.soundId, cfg.criticalAlarm.sound, cfg.criticalAlarm.soundSet, true)
        end
    else
        if EngineState.soundId then
            StopSound(EngineState.soundId)
            ReleaseScriptAudioId(EngineState.soundId)
            EngineState.soundId = nil
        end
    end
end

-- ════════════════════════════════════════════════════════════════
-- ENGINE TEMPERATURE
-- ════════════════════════════════════════════════════════════════
local function GetEnginePhase(temp)
    local c = Config.Engine.temperature
    if     temp < c.normalTemp   then return 'cold'
    elseif temp < c.warmTemp     then return 'normal'
    elseif temp < c.hotTemp      then return 'warm'
    elseif temp < c.criticalTemp then return 'hot'
    elseif temp < c.overheatTemp then return 'critical'
    elseif temp < c.damageTemp   then return 'overheating'
    else                              return 'damaged'
    end
end

local function SendEngineNotification(phase, temp)
    if not Config.Engine.temperature.notifications.enabled then return end
    local cfg = Config.Engine.temperature.notifications
    if phase == 'hot' and cfg.showWarnings and CanNotify('eng_hot') then
        lib.notify({ title='⚠️ '..L('warning'), description=L('engine_hot',temp), type='warning', duration=5000, icon=Config.Icons.engine })
    elseif phase == 'critical' and cfg.showCritical and CanNotify('eng_critical') then
        lib.notify({ title='🔥 '..L('error'), description=L('engine_critical',temp), type='error', duration=6000, icon=Config.Icons.engine })
    elseif phase == 'overheating' and cfg.showCritical and CanNotify('eng_overheat') then
        lib.notify({ title='🔥 '..L('error'), description=L('engine_overheating',temp), type='error', duration=7000, icon=Config.Icons.engine })
    elseif phase == 'damaged' and cfg.showDamage and CanNotify('eng_damaged', 20000) then
        lib.notify({ title='💀 '..L('error'), description=L('engine_damaged',temp), type='error', duration=10000, icon=Config.Icons.engine })
        EngineState.isPermanentlyDamaged = true
        EngineState.damageLevel = math.min(100, EngineState.damageLevel + 25)
    end
end

local function CalculatePerformanceLoss(phase)
    if not Config.Engine.temperature.performanceLoss.enabled then return 0.0 end
    local cfg = Config.Engine.temperature.performanceLoss
    local loss = 0.0
    if     phase == 'hot'                                   then loss = cfg.hotLoss
    elseif phase == 'critical'                              then loss = cfg.criticalLoss
    elseif phase == 'overheating'                           then loss = cfg.overheatLoss
    elseif phase == 'damaged' or EngineState.isPermanentlyDamaged then loss = cfg.damagedLoss
    end
    loss = loss + (EngineState.damageLevel / 100) * 0.3
    return math.min(1.0, loss)
end

local function ApplyEngineDamage(veh, loss)
    if not DoesEntityExist(veh) then return end
    local mult = 1.0 - loss
    SetVehicleEnginePowerMultiplier(veh, mult)
    SetVehicleEngineTorqueMultiplier(veh, mult)
    if EngineState.isPermanentlyDamaged then
        SetVehicleUndriveable(veh, loss > 0.6)
    end
end

CreateThread(function()
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
            local plate = GetPlate(veh)
            if plate and GetState(plate) == 'running' then
                local c       = Config.Engine.temperature
                local speed   = GetEntitySpeed(veh) * 3.6
                local running = GetIsVehicleEngineRunning(veh)
                local temp    = EngineState.temperature
                local change  = 0.0

                if running then
                    if speed > 100 then change = -c.highwayCoolRate
                    elseif speed > 80 then change = c.highwayHeatRate - c.highwayCoolRate
                    elseif speed > 30 then change = c.cityHeatRate - c.cityDriveCoolRate
                    else change = c.idleHeatRate - c.idleCoolRate end

                    local engHealth = GetVehicleEngineHealth(veh)
                    if engHealth < c.lowHealthThreshold and change > 0 then
                        change = change * c.damagedHeatMultiplier
                    end
                    if EngineState.isPermanentlyDamaged and change > 0 then
                        change = change * 1.8
                    end
                    EngineState.coolingDownSince = 0
                else
                    change = -c.stillCoolRate
                end

                temp = math.max(c.minTemp, temp + change)

                if temp >= c.permanentDamageThreshold and not EngineState.isPermanentlyDamaged then
                    EngineState.isPermanentlyDamaged = true
                    EngineState.damageLevel = 50
                end

                if c.recoveryEnabled and not EngineState.isPermanentlyDamaged
                    and temp < c.recoveryThreshold and not running then
                    if EngineState.coolingDownSince == 0 then
                        EngineState.coolingDownSince = GetGameTimer()
                    elseif (GetGameTimer() - EngineState.coolingDownSince) > c.recoveryTime then
                        EngineState.damageLevel = math.max(0, EngineState.damageLevel - 20)
                        if EngineState.damageLevel <= 0 then
                            EngineState.coolingDownSince = 0
                            if c.notifications.enabled then
                                lib.notify({ title=L('success'), description=L('engine_recovered'), type='success', duration=4000, icon=Config.Icons.engine })
                            end
                        end
                    end
                end

                EngineState.temperature = temp
                local newPhase = GetEnginePhase(temp)
                local phaseChanged = newPhase ~= EngineState.phase
                EngineState.phase = newPhase
                EngineState.performanceLoss = CalculatePerformanceLoss(newPhase)
                ApplyEngineDamage(veh, EngineState.performanceLoss)
                UpdateEngineEffects(veh, newPhase, temp)
                UpdateEngineSounds(newPhase, temp)
                if phaseChanged then SendEngineNotification(newPhase, temp) end

                local stateBagTemp = Entity(veh).state.engineTemp or 90
                if math.abs(temp - stateBagTemp) > 2 then
                    Entity(veh).state:set('engineTemp', math.floor(temp), true)
                    Entity(veh).state:set('engineDamage', EngineState.damageLevel, true)
                end
            end
        end
    end
end)

-- ════════════════════════════════════════════════════════════════
-- ENGINE MAINTENANCE THREAD
-- Runs every frame ONLY when in vehicle as driver.
-- Keeps GTA from auto-restarting the engine.
-- Blocks W throttle when stopped/starting.
-- ════════════════════════════════════════════════════════════════
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
            local plate = GetPlate(veh)
            if plate then
                local state = GetState(plate)

                if state == 'stopped' or state == 'stopping' then
                    -- Keep forcing engine off — GTA will try to restart it on gas input
                    if GetIsVehicleEngineRunning(veh) then
                        ForceEngineOff(veh)
                    end
                    -- Block throttle (71 = VehicleAccelerate)
                    if Config.EngineControl.blockThrottleWhenOff then
                        DisableControlAction(0, 71, true)
                    end
                    -- Show hint
                    if CanNotify('throttle_hint_'..plate, 8000) then
                        lib.notify({
                            title       = L('info'),
                            description = L('engine_off'),
                            type        = 'info',
                            duration    = 4000,
                            icon        = Config.Icons.engine,
                        })
                    end
                    Wait(0)

                elseif state == 'starting' then
                    -- Block throttle during start sequence
                    if Config.EngineControl.blockThrottleWhenOff then
                        DisableControlAction(0, 71, true)
                    end
                    Wait(0)

                else -- running
                    -- Engine is running: release control, do nothing
                    Wait(200)
                end
            else
                Wait(100)
            end
        else
            Wait(300)
        end
    end
end)

-- ════════════════════════════════════════════════════════════════
-- ENGINE TOGGLE — M key (via RegisterKeyMapping)
-- State machine: stopped -> starting -> running -> stopping -> stopped
-- ════════════════════════════════════════════════════════════════
local function StartEngine(veh)
    local plate = GetPlate(veh)
    if not plate then return end

    local state = GetState(plate)
    if state == 'running' then
        if CanNotify('eng_already', 3000) then
            lib.notify({ title=L('info'), description=L('engine_running'), type='info', duration=2000, icon=Config.Icons.engine })
        end
        return
    end
    if state == 'starting' or state == 'stopping' then return end

    -- Immediately set starting so the frame thread blocks W
    vehState[plate] = 'starting'
    ForceEngineOff(veh)

    local ped = PlayerPedId()

    -- ── Phase 1: Key-fob / ignition click animation (instant) ──────
    if Config.EngineControl.useStartAnimation then
        local dict = 'anim@mp_player_intmenu@key_fob@'
        RequestAnimDict(dict)
        local t = 0
        while not HasAnimDictLoaded(dict) and t < 30 do Wait(20); t=t+1 end
        if HasAnimDictLoaded(dict) then
            TaskPlayAnim(ped, dict, 'fob_click', 8.0, 1.0, 800, 48, 0, false, false, false)
        end
    end

    -- ── Phase 2: Ignition click sound (key turn) ─────────────────
    SendNUIMessage({ action = 'engineStart', phase = 'click' })
    Wait(350)

    -- ── Phase 3: Starter cranking ─────────────────────────────────
    -- Notify player engine is trying to start
    lib.notify({ title=L('info'), description=L('engine_starting'), type='info',
        duration=Config.EngineControl.startDelay, icon=Config.Icons.engine })

    SendNUIMessage({ action = 'engineStart', phase = 'crank', duration = Config.EngineControl.startDelay })

    -- Crank the starter: RPM needle should bounce a little
    -- We achieve this by briefly flicking engine on/off during crank
    CreateThread(function()
        if not DoesEntityExist(veh) then vehState[plate] = 'stopped'; return end

        -- Crank phase: 3 short "tries" over startDelay ms
        local crankSteps = 3
        local stepTime   = math.floor(Config.EngineControl.startDelay / crankSteps)

        for i = 1, crankSteps do
            if GetState(plate) ~= 'starting' then return end
            -- Brief engine flick so RPM needle moves realistically
            SetVehicleEngineOn(veh, true, true, true)
            Wait(80)
            SetVehicleEngineOn(veh, false, true, true)
            Wait(stepTime - 80)
        end

        -- ── Phase 4: Engine fires ──────────────────────────────────
        if not DoesEntityExist(veh) or GetState(plate) ~= 'starting' then
            vehState[plate] = 'stopped'; return
        end

        SendNUIMessage({ action = 'engineStart', phase = 'fire' })
        ForceEngineOn(veh)
        SetState(veh, plate, 'running')

        if Config.EngineControl.useStartAnimation then
            StopAnimTask(ped, 'anim@mp_player_intmenu@key_fob@', 'fob_click', 1.0)
        end

        lib.notify({ title=L('success'), description=L('engine_started'), type='success', duration=3000, icon=Config.Icons.engine })

        if Config.Debug then print(('[RDE Engine] START (realistic): %s'):format(plate)) end
    end)
end

local function StopEngine(veh)
    local plate = GetPlate(veh)
    if not plate then return end

    local state = GetState(plate)
    if state == 'stopped' then return end
    if state == 'stopping' then return end

    -- Immediately set stopping so the maintenance thread kills it
    vehState[plate] = 'stopping'
    ForceEngineOff(veh)

    -- Reset power
    SetVehicleEnginePowerMultiplier(veh, 1.0)
    SetVehicleEngineTorqueMultiplier(veh, 1.0)
    StopEngineEffects()

    -- Short delay then mark fully stopped
    CreateThread(function()
        Wait(200)
        if GetState(plate) == 'stopping' then
            SetState(veh, plate, 'stopped')
        end
    end)

    lib.notify({ title=L('info'), description=L('engine_stopped'), type='info', duration=2000, icon=Config.Icons.engine })
    if Config.Debug then print(('[RDE Engine] STOP: %s'):format(plate)) end
end

RegisterCommand('rde_toggleengine', function()
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if not DoesEntityExist(veh) then return end
    local plate = GetPlate(veh)
    if not plate then return end

    local state = GetState(plate)
    if state == 'running' then
        StopEngine(veh)
    elseif state == 'stopped' then
        StartEngine(veh)
    end
    -- ignore if starting/stopping (in progress)
end, false)

RegisterKeyMapping('rde_toggleengine', 'Toggle engine on/off', 'keyboard', Config.EngineControl.toggleKey)

-- ════════════════════════════════════════════════════════════════
-- VEHICLE ENTER — restore engine state
-- ════════════════════════════════════════════════════════════════
CreateThread(function()
    while true do
        Wait(500)
        local ped   = PlayerPedId()
        local veh   = GetVehiclePedIsIn(ped, false)
        local plate = veh ~= 0 and GetPlate(veh) or nil

        if plate and plate ~= lastKnownPlate then
            lastKnownPlate = plate
            currentVehicle = veh

            -- Ask server for persisted state first
            TriggerServerEvent('rde_cockpit:requestEngineState', plate)

            -- Check statebag as immediate fallback
            local sbRunning = Entity(veh).state.rde_engineRunning
            if sbRunning == true and not vehState[plate] then
                vehState[plate] = 'running'
                ForceEngineOn(veh)
            elseif sbRunning == false then
                vehState[plate] = 'stopped'
                ForceEngineOff(veh)
            elseif sbRunning == nil and not vehState[plate] then
                -- BUGFIX: no StateBag record exists at all for this plate yet
                -- (e.g. an NPC-driven vehicle nobody ever touched via this
                -- script). The old code treated "no record" the same as
                -- "engine off" and force-killed it the instant you jacked a
                -- running NPC car. Mirror the vehicle's REAL current engine
                -- state instead — no forced toggle, just acknowledge reality
                -- and sync that as the new baseline for other clients/server.
                SetState(veh, plate, GetIsVehicleEngineRunning(veh) and 'running' or 'stopped')
            end

            -- Restore neon
            local neonOn = vehicleNeonState[plate]
            if neonOn ~= nil then
                for i = 0, 3 do SetVehicleNeonLightEnabled(veh, i, neonOn) end
            end

            if Config.Debug then
                print(('[RDE Engine] Entered vehicle: %s | state: %s'):format(plate, GetState(plate)))
            end
        end

        if plate == nil then
            lastKnownPlate = nil
            currentVehicle = 0
        end
    end
end)

-- ════════════════════════════════════════════════════════════════
-- VEHICLE EXIT — keep engine running if it was on
-- ════════════════════════════════════════════════════════════════
AddEventHandler('getOutOfVehicle', function() end) -- no native event, use poll below

CreateThread(function()
    local prevInVeh = false

    while true do
        Wait(100)
        local ped     = PlayerPedId()
        local inVeh   = IsPedInAnyVehicle(ped, false)

        if prevInVeh and not inVeh then
            -- Just exited — lastKnownPlate still has the plate
            local plate = lastKnownPlate
            if plate and currentVehicle ~= 0 and DoesEntityExist(currentVehicle) then
                local state = GetState(plate)

                if state == 'running' and Config.EngineControl.keepRunningOnExit then
                    -- BUGFIX (race condition): the ENTER thread (separate
                    -- 500ms poll) resets the shared `currentVehicle` upvalue
                    -- to 0 as soon as it sees you on foot — which can land
                    -- inside this 200ms window and silently skip
                    -- ForceEngineOn below ("mal an, mal aus"). Snapshot the
                    -- handle into a fresh local now so the delayed thread
                    -- can't have it pulled out from under it.
                    local exitedVehicle = currentVehicle
                    local exitedPlate   = plate
                    CreateThread(function()
                        Wait(200) -- wait for GTA's own exit routine
                        if DoesEntityExist(exitedVehicle) then
                            ForceEngineOn(exitedVehicle)
                            -- Explicit re-sync: GTA's exit routine killed the
                            -- engine natively, we just restarted it — make
                            -- sure every other client + the server's
                            -- persisted cache agree via the StateBag, instead
                            -- of silently relying on whatever was set before.
                            SetState(exitedVehicle, exitedPlate, 'running')
                            if CanNotify('exit_engine', 8000) then
                                lib.notify({ title=L('info'), description=L('engine_keeps_running'), type='info', duration=3000, icon=Config.Icons.engine })
                            end
                        end
                    end)
                elseif state == 'running' and not Config.EngineControl.keepRunningOnExit then
                    -- Config says stop on exit
                    StopEngine(currentVehicle)
                end
            end

            StopEngineEffects()
        end

        prevInVeh = inVeh
    end
end)

-- ════════════════════════════════════════════════════════════════
-- NEON TOGGLE (N)
-- ════════════════════════════════════════════════════════════════
local function ToggleNeon(veh)
    if not DoesEntityExist(veh) then return end
    local plate = GetPlate(veh)
    if not plate then return end

    vehicleNeonState[plate] = not (vehicleNeonState[plate] or false)
    local on = vehicleNeonState[plate]
    for i = 0, 3 do SetVehicleNeonLightEnabled(veh, i, on) end
    Entity(veh).state:set('rde_neonOn', on, true)

    lib.notify({ title=L('info'), description=on and L('neon_on') or L('neon_off'), type='info', duration=2000,
        icon=Config.Icons.neon, iconColor=on and '#f59e0b' or '#6b7280' })
end

RegisterCommand('rde_toggleneon', function()
    ToggleNeon(GetVehiclePedIsIn(PlayerPedId(), false))
end, false)
RegisterKeyMapping('rde_toggleneon', 'Toggle neon lights', 'keyboard', Config.EngineControl.neonKey)

-- ════════════════════════════════════════════════════════════════
-- WINDOWS MENU (K)
-- ════════════════════════════════════════════════════════════════
local function HandleWindows(veh)
    if not DoesEntityExist(veh) then return end
    local plate = GetPlate(veh)
    if not plate then return end

    vehicleWindows[plate] = vehicleWindows[plate] or { FrontLeft=true, FrontRight=true, RearLeft=true, RearRight=true }
    local w = vehicleWindows[plate]

    local wins = {
        { key='FrontLeft',  label=L('window_front_left'),  idx=0 },
        { key='FrontRight', label=L('window_front_right'), idx=1 },
        { key='RearLeft',   label=L('window_rear_left'),   idx=2 },
        { key='RearRight',  label=L('window_rear_right'),  idx=3 },
    }

    local options = {}
    for _, win in ipairs(wins) do
        local isUp = w[win.key]
        options[#options+1] = {
            title       = win.label,
            description = isUp and L('window_status_up') or L('window_status_down'),
            icon        = Config.Icons.window,
            onSelect    = function()
                w[win.key] = not w[win.key]
                if w[win.key] then RollUpWindow(veh, win.idx) else RollDownWindow(veh, win.idx) end
                lib.notify({ title=L('info'), description=w[win.key] and L('window_up') or L('window_down'), type='info', duration=1500 })
            end,
        }
    end
    options[#options+1] = {
        title    = L('window_toggle_all'),
        icon     = Config.Icons.window,
        onSelect = function()
            local allUp = w.FrontLeft and w.FrontRight and w.RearLeft and w.RearRight
            for _, win in ipairs(wins) do
                w[win.key] = not allUp
                if w[win.key] then RollUpWindow(veh, win.idx) else RollDownWindow(veh, win.idx) end
            end
            lib.notify({ title=L('info'), description=not allUp and L('all_windows_up') or L('all_windows_down'), type='info', duration=2000 })
        end,
    }

    lib.registerContext({ id='rde_window_menu', title=L('window_menu_title'), options=options })
    lib.showContext('rde_window_menu')
end

RegisterCommand('rde_windows', function()
    HandleWindows(GetVehiclePedIsIn(PlayerPedId(), false))
end, false)
RegisterKeyMapping('rde_windows', 'Open window control menu', 'keyboard', Config.EngineControl.windowsKey)

-- ════════════════════════════════════════════════════════════════
-- STATEBAG LISTENERS
-- selfSetting guard prevents echo loop when we set it ourselves
-- ════════════════════════════════════════════════════════════════
AddStateBagChangeHandler('rde_engineRunning', nil, function(bagName, _, value)
    if selfSetting or value == nil then return end
    local entity = GetEntityFromStateBagName(bagName)
    if not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then return end

    -- Only apply to vehicles OTHER than the one we're currently driving
    local ped = PlayerPedId()
    if GetPedInVehicleSeat(entity, -1) == ped then return end

    -- Sync visual engine state for other players' vehicles
    if value then ForceEngineOn(entity) else ForceEngineOff(entity) end
end)

AddStateBagChangeHandler('rde_neonOn', nil, function(bagName, _, value)
    if value == nil then return end
    local entity = GetEntityFromStateBagName(bagName)
    if not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then return end
    for i = 0, 3 do SetVehicleNeonLightEnabled(entity, i, value) end
end)

-- ════════════════════════════════════════════════════════════════
-- NETWORK EVENTS
-- ════════════════════════════════════════════════════════════════
RegisterNetEvent('rde_cockpit:receiveEngineState', function(plate, running)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if not DoesEntityExist(veh) then return end
    if GetPlate(veh) ~= plate then return end

    -- Only apply if we don't already have a definitive state
    local cur = GetState(plate)
    if cur == 'stopped' or cur == 'running' then
        -- Already set locally, server just confirms
        if running and cur ~= 'running' then
            vehState[plate] = 'running'
            ForceEngineOn(veh)
        elseif not running and cur ~= 'stopped' then
            vehState[plate] = 'stopped'
            ForceEngineOff(veh)
        end
    else
        vehState[plate] = running and 'running' or 'stopped'
        if running then ForceEngineOn(veh) else ForceEngineOff(veh) end
    end
end)

RegisterNetEvent('rde_cockpit:adminEngineStop', function()
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if DoesEntityExist(veh) then
        local plate = GetPlate(veh)
        vehState[plate] = 'stopped'
        ForceEngineOff(veh)
        lib.notify({ title=L('warning'), description=L('admin_stop_all'), type='error', duration=5000, icon=Config.Icons.engine })
    end
end)

RegisterNetEvent('rde_cockpit:adminEngineStart', function()
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if DoesEntityExist(veh) then
        local plate = GetPlate(veh)
        vehState[plate] = 'running'
        ForceEngineOn(veh)
        lib.notify({ title=L('success'), description=L('admin_start_all'), type='success', duration=5000, icon=Config.Icons.engine })
    end
end)

-- ════════════════════════════════════════════════════════════════
-- EXPORTS
-- ════════════════════════════════════════════════════════════════
exports('isEngineRunning',  function(plate) return GetState(plate) == 'running' end)
exports('getEngineState',   function() return EngineState end)
exports('startEngine',      function(plate)
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if DoesEntityExist(veh) and GetPlate(veh) == plate then StartEngine(veh) end
end)
exports('stopEngine',       function(plate)
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if DoesEntityExist(veh) and GetPlate(veh) == plate then StopEngine(veh) end
end)

-- ════════════════════════════════════════════════════════════════
-- CLEANUP
-- ════════════════════════════════════════════════════════════════
AddEventHandler('ox:playerLogout', function()
    StopEngineEffects()
    vehState         = {}
    vehicleNeonState = {}
    vehicleWindows   = {}
    lastKnownPlate   = nil
    currentVehicle   = 0
    EngineState = {
        temperature=90, phase='normal', isPermanentlyDamaged=false,
        damageLevel=0, performanceLoss=0.0, lastWarningTime=0,
        coolingDownSince=0, particleHandle=nil, steamHandle=nil, soundId=nil,
    }
end)

if Config.Debug then
    print('^2[RDE | Cockpit v1.0.1]^0 engine.lua loaded — M=engine, N=neon, K=windows')
end
