-- ════════════════════════════════════════════════════════════════
-- RDE | VEHICLE COCKPIT v1.0.1 - CONFIG
-- Merged: HUD + Engine Control + WheelDamage + Nitro + RepairKit
-- ════════════════════════════════════════════════════════════════

Config = {}

Config.Debug    = false
Config.Locale   = GetConvar('ox:locale', 'en')

-- ════════════════════════════════════════════════════════════════
-- DATABASE
-- ════════════════════════════════════════════════════════════════
Config.Database = {
    enabled      = true,
    tableName    = 'rde_vehicle_data',
    saveInterval = 30000,
}

-- ════════════════════════════════════════════════════════════════
-- VEHICLE / HUD
-- ════════════════════════════════════════════════════════════════
Config.Vehicle = {
    speedUnit      = 'KMH',
    maxSpeed       = 280,
    updateInterval = 50,

    showMileage          = true,
    showTripMeter        = true,
    showFuelRange        = true,
    showEngineTemp       = true,
    showOilPressure      = true,
    showBattery          = true,
    showTirePressure     = true,
    showTurboBoost       = true,
    showWindshieldDamage = true,

    statebagSync  = true,
    syncDistance  = 150.0,

    -- Vehicle classes that support seatbelt (bikes excluded via vehClass == 8)
    allowedClasses = {
        [0]=true, [1]=true, [2]=true, [3]=true, [4]=true,
        [5]=true, [6]=true, [7]=true, [9]=true, [10]=true,
        [11]=true, [12]=true, [17]=true, [18]=true, [19]=true,
    },

    seatbelt = {
        enabled       = true,
        ejectSpeed    = 25.0,
        minEjectForce = 3.0,
        maxEjectForce = 7.0,
        ragdollTime   = 5000,
        limpDuration  = 5000,
        damageOnEject = true,
        damageAmount  = 25,
        dynamicEject  = true,
    },
}

-- ════════════════════════════════════════════════════════════════
-- ENGINE CONTROL
-- ════════════════════════════════════════════════════════════════
Config.EngineControl = {
    toggleKey    = 'M',
    startDelay   = 1800,

    keepRunningOnExit    = true,
    blockThrottleWhenOff = true,
    useStartAnimation    = true,

    neonKey    = 'N',
    windowsKey = 'J',

    admin = {
        acePermission = 'rde.carhud.admin',
        oxGroups      = { owner = 0, admin = 0, manager = 0 },
        steamIds      = {},
        checkOrder    = { 'ace', 'oxcore', 'steam' },
    },
}

-- ════════════════════════════════════════════════════════════════
-- CRUISE CONTROL
-- ════════════════════════════════════════════════════════════════
Config.CruiseControl = {
    enabled  = true,
    minSpeed = 30,
    maxSpeed = 250,
}

-- ════════════════════════════════════════════════════════════════
-- FUEL
-- ════════════════════════════════════════════════════════════════
Config.Fuel = {
    enabled         = true,
    consumptionRate = 1.0,
    warningLevel    = 20,
    criticalLevel   = 10,
    calculateRange  = true,
}

-- ════════════════════════════════════════════════════════════════
-- ENGINE TEMPERATURE
-- ════════════════════════════════════════════════════════════════
Config.Engine = {
    temperature = {
        enabled = true,

        minTemp         = 40,
        normalTemp      = 90,
        warmTemp        = 100,
        hotTemp         = 110,
        criticalTemp    = 120,
        overheatTemp    = 130,
        damageTemp      = 140,

        idleHeatRate    = 0.02,
        cityHeatRate    = 0.05,
        highwayHeatRate = 0.08,
        racingHeatRate  = 0.20,

        stillCoolRate      = 0.08,
        idleCoolRate       = 0.15,
        cityDriveCoolRate  = 0.22,
        highwayCoolRate    = 0.35,

        damagedHeatMultiplier = 3.0,
        lowHealthThreshold    = 600,

        recoveryEnabled          = true,
        recoveryThreshold        = 120,
        permanentDamageThreshold = 140,
        recoveryTime             = 90000,

        performanceLoss = {
            enabled      = true,
            hotLoss      = 0.05,
            criticalLoss = 0.20,
            overheatLoss = 0.45,
            damagedLoss  = 0.75,
        },

        effects = {
            enabled = true,
            lightSmoke = {
                startTemp = 120,
                particle  = 'core',
                asset     = 'ent_ray_heli_aprtmnt_l_fire',
                scale     = 0.5,
            },
            darkSmoke = {
                startTemp = 135,
                particle  = 'core',
                asset     = 'exp_grd_bzgas_smoke',
                scale     = 1.0,
            },
            steam = {
                enabled  = true,
                temp     = 110,
                particle = 'core',
                asset    = 'ent_anim_pneumatic_drill',
                scale    = 0.3,
            },
        },

        sounds = {
            enabled = true,
            warningBeep = {
                temp     = 110,
                sound    = 'Beep_Red',
                soundSet = 'DLC_HEIST_HACKING_SNAKE_SOUNDS',
            },
            criticalAlarm = {
                temp     = 120,
                sound    = 'timer',
                soundSet = 'HUD_MINI_GAME_SOUNDSET',
            },
        },

        notifications = {
            enabled      = true,
            showWarnings = true,
            showCritical = true,
            showDamage   = true,
        },
    },

    oilPressure = {
        enabled        = true,
        minPressure    = 20,
        normalPressure = 45,
        maxPressure    = 80,
    },

    turbo = {
        enabled        = true,
        maxBoost       = 2.5,
        showBoostGauge = true,
    },
}

-- ════════════════════════════════════════════════════════════════
-- TIRE PRESSURE (TPMS)
-- ════════════════════════════════════════════════════════════════
Config.TirePressure = {
    enabled           = true,
    normalPressure    = 2.5,
    warningThreshold  = 2.0,
    criticalThreshold = 1.5,
    showIndicators    = true,
}

-- ════════════════════════════════════════════════════════════════
-- WINDSHIELD DAMAGE
-- ════════════════════════════════════════════════════════════════
Config.Windshield = {
    enabled          = true,
    maxDamage        = 100,
    damagePerCrash   = 20,
    repairCost       = 500,
    syncWithStatebag = true,
}

-- ════════════════════════════════════════════════════════════════
-- KEY BINDINGS
-- ════════════════════════════════════════════════════════════════
Config.Keys = {
    seatbelt      = 'B',
    cruiseControl = 'X',
    signalLeft    = 174,
    signalRight   = 175,
    signalBoth    = 173,
    tripReset     = 'T',
    displayMode   = 'C',
    toggleLights  = 'L',
    indicatorInverted = true,
}

-- ════════════════════════════════════════════════════════════════
-- NOTIFICATIONS & SOUNDS
-- ════════════════════════════════════════════════════════════════
Config.Notifications = {
    enabled  = true,
    position = 'top-right',
    duration = 3000,
}

Config.Sounds = {
    enabled = true,
    volume  = 0.3,
}

Config.Icons = {
    speed      = 'gauge-high',
    rpm        = 'tachometer-alt',
    fuel       = 'gas-pump',
    temp       = 'temperature-high',
    oil        = 'oil-can',
    battery    = 'car-battery',
    turbo      = 'wind',
    seatbelt   = 'user-shield',
    cruise     = 'ship',
    lights     = 'lightbulb',
    tire       = 'circle',
    engine     = 'engine',
    windshield = 'car-burst',
    neon       = 'lightbulb',
    window     = 'window-maximize',
    wheel      = 'circle-dot',
    nitro      = 'bolt',
    sparetire  = 'wrench',
}

Config.Colors = {
    primary = '#3b82f6',
    success = '#10b981',
    error   = '#ef4444',
    warning = '#f59e0b',
    info    = '#06b6d4',
}

-- ════════════════════════════════════════════════════════════════
-- NITRO SYSTEM
-- ════════════════════════════════════════════════════════════════
Config.Nitro = {
    Power         = 100.0,
    Torque        = 100.0,
    Consumption   = 50,     -- ms between nitro consumption ticks
    FlameInterval = 10,     -- ms between exhaust flame bursts
}

-- ════════════════════════════════════════════════════════════════
-- REPAIR KIT
-- ════════════════════════════════════════════════════════════════
Config.RepairKit = {
    InfiniteRepairs = false,
    RepairTime      = 15000,
    SearchRadius    = 5.0,
    AllowMechanics  = false,
    MechanicJob     = 'mechanic',
    BodyRepair      = 100,
    EngineRepair    = 100,
    UseAnimation    = true,
    AnimDict        = 'mini@repair',
    AnimName        = 'fixing_a_player',
    RepairSound     = true,
    SoundName       = 'CHECKPOINT_PERFECT',
    SoundSet        = 'HUD_MINI_GAME_SOUNDSET',
}

-- ════════════════════════════════════════════════════════════════
-- WHEEL DAMAGE (merged from rde_realcardamage)
-- Vehicle classes: https://docs.fivem.net/natives/?_0x29439776AAA00A62
-- ════════════════════════════════════════════════════════════════
Config.WheelDamage = {
    enabled = true,

    -- ── Collision damage ──────────────────────────────────────
    -- Damage wheels take on vehicle collision
    collisionDamageAmount = 50,  -- raised from 30 for better visibility
    collisionDamageMultiplier = {
        models = {
            kuruma2 = 0.5,
        },
        classes = {
            [0]  = 1.2,  -- Compacts
            [1]  = 1.0,  -- Sedans
            [2]  = 0.8,  -- SUVs
            [3]  = 1.0,  -- Coupes
            [4]  = 1.0,  -- Muscle
            [5]  = 1.25, -- Sports Classics
            [6]  = 1.2,  -- Sports
            [7]  = 1.2,  -- Super
            [8]  = 1.1,  -- Motorcycles
            [9]  = 0.5,  -- Off-road
            [10] = 0.5,  -- Industrial
            [11] = 0.5,  -- Utility
            [12] = 1.0,  -- Vans
            [13] = 0.5,  -- Cycles
            [14] = 0.0,  -- Boats
            [15] = 0.0,  -- Helicopters
            [16] = 0.0,  -- Planes
            [17] = 0.9,  -- Service
            [18] = 0.7,  -- Emergency
            [19] = 0.5,  -- Military
            [20] = 0.5,  -- Commercial
            [21] = 0.0,  -- Trains
        },
    },

    -- ── Fall damage ───────────────────────────────────────────
    fallDamageAmount              = 30,
    offroadTireFallDamageMultiplier = 0.7,
    -- Minimum downward velocity to trigger fall damage
    fallThreshold   = 1.5,
    -- Minimum fall airtime (seconds) required
    minimumAirTime  = 0.5,
    fallDamageMultiplier = {
        models = {
            bf400    = 0.4,
            sanchez  = 0.4,
            sanchez2 = 0.4,
            manchez  = 0.4,
        },
        classes = {
            [0]  = 1.0,  -- Compacts
            [1]  = 1.0,  -- Sedans
            [2]  = 0.3,  -- SUVs
            [3]  = 1.0,  -- Coupes
            [4]  = 0.7,  -- Muscle
            [5]  = 1.3,  -- Sports Classics
            [6]  = 1.2,  -- Sports
            [7]  = 1.5,  -- Super
            [8]  = 0.6,  -- Motorcycles
            [9]  = 0.3,  -- Off-road
            [10] = 0.7,  -- Industrial
            [11] = 0.7,  -- Utility
            [12] = 1.3,  -- Vans
            [13] = 0.6,  -- Cycles
            [14] = 0.0,  -- Boats
            [15] = 0.0,  -- Helicopters
            [16] = 0.0,  -- Planes
            [17] = 0.9,  -- Service
            [18] = 0.5,  -- Emergency
            [19] = 0.2,  -- Military
            [20] = 0.7,  -- Commercial
            [21] = 0.0,  -- Trains
        },
    },

    -- ── Outcomes ──────────────────────────────────────────────
    -- Chance (0–100) the wheel falls off on critical damage (4-wheeled vehicles)
    fallOffChance   = 100,
    -- Chance (0–100) the tire bursts on critical damage (>4-wheeled vehicles)
    tireBurstChance = 100,
    -- If true, bulletproof tires won't burst (wheels can still fall off)
    respectBulletproofTires = false,
    -- Make vehicle undriveable when a wheel falls off
    setVehicleUndriveable   = false,
    -- Limit vehicle speed when a wheel is missing
    limitVehicleSpeed = true,
    speedLimit        = 50.0,   -- km/h

    -- ── Props ─────────────────────────────────────────────────
    wheelModel = 'prop_wheel_01',
    wheelRim   = 'prop_wheel_rim_03',

    -- ── Blacklist ─────────────────────────────────────────────
    blacklist = {
        models = {
            'blazer', 'blazer2', 'blazer3', 'blazer4', 'blazer5',
            'monster', 'monster3', 'monster4', 'monster5',
        },
        classes = { 14, 15, 16, 21 },
    },

    -- ── Surface types counted as road ─────────────────────────
    -- https://docs.fivem.net/natives/?_0xA7F04022
    roadSurfaces = { 1, 3, 4, 12 },

    -- Fall damage multiplier on off-road surfaces
    offroadFallDamageMultiplier = {
        models = {
            bf400    = 0.3,
            sanchez  = 0.3,
            sanchez2 = 0.3,
            manchez  = 0.3,
            buggy    = 0.7,
        },
        classes = {
            [0]  = 1.0,  -- Compacts
            [1]  = 1.0,  -- Sedans
            [2]  = 0.9,  -- SUVs
            [3]  = 1.0,  -- Coupes
            [4]  = 0.9,  -- Muscle
            [5]  = 1.3,  -- Sports Classics
            [6]  = 1.3,  -- Sports
            [7]  = 1.3,  -- Super
            [8]  = 1.0,  -- Motorcycles
            [9]  = 0.7,  -- Off-road
            [10] = 0.9,  -- Industrial
            [11] = 1.0,  -- Utility
            [12] = 1.2,  -- Vans
            [13] = 0.6,  -- Cycles
            [14] = 0.0,  -- Boats
            [15] = 0.0,  -- Helicopters
            [16] = 0.0,  -- Planes
            [17] = 0.9,  -- Service
            [18] = 0.5,  -- Emergency
            [19] = 0.2,  -- Military
            [20] = 0.7,  -- Commercial
            [21] = 0.0,  -- Trains
        },
    },
}

-- ════════════════════════════════════════════════════════════════
-- SPARE TIRE ITEM
-- ════════════════════════════════════════════════════════════════
Config.SpareTire = {
    item        = 'rde_ersatzreifen',
    repairTime  = 8000,     -- ms
    searchRadius = 6.0,     -- m — how close player must be to vehicle
    animDict    = 'mini@repair',
    animName    = 'fixing_a_player',
    sound       = 'CHECKPOINT_PERFECT',
    soundSet    = 'HUD_MINI_GAME_SOUNDSET',
}

-- Config is a global, accessible from all shared_scripts, client_scripts, server_scripts

-- ════════════════════════════════════════════════════════════════
-- VEHICLE FAILURE SYSTEM (merged from esx_RealisticVehicleFailure)
-- Next-gen: StateBag sync, entity-bone particles, no ESX
-- ════════════════════════════════════════════════════════════════
Config.VehicleFailure = {
    enabled = true,

    -- ── Damage amplification ──────────────────────────────────
    -- On each 50ms tick, health delta is multiplied by these factors
    -- and fed back into the engine. This makes cars feel more fragile.
    damageFactorEngine     = 3.0,   -- Engine health delta multiplier
    damageFactorBody       = 2.0,   -- Body health delta multiplier
    damageFactorPetrolTank = 15.0,  -- Petrol tank health delta multiplier

    -- ── Health phase thresholds (engine health 0-1000) ────────
    phaseThresholds = {
        degrading = 677.0,  -- < this → slow passive decay starts
        critical  = 310.0,  -- < this → cascading fast failure
        limp      = 100.0,  -- < this → engine nearly dead
    },

    -- ── Passive decay rates (HP per 50ms tick) ────────────────
    degradingDecayRate  = 0.019,  -- ~0.38 HP/s in degrading phase
    cascadingDecayRate  = 0.075,  -- ~1.5 HP/s in critical phase

    -- ── Engine floor & limp mode ──────────────────────────────
    engineSafeGuard  = 100.0,  -- Engine health never drops below this
    limpMode         = true,   -- Minimum power instead of dead stop
    limpTorque       = 0.08,   -- 8% power at engineSafeGuard

    -- ── Handling normalization (on vehicle enter) ─────────────
    -- Pulls all handling damage values toward 1.0 for consistency
    normalizeHandling       = true,
    weaponsDamageMult       = 0.124,  -- Weapon damage factor (-1 = don't touch)
    preventExplosions       = true,   -- Keep petrol tank >= 750 to prevent explosions
    preventVehicleFlip      = false,  -- Disable controls when rolled >75° at low speed

    -- ── Per-class damage multipliers ──────────────────────────
    classDamageMultiplier = {
        [0]=1.0,  [1]=1.0,  [2]=1.0,  [3]=0.95, [4]=1.0,
        [5]=0.95, [6]=0.95, [7]=0.95, [8]=0.27, [9]=0.7,
        [10]=0.25,[11]=0.35,[12]=0.85,[13]=1.0, [14]=0.4,
        [15]=0.7, [16]=0.7, [17]=0.75,[18]=0.85,[19]=0.67,
        [20]=0.43,[21]=1.0,
    },

    -- ── Visual effects — attached to entity bones ─────────────
    -- Uses StartParticleFxLoopedOnEntityBone_2 so particles follow the car
    effects = {
        -- Phase: critical (light oil smoke from engine)
        criticalSmoke = { ptfx = 'core', fx = 'ent_ray_heli_aprtmnt_l_fire', scale = 0.35 },
        -- Phase: limp (heavy dark smoke)
        limpSmoke     = { ptfx = 'core', fx = 'exp_grd_bzgas_smoke',          scale = 1.1  },
        -- Phase: dead (thick smoke)
        deadSmoke     = { ptfx = 'core', fx = 'exp_grd_bzgas_smoke',          scale = 2.0  },
        -- Phase: dead (fire)
        deadFire      = { ptfx = 'core', fx = 'ent_ray_blimp_night_fire',     scale = 0.7  },
        -- Body damage sparks (burst, not looped) — triggered by thread
        sparks        = { ptfx = 'core', fx = 'ent_anim_sparks_gen_sp',       scale = 0.3  },
        -- Oil drip (looped, subtle) — limp+ phase when moving slow
        oilDrip       = { ptfx = 'core', fx = 'ent_anim_meth_pipe_smoke',     scale = 0.2  },
    },

    -- ── Blacklisted classes (no failure simulation) ───────────
    -- Bicycles, helicopters, planes, trains handled differently
    blacklistClasses = { [13]=true, [14]=true, [15]=true, [16]=true, [21]=true },
}
-- Config is a global, accessible from all shared_scripts, client_scripts, server_scripts
