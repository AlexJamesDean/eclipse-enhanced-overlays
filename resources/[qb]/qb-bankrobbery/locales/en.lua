local Translations = {
    success = {
        success_message = "ACCESS GRANTED",
        fuses_are_blown = "City grid breached — cameras are dropping",
        door_has_opened = "Vault access granted"
    },
    error = {
        cancel_message = "Job aborted",
        safe_too_strong = "The vault lock resisted the drill...",
        missing_item = "You don't have the kit for this job...",
        bank_already_open = "This branch has already been hit...",
        minimum_police_required = (AJD_CITY.name .. " is too quiet — %{police} on-duty police required"),
        security_lock_active = (AJD_CITY.short .. " Security has sealed this door"),
        wrong_type = "%{receiver} did not receive the right type for argument '%{argument}'\nreceived type: %{receivedType}\nreceived value: %{receivedValue}\n expected type: %{expected}",
        fuses_already_blown = "This section of the city grid is already down...",
        event_trigger_wrong = "%{event}%{extraInfo} was triggered when some conditions weren't met, source: %{source}",
        missing_ignition_source = "You're missing an ignition source"
    },
    general = {
        breaking_open_safe = "Drilling the deposit lock...",
        connecting_hacking_device = ("Breaching " .. AJD_CITY.short .. " Security..."),
        fleeca_robbery_alert = (AJD_CITY.short:upper() .. " ALERT — branch robbery in progress"),
        paleto_robbery_alert = (AJD_CITY.short:upper() .. " ALERT — North County Savings robbery"),
        pacific_robbery_alert = (AJD_CITY.short:upper() .. " ALERT — Central Vault robbery"),
        break_safe_open_option_target = "Drill Deposit Lock",
        break_safe_open_option_drawtext = "[E] Drill deposit lock",
        validating_bankcard = "Spoofing banking credentials...",
        thermite_detonating_in_seconds = "Charge burns in %{time} second(s)",
        bank_robbery_police_call = (AJD_CITY.short:upper() .. " DISPATCH • 10-90 BANK ROBBERY")
    }
}

Lang = Lang or Locale:new({
    phrases = Translations,
    warnOnMissing = true
})
