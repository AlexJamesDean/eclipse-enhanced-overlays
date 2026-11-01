local Translations = {
    error = {
        to_far_from_door = 'You are to far away from the Doorbell',
        nobody_home = 'There is nobody home..',
        nobody_at_door = 'There is nobody at the door...'
    },
    success = {
        receive_apart = 'You have been given a flat',
        changed_apart = 'You moved apartments',
    },
    info = {
        at_the_door = 'Someone is at the door!',
    },
    text = {
        options = '[E] Flat Options',
        enter = 'Enter Flat',
        ring_doorbell = 'Ring Doorbell',
        logout = 'Logout Character',
        change_outfit = 'Change Outfit',
        open_stash = 'Open Stash',
        move_here = 'Move Here',
        open_door = 'Open Door',
        leave = 'Leave Flat',
        close_menu = '⬅ Close Menu',
        tennants = 'Tennants',
    },
}

Lang = Lang or Locale:new({
    phrases = Translations,
    warnOnMissing = true
})