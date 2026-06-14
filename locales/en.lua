-- RDE | Cockpit v1.0.0 — English locale
locale = {
    -- General
    success             = 'Success',
    error               = 'Error',
    warning             = 'Warning',
    info                = 'Information',
    no_permission       = 'You do not have permission',

    -- Seatbelt
    seatbelt_on         = 'Seatbelt fastened',
    seatbelt_off        = 'Seatbelt unfastened',
    crash_ejected       = 'You were ejected!',

    -- Cruise Control
    cruise_activated    = 'Cruise Control activated: %d %s',
    cruise_deactivated  = 'Cruise Control deactivated',

    -- Engine Control
    engine_starting     = 'Starting engine...',
    engine_started      = 'Engine started',
    engine_stopped      = 'Engine stopped',
    engine_running      = 'Engine is already running',
    engine_off          = 'Engine is off — press M to start',
    engine_keeps_running = 'Engine keeps running',

    -- Neon
    neon_on             = 'Neon lights ON',
    neon_off            = 'Neon lights OFF',

    -- Windows
    window_front_left   = 'Front left window',
    window_front_right  = 'Front right window',
    window_rear_left    = 'Rear left window',
    window_rear_right   = 'Rear right window',
    window_toggle_all   = 'Toggle all windows',
    all_windows_up      = 'All windows closed',
    all_windows_down    = 'All windows open',
    window_up           = 'Window closed',
    window_down         = 'Window opened',
    window_status_up    = '▲ Closed',
    window_status_down  = '▼ Open',
    window_menu_title   = 'Window Control',

    -- Engine temperature
    engine_hot          = 'Engine running hot: %.0f°C\nReduce speed to cool down',
    engine_critical     = 'CRITICAL: Engine Overheating!\n%.0f°C — Stop NOW or risk permanent damage!',
    engine_overheating  = 'ENGINE OVERHEATING!\n%.0f°C — Severe power loss! Let engine cool down!',
    engine_damaged      = 'ENGINE DAMAGED!\nPermanent damage at %.0f°C — Mechanic required!',
    engine_recovered    = 'Engine recovered and cooled down',

    -- Admin
    admin_stop_all      = 'Admin stopped all engines!',
    admin_start_all     = 'Admin started all engines!',

    -- Mileage
    mileage_check       = '%s: %d km | Windshield: %d%%',
    mileage_reset_done  = 'Mileage and windshield damage reset',
    must_be_in_vehicle  = 'You must be in a vehicle',

    -- Wheel damage
    wheel_burst         = 'Tire burst! (Wheel %s)',
    wheel_missing       = 'Wheel fell off! (%s)',
    wheel_warning       = 'Wheel damage detected!',
    speed_limited       = 'Speed limited due to missing wheel',

    -- Spare tire
    spare_no_vehicle    = 'No vehicle nearby to repair!',
    spare_no_damage     = 'All tires are intact — no repair needed',
    spare_repairing     = 'Changing tire...',
    spare_done          = 'Tire changed successfully!',
    spare_cancelled     = 'Tire change cancelled',
    spare_no_item       = 'You don\'t have a spare tire!',
    spare_must_stop     = 'Stop the vehicle before changing a tire!',
}
