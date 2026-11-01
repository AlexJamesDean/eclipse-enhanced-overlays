Config = {}

Config.Currency = '$'

Config.MinimumRaceDistance = 100.0 -- Minimum distance for a race.
Config.MinimumStake = 100          -- Minimum stake for a race.
Config.MaximumStake = 15000        -- Minimum stake for a race.

Config.Commands = {}

Config.Commands.CreateRace = 'createrace' -- Command to start race
-- RENAMED 26 Jul 2026: was 'cancelrace', which qb-lapraces/server.lua:529 also registers.
-- qb-lapraces starts first, so THIS registration lost and street races could not be
-- cancelled at all ("Command cancelrace is already registered" on every boot).
-- The in-game hint at server.lua:164 reads from this value, so it updates itself.
Config.Commands.CancelRace = 'cancelstreetrace' -- Command to cancel race you created
Config.Commands.QuitRace = 'quitrace'     -- Command to leave a race you have entered
Config.Commands.StartRace = 'startrace'   -- Command to start a race you created
