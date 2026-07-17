--!strict

export type RebirthData = {
	LevelRequired: number,
	WinsMultiplier: number,
}

-- Índice = número de rebirth a realizar (1-8)
-- LevelRequired: nivel mínimo necesario para hacer ese rebirth
-- WinsMultiplier: multiplicador activo después de completarlo
--
-- Los 8 rebirths caben dentro del rango 1..130, que es el recorrido del juego
-- (nivel 130 = se pasa el stage 14). El ciclo final va del rebirth 8 al 130.
--
-- OJO: este multiplicador se aplica en DOS sitios — a los Wins ganados en
-- WinsService:_creditWins y al Speed dentro del TotalMultiplier de
-- SpeedService:_updateTotalMultiplier. Por eso el techo es x26 y no x248.
local RebirthConfig: { RebirthData } = {
	{ LevelRequired = 40,  WinsMultiplier = 2.0  },
	{ LevelRequired = 55,  WinsMultiplier = 3.5  },
	{ LevelRequired = 68,  WinsMultiplier = 5.5  },
	{ LevelRequired = 80,  WinsMultiplier = 8.0  },
	{ LevelRequired = 92,  WinsMultiplier = 11.0 },
	{ LevelRequired = 103, WinsMultiplier = 15.0 },
	{ LevelRequired = 114, WinsMultiplier = 20.0 },
	{ LevelRequired = 125, WinsMultiplier = 26.0 },
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
