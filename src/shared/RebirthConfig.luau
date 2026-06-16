--!strict

export type RebirthData = {
	LevelRequired: number,
	WinsMultiplier: number,
}

-- Índice = número de rebirth a realizar (1-20)
-- LevelRequired: nivel mínimo necesario para hacer ese rebirth
-- WinsMultiplier: multiplicador de wins activo después de completarlo
local RebirthConfig: { RebirthData } = {
	{ LevelRequired = 50,     WinsMultiplier = 1.5   },
	{ LevelRequired = 100,    WinsMultiplier = 2.0   },
	{ LevelRequired = 175,    WinsMultiplier = 2.75  },
	{ LevelRequired = 280,    WinsMultiplier = 3.5   },
	{ LevelRequired = 430,    WinsMultiplier = 4.5   },
	{ LevelRequired = 650,    WinsMultiplier = 6.0   },
	{ LevelRequired = 975,    WinsMultiplier = 8.0   },
	{ LevelRequired = 1450,   WinsMultiplier = 10.5  },
	{ LevelRequired = 2150,   WinsMultiplier = 14.0  },
	{ LevelRequired = 3200,   WinsMultiplier = 18.5  },
	{ LevelRequired = 4750,   WinsMultiplier = 24.0  },
	{ LevelRequired = 7000,   WinsMultiplier = 31.0  },
	{ LevelRequired = 10300,  WinsMultiplier = 40.0  },
	{ LevelRequired = 15200,  WinsMultiplier = 52.0  },
	{ LevelRequired = 22500,  WinsMultiplier = 67.0  },
	{ LevelRequired = 33000,  WinsMultiplier = 87.0  },
	{ LevelRequired = 49000,  WinsMultiplier = 113.0 },
	{ LevelRequired = 72000,  WinsMultiplier = 147.0 },
	{ LevelRequired = 106000, WinsMultiplier = 191.0 },
	{ LevelRequired = 156000, WinsMultiplier = 248.0 },
}

function RebirthConfig.getWinsMultiplier(rebirthCount: number): number
	if rebirthCount <= 0 then return 1.0 end
	local data = RebirthConfig[rebirthCount]
	return data and data.WinsMultiplier or RebirthConfig[#RebirthConfig].WinsMultiplier
end

function RebirthConfig.getNextData(rebirthCount: number): RebirthData?
	return RebirthConfig[rebirthCount + 1]
end

return RebirthConfig
