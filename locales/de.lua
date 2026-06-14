-- RDE | Cockpit v1.0.0 — Deutsch locale
locale = {
    -- Allgemein
    success             = 'Erfolg',
    error               = 'Fehler',
    warning             = 'Warnung',
    info                = 'Information',
    no_permission       = 'Keine Berechtigung',

    -- Seatbelt
    seatbelt_on         = 'Sicherheitsgurt angelegt',
    seatbelt_off        = 'Sicherheitsgurt abgelegt',
    crash_ejected       = 'Du wurdest herausgeschleudert!',

    -- Tempomat
    cruise_activated    = 'Tempomat aktiviert: %d %s',
    cruise_deactivated  = 'Tempomat deaktiviert',

    -- Motorsteuerung
    engine_starting     = 'Motor wird gestartet...',
    engine_started      = 'Motor gestartet',
    engine_stopped      = 'Motor gestoppt',
    engine_running      = 'Motor läuft bereits',
    engine_off          = 'Motor aus — drücke M zum Starten',
    engine_keeps_running = 'Motor läuft weiter...',

    -- Neon
    neon_on             = 'Neon-Lichter AN',
    neon_off            = 'Neon-Lichter AUS',

    -- Fenster
    window_front_left   = 'Vorderes linkes Fenster',
    window_front_right  = 'Vorderes rechtes Fenster',
    window_rear_left    = 'Hinteres linkes Fenster',
    window_rear_right   = 'Hinteres rechtes Fenster',
    window_toggle_all   = 'Alle Fenster umschalten',
    all_windows_up      = 'Alle Fenster geschlossen',
    all_windows_down    = 'Alle Fenster geöffnet',
    window_up           = 'Fenster geschlossen',
    window_down         = 'Fenster geöffnet',
    window_status_up    = '▲ Hoch',
    window_status_down  = '▼ Runter',
    window_menu_title   = 'Fenstersteuerung',

    -- Motortemperatur
    engine_hot          = 'Motor läuft heiß: %.0f°C\nGeschwindigkeit reduzieren',
    engine_critical     = 'KRITISCH: Motor überhitzt!\n%.0f°C — Sofort anhalten!',
    engine_overheating  = 'MOTOR ÜBERHITZT!\n%.0f°C — Motor abkühlen lassen!',
    engine_damaged      = 'MOTOR BESCHÄDIGT!\nDauerschaden bei %.0f°C — Mechaniker nötig!',
    engine_recovered    = 'Motor hat sich abgekühlt und erholt',

    -- Admin
    admin_stop_all      = 'Admin hat alle Motoren gestoppt!',
    admin_start_all     = 'Admin hat alle Motoren gestartet!',

    -- Kilometerstand
    mileage_check       = '%s: %d km | Windschutzscheibe: %d%%',
    mileage_reset_done  = 'Kilometerstand und Windschutzscheibenschaden zurückgesetzt',
    must_be_in_vehicle  = 'Du musst in einem Fahrzeug sitzen',

    -- Reifenschaden
    wheel_burst         = 'Reifen geplatzt! (Rad %s)',
    wheel_missing       = 'Rad abgefallen! (%s)',
    wheel_warning       = 'Reifenschaden festgestellt!',
    speed_limited       = 'Geschwindigkeit begrenzt wegen fehlendem Rad',

    -- Ersatzreifen
    spare_no_vehicle    = 'Kein Fahrzeug in der Nähe zum Reparieren!',
    spare_no_damage     = 'Alle Reifen intakt — kein Reifenwechsel nötig',
    spare_repairing     = 'Reifen wird gewechselt...',
    spare_done          = 'Reifen erfolgreich gewechselt!',
    spare_cancelled     = 'Reifenwechsel abgebrochen',
    spare_no_item       = 'Du hast keinen Ersatzreifen!',
    spare_must_stop     = 'Fahrzeug anhalten bevor du den Reifen wechselst!',
}
