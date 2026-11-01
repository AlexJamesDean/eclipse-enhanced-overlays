local Translations = {
    error = {
        smash_own = "You can't smash a vehicle that owns it.",
        cannot_scrap = "Turner's isn't taking this model right now. The list changes every hour, so grab a fresh one from the office.",
        not_driver = "You Are Not The Driver",
        on_foot = "Step out of the vehicle to use the office terminal.",
        email_pending = "Your list is already on its way. Check your phone's Mail shortly.",
        demolish_vehicle = "You Are Not Allowed To Demolish Vehicles Now",
        canceled = "Canceled",
    },
    text = {
        scrapyard = 'Scrap Yard',
        disassemble_vehicle = '[E] - Disassemble Vehicle',
        disassemble_vehicle_target = 'Disassemble Vehicle',
        email_list = "[E] - E-mail Vehicle List",
        email_list_target = "E-mail Vehicle List",
        demolish_vehicle = "Demolish Vehicle",
    },
    email = {
        sender = "Turner’s Auto Wrecking",
        subject = "Vehicle List",
        message = "You Can Only Demolish A Number Of Vehicles.<br />You Can Keep Everything You Demolish For Yourself As Long As You Dont Bother Me.<br />This List Is Only Good For The Hour, And Anything Someone Else Brings In Comes Off It.<br /><br /><strong>Vehicle List:</strong><br />",
    },
}

Lang = Lang or Locale:new({
    phrases = Translations,
    warnOnMissing = true
})
