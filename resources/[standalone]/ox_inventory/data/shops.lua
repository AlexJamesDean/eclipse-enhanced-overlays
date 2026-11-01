-- NOTE (30 Jul 2026): shared.target is FALSE on this server — this ox build only
-- supports ox_target (qb-target does not count), so shops run off each entry's
-- `locations` (marker + [E]); the `targets` arrays are ignored dead weight.
-- New entries below define locations only.
-- 30 Jul consolidation: every qb-shops location is now covered here and
-- qb-shops is disabled. Prices mirror the old qb-shops config.

-- Shared stock for the five mechanic job shops. The veh_*/nitrous/tunerlaptop
-- tuning items were dropped 30 Jul 2026 with qb-mechanicjob's retirement —
-- their use handlers lived there and ajd-mechanic's NUI applies mods directly,
-- so they would have sold as dead weight. Kit use handlers now live in
-- ajd-mechanic (server/kits.lua); prices stay at the old public hardware rates.
local mechanicInventory = {
	{ name = 'repairkit', price = 250 },
	{ name = 'advancedrepairkit', price = 500 },
	{ name = 'tirerepairkit', price = 250 },
	{ name = 'cleaningkit', price = 150 },
}

return {
	General = {
		name = 'Corner Shop',
		blip = {
			id = 59, colour = 69, scale = 0.8
		}, inventory = {
			-- Item names MUST exist in data/items.lua (or weapons.lua) — ox
			-- silently drops unknown names and the shop renders empty. This
			-- server's items are the qb-migrated names, NOT ox's demo
			-- burger/water/cola. Prices mirror qb-shops config.lua.
			{ name = 'tosti', price = 2 },
			{ name = 'sandwich', price = 2 },
			{ name = 'water_bottle', price = 2 },
			{ name = 'kurkakola', price = 2 },
			{ name = 'twerks_candy', price = 2 },
			{ name = 'snikkel_candy', price = 2 },
			{ name = 'beer', price = 7 },
			{ name = 'whiskey', price = 10 },
			{ name = 'vodka', price = 12 },
			{ name = 'bandage', price = 100 },
			{ name = 'lighter', price = 2 },
			{ name = 'rolling_paper', price = 2 },
		}, locations = {
			vec3(25.7, -1347.3, 29.49),
			vec3(-3038.71, 585.9, 7.9),
			vec3(-3241.47, 1001.14, 12.83),
			vec3(1728.66, 6414.16, 35.03),
			vec3(1961.48, 3739.96, 32.34),
			vec3(547.79, 2671.79, 42.15),
			vec3(2679.25, 3280.12, 55.24),
			vec3(2557.94, 382.05, 108.62),
			vec3(373.55, 325.56, 103.56),
			-- LTD Gasoline (ported from qb-shops; same product range)
			vec3(-47.02, -1758.23, 29.42),
			vec3(-706.06, -913.97, 19.22),
			vec3(-1820.02, 794.03, 138.09),
			vec3(1164.71, -322.94, 69.21),
		}, targets = {
			{ loc = vec3(25.06, -1347.32, 29.5), length = 0.7, width = 0.5, heading = 0.0, minZ = 29.5, maxZ = 29.9, distance = 1.5 },
			{ loc = vec3(-3039.18, 585.13, 7.91), length = 0.6, width = 0.5, heading = 15.0, minZ = 7.91, maxZ = 8.31, distance = 1.5 },
			{ loc = vec3(-3242.2, 1000.58, 12.83), length = 0.6, width = 0.6, heading = 175.0, minZ = 12.83, maxZ = 13.23, distance = 1.5 },
			{ loc = vec3(1728.39, 6414.95, 35.04), length = 0.6, width = 0.6, heading = 65.0, minZ = 35.04, maxZ = 35.44, distance = 1.5 },
			{ loc = vec3(1960.54, 3740.28, 32.34), length = 0.6, width = 0.5, heading = 120.0, minZ = 32.34, maxZ = 32.74, distance = 1.5 },
			{ loc = vec3(548.5, 2671.25, 42.16), length = 0.6, width = 0.5, heading = 10.0, minZ = 42.16, maxZ = 42.56, distance = 1.5 },
			{ loc = vec3(2678.29, 3279.94, 55.24), length = 0.6, width = 0.5, heading = 330.0, minZ = 55.24, maxZ = 55.64, distance = 1.5 },
			{ loc = vec3(2557.19, 381.4, 108.62), length = 0.6, width = 0.5, heading = 0.0, minZ = 108.62, maxZ = 109.02, distance = 1.5 },
			{ loc = vec3(373.13, 326.29, 103.57), length = 0.6, width = 0.5, heading = 345.0, minZ = 103.57, maxZ = 103.97, distance = 1.5 },
		}
	},

	GrapeseedGeneral = {
		name = 'Corner Shop',
		-- No special blip or label advertises the packaging supply.
		blip = {
			id = 59, colour = 69, scale = 0.8
		},
		inventory = {
			{ name = 'tosti', price = 2 },
			{ name = 'sandwich', price = 2 },
			{ name = 'water_bottle', price = 2 },
			{ name = 'kurkakola', price = 2 },
			{ name = 'beer', price = 7 },
			{ name = 'bandage', price = 100 },
			{ name = 'lighter', price = 2 },
			{ name = 'rolling_paper', price = 2 },
			{ name = 'empty_weed_bag', price = 2 },
		},
		locations = {
			vec3(1697.99, 4924.4, 42.06),
		},
		targets = {
			{ loc = vec3(1698.37, 4923.43, 42.06), length = 0.5, width = 0.5, heading = 235.0, minZ = 42.06, maxZ = 42.46, distance = 1.5 },
		}
	},

	Liquor = {
		name = 'Off-Licence',
		blip = {
			id = 93, colour = 69, scale = 0.8
		}, inventory = {
			{ name = 'beer', price = 7 },
			{ name = 'whiskey', price = 10 },
			{ name = 'vodka', price = 12 },
			{ name = 'water_bottle', price = 2 },
			{ name = 'kurkakola', price = 2 },
		}, locations = {
			vec3(1135.808, -982.281, 46.415),
			vec3(-1222.915, -906.983, 12.326),
			vec3(-1487.553, -379.107, 40.163),
			vec3(-2968.243, 390.910, 15.043),
			vec3(1166.024, 2708.930, 38.157),
			vec3(1392.562, 3604.684, 34.980),
			vec3(-1393.409, -606.624, 30.319)
		}, targets = {
			{ loc = vec3(1134.9, -982.34, 46.41), length = 0.5, width = 0.5, heading = 96.0, minZ = 46.4, maxZ = 46.8, distance = 1.5 },
			{ loc = vec3(-1222.33, -907.82, 12.43), length = 0.6, width = 0.5, heading = 32.7, minZ = 12.3, maxZ = 12.7, distance = 1.5 },
			{ loc = vec3(-1486.67, -378.46, 40.26), length = 0.6, width = 0.5, heading = 133.77, minZ = 40.1, maxZ = 40.5, distance = 1.5 },
			{ loc = vec3(-2967.0, 390.9, 15.14), length = 0.7, width = 0.5, heading = 85.23, minZ = 15.0, maxZ = 15.4, distance = 1.5 },
			{ loc = vec3(1165.95, 2710.20, 38.26), length = 0.6, width = 0.5, heading = 178.84, minZ = 38.1, maxZ = 38.5, distance = 1.5 },
			{ loc = vec3(1393.0, 3605.95, 35.11), length = 0.6, width = 0.6, heading = 200.0, minZ = 35.0, maxZ = 35.4, distance = 1.5 }
		}
	},

	YouTool = {
		name = 'Tool Hire & Hardware',
		blip = {
			id = 402, colour = 69, scale = 0.8
		}, inventory = {
			-- Full hardware range ported from qb-shops (prices mirrored).
			-- repairkit/advancedrepairkit are NOT sold publicly (qb job-locked
			-- them); they live in the mechanic job shops below.
			{ name = 'lockpick', price = 200 },
			{ name = 'WEAPON_WRENCH', price = 250 },
			{ name = 'WEAPON_HAMMER', price = 250 },
			{ name = 'plant_trimmers', price = 250 },
			{ name = 'screwdriverset', price = 350 },
			{ name = 'phone', price = 850 },
			{ name = 'radio', price = 250 },
			{ name = 'binoculars', price = 50 },
			{ name = 'firework1', price = 50 },
			{ name = 'firework2', price = 50 },
			{ name = 'firework3', price = 50 },
			{ name = 'firework4', price = 50 },
			{ name = 'fitbit', price = 400 },
			{ name = 'cleaningkit', price = 150 },
		}, locations = {
			vec3(2748.0, 3473.0, 55.67),
			vec3(342.99, -1298.26, 32.51),
			-- Ported from qb-shops (hardware + Paleto hardware)
			vec3(45.68, -1749.04, 29.61),
			vec3(-421.83, 6136.13, 31.88),
		}, targets = {
			{ loc = vec3(2746.8, 3473.13, 55.67), length = 0.6, width = 3.0, heading = 65.0, minZ = 55.0, maxZ = 56.8, distance = 3.0 }
		}
	},

	Ammunation = {
		name = 'Registered Firearms Dealer',
		blip = {
			id = 110, colour = 69, scale = 0.8
		}, inventory = {
			{ name = 'ammo-9', price = 5, },
			-- Prices aligned to the old qb-shops economy 30 Jul
			{ name = 'WEAPON_KNIFE', price = 250 },
			{ name = 'WEAPON_BAT', price = 250 },
			{ name = 'WEAPON_HATCHET', price = 250 },
			{ name = 'WEAPON_PISTOL', price = 2500, metadata = { registered = true }, license = 'weapon' },
			{ name = 'WEAPON_SNSPISTOL', price = 1500, metadata = { registered = true }, license = 'weapon' },
			{ name = 'WEAPON_VINTAGEPISTOL', price = 4000, metadata = { registered = true }, license = 'weapon' }
		}, locations = {
			vec3(-662.180, -934.961, 21.829),
			vec3(810.25, -2157.60, 29.62),
			vec3(1693.44, 3760.16, 34.71),
			vec3(-330.24, 6083.88, 31.45),
			vec3(252.63, -50.00, 69.94),
			vec3(22.56, -1109.89, 29.80),
			vec3(2567.69, 294.38, 108.73),
			vec3(-1117.58, 2698.61, 18.55),
			vec3(842.44, -1033.42, 28.19),
			-- Ported from qb-shops (Morningwood + Chumash)
			vec3(-1304.19, -395.12, 36.70),
			vec3(-3173.31, 1088.85, 20.84)
		}, targets = {
			{ loc = vec3(-660.92, -934.10, 21.94), length = 0.6, width = 0.5, heading = 180.0, minZ = 21.8, maxZ = 22.2, distance = 2.0 },
			{ loc = vec3(808.86, -2158.50, 29.73), length = 0.6, width = 0.5, heading = 360.0, minZ = 29.6, maxZ = 30.0, distance = 2.0 },
			{ loc = vec3(1693.57, 3761.60, 34.82), length = 0.6, width = 0.5, heading = 227.39, minZ = 34.7, maxZ = 35.1, distance = 2.0 },
			{ loc = vec3(-330.29, 6085.54, 31.57), length = 0.6, width = 0.5, heading = 225.0, minZ = 31.4, maxZ = 31.8, distance = 2.0 },
			{ loc = vec3(252.85, -51.62, 70.0), length = 0.6, width = 0.5, heading = 70.0, minZ = 69.9, maxZ = 70.3, distance = 2.0 },
			{ loc = vec3(23.68, -1106.46, 29.91), length = 0.6, width = 0.5, heading = 160.0, minZ = 29.8, maxZ = 30.2, distance = 2.0 },
			{ loc = vec3(2566.59, 293.13, 108.85), length = 0.6, width = 0.5, heading = 360.0, minZ = 108.7, maxZ = 109.1, distance = 2.0 },
			{ loc = vec3(-1117.61, 2700.26, 18.67), length = 0.6, width = 0.5, heading = 221.82, minZ = 18.5, maxZ = 18.9, distance = 2.0 },
			{ loc = vec3(841.05, -1034.76, 28.31), length = 0.6, width = 0.5, heading = 360.0, minZ = 28.2, maxZ = 28.6, distance = 2.0 }
		}
	},

	PoliceArmoury = {
		name = 'Police Armoury',
		groups = shared.police,
		blip = {
			id = 110, colour = 84, scale = 0.8
		}, inventory = {
			{ name = 'ammo-9', price = 5, },
			{ name = 'ammo-rifle', price = 5, },
			{ name = 'WEAPON_FLASHLIGHT', price = 200 },
			{ name = 'WEAPON_NIGHTSTICK', price = 100 },
			{ name = 'WEAPON_PISTOL', price = 500, metadata = { registered = true, serial = 'POL' }, license = 'weapon' },
			{ name = 'WEAPON_CARBINERIFLE', price = 1000, metadata = { registered = true, serial = 'POL' }, license = 'weapon', grade = 3 },
			{ name = 'WEAPON_STUNGUN', price = 500, metadata = { registered = true, serial = 'POL'} },
			-- Ported from qb-shops' police shop (it issued these free)
			{ name = 'WEAPON_PUMPSHOTGUN', price = 0, metadata = { registered = true, serial = 'POL' }, license = 'weapon' },
			{ name = 'WEAPON_SMG', price = 0, metadata = { registered = true, serial = 'POL' }, license = 'weapon', grade = 3 },
			{ name = 'ammo-shotgun', price = 5 },
			{ name = 'handcuffs', price = 0 },
			{ name = 'empty_evidence_bag', price = 0 },
			{ name = 'police_stormram', price = 0 },
			{ name = 'armor', price = 0 },
			{ name = 'heavyarmor', price = 0 },
			{ name = 'radio', price = 0 }
		}, locations = {
			vec3(451.51, -979.44, 30.68)
		}, targets = {
			{ loc = vec3(453.21, -980.03, 30.68), length = 0.5, width = 3.0, heading = 270.0, minZ = 30.5, maxZ = 32.0, distance = 6 }
		}
	},

	Medicine = {
		name = 'Medicine Cabinet',
		groups = {
			['ambulance'] = 0
		},
		blip = {
			id = 403, colour = 69, scale = 0.8
		}, inventory = {
			{ name = 'firstaid', price = 26 },
			{ name = 'ifaks', price = 10 },
			{ name = 'bandage', price = 5 },
			-- Ported from qb-shops' ambulance shop (it issued these free)
			{ name = 'painkillers', price = 0 },
			{ name = 'radio', price = 0 },
			{ name = 'WEAPON_FLASHLIGHT', price = 0 },
			{ name = 'WEAPON_FIREEXTINGUISHER', price = 0 }
		}, locations = {
			vec3(306.3687, -601.5139, 43.28406)
		}, targets = {

		}
	},

	BlackMarketArms = {
		name = 'Black Market (Arms)',
		inventory = {
			{ name = 'WEAPON_DAGGER', price = 5000, metadata = { registered = false	}, currency = 'black_money' },
			{ name = 'WEAPON_CERAMICPISTOL', price = 50000, metadata = { registered = false }, currency = 'black_money' },
			{ name = 'at_suppressor_light', price = 50000, currency = 'black_money' },
			{ name = 'ammo-rifle', price = 1000, currency = 'black_money' },
			{ name = 'ammo-rifle2', price = 1000, currency = 'black_money' }
		}, locations = {
			vec3(309.09, -913.75, 56.46)
		}, targets = {

		}
	},

	-- ==== Shops ported from qb-shops, 30 Jul 2026 consolidation ====

	WeedShop = {
		name = 'Smoke On The Water',
		blip = {
			id = 140, colour = 69, scale = 0.8
		}, inventory = {
			{ name = 'joint', price = 10 },
			{ name = 'WEAPON_POOLCUE', price = 100 },
			{ name = 'weed_nutrition', price = 20 },
			{ name = 'empty_weed_bag', price = 2 },
			{ name = 'rolling_paper', price = 2 },
		}, locations = {
			vec3(-1168.26, -1573.2, 4.66)
		}
	},

	SeaWord = {
		name = 'Sea Word',
		blip = {
			id = 52, colour = 69, scale = 0.8
		}, inventory = {
			{ name = 'diving_gear', price = 2500 },
			{ name = 'jerry_can', price = 200 },
		}, locations = {
			vec3(-1687.03, -1072.18, 13.15)
		}
	},

	LeisureShop = {
		name = 'Leisure Shop',
		blip = {
			id = 52, colour = 69, scale = 0.8
		}, inventory = {
			{ name = 'parachute', price = 2500 },
			{ name = 'binoculars', price = 50 },
			{ name = 'diving_gear', price = 2500 },
			{ name = 'diving_fill', price = 500 },
		}, locations = {
			vec3(-1505.91, 1511.95, 115.29)
		}
	},

	PrisonCanteen = {
		name = 'Canteen',
		inventory = {
			{ name = 'sandwich', price = 4 },
			{ name = 'water_bottle', price = 4 },
		}, locations = {
			vec3(1777.59, 2560.52, 44.62)
		}
	},

	-- Mechanic job shops: one entry per shop job (mirrors qb-shops requiredJob).
	MechanicShop = {
		name = 'Motor Factors',
		groups = { ['mechanic'] = 0 },
		inventory = mechanicInventory,
		locations = {
			vec3(-343.66, -140.78, 39.02),  -- 1: LS Customs Burton
			vec3(720.48, -1092.19, 22.29),  -- 2: LS Customs La Mesa (ajd-mechanic bay id 2)
		}
	},

	MechanicShopSandy = {
		name = 'Motor Factors',
		groups = { ['mechanic2'] = 0 },
		inventory = mechanicInventory,
		locations = {
			vec3(1189.36, 2641.00, 38.44)
		}
	},

	MechanicShopSouthLS = {
		name = 'Motor Factors',
		groups = { ['mechanic3'] = 0 },
		inventory = mechanicInventory,
		locations = {
			vec3(-1156.56, -1999.85, 13.19)
		}
	},

	BennysShop = {
		name = 'Motor Factors',
		groups = { ['bennys'] = 0 },
		inventory = mechanicInventory,
		locations = {
			vec3(-195.80, -1318.24, 31.08)
		}
	},

	BeekersShop = {
		name = 'Motor Factors',
		groups = { ['beeker'] = 0 },
		inventory = mechanicInventory,
		locations = {
			vec3(100.92, 6616.00, 32.47)
		}
	},

	BlackMarketTools = {
		name = 'Black Market',
		-- Heist/tool side of qb-shops' black market (cash, like qb charged).
		-- Its drug resale + markedbills lines were deliberately dropped: drugs
		-- move through ajd-crafting/ajd-streetselling, not over a counter.
		-- No blip, same as qb.
		inventory = {
			{ name = 'security_card_01', price = 5000 },
			{ name = 'security_card_02', price = 5000 },
			{ name = 'advancedlockpick', price = 5000 }, -- qb config said advanced_lockpick; the real item name has no underscore
			{ name = 'electronickit', price = 5000 },
			{ name = 'gatecrack', price = 5000 },
			{ name = 'thermite', price = 5000 },
			{ name = 'trojan_usb', price = 5000 },
			{ name = 'drill', price = 5000 },
			{ name = 'radioscanner', price = 5000 },
			{ name = 'cryptostick', price = 5000 },
		}, locations = {
			vec3(-594.70, -1616.36, 33.01)
		}
	},

	VendingMachineDrinks = {
		name = 'Vending Machine',
		inventory = {
			{ name = 'water_bottle', price = 2 },
			{ name = 'kurkakola', price = 2 },
		},
		model = {
			`prop_vend_soda_02`, `prop_vend_fridge01`, `prop_vend_water_01`, `prop_vend_soda_01`
		}
	}
}
