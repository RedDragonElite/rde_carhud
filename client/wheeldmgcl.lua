-- ════════════════════════════════════════════════════════════════
-- RDE | VEHICLE COCKPIT v1.0.0 — CLIENT/WHEELDMG
-- Merged from rde_realcardamage — clean RDE OX Standards rewrite
-- Handles: collision damage, fall damage, wheel dropping, HUD sync
-- ════════════════════════════════════════════════════════════════

if not Config.WheelDamage or not Config.WheelDamage.enabled then return end

local function Debug(msg, ...)
    if not Config.Debug then return end
    print(('^5[RDE WHEELDMG]^7 ' .. tostring(msg)):format(...))
end

-- ════════════════════════════════════════════════════════════════
-- CONSTANTS
-- ════════════════════════════════════════════════════════════════

-- Bone name → wheel index (shared with event handlers)
local WheelBones = {
    wheel_lf = 0, -- front left
    wheel_rf = 1, -- front right
    wheel_lr = 2, -- rear left
    wheel_rr = 3, -- rear right
}

-- Wheel index → bone name
local IndexToBone = {
    [0] = 'wheel_lf',
    [1] = 'wheel_rf',
    [2] = 'wheel_lr',
    [3] = 'wheel_rr',
}

-- Default wheel flags per index (used when no saved flags available)
local DefaultWheelFlags = {
    [0] = 570,
    [1] = 568,
    [2] = 566,
    [3] = 564,
}

-- Wheel flag value that indicates "visually removed"
local WHEEL_REMOVED_FLAG = 63487  -- -1 as uint16

-- Label strings for notifications
local WheelLabels = { 'FL', 'FR', 'RL', 'RR' }

-- ════════════════════════════════════════════════════════════════
-- STATE
-- ════════════════════════════════════════════════════════════════

-- Vehicles currently tracked as having broken wheels
local BrokenVehicles = {}

-- Saved wheel flags per vehicle per wheel (to restore after repair)
-- SavedWheelFlags[vehicleHandle][wheelIdx] = flags
local SavedWheelFlags  = {}
local SavedWheelXOffset = {}

-- Cooldowns for wheel drop (prevent double-drop in one tick)
local WheelDropCooldown = {}

-- Blacklist cache per vehicle handle
local BlacklistCache = {}

-- ════════════════════════════════════════════════════════════════
-- HELPERS
-- ════════════════════════════════════════════════════════════════

local function Contains(tbl, val)
    for _, v in ipairs(tbl) do
        if v == val then return true end
    end
    return false
end

-- Returns multiplier if model matches, 0 if not
local function ContainsModel(modelTable, veh)
    local modelHash = GetEntityModel(veh)
    for modelName, mult in pairs(modelTable) do
        if modelHash == GetHashKey(modelName) then
            return mult + 0.001  -- non-zero means "found"
        end
    end
    return 0
end

local function IsBlacklisted(veh)
    if Contains(Config.WheelDamage.blacklist.classes, GetVehicleClass(veh)) then
        return true
    end
    for _, modelName in pairs(Config.WheelDamage.blacklist.models) do
        if GetEntityModel(veh) == GetHashKey(modelName) then
            return true
        end
    end
    return false
end

local function IsBlacklistedCached(veh)
    if BlacklistCache[veh] ~= nil then return BlacklistCache[veh] end
    BlacklistCache[veh] = IsBlacklisted(veh)
    return BlacklistCache[veh]
end

local function SetWheelDropCooldown(wheelIdx, ms)
    WheelDropCooldown[wheelIdx] = true
    CreateThread(function()
        Wait(ms or 500)
        WheelDropCooldown[wheelIdx] = false
    end)
end

local function DoRequestModel(modelName)
    local hash = GetHashKey(modelName)
    if HasModelLoaded(hash) then return end
    RequestModel(hash)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(100) end
end

-- ════════════════════════════════════════════════════════════════
-- DROP WHEEL  —  spawn prop, set statebags, sync server
-- ════════════════════════════════════════════════════════════════

local function DropWheel(veh, wheelIdx, boneName)
    if WheelDropCooldown[wheelIdx] then return end
    SetWheelDropCooldown(wheelIdx, 500)

    CreateThread(function()
        -- Save current wheel flags before removal
        if not SavedWheelFlags[veh]  then SavedWheelFlags[veh]  = {} end
        if not SavedWheelXOffset[veh] then SavedWheelXOffset[veh] = {} end
        SavedWheelFlags[veh][wheelIdx] = GetVehicleWheelFlags(veh, wheelIdx)

        -- Save natural wheel X position via bone (NOT 0.0 — that puts wheel at vehicle center)
        local saveBoneIdx = GetEntityBoneIndexByName(veh, boneName or IndexToBone[wheelIdx] or 'wheel_lf')
        if saveBoneIdx ~= -1 then
            -- GetWorldPositionOfEntityBone returns vector3 — access .x/.y/.z explicitly
            local boneWorld = GetWorldPositionOfEntityBone(veh, saveBoneIdx)
            local boneLocal = GetOffsetFromEntityGivenWorldCoords(
                veh, boneWorld.x, boneWorld.y, boneWorld.z
            )
            -- boneLocal is also vector3 — save only the X axis (wheel side offset)
            SavedWheelXOffset[veh][wheelIdx] = boneLocal.x
        end

        -- Pick model (rim only if tire was already burst)
        local model = Config.WheelDamage.wheelModel
        if IsVehicleTyreBurst(veh, wheelIdx, false) then
            model = Config.WheelDamage.wheelRim
        end
        DoRequestModel(model)

        -- Get spawn position
        local boneIdx = GetEntityBoneIndexByName(veh, boneName)
        if boneIdx == -1 then return end
        local bonePos = GetWorldPositionOfEntityBone(veh, boneIdx)
        local vel     = GetEntityVelocity(veh)

        -- Spawn prop slightly below world (teleported in next line)
        local obj = CreateObjectNoOffset(GetHashKey(model), bonePos.x, bonePos.y, -10.0, true, false, false)

        -- Prevent collision with parent vehicle for ~150 frames
        CreateThread(function()
            for _ = 1, 150 do
                SetEntityNoCollisionEntity(obj, veh, true)
                Wait(1)
            end
        end)

        SetEntityCoords(obj, bonePos, false, false, false, false)
        SetEntityHeading(obj, GetEntityHeading(veh) + 270.0)
        SetEntityDynamic(obj, true)
        SetEntityVelocity(obj,
            vel.x * 1.5 + math.random(-2, 2),
            vel.y * 1.5 + math.random(-2, 2),
            vel.z * 1.25
        )

        -- Kill wheel health so monitoring thread hides it
        SetVehicleWheelHealth(veh, wheelIdx, 0.0)

        -- Mark prop for GC
        SetEntityAsMissionEntity(obj, false, false)
        SetEntityAsNoLongerNeeded(obj)
        MarkObjectForDeletion(obj)

        -- Add to broken list so monitoring thread picks it up
        table.insert(BrokenVehicles, veh)

        -- Set entity statebags (broadcast=true → other clients see it)
        Entity(veh).state:set('rde_wheeldamage_broken', true, true)
        Entity(veh).state:set('rde_wheeldamage_broken_' .. wheelIdx, true, true)

        -- Sync to server (server sets authoritative statebag)
        TriggerServerEvent('rde_wheeldamage:setState',
            NetworkGetNetworkIdFromEntity(veh), true)
        TriggerServerEvent('rde_wheeldamage:setBroken',
            NetworkGetNetworkIdFromEntity(veh), wheelIdx, true)

        -- Notification
        lib.notify({
            title       = '⚠️ ' .. (locale and locale['warning'] or 'Warning'),
            description = (locale and locale['wheel_missing'] or 'Wheel fell off! (%s)'):format(WheelLabels[wheelIdx + 1] or wheelIdx),
            type        = 'error',
            duration    = 5000,
            icon        = Config.Icons.wheel,
        })

        Debug('Wheel dropped: veh=%d idx=%d bone=%s', veh, wheelIdx, boneName)
    end)
end

-- ════════════════════════════════════════════════════════════════
-- APPLY WHEEL DAMAGE
-- Called by both fall and collision threads.
-- Exposed as global so event handlers below can reference it.
-- ════════════════════════════════════════════════════════════════

local function _ApplyWheelDamage(veh, wheelIdx, damage, boneName)
    if wheelIdx > GetVehicleNumberOfWheels(veh) - 1 then return end

    local currentHealth = GetVehicleWheelHealth(veh, wheelIdx)
    local newHealth     = currentHealth - damage

    if newHealth <= 1 then
        -- Critical damage — check if already flagged removed
        local flags = GetVehicleWheelFlags(veh, wheelIdx)
        if flags == WHEEL_REMOVED_FLAG then return end  -- already gone

        if GetVehicleNumberOfWheels(veh) == 4 then
            -- 4-wheeled: chance to drop wheel entirely
            if math.random(1, 100) <= Config.WheelDamage.fallOffChance then
                DropWheel(veh, wheelIdx, boneName or IndexToBone[wheelIdx] or 'wheel_lf')
            end
        else
            -- More than 4 wheels: burst tire instead
            if math.random(1, 100) <= Config.WheelDamage.tireBurstChance then
                if not IsVehicleTyreBurst(veh, wheelIdx, false) then
                    if not Config.WheelDamage.respectBulletproofTires
                        or GetVehicleTyresCanBurst(veh) then
                        SetVehicleTyreBurst(veh, wheelIdx, true, 1)

                        lib.notify({
                            title       = '⚠️ ' .. (locale and locale['warning'] or 'Warning'),
                            description = (locale and locale['wheel_burst'] or 'Tire burst! (%s)'):format(WheelLabels[wheelIdx + 1] or wheelIdx),
                            type        = 'error',
                            duration    = 4000,
                            icon        = Config.Icons.wheel,
                        })
                    end
                end
            end
            SetVehicleWheelHealth(veh, wheelIdx, 250.0)
        end
    else
        SetVehicleWheelHealth(veh, wheelIdx, newHealth)
    end

    Debug('WheelDamage applied: idx=%d dmg=%.1f new=%.1f', wheelIdx, damage, math.max(0, newHealth))
end

-- Expose globally for event handlers
ApplyWheelDamage = _ApplyWheelDamage

-- ════════════════════════════════════════════════════════════════
-- FALL DAMAGE THREAD
-- Monitors Z-velocity change to detect hard landings.
-- ════════════════════════════════════════════════════════════════
CreateThread(function()
    local airTimeMs = 0
    local prevVelZ  = 0.0

    while true do
        local sleep = 2000
        local ped   = cache.ped

        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)

            if GetPedInVehicleSeat(veh, -1) == ped and not IsBlacklistedCached(veh) then
                sleep = 25

                local speed  = GetEntitySpeed(veh)
                local velZ   = GetEntityVelocity(veh).z
                local impact = velZ - prevVelZ  -- positive = landing impact
                local didDmg = false

                if impact > Config.WheelDamage.fallThreshold and speed > 4 then
                    if (airTimeMs / 1000) > Config.WheelDamage.minimumAirTime then
                        -- Apply to all wheels
                        for boneName, wheelIdx in pairs(WheelBones) do
                            if wheelIdx <= GetVehicleNumberOfWheels(veh) - 1 then
                                -- Suspension compression amplifies impact
                                local susp        = GetVehicleWheelSuspensionCompression(veh, wheelIdx)
                                local impactFactor = math.min(1.0, (susp + 0.05) * 5)

                                -- Class multiplier
                                local mult = Config.WheelDamage.fallDamageMultiplier.classes[GetVehicleClass(veh)] or 1.0
                                local modelMult = ContainsModel(Config.WheelDamage.fallDamageMultiplier.models, veh)
                                if modelMult ~= 0 then mult = modelMult end

                                -- Surface multiplier
                                local surfMult = 1.0
                                local surface  = GetVehicleWheelSurfaceMaterial(veh, wheelIdx)
                                if not Contains(Config.WheelDamage.roadSurfaces, surface) then
                                    surfMult = Config.WheelDamage.offroadFallDamageMultiplier.classes[GetVehicleClass(veh)] or 1.0
                                    local modelSurf = ContainsModel(Config.WheelDamage.offroadFallDamageMultiplier.models, veh)
                                    if modelSurf ~= 0 then surfMult = modelSurf end
                                end

                                -- Off-road tire multiplier
                                local tireMult = 1.0
                                if GetVehicleWheelType(veh) == 4 then
                                    tireMult = Config.WheelDamage.offroadTireFallDamageMultiplier
                                end

                                local damage = impact
                                    * Config.WheelDamage.fallDamageAmount
                                    * mult
                                    * impactFactor
                                    * surfMult
                                    * tireMult
                                    * impactFactor  -- squared: harder = more damage

                                _ApplyWheelDamage(veh, wheelIdx, damage, boneName)
                                didDmg = true
                            end
                        end
                    end
                end

                -- Track airtime (only when descending + not on all wheels)
                if velZ < -1 then
                    if not IsVehicleOnAllWheels(veh) then
                        airTimeMs = airTimeMs + sleep
                    end
                elseif airTimeMs ~= 0 then
                    Debug('Airtime: %.2fs', airTimeMs / 1000)
                    airTimeMs = 0
                end

                if didDmg then Wait(100) end
                prevVelZ = velZ
            end
        end

        Wait(sleep)
    end
end)

-- ════════════════════════════════════════════════════════════════
-- COLLISION DAMAGE THREAD
-- Monitors body/engine health loss during collisions.
-- ════════════════════════════════════════════════════════════════
CreateThread(function()
    local prevHealth = nil

    while true do
        local sleep = 2000
        local ped   = cache.ped

        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)

            if GetPedInVehicleSeat(veh, -1) == ped and not IsBlacklistedCached(veh) then
                local speed      = GetEntitySpeed(veh)
                local bodyH      = GetVehicleBodyHealth(veh)
                local engH       = GetVehicleEngineHealth(veh)
                local combined   = bodyH + engH * 0.4

                -- Only track the max health seen (prevents counting natural regen)
                if prevHealth == nil or prevHealth < combined then
                    prevHealth = combined
                end

                local healthLoss = prevHealth - combined

                if combined < 980 and speed > 7 then
                    sleep = 1
                else
                    sleep = 50
                end

                local norm = GetCollisionNormalOfLastHitForEntity(veh)
                local hasCollision = norm.x ~= 0 or norm.y ~= 0 or norm.z ~= 0

                if hasCollision and healthLoss > 0 then
                    -- Class + model multiplier
                    local vehClass = GetVehicleClass(veh)
                    local mult = Config.WheelDamage.collisionDamageMultiplier.classes[vehClass] or 1.0
                    local modelMult = ContainsModel(Config.WheelDamage.collisionDamageMultiplier.models, veh)
                    if modelMult ~= 0 then mult = modelMult end

                    local damage = (math.abs(speed) * 0.1 + healthLoss * 0.7)
                        * 0.35
                        * Config.WheelDamage.collisionDamageAmount
                        * mult

                    prevHealth = combined

                    -- Determine hit side using collision normal in vehicle local space
                    -- Convert world normal to vehicle-local to find front/rear/side impact
                    local vehFwd  = GetEntityForwardVector(veh)
                    -- Dot product of world-norm with vehicle forward → positive = rear hit, negative = front hit
                    local fwdDot  = norm.x * vehFwd.x + norm.y * vehFwd.y
                    local hitFront = fwdDot < -0.3   -- norm points against forward = front impact
                    local hitRear  = fwdDot >  0.3   -- norm points with forward = rear impact
                    -- Side impact: abs(fwdDot) < 0.3 → damage all wheels

                    local wheelCount = GetVehicleNumberOfWheels(veh)
                    for boneName, wheelIdx in pairs(WheelBones) do
                        if wheelIdx <= wheelCount - 1 then
                            local isFront = (wheelIdx == 0 or wheelIdx == 1)  -- FL=0, FR=1
                            local shouldDamage = true
                            if hitFront and not isFront then shouldDamage = false end
                            if hitRear  and isFront     then shouldDamage = false end

                            if shouldDamage then
                                _ApplyWheelDamage(veh, wheelIdx, damage, boneName)
                                Debug('Collision dmg: wheel=%d dmg=%.1f healthLoss=%.1f', wheelIdx, damage, healthLoss)
                            end
                        end
                    end
                end
            end
        elseif prevHealth ~= nil then
            prevHealth = nil
        end

        Wait(sleep)
    end
end)

-- ════════════════════════════════════════════════════════════════
-- VEHICLE POOL SCANNER
-- Rebuilds BrokenVehicles list every 3 seconds.
-- ════════════════════════════════════════════════════════════════
CreateThread(function()
    while true do
        local ped  = cache.ped
        local list = {}

        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if DoesEntityExist(veh) and Entity(veh).state.rde_wheeldamage_broken then
                table.insert(list, veh)
            end
        end

        -- Always include current vehicle so it reacts immediately
        local curVeh = GetVehiclePedIsIn(ped, false)
        if curVeh ~= 0 then
            table.insert(list, curVeh)
        end

        BrokenVehicles = list
        Wait(3000)
    end
end)

-- ════════════════════════════════════════════════════════════════
-- WHEEL VISUAL STATE THREAD
-- Applies/restores the visual wheel-removal flags and speed limits.
-- Runs at 300ms normally, 150ms with damaged wheels.
-- ════════════════════════════════════════════════════════════════
CreateThread(function()
    while true do
        local sleep       = 300
        local ped         = cache.ped
        local playerVeh   = GetVehiclePedIsIn(ped, false)
        local shouldApply = false

        for _, veh in ipairs(BrokenVehicles) do
            if not DoesEntityExist(veh) then goto nextVeh end

            local totalMissing = 0
            local totalDamaged = 0

            for boneName, wheelIdx in pairs(WheelBones) do
                if wheelIdx > GetVehicleNumberOfWheels(veh) - 1 then goto nextWheel end

                local health      = GetVehicleWheelHealth(veh, wheelIdx)
                local flags       = GetVehicleWheelFlags(veh, wheelIdx)
                local brokenState = Entity(veh).state['rde_wheeldamage_broken_' .. wheelIdx]

                -- ── Determine if this wheel SHOULD be visually missing ─────
                -- Smart auto-detect external repairs (fixkit, carservice, admin commands,
                -- SetVehicleFixed, etc.) — no extra polling needed, runs on existing 300ms tick
                local shouldBeMissing = false
                if health <= 1.0 then
                    shouldBeMissing = true
                elseif brokenState == true then
                    -- StateBag says broken — but check if it was externally repaired
                    local isBurst = IsVehicleTyreBurst(veh, wheelIdx, false)
                    if isBurst or health < 500 then
                        -- Genuinely still broken/burst
                        shouldBeMissing = true
                    else
                        -- Wheel health restored by external system → auto-clear StateBag.
                        -- Fires within ≤300ms of any repair (fixkit, carservice, /car fix…)
                        Entity(veh).state:set('rde_wheeldamage_broken_' .. wheelIdx, false, true)
                        TriggerServerEvent('rde_wheeldamage:setBroken',
                            NetworkGetNetworkIdFromEntity(veh), wheelIdx, false)
                        shouldBeMissing = false
                        Debug('External repair detected: wheel=%d veh=%d h=%.0f', wheelIdx, veh, health)
                    end
                end

                if shouldBeMissing then
                    totalMissing = totalMissing + 1
                    -- Apply visual removal
                    SetVehicleWheelFlags(veh, wheelIdx, -1)
                    SetVehicleWheelXOffset(veh, wheelIdx, -9999.9)
                else
                    -- Wheel should be present
                    if flags == WHEEL_REMOVED_FLAG then
                        -- Wheel was flagged as missing but should be restored now
                        Debug('Restoring wheel idx=%d on veh=%d', wheelIdx, veh)

                        -- Client-side statebag update (broadcast)
                        Entity(veh).state:set('rde_wheeldamage_broken_' .. wheelIdx, false, true)

                        -- Tell server to clear
                        TriggerServerEvent('rde_wheeldamage:setBroken',
                            NetworkGetNetworkIdFromEntity(veh), wheelIdx, false)

                        -- Restore original flags AND natural wheel position
                        local savedFlag   = SavedWheelFlags[veh]  and SavedWheelFlags[veh][wheelIdx]
                        local savedXOff   = SavedWheelXOffset[veh] and SavedWheelXOffset[veh][wheelIdx]
                        SetVehicleWheelFlags(veh, wheelIdx, savedFlag or DefaultWheelFlags[wheelIdx])
                        -- Restore saved X position (bone-based). Never use 0.0 — that puts wheels at center!
                        if savedXOff then
                            SetVehicleWheelXOffset(veh, wheelIdx, savedXOff)
                        end
                        -- (If no saved offset: don't call SetVehicleWheelXOffset at all — original behaviour)

                        -- Reset movement restrictions
                        if Config.WheelDamage.setVehicleUndriveable then
                            SetVehicleUndriveable(veh, false)
                        end
                        if Config.WheelDamage.limitVehicleSpeed then
                            SetVehicleMaxSpeed(veh, 0.0)
                        end
                        Wait(1)
                    end

                    if health <= 300.0 then
                        totalDamaged = totalDamaged + 1
                    end
                end

                ::nextWheel::
            end

            -- ── Check if any wheel is missing on a nearby/driven vehicle ─
            if totalMissing > 0 then
                local dist = GetDistanceBetweenCoords(
                    GetEntityCoords(ped), GetEntityCoords(veh), true)
                local driverPed = GetPedInVehicleSeat(veh, -1)

                if veh == playerVeh
                    or driverPed == 0
                    or dist < 50.0
                then
                    shouldApply = true
                end

                -- Apply movement restriction
                if Config.WheelDamage.setVehicleUndriveable then
                    SetVehicleUndriveable(veh, true)
                elseif Config.WheelDamage.limitVehicleSpeed then
                    local speedMs = GetEntitySpeed(veh)
                    local limitMs = Config.WheelDamage.speedLimit / 3.6
                    if speedMs > limitMs then
                        SetVehicleCheatPowerIncrease(veh, 0.0)
                    else
                        SetVehicleMaxSpeed(veh, limitMs)
                    end
                end
            else
                -- No missing wheels: check if rde_wheeldamage_broken should be cleared
                if Entity(veh).state.rde_wheeldamage_broken then
                    TriggerServerEvent('rde_wheeldamage:setState',
                        NetworkGetNetworkIdFromEntity(veh), false)
                    Entity(veh).state:set('rde_wheeldamage_broken', false, true)
                end
            end

            if totalDamaged > 0 then sleep = 150 end
            if totalMissing > 0 then sleep = 1 end

            ::nextVeh::
        end

        Wait(sleep)
    end
end)

-- ════════════════════════════════════════════════════════════════
-- NET EVENTS — mirror of original rde_realcardamage editable.lua
-- ════════════════════════════════════════════════════════════════

-- Damage a specific wheel programmatically
RegisterNetEvent('rde_wheeldamage:damageWheel', function(veh, wheelIdx, damage)
    _ApplyWheelDamage(veh, wheelIdx, damage, IndexToBone[wheelIdx])
end)

-- Remove wheel silently (no prop spawn)
RegisterNetEvent('rde_wheeldamage:removeWheel', function(veh, wheelIdx)
    SetVehicleWheelHealth(veh, wheelIdx, 0.0)
    Entity(veh).state:set('rde_wheeldamage_broken', true, true)
    Entity(veh).state:set('rde_wheeldamage_broken_' .. wheelIdx, true, true)
    TriggerServerEvent('rde_wheeldamage:setState', NetworkGetNetworkIdFromEntity(veh), true)
    TriggerServerEvent('rde_wheeldamage:setBroken', NetworkGetNetworkIdFromEntity(veh), wheelIdx, true)
end)

-- Repair a single wheel (spare tire, mechanic, etc.)
RegisterNetEvent('rde_wheeldamage:fixWheel', function(veh, wheelIdx)
    SetVehicleTyreFixed(veh, wheelIdx)
    SetVehicleWheelHealth(veh, wheelIdx, 1000.0)
    Entity(veh).state:set('rde_wheeldamage_broken_' .. wheelIdx, false, true)
    TriggerServerEvent('rde_wheeldamage:setBroken', NetworkGetNetworkIdFromEntity(veh), wheelIdx, false)
end)

-- Repair all wheels (full repair kit)
RegisterNetEvent('rde_wheeldamage:fixCar', function(veh)
    for wheelIdx = 0, GetVehicleNumberOfWheels(veh) - 1 do
        SetVehicleTyreFixed(veh, wheelIdx)
        SetVehicleWheelHealth(veh, wheelIdx, 1000.0)
        Entity(veh).state:set('rde_wheeldamage_broken_' .. wheelIdx, false, true)
        TriggerServerEvent('rde_wheeldamage:setBroken', NetworkGetNetworkIdFromEntity(veh), wheelIdx, false)
    end
    Entity(veh).state:set('rde_wheeldamage_broken', false, true)
    TriggerServerEvent('rde_wheeldamage:setState', NetworkGetNetworkIdFromEntity(veh), false)
end)

-- ════════════════════════════════════════════════════════════════
-- CLEANUP
-- ════════════════════════════════════════════════════════════════
AddEventHandler('ox:playerLogout', function()
    BrokenVehicles    = {}
    SavedWheelFlags   = {}
    SavedWheelXOffset = {}
    WheelDropCooldown = {}
    BlacklistCache    = {}
end)

if Config.Debug then
    print('^2[RDE | Cockpit v1.0.0]^0 wheeldmgcl.lua loaded — WheelDamage active')
end

-- ════════════════════════════════════════════════════════════════
-- REALTIME STATEBAG SYNC
-- React immediately when another player's wheel breaks or is fixed,
-- without waiting for the 3-second pool scanner.
-- Low cost: fires only on state change, not on every tick.
-- ════════════════════════════════════════════════════════════════

local function IsInBrokenList(entity)
    for _, veh in ipairs(BrokenVehicles) do
        if veh == entity then return true end
    end
    return false
end

-- rde_wheeldamage_broken → add/remove from tracked list immediately
AddStateBagChangeHandler('rde_wheeldamage_broken', nil, function(bagName, _, value)
    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 or not DoesEntityExist(entity) then return end

    if value == true then
        if not IsInBrokenList(entity) then
            table.insert(BrokenVehicles, entity)
            Debug('StateBag: added veh=%d to BrokenVehicles', entity)
        end
    else
        -- Wheel was repaired/cleared → remove from list
        for i = #BrokenVehicles, 1, -1 do
            if BrokenVehicles[i] == entity then
                table.remove(BrokenVehicles, i)
                Debug('StateBag: removed veh=%d from BrokenVehicles', entity)
            end
        end
        -- Clear any leftover visual restrictions on this client
        for wheelIdx = 0, 3 do
            if wheelIdx < GetVehicleNumberOfWheels(entity) then
                local savedFlag = SavedWheelFlags[entity]   and SavedWheelFlags[entity][wheelIdx]
                local savedXOff = SavedWheelXOffset[entity] and SavedWheelXOffset[entity][wheelIdx]
                if savedFlag then
                    SetVehicleWheelFlags(entity, wheelIdx, savedFlag)
                else
                    SetVehicleWheelFlags(entity, wheelIdx, DefaultWheelFlags[wheelIdx] or 570)
                end
                -- Restore natural position (bone-saved). NEVER use 0.0 = vehicle center!
                if savedXOff then
                    SetVehicleWheelXOffset(entity, wheelIdx, savedXOff)
                end
            end
        end
        if Config.WheelDamage.limitVehicleSpeed then
            SetVehicleMaxSpeed(entity, 0.0)
        end
    end
end)

-- ════════════════════════════════════════════════════════════════
-- EXTERNAL REPAIR DETECTION via StateBag
-- Listens for repair signals from any system that sets these bags:
--   repairState  → rde_carhud fixkit / repairkitcl.lua
--   rde_vf_phase → vehiclefailurecl.lua (reset to 'healthy' = full repair)
-- Instantly clears wheel damage state without any polling.
-- ════════════════════════════════════════════════════════════════

-- repairState is set by repairkitcl.lua after any repair sync
AddStateBagChangeHandler('repairState', nil, function(bagName, _, value)
    if not value then return end
    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 or not DoesEntityExist(entity) then return end

    -- Give GTA one frame to apply the repair natives before we read health
    CreateThread(function()
        Wait(200)
        if not DoesEntityExist(entity) then return end

        local wheelCount = GetVehicleNumberOfWheels(entity)
        local allFixed   = true

        for i = 0, wheelCount - 1 do
            local h       = GetVehicleWheelHealth(entity, i)
            local isBurst = IsVehicleTyreBurst(entity, i, false)
            if h >= 500 and not isBurst then
                -- Wheel is repaired — clear StateBag immediately
                if Entity(entity).state['rde_wheeldamage_broken_' .. i] == true then
                    Entity(entity).state:set('rde_wheeldamage_broken_' .. i, false, true)
                    TriggerServerEvent('rde_wheeldamage:setBroken',
                        NetworkGetNetworkIdFromEntity(entity), i, false)
                    Debug('repairState event: cleared wheel=%d on veh=%d', i, entity)
                end
            else
                allFixed = false
            end
        end

        -- If all wheels OK: clear global broken flag + remove from tracking list
        if allFixed then
            Entity(entity).state:set('rde_wheeldamage_broken', false, true)
            TriggerServerEvent('rde_wheeldamage:setState',
                NetworkGetNetworkIdFromEntity(entity), false)
            -- Remove from BrokenVehicles list
            for i = #BrokenVehicles, 1, -1 do
                if BrokenVehicles[i] == entity then
                    table.remove(BrokenVehicles, i)
                end
            end
            -- Restore visual only for wheels we KNOW about (wheels we removed ourselves).
            -- DO NOT blindly set flags for all wheel indices — vans/trucks have 6+ wheels
            -- and setting wrong flags (570) on indices 4-5 makes them disappear!
            for i = 0, 3 do  -- only indices 0-3, those we track
                local currentFlags = GetVehicleWheelFlags(entity, i)
                local savedFlag    = SavedWheelFlags[entity] and SavedWheelFlags[entity][i]
                if savedFlag then
                    -- We removed this wheel ourselves → restore saved original flags + position
                    SetVehicleWheelFlags(entity, i, savedFlag)
                    local savedXOff = SavedWheelXOffset[entity] and SavedWheelXOffset[entity][i]
                    if savedXOff then
                        SetVehicleWheelXOffset(entity, i, savedXOff)
                    end
                elseif currentFlags == WHEEL_REMOVED_FLAG then
                    -- Wheel is flagged as removed but we don't have saved flags
                    -- (other client removed it) → reset flags only, let GTA handle position
                    SetVehicleWheelFlags(entity, i, DefaultWheelFlags[i])
                end
                -- If flags are normal and no saved flags → don't touch (could break things)
            end
            -- Clear saved caches now that we're done
            if SavedWheelFlags[entity]  then SavedWheelFlags[entity]  = nil end
            if SavedWheelXOffset[entity] then SavedWheelXOffset[entity] = nil end
            if Config.WheelDamage.limitVehicleSpeed then
                SetVehicleMaxSpeed(entity, 0.0)
            end
            Debug('repairState event: all wheels cleared on veh=%d', entity)
        end
    end)
end)
