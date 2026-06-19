-- ════════════════════════════════════════════════════════════════
-- RDE | VEHICLE COCKPIT v1.0.1 — CLIENT/VEHICLEFAILURE
-- Next-gen rewrite of esx_RealisticVehicleFailure
--
-- Architecture:
--   DRIVER (owns vehicle):  damage amplification, cascading failure,
--                           torque loss, statebag phase sync
--   ALL CLIENTS:            AddStateBagChangeHandler → particles via
--                           entity-bone attachment (follows car perfectly)
--
-- Zero TriggerClientEvent spam. Zero polling for effects.
-- Every player sees identical effects in realtime via StateBag.
-- ════════════════════════════════════════════════════════════════

if not Config.VehicleFailure or not Config.VehicleFailure.enabled then return end

local function Debug(msg, ...)
    if not Config.Debug then return end
    print(('^4[RDE VF]^7 ' .. tostring(msg)):format(...))
end

-- ════════════════════════════════════════════════════════════════
-- CONSTANTS
-- ════════════════════════════════════════════════════════════════

local PHASE_HEALTHY   = 'healthy'
local PHASE_DEGRADING = 'degrading'
local PHASE_CRITICAL  = 'critical'
local PHASE_LIMP      = 'limp'
local PHASE_DEAD      = 'dead'

-- Phase → minimum required engine health
local PHASE_ORDER = { PHASE_HEALTHY, PHASE_DEGRADING, PHASE_CRITICAL, PHASE_LIMP, PHASE_DEAD }

-- ════════════════════════════════════════════════════════════════
-- STATE
-- ════════════════════════════════════════════════════════════════

-- Per-vehicle effect handles — keyed by vehicle entity handle
-- Used by ALL clients (driver + passengers + nearby players)
-- [veh] = { phase, smoke1, smoke2, fire, sparks, oil }
local VehicleEffects = {}

-- Per-vehicle original handling values — keyed by vehicle handle
-- Restored when driver exits
local OrigHandling = {}

-- Driver-side state (single player, not synced)
local State = {
    phase       = PHASE_HEALTHY,
    lastEngineH = 1000.0,
    lastBodyH   = 1000.0,
    lastTankH   = 1000.0,
    justEntered = true,       -- true on first tick in a new vehicle
    lastVeh     = 0,
    sparkTimer  = 0,          -- cooldown for spark bursts
}

-- ════════════════════════════════════════════════════════════════
-- HELPERS
-- ════════════════════════════════════════════════════════════════

local function GetBoneIdx(veh, boneName, fallback)
    local idx = GetEntityBoneIndexByName(veh, boneName)
    if idx ~= -1 then return idx end
    return fallback or 0
end

-- Request ptfx asset with timeout guard (non-blocking via Create Thread)
local PtfxLoaded = {}
local function EnsurePtfx(ptfx, callback)
    if PtfxLoaded[ptfx] and HasNamedPtfxAssetLoaded(ptfx) then
        callback()
        return
    end
    CreateThread(function()
        RequestNamedPtfxAsset(ptfx)
        local t = 0
        while not HasNamedPtfxAssetLoaded(ptfx) and t < 100 do
            Wait(10); t = t + 1
        end
        if HasNamedPtfxAssetLoaded(ptfx) then
            PtfxLoaded[ptfx] = true
            callback()
        end
    end)
end

-- Start looped particle attached to entity bone (follows the vehicle!)
-- Returns handle or nil
local function StartBonePtfx(ptfx, fx, veh, boneIdx, scale, ox, oy, oz)
    if not HasNamedPtfxAssetLoaded(ptfx) then return nil end
    UseParticleFxAsset(ptfx)
    local handle = StartParticleFxLoopedOnEntityBone_2(
        fx, veh,
        ox or 0.0, oy or 0.0, oz or 0.2,
        0.0, 0.0, 0.0,
        boneIdx,
        scale,
        false, false, false
    )
    return (handle ~= 0) and handle or nil
end

-- One-shot spark burst attached to entity bone
local function BurstBonePtfx(ptfx, fx, veh, boneIdx, scale)
    if not HasNamedPtfxAssetLoaded(ptfx) then return end
    UseParticleFxAsset(ptfx)
    StartParticleFxNonLoopedOnEntity(fx, veh, 0, 0, 0.1, 0, 0, 0, scale, false, false, false)
end

-- Determine phase from engine health
local function GetPhase(engH)
    local t = Config.VehicleFailure.phaseThresholds
    if     engH >= t.degrading  then return PHASE_HEALTHY
    elseif engH >= t.critical   then return PHASE_DEGRADING
    elseif engH >= t.limp       then return PHASE_CRITICAL
    elseif engH > 0             then return PHASE_LIMP
    else                              return PHASE_DEAD
    end
end

local function IsBlacklistedClass(veh)
    return Config.VehicleFailure.blacklistClasses[GetVehicleClass(veh)] == true
end

-- ════════════════════════════════════════════════════════════════
-- EFFECT MANAGEMENT
-- Starts / stops entity-bone-attached particles.
-- Called by the StateBag handler on ALL clients.
-- ════════════════════════════════════════════════════════════════

local function StopHandle(handle)
    if handle and DoesParticleFxLoopedExist(handle) then
        StopParticleFxLooped(handle, false)
    end
end

local function ClearEffects(veh)
    local eff = VehicleEffects[veh]
    if not eff then return end
    StopHandle(eff.smoke1)
    StopHandle(eff.smoke2)
    StopHandle(eff.fire)
    StopHandle(eff.oil)
    VehicleEffects[veh] = nil
    Debug('Effects cleared: veh=%d', veh)
end

local function ApplyEffects(veh, phase)
    if not DoesEntityExist(veh) then return end

    ClearEffects(veh)
    if phase == PHASE_HEALTHY or phase == PHASE_DEGRADING then return end

    local cfg     = Config.VehicleFailure.effects
    local engBone = GetBoneIdx(veh, 'engine', 0)
    local effCfg  = cfg.criticalSmoke

    if     phase == PHASE_CRITICAL then effCfg = cfg.criticalSmoke
    elseif phase == PHASE_LIMP     then effCfg = cfg.limpSmoke
    elseif phase == PHASE_DEAD     then effCfg = cfg.deadSmoke
    end

    -- Load ptfx and spawn particles once loaded
    local ptfx = effCfg.ptfx
    EnsurePtfx(ptfx, function()
        if not DoesEntityExist(veh) then return end  -- vehicle might be gone by now

        local eff = { phase = phase }

        -- Main engine smoke
        eff.smoke1 = StartBonePtfx(ptfx, effCfg.fx, veh, engBone, effCfg.scale, 0, 0, 0.3)

        -- Dead phase: add fire + second thick smoke
        if phase == PHASE_DEAD then
            EnsurePtfx(cfg.deadFire.ptfx, function()
                if not DoesEntityExist(veh) then return end
                eff.fire = StartBonePtfx(cfg.deadFire.ptfx, cfg.deadFire.fx, veh, engBone, cfg.deadFire.scale, 0, 0, 0.15)
            end)
        end

        -- Limp / Dead: oil drip from undercarriage
        if phase == PHASE_LIMP or phase == PHASE_DEAD then
            local chassisBone = GetBoneIdx(veh, 'chassis', 0)
            EnsurePtfx(cfg.oilDrip.ptfx, function()
                if not DoesEntityExist(veh) then return end
                eff.oil = StartBonePtfx(cfg.oilDrip.ptfx, cfg.oilDrip.fx, veh, chassisBone, cfg.oilDrip.scale, 0, 0, -0.1)
            end)
        end

        VehicleEffects[veh] = eff
        Debug('Effects applied: veh=%d phase=%s', veh, phase)
    end)
end

-- ════════════════════════════════════════════════════════════════
-- STATEBAG HANDLERS — realtime sync for ALL players
-- ════════════════════════════════════════════════════════════════

AddStateBagChangeHandler('rde_vf_phase', nil, function(bagName, _, value)
    if not value then return end
    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then return end

    local current = VehicleEffects[entity]
    if current and current.phase == value then return end  -- No change

    ApplyEffects(entity, value)
end)

-- ════════════════════════════════════════════════════════════════
-- EFFECT MAINTENANCE THREAD
-- Checks every 2s if looped particles are still alive.
-- GTA can silently kill particles on heavy load — we restart them.
-- Cost: negligible (only runs if VehicleEffects table has entries)
-- ════════════════════════════════════════════════════════════════
CreateThread(function()
    while true do
        Wait(2000)
        for veh, eff in pairs(VehicleEffects) do
            if not DoesEntityExist(veh) then
                ClearEffects(veh)
            elseif eff.smoke1 and not DoesParticleFxLoopedExist(eff.smoke1) then
                -- Particle died, restart
                Debug('Particle died, restarting: veh=%d phase=%s', veh, eff.phase)
                ApplyEffects(veh, eff.phase)
            end
        end
    end
end)

-- ════════════════════════════════════════════════════════════════
-- SPARK BURST THREAD
-- Fires random one-shot sparks on damaged vehicles while moving.
-- Runs only when there are damaged vehicles in range.
-- Event-driven: only triggers when body damage detected.
-- ════════════════════════════════════════════════════════════════
CreateThread(function()
    while true do
        Wait(500)

        local myPed = cache.ped
        local myPos = GetEntityCoords(myPed)
        local sparksAny = false

        for veh, eff in pairs(VehicleEffects) do
            if not DoesEntityExist(veh) then goto nextVeh end

            -- Only for limp/dead phase vehicles nearby
            if eff.phase ~= PHASE_LIMP and eff.phase ~= PHASE_DEAD then goto nextVeh end

            local dist = #(myPos - GetEntityCoords(veh))
            if dist > 80 then goto nextVeh end

            -- Only when vehicle is moving
            local speed = GetEntitySpeed(veh)
            if speed < 2.0 then goto nextVeh end

            sparksAny = true

            -- Random spark burst every 3-8 seconds
            local now = GetGameTimer()
            if not eff.lastSpark or (now - eff.lastSpark) > math.random(3000, 8000) then
                eff.lastSpark = now
                local chassisBone = GetBoneIdx(veh, 'chassis', 0)
                local cfg = Config.VehicleFailure.effects.sparks
                EnsurePtfx(cfg.ptfx, function()
                    if DoesEntityExist(veh) then
                        BurstBonePtfx(cfg.ptfx, cfg.fx, veh, chassisBone, cfg.scale)
                    end
                end)
            end

            ::nextVeh::
        end

        -- Sleep longer when nothing is happening
        if not sparksAny then Wait(1500) end
    end
end)

-- ════════════════════════════════════════════════════════════════
-- PREVENT VEHICLE FLIP (optional)
-- Disables left/right controls when vehicle is rolled >75° at low speed
-- ════════════════════════════════════════════════════════════════
if Config.VehicleFailure.preventVehicleFlip then
    CreateThread(function()
        while true do
            local veh = cache.vehicle
            if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == cache.ped then
                local roll = GetEntityRoll(veh)
                if math.abs(roll) > 75.0 and GetEntitySpeed(veh) < 2.0 then
                    DisableControlAction(0, 59, true)
                    DisableControlAction(0, 60, true)
                end
                Wait(10)
            else
                Wait(500)
            end
        end
    end)
end

-- ════════════════════════════════════════════════════════════════
-- DRIVER: HANDLING NORMALIZATION
-- On enter: pull handling damage values toward 1.0 for consistency.
-- On exit: restore original values.
-- ════════════════════════════════════════════════════════════════

local function NormalizeHandling(veh)
    if not Config.VehicleFailure.normalizeHandling then return end
    if not DoesEntityExist(veh) then return end

    local orig = {
        collision = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fCollisionDamageMult'),
        engine    = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fEngineDamageMult'),
        deform    = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fDeformationDamageMult'),
        weapons   = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fWeaponDamageMult'),
    }
    OrigHandling[veh] = orig

    -- Normalize: set all to 1.0 (we manage damage ourselves)
    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fCollisionDamageMult', 1.0)
    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fEngineDamageMult',    1.0)
    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fDeformationDamageMult', 1.0)
    if Config.VehicleFailure.weaponsDamageMult ~= -1 then
        SetVehicleHandlingFloat(veh, 'CHandlingData', 'fWeaponDamageMult', Config.VehicleFailure.weaponsDamageMult)
    end

    Debug('Handling normalized: veh=%d', veh)
end

local function RestoreHandling(veh)
    if not DoesEntityExist(veh) then return end
    local orig = OrigHandling[veh]
    if not orig then return end

    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fCollisionDamageMult',  orig.collision)
    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fEngineDamageMult',     orig.engine)
    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fDeformationDamageMult', orig.deform)
    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fWeaponDamageMult',     orig.weapons)
    OrigHandling[veh] = nil

    Debug('Handling restored: veh=%d', veh)
end

-- ox_lib cache event: fires when player enters/exits vehicle
lib.onCache('vehicle', function(veh)
    if veh == 0 then
        -- Exited — restore handling of last vehicle
        if State.lastVeh ~= 0 then
            RestoreHandling(State.lastVeh)
            -- Reset torque to full on exit
            if DoesEntityExist(State.lastVeh) then
                SetVehicleEngineTorqueMultiplier(State.lastVeh, 1.0)
                SetVehicleUndriveable(State.lastVeh, false)
            end
        end
        State.justEntered = true
        State.lastVeh     = 0
    else
        -- Entered new vehicle
        if State.lastVeh ~= 0 and State.lastVeh ~= veh then
            RestoreHandling(State.lastVeh)
        end
        State.lastVeh     = veh
        State.justEntered = true
    end
end)

-- ════════════════════════════════════════════════════════════════
-- DRIVER: MAIN DAMAGE + FAILURE THREAD
-- 50ms — only on driver's client (owner-side)
-- Amplifies damage, runs cascading failure, syncs phase via StateBag.
-- ════════════════════════════════════════════════════════════════
CreateThread(function()
    while true do
        Wait(50)

        local ped = cache.ped
        local veh = cache.vehicle

        -- Must be driver
        if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then goto continue end
        if IsBlacklistedClass(veh) then goto continue end

        -- ── First tick in vehicle: normalize handling + read baseline ─
        if State.justEntered then
            State.justEntered = false

            NormalizeHandling(veh)

            State.lastEngineH = GetVehicleEngineHealth(veh)
            State.lastBodyH   = GetVehicleBodyHealth(veh)
            State.lastTankH   = GetVehiclePetrolTankHealth(veh)
            State.phase       = GetPhase(State.lastEngineH)

            -- Apply visual effects for current phase on initial enter
            if State.phase ~= PHASE_HEALTHY and State.phase ~= PHASE_DEGRADING then
                ApplyEffects(veh, State.phase)
            end
        end

        -- ── Read current health ───────────────────────────────────────
        local engH  = GetVehicleEngineHealth(veh)
        local bodyH = GetVehicleBodyHealth(veh)
        local tankH = GetVehiclePetrolTankHealth(veh)

        -- Full health reset (trainer fix, SetVehicleFixed, etc.)
        if engH  == 1000.0 then State.lastEngineH = 1000.0 end
        if bodyH == 1000.0 then State.lastBodyH   = 1000.0 end
        if tankH == 1000.0 then State.lastTankH   = 1000.0 end

        -- ── Damage amplification ──────────────────────────────────────
        local classMult = Config.VehicleFailure.classDamageMultiplier[GetVehicleClass(veh)] or 1.0
        local cfg       = Config.VehicleFailure

        local engDelta  = math.max(0, State.lastEngineH - engH)  * cfg.damageFactorEngine     * classMult
        local bodyDelta = math.max(0, State.lastBodyH   - bodyH) * cfg.damageFactorBody        * classMult
        local tankDelta = math.max(0, State.lastTankH   - tankH) * cfg.damageFactorPetrolTank  * classMult

        -- Use largest damage source
        local combined = math.max(engDelta, bodyDelta, tankDelta)

        -- Cap: don't kill instantly on huge hits (allow 1-2 ticks of grace)
        local safeGuard = cfg.engineSafeGuard
        if combined > (engH - safeGuard) then
            combined = combined * 0.7
        end
        if combined > engH then
            combined = engH - (cfg.phaseThresholds.critical / 5)
        end

        local newEngH = engH - combined

        -- ── Cascading / degrading passive decay ───────────────────────
        if newEngH < cfg.phaseThresholds.degrading and newEngH > cfg.phaseThresholds.critical + 5 then
            -- Slow passive decay (degrading phase)
            newEngH = newEngH - cfg.degradingDecayRate
        end

        if newEngH <= cfg.phaseThresholds.critical then
            -- Rapid cascading failure
            newEngH = newEngH - cfg.cascadingDecayRate
        end

        -- ── Floor: engine never dies completely (limp mode) ──────────
        if newEngH < safeGuard then
            newEngH = safeGuard
        end

        -- ── Petrol tank explosion prevention ─────────────────────────
        if cfg.preventExplosions and tankH < 750.0 then
            SetVehiclePetrolTankHealth(veh, 750.0)
        end

        -- ── Apply new engine health ───────────────────────────────────
        if math.abs(newEngH - engH) > 0.05 then
            SetVehicleEngineHealth(veh, newEngH)
        end

        -- ── Torque / limp mode ───────────────────────────────────────
        if cfg.limpMode then
            if newEngH <= safeGuard + 1 then
                SetVehicleEngineTorqueMultiplier(veh, cfg.limpTorque)
                SetVehicleUndriveable(veh, false)  -- still driveable (limp)
            elseif newEngH < 900 then
                local torque = (newEngH + 200.0) / 1100.0
                SetVehicleEngineTorqueMultiplier(veh, torque)
                SetVehicleUndriveable(veh, false)
            else
                SetVehicleEngineTorqueMultiplier(veh, 1.0)
                SetVehicleUndriveable(veh, false)
            end
        else
            -- Hard mode: fully undriveable at safeguard
            if newEngH <= safeGuard + 1 then
                SetVehicleUndriveable(veh, true)
            elseif newEngH > safeGuard + 5 then
                SetVehicleUndriveable(veh, false)
            end
        end

        -- ── Phase detection + StateBag sync ──────────────────────────
        local newPhase = GetPhase(newEngH)
        if newPhase ~= State.phase then
            State.phase = newPhase
            Entity(veh).state:set('rde_vf_phase', newPhase, true)
            Debug('Phase → %s (engine: %.0f HP)', newPhase, newEngH)

            -- Driver-only notifications (no spam for others)
            if newPhase == PHASE_CRITICAL and Config.Notifications.enabled then
                lib.notify({
                    title       = '⚠️ Motor-Warnung',
                    description = 'Motor kritisch beschädigt — Mechaniker aufsuchen!',
                    type        = 'error',
                    duration    = 6000,
                    icon        = Config.Icons.engine,
                })
            elseif newPhase == PHASE_LIMP and Config.Notifications.enabled then
                lib.notify({
                    title       = '🔴 Notlauf-Modus',
                    description = 'Motor stark beschädigt — Notlauf aktiv!',
                    type        = 'error',
                    duration    = 8000,
                    icon        = Config.Icons.engine,
                })
            elseif newPhase == PHASE_HEALTHY and State.phase ~= PHASE_DEGRADING then
                -- Repaired
                lib.notify({
                    title       = '✅ Motor OK',
                    description = 'Motor vollständig repariert',
                    type        = 'success',
                    duration    = 3000,
                    icon        = Config.Icons.engine,
                })
            end
        end

        -- ── Save last values ─────────────────────────────────────────
        State.lastEngineH = newEngH
        State.lastBodyH   = bodyH
        State.lastTankH   = tankH

        ::continue::
    end
end)

-- ════════════════════════════════════════════════════════════════
-- CLEANUP
-- ════════════════════════════════════════════════════════════════
AddEventHandler('ox:playerLogout', function()
    -- Clear all effects
    for veh in pairs(VehicleEffects) do
        ClearEffects(veh)
    end
    -- Restore handling of last vehicle
    if State.lastVeh ~= 0 then
        RestoreHandling(State.lastVeh)
    end
    State = {
        phase       = PHASE_HEALTHY,
        lastEngineH = 1000.0,
        lastBodyH   = 1000.0,
        lastTankH   = 1000.0,
        justEntered = true,
        lastVeh     = 0,
        sparkTimer  = 0,
    }
end)

-- ════════════════════════════════════════════════════════════════
-- EXPORTS (für andere Ressourcen)
-- ════════════════════════════════════════════════════════════════
exports('getVehicleFailurePhase', function(veh)
    local v = veh or cache.vehicle
    if not DoesEntityExist(v) then return PHASE_HEALTHY end
    return Entity(v).state.rde_vf_phase or PHASE_HEALTHY
end)

exports('isVehicleInLimpMode', function(veh)
    local phase = exports.rde_carhud:getVehicleFailurePhase(veh)
    return phase == PHASE_LIMP or phase == PHASE_DEAD
end)

if Config.Debug then
    print('^2[RDE | Cockpit v1.0.1]^0 vehiclefailurecl.lua loaded — AAA damage sim active')
end
