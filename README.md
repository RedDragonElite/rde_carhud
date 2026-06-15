# 🐉 RDE Car HUD — Vehicle Cockpit Suite

[![Version](https://img.shields.io/badge/version-1.0.0--beta-red?style=for-the-badge&logo=github)](https://github.com/RedDragonElite/rde_carhud)
[![Beta](https://img.shields.io/badge/status-COMMUNITY%20BETA-orange?style=for-the-badge)](https://github.com/RedDragonElite/rde_carhud/issues)
[![License](https://img.shields.io/badge/license-RDE%20Black%20Flag%20v6.66-black?style=for-the-badge)](LICENSE)
[![FiveM](https://img.shields.io/badge/FiveM-Compatible-orange?style=for-the-badge)](https://fivem.net)
[![ox_core](https://img.shields.io/badge/ox__core-Required-blue?style=for-the-badge)](https://github.com/communityox/ox_core)
[![Free](https://img.shields.io/badge/price-FREE%20FOREVER-brightgreen?style=for-the-badge)](https://rd-elite.com)

**Analog cockpit gauges · Realtime wheel damage · Engine failure simulation · StateBag-first architecture · Zero ESX**

> ⚠️ **COMMUNITY BETA — v1.0.0-beta** · Core systems tested and confirmed working. Some edge cases may remain. Found a bug? [Open an issue](https://github.com/RedDragonElite/rde_carhud/issues) — hotfixes ship fast.

Built on ox_core · ox_lib · ox_inventory · oxmysql

*Built by [Red Dragon Elite](https://rd-elite.com) | SerpentsByte*

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/c2e2f302-f15f-4559-868f-270e12e5df58" />

---

## 📖 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Architecture](#-architecture)
- [Dependencies](#-dependencies)
- [Installation](#-installation)
- [Configuration](#-configuration)
- [Key Bindings](#-key-bindings)
- [Item Integration](#-item-integration)
- [Developer API](#-developer-api)
- [Database](#-database)
- [Performance](#-performance)
- [Troubleshooting](#-troubleshooting)
- [Changelog](#-changelog)
- [License](#-license)

---

## 🎯 Overview

**RDE Car HUD** is a production-grade all-in-one vehicle experience system for FiveM servers. Four separate resources have been merged into one clean, zero-dependency suite:

| Merged From | What it did | RDE Replacement |
|---|---|---|
| Generic speedometer HUDs | Basic NUI gauges | Analog cockpit w/ turbo, nitro, tires |
| `rde_realcardamage` | Wheel damage + drop | `client/wheeldmgcl.lua` — clean rewrite |
| `esx_RealisticVehicleFailure` | ESX damage sim | `client/vehiclefailurecl.lua` — StateBag sync |
| Standalone nitro scripts | 2D text displays | Integrated NUI bar, entity-bone flames |

### Why RDE Car HUD?

| Feature | Generic Car HUDs | RDE Car HUD |
|---|---|---|
| Realtime multi-player sync | Polling / TriggerClientEvent | ✅ StateBag — event-driven, zero spam |
| Wheel damage | ❌ | ✅ Fall + collision detection |
| Wheels fall off | ❌ | ✅ Physics prop spawn |
| Engine failure phases | ❌ | ✅ 5-phase cascading system |
| Smoke / fire effects | Static GTA defaults | ✅ Entity-bone attached — follow the car |
| All players see effects | ❌ | ✅ StateBag broadcasts instantly |
| Turbo boost display | ❌ | ✅ Live bar in cockpit |
| Nitro display | 2D screen text | ✅ Integrated NUI bar |
| Tire status in HUD | ❌ | ✅ FL/FR/RL/RR with 4 states |
| Passenger seatbelt | ❌ | ✅ Dedicated indicator |
| Spare tire item | ❌ | ✅ `rde_ersatzreifen` with animation |
| External repair detection | ❌ | ✅ Auto-detects fixkit/carservice/admin |
| ESX dependency | Required | ✅ None — pure ox stack |

---

## ✨ Features

### 🎛️ Analog Cockpit (NUI)

- Dual primary gauges — **Speedometer** (0–280 km/h or mph) and **RPM** (0–8000 rpm × 1000)
- Dual secondary gauges — **Fuel** and **Engine Temperature**
- Real-time **Gear Display** with N/R/1–8 states
- **Odometer** + **Trip Meter** with automatic DB persistence
- **Fuel percentage** with low-fuel color warning
- **Turbo Boost Bar** — only visible when vehicle has turbo installed (`IsToggleModOn 18`)
- **Nitro Bar** — replaces old 2D text, only visible when nitro > 0
- **Tire Status Row** (FL / FR / RL / RR) with 4 visual states: ok / damaged / burst / missing
- **Status Icons** — engine, seatbelt, cruise control, low beam, high beam
- **Blinker Arrows** with animated pulse
- **Windshield Damage Overlay** — 5 severity levels of crack overlay
- **Engine Overheat Banner** — pulsing warning at 110°C+

### 🔧 Engine Control

- **M key** to toggle engine on/off with starter crank audio sequence (procedurally generated)
- **Limp Mode** feedback — notification when engine is critically damaged
- **Temperature tracking** — idle / city / highway / racing heat rates, cooling when driving
- **Performance loss** based on temperature phase
- Admin commands for fleet engine control

### 🚗 Cruise Control & Signals

- **X key** cruise control with speed lock
- **Blinkers** (← → both) with statebag sync to all players
- All signal states visible on other players' vehicles

### 💺 Seatbelt System

- **B key** for driver and passengers
- **Ejection mechanic** on crash above threshold speed
- **Passenger seatbelt indicator** — dedicated bottom-right element, zero flicker (single dedicated thread)
- Windshield damage accumulates on crash

### 🛞 Wheel Damage (merged from rde_realcardamage)

- **Fall damage** — Z-velocity impact detection, suspension compression as multiplier, per-class damage multiplier, minimum airtime gate
- **Collision damage** — health delta detection, forward-vector dot-product to determine front/rear/side impact, correct wheels take damage
- **Wheel falls off** — physics prop spawns with vehicle velocity impulse, 100% realistic (4-wheel vehicles)
- **Burst tires** — for 6+ wheel vehicles on critical damage
- **Visual state** — entity XOffset saved per bone before drop, restored exactly (no center-spawn bug)
- **StateBag sync** `rde_wheeldamage_broken_N` — all nearby players see missing wheel in ≤300ms
- **Auto repair detection** — smart health check in 300ms thread catches fixkit, carservice, `/car fix`, `SetVehicleFixed` — no extra polling
- **Spare tire item** (`rde_ersatzreifen`) with progress bar + server item validation

### 🔥 Vehicle Failure Simulation (merged from esx_RealisticVehicleFailure)

- **Damage amplification** — engine 3×, body 2×, petrol tank 15× per 50ms tick
- **Cascading failure** 5-phase state machine:
  - `healthy` → no effects
  - `degrading` (<677 HP) → slow passive decay, no visual
  - `critical` (<310 HP) → light oil smoke, driver notification
  - `limp` (<100 HP) → heavy black smoke + oil drip + spark bursts, limp mode active
  - `dead` — thick smoke + fire, minimal power
- **Entity-bone attached particles** — smoke and fire follow the car at any speed
- **StateBag `rde_vf_phase`** — all players see identical effects in realtime, zero polling
- **Handling normalization** on vehicle enter — equal damage properties across all vehicle classes
- **Spark bursts** — random burst particles on limp/dead phase vehicles while moving
- **Petrol tank explosion prevention** — tank never drops below 750

### ⚡ Nitro System

- Per-vehicle statebag nitro level (0–100)
- Exhaust flame effects on all nearby vehicles
- Sound effects during boost
- Item-based installation (`nitro` item)

### 🔨 Repair Kit

- `fixkit` item with progress animation
- Per-vehicle repair amount configurable
- Auto-syncs state to all players via statebag

---

## 🏗️ Architecture

```
rde_carhud/
├── config.lua                    ← Single global Config, all systems here
├── fxmanifest.lua
├── locales/
│   ├── en.lua
│   └── de.lua
├── data/
│   └── items.lua                 ← ox_inventory export handlers
├── client/
│   ├── main.lua                  ← HUD loop, seatbelt, cruise, signals
│   ├── engine.lua                ← Engine on/off, temperature, audio
│   ├── nitrocl.lua               ← Nitro boost, flames, statebag
│   ├── repairkitcl.lua           ← Repair kit item logic
│   ├── wheeldmgcl.lua            ← Wheel damage, drop, restore, sync
│   └── vehiclefailurecl.lua      ← Damage amplification, phases, particles
├── server/
│   ├── main.lua                  ← DB, mileage, windshield, eject sync
│   ├── nitrosrv.lua              ← Nitro item validation
│   ├── repairkitsrv.lua          ← Repair kit server-side
│   └── wheeldmgsrv.lua           ← Wheel statebag authority, spare tire
└── nui/
    └── index.html                ← Full cockpit UI (no external deps in prod)
```

### Sync Model

```
DRIVER CLIENT                    SERVER                   ALL CLIENTS
     │                              │                          │
     │  SetVehicleWheelHealth()     │                          │
     │  ──────────────────────────► │                          │
     │                              │                          │
     │  Entity.state:set(           │                          │
     │    'rde_wheeldamage_broken', │                          │
     │    true, broadcast=true)     │                          │
     │  ──────────────────────────► │ ────────────────────────►│
     │                              │   AddStateBagChangeHandler
     │                              │   fires immediately      │
     │                              │   → ApplyEffects()       │
```

**Zero `TriggerClientEvent` spam. Zero polling for effects. Pure StateBag.**

---

## 📦 Dependencies

| Resource | Required | Notes |
|---|---|---|
| [oxmysql](https://github.com/communityox/oxmysql) | ✅ Required | Mileage + windshield persistence |
| [ox_core](https://github.com/communityox/ox_core) | ✅ Required | Player/character, groups |
| [ox_lib](https://github.com/communityox/ox_lib) | ✅ Required | UI, notifications, progress, cache |
| [ox_inventory](https://github.com/communityox/ox_inventory) | ✅ Required | Nitro, spare tire, fixkit items |

---

## 🚀 Installation

### 1. Clone

```bash
cd resources
git clone https://github.com/RedDragonElite/rde_carhud.git
```

### 2. Add to `server.cfg`

```cfg
ensure oxmysql
ensure ox_core
ensure ox_lib
ensure ox_inventory
ensure rde_carhud
```

> **Order matters.** `rde_carhud` must start **after** all its dependencies.

### 3. Add Items to ox_inventory

In `ox_inventory/data/items.lua`, add:

```lua
-- Spare Tire
['rde_ersatzreifen'] = {
    label       = 'Spare Tire',
    weight      = 5000,
    stack       = true,
    description = 'Emergency spare tire for wheel replacements.',
},

-- Nitro Kit
['nitro'] = {
    label       = 'Nitrous Kit',
    weight      = 3000,
    stack       = false,
    description = 'Install a nitrous system into any car.',
    client = {
        export = 'rde_carhud.useNitro',
    },
},

-- Repair Kit (if not already present)
['fixkit'] = {
    label       = 'Repair Kit',
    weight      = 2000,
    stack       = true,
    description = 'Emergency vehicle repair kit.',
    client = {
        export = 'rde_carhud.useRepairKit',
    },
},
```

### 4. Database

Table `rde_vehicle_data` is created automatically on first start. No manual SQL import needed.

### 5. Restart

```
restart rde_carhud
```

---

## ⚙️ Configuration

All settings live in `config.lua`. The global `Config` table is accessible from all scripts automatically.

### Core

```lua
Config.Debug  = false           -- verbose F8 / server console output
Config.Locale = 'de'            -- 'en' or 'de'
```

### Vehicle HUD

```lua
Config.Vehicle = {
    speedUnit      = 'KMH',     -- 'KMH' or 'MPH'
    maxSpeed       = 280,        -- speedometer max
    updateInterval = 50,         -- HUD refresh in ms

    seatbelt = {
        enabled       = true,
        ejectSpeed    = 25.0,   -- km/h threshold for ejection
        damageOnEject = true,
        damageAmount  = 25,
    },
}
```

### Wheel Damage

```lua
Config.WheelDamage = {
    enabled               = true,
    collisionDamageAmount = 50,   -- damage per collision event
    fallDamageAmount      = 30,   -- damage per hard landing
    fallThreshold         = 1.5,  -- minimum Z-velocity impact
    minimumAirTime        = 0.5,  -- seconds airborne before fall damage
    fallOffChance         = 100,  -- % chance wheel falls off (4-wheel vehicles)
    tireBurstChance       = 100,  -- % chance tire bursts (6+ wheel vehicles)
    limitVehicleSpeed     = true,
    speedLimit            = 50.0, -- km/h max with missing wheel
    wheelModel            = 'prop_wheel_01',
    wheelRim              = 'prop_wheel_rim_03',
    blacklist = {
        models  = { 'blazer', 'monster' },
        classes = { 14, 15, 16, 21 }, -- boats, helis, planes, trains
    },
}
```

### Spare Tire

```lua
Config.SpareTire = {
    item         = 'rde_ersatzreifen',
    repairTime   = 8000,    -- ms progress bar
    searchRadius = 6.0,     -- max distance to target vehicle
}
```

### Vehicle Failure

```lua
Config.VehicleFailure = {
    enabled               = true,
    damageFactorEngine    = 3.0,    -- engine health delta multiplier
    damageFactorBody      = 2.0,    -- body health delta multiplier
    damageFactorPetrolTank = 15.0,  -- petrol tank delta multiplier
    phaseThresholds = {
        degrading = 677.0,          -- slow passive decay starts
        critical  = 310.0,          -- fast cascading failure
        limp      = 100.0,          -- limp mode floor
    },
    engineSafeGuard       = 100.0,  -- minimum engine health
    limpMode              = true,   -- allow slow movement at floor
    limpTorque            = 0.08,   -- 8% power in limp mode
    normalizeHandling     = true,   -- equal damage properties on enter
    preventExplosions     = true,   -- keep petrol tank ≥ 750
}
```

### Engine Temperature

```lua
Config.Engine.temperature = {
    enabled      = true,
    normalTemp   = 90,
    hotTemp      = 110,    -- light smoke starts
    criticalTemp = 120,    -- heavy smoke, warning notification
    overheatTemp = 130,    -- critical power loss
    damageTemp   = 140,    -- permanent damage risk
}
```

### Nitro

```lua
Config.Nitro = {
    Power         = 100.0,  -- engine power multiplier during boost
    Torque        = 100.0,  -- torque multiplier during boost
    Consumption   = 50,     -- ms between nitro consumption ticks
    FlameInterval = 10,     -- ms between exhaust flame bursts
}
```

### Per-Class Damage Multipliers (Wheel Damage)

```lua
Config.WheelDamage.classDamageMultiplier = {
    [0]=1.0,  -- Compacts
    [1]=1.0,  -- Sedans
    [2]=1.0,  -- SUVs
    [6]=0.95, -- Sports
    [7]=0.95, -- Super
    [8]=0.27, -- Motorcycles (much more resistant)
    [9]=0.7,  -- Off-road
    -- ...
}
```

---

## ⌨️ Key Bindings

| Key | Action |
|---|---|
| `M` | Toggle engine on/off |
| `B` | Toggle seatbelt (driver + passengers) |
| `X` | Toggle cruise control |
| `←` / `→` | Left / right blinker |
| `↓` | Hazard lights (both blinkers) |
| `N` | Toggle neon lights |
| `J` | Toggle windows |

---

## 📦 Item Integration

### Spare Tire (`rde_ersatzreifen`)

Use near a vehicle with damaged/missing wheel:

1. Item used → finds worst wheel (missing > burst > damaged)
2. Server validates item ownership → removes it
3. Client plays repair animation (8s progress bar)
4. Wheel restored, statebag cleared, HUD updates in ≤300ms

```lua
-- Give player a spare tire (server-side example)
exports.ox_inventory:AddItem(source, 'rde_ersatzreifen', 1)
```

### Nitro Kit (`nitro`)

```lua
-- Give nitro kit to player
exports.ox_inventory:AddItem(source, 'nitro', 1)
-- Player uses item → installer animation → vehicle gets 100% nitro
-- Boost with Left Shift while driving
```

### Repair Kit (`fixkit`)

```lua
-- Full vehicle repair
exports.ox_inventory:AddItem(source, 'fixkit', 1)
-- After repair: rde_carhud auto-detects wheel statebag changes
-- HUD tire indicators update automatically without polling
```

---

## 🔧 Developer API

### Client Exports

```lua
-- Vehicle HUD state
local data  = exports.rde_carhud:getVehicleData()   -- {plate, mileage, tripMeter, ...}
local state = exports.rde_carhud:getPlayerState()    -- {inVehicle, isDriver, seatbelt, ...}
local km    = exports.rde_carhud:getMileage()        -- current odometer as integer

-- Seatbelt
local buckled = exports.rde_carhud:isSeatbeltOn()

-- Engine state
local engState  = exports.rde_carhud:getEngineState()
local temp      = exports.rde_carhud:getEngineTemperature()
local phase     = exports.rde_carhud:getEnginePhase()   -- 'normal'|'hot'|'critical'|'overheating'
local isDamaged = exports.rde_carhud:isEngineDamaged()

-- Vehicle failure phase
local vfPhase = exports.rde_carhud:getVehicleFailurePhase(veh)
-- returns 'healthy'|'degrading'|'critical'|'limp'|'dead'

local isLimp = exports.rde_carhud:isVehicleInLimpMode(veh)

-- Nitro
local level  = exports.rde_carhud:getNitroLevel(veh)
local active = exports.rde_carhud:isNitroActive(veh)
exports.rde_carhud:setNitroLevel(veh, 100)

-- Repair kit
local repairing = exports.rde_carhud:isRepairing()
local health    = exports.rde_carhud:getVehicleHealth(veh) -- {body, engine, petrol}
exports.rde_carhud:repairVehicle(veh)                      -- trigger repair
```

### Server Exports

```lua
-- Wheel damage
local broken = exports.rde_carhud:isWheelBroken(vehicleNetId, wheelIdx)
-- wheelIdx nil = check any wheel

exports.rde_carhud:fixAllWheels(vehicleNetId)
-- Clears all statebags, triggers client restore
```

### Net Events

```lua
-- Force wheel damage (from another resource)
TriggerClientEvent('rde_wheeldamage:damageWheel', source, veh, wheelIdx, damage)

-- Force wheel removal
TriggerClientEvent('rde_wheeldamage:removeWheel', source, veh, wheelIdx)

-- Fix a specific wheel
TriggerClientEvent('rde_wheeldamage:fixWheel', source, veh, wheelIdx)

-- Fix all wheels
TriggerClientEvent('rde_wheeldamage:fixCar', source, veh)
```

### StateBags (read from any resource)

```lua
-- Wheel damage
Entity(veh).state.rde_wheeldamage_broken           -- bool: any wheel missing
Entity(veh).state['rde_wheeldamage_broken_0']      -- bool: FL wheel
Entity(veh).state['rde_wheeldamage_broken_1']      -- bool: FR wheel
Entity(veh).state['rde_wheeldamage_broken_2']      -- bool: RL wheel
Entity(veh).state['rde_wheeldamage_broken_3']      -- bool: RR wheel

-- Vehicle failure
Entity(veh).state.rde_vf_phase                     -- 'healthy'|'degrading'|'critical'|'limp'|'dead'

-- Nitro
Entity(veh).state.nitro                             -- 0-100 level
Entity(veh).state.nitroActive                       -- bool: currently boosting

-- HUD
Entity(veh).state.mileage                           -- integer km
Entity(veh).state.windshieldDamage                  -- 0-100
Entity(veh).state.blinkerSignal                     -- 'off'|'left'|'right'|'both'
```

---

## 🗄️ Database

Table auto-created on first start:

```sql
CREATE TABLE rde_vehicle_data (
    plate            VARCHAR(20)   PRIMARY KEY,
    mileage          INT           DEFAULT 0,
    windshield_damage INT          DEFAULT 0,
    engine_damage    INT           DEFAULT 0,
    engine_temp      FLOAT         DEFAULT 90,
    last_updated     TIMESTAMP     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

Data is saved every **5 km** driven or on vehicle exit. No manual imports needed.

---

## ⚡ Performance

### Thread Budget

| Thread | Interval | Condition |
|---|---|---|
| HUD update | 50ms | Driver in vehicle |
| Seatbelt eject detection | Wait(0) / frame | Any vehicle occupant |
| Passenger seatbelt indicator | 120ms / 500ms | Passenger / on foot |
| Wheel fall damage | 25ms | Driver, not blacklisted |
| Wheel collision damage | 1–50ms | Driver, vehicle damaged |
| Wheel visual state | 300ms → 1ms | Vehicles in BrokenVehicles list |
| Vehicle pool scan | 3000ms | Always (very cheap) |
| Effect maintenance | 2000ms | Vehicles with active effects |
| Spark bursts | 500–2000ms | limp/dead phase vehicles nearby |
| Vehicle failure damage | 50ms | Driver only |

### StateBag Events (zero-cost when idle)

| StateBag | Fires when |
|---|---|
| `rde_wheeldamage_broken` | Wheel drops or is repaired |
| `rde_wheeldamage_broken_N` | Specific wheel state change |
| `rde_vf_phase` | Engine phase transition |
| `repairState` | Fixkit repair completed |

### Benchmarks

| Scenario | Overhead |
|---|---|
| Idle in vehicle (driver) | ~0.02ms |
| Driving, all systems active | ~0.08ms |
| Wheel dropped, 3 clients watching | <0.1ms sync |
| Vehicle in limp phase (sparks) | ~0.05ms |

---

## 🐛 Troubleshooting

**Wheels not falling off after crashes?**
The system requires actual body or engine health loss detected in the collision thread. Minor bumps won't drop wheels — you need a proper collision. Enable `Config.Debug = true` and check F8 console for `[RDE WHEELDMG]` output confirming damage was applied.

**HUD not showing?**
Ensure `Config.Vehicle.allowedClasses` includes your vehicle class. Motorcycles (class 8) are excluded by default from the seatbelt system but HUD should still show.

**Wheels appear in the center of the car after repair?**
This was a known bug fixed in v1.0.0. The bone-based XOffset save/restore is now correct. If you see it: update to latest zip and restart.

**`useNitro` export not found error?**
Ensure your `ox_inventory` item for `nitro` is configured with `export = 'rde_carhud.useNitro'`. This export is in `client/nitrocl.lua`.

**Spare tire doesn't do anything?**
The item must be named exactly `rde_ersatzreifen` in ox_inventory. Check server console for `rde_carhud:requestSpareTire` events. If nothing fires, the item export `use_rde_ersatzreifen` is not registered — ensure `data/items.lua` is in the `client_scripts` block of `fxmanifest.lua`.

**Smoke / fire not visible to other players?**
StateBag `rde_vf_phase` must be set by the driver's client. Check that `Config.VehicleFailure.enabled = true` and no script errors are killing the `vehiclefailurecl.lua` thread. Check the client F8 console for errors.

**Engine temperature always at 90°C?**
`Config.Engine.temperature.enabled` might be false, or the engine control system (engine.lua) has a script error. Enable debug and check console.

**Blinkers not visible to other players?**
StateBag `blinkerSignal` is set on blinker toggle. Ensure the vehicle is networked (not a local entity). Check `Config.Vehicle.statebagSync = true`.

**Database table not created?**
Ensure `oxmysql` is fully started before `rde_carhud` in `server.cfg`. Check server console for `[RDE | Cockpit v1.0.0] Database table rde_vehicle_data initialized`.

---

## 📝 Changelog

### v1.0.0-beta — 2026-06-14 — Community Beta Release

**Status:** Core systems confirmed working in live testing. Edge cases possible — report via GitHub Issues.

**Merged resources:**
- `rde_realcardamage` — complete clean rewrite in RDE OX Standards
- `esx_RealisticVehicleFailure` — full rewrite, ESX removed, StateBag sync added

**New features:**
- Turbo boost bar in cockpit NUI
- Nitro bar replaces 2D DrawAdvancedText
- Tire status (FL/FR/RL/RR) with 4 visual states in cockpit
- Passenger seatbelt indicator (dedicated thread, no flicker)
- Spare tire item `rde_ersatzreifen` with server validation
- Forward-vector dot-product collision detection (correct front/rear wheels take damage)
- Entity-bone attached particles (smoke/fire follow the car)
- Auto repair detection for all external repair systems
- Bone-based XOffset save/restore (correct wheel position on repair)

**Architecture:**
- StateBag-first, zero `TriggerClientEvent` spam for effects
- Single dedicated thread per concern, no shared state conflicts
- `Config` global (not local) — accessible from all scripts

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Follow existing Lua conventions — RDE OX Standards apply
4. Each file must have its own `local function Debug()`
5. Never `Wait()` inside NetEvents — always `CreateThread`
6. Fix ≠ Refactor — surgical patches over architectural rewrites
7. Test on a live server before PR
8. Update this README if adding features

---

## 📜 License

```
###################################################################################
#                                                                                 #
#      .:: RED DRAGON ELITE (RDE)  -  BLACK FLAG SOURCE LICENSE v6.66 ::.         #
#                                                                                 #
#   PROJECT:    RDE_CARHUD v1.0.0 (VEHICLE COCKPIT | DAMAGE SIM | HUD SUITE)     #
#   ARCHITECT:  .:: RDE ⧌ Shin [△ ᛋᛅᚱᛒᛅᚾᛏᛋ ᛒᛁᛏᛅ ▽] ::. | https://rd-elite.com     #
#   ORIGIN:     https://github.com/RedDragonElite                                 #
#                                                                                 #
#   1. FREE FOREVER — use it, edit it, learn from it. Cost: 0.00€.               #
#   2. TEBEX = DMCA — selling this is theft. You will be found.                   #
#   3. KEEP THE HEADER — credit where it is due.                                  #
#   4. RTFM — copy-paste without reading will break your server.                  #
#                                                                                 #
#   "We build the future on the graves of paid resources."                        #
###################################################################################
```

**TL;DR:**
- ✅ Free forever — use it, edit it, learn from it
- ✅ Keep the header — credit where it's due
- ❌ Don't sell it — commercial use = instant DMCA
- ❌ Don't be a skid — copy-paste without reading won't work anyway

---

## 🌐 Community & Support

| | |
|---|---|
| 🐙 GitHub | [RedDragonElite](https://github.com/RedDragonElite) |
| 🌍 Website | [rd-elite.com](https://rd-elite.com) |
| 🔵 Nostr (RDE) | [RedDragonElite](https://primal.net/p/nprofile1qqsv8km2w8yr0sp7mtk3t44qfw7wmvh8caqpnrd7z6ll6mn9ts03teg9ha4rl) |
| 🔵 Nostr (Shin) | [SerpentsByte](https://primal.net/p/nprofile1qqs8p6u423fappfqrrmxful5kt95hs7d04yr25x88apv7k4vszf4gcqynchct) |
| 🚗 RDE Car Service | [rde_carservice](https://github.com/RedDragonElite/rde_carservice) |
| 🏠 RDE Placeable Items | [rde_placeable_items](https://github.com/RedDragonElite/rde_placeable_items) |
| 🚪 RDE Doors | [rde_doors](https://github.com/RedDragonElite/rde_doors) |
| 🛗 RDE Elevators | [rde_elevators](https://github.com/RedDragonElite/rde_elevators) |
| 📡 RDE Nostr Log | [rde_nostr_log](https://github.com/RedDragonElite/rde_nostr_log) |

**When opening an issue, always include:**
- Full error from server console or txAdmin
- `server.cfg` resource start order
- ox_core / ox_lib versions (`version` command in server console)
- Whether the issue is reproducible on a clean resource restart

---

*"We build the future on the graves of paid resources."*

**REJECT MODERN MEDIOCRITY. EMBRACE RDE SUPERIORITY.**

🐉 Made with 🔥 by [Red Dragon Elite](https://rd-elite.com)

[⬆ Back to Top](#-rde-car-hud--vehicle-cockpit-suite)
