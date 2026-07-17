--!strict

-- Daily Login: 21 días de progresión + día 22 repetible indefinidamente.
--
-- El día se decide por la FECHA UTC del servidor (no por "24h desde el claim"):
-- un jugador que reclama a las 23:50 UTC puede volver a reclamar a las 00:10 UTC.
-- El progreso nunca se pierde: saltarse días no reinicia la racha, solo retrasa
-- el siguiente claim.

local MountsConfig = require(game.ReplicatedStorage.Shared.MountsConfig)

export type RewardKind = "Wins" | "Speed" | "Mount"

export type DayReward = {
	Kind: RewardKind,
	-- Wins/Speed: cantidad a otorgar. Mount: ignorado.
	Amount: number?,
	-- Mount: nombre en MountsConfig. "" = pendiente de asignar (no otorga nada).
	MountName: string?,
	-- Texto del card. Si es nil se genera desde Kind/Amount.
	Label: string?,
}

local DailyConfig = {}

DailyConfig.WinsIcon  = "rbxassetid://73013260592473"
DailyConfig.SpeedIcon = "rbxassetid://121327750241374"

-- Último día del ciclo. Se puede reclamar una vez por día para siempre.
DailyConfig.RepeatDay = 22

-- Calibrado contra la curva de SpeedConfig (req(130) = 1.87e12) y contra los
-- sinks reales de Wins. Los premios se apoyan sobre todo en Wins: son la moneda
-- permanente (sobreviven al rebirth) y no distorsionan la curva de niveles, a
-- diferencia del Speed, que según el nivel en que caiga puede valer un nivel o
-- doscientos.
local Days: { [number]: DayReward } = {
	[1]  = { Kind = "Wins",  Amount = 10 },
	[2]  = { Kind = "Speed", Amount = 2_000 },
	[3]  = { Kind = "Wins",  Amount = 500 },
	[4]  = { Kind = "Speed", Amount = 60_000 },
	[5]  = { Kind = "Wins",  Amount = 3_000 },
	[6]  = { Kind = "Speed", Amount = 500_000 },
	[7]  = { Kind = "Mount", MountName = "Velune" },
	[8]  = { Kind = "Wins",  Amount = 20_000 },
	[9]  = { Kind = "Speed", Amount = 5_000_000 },
	[10] = { Kind = "Wins",  Amount = 60_000 },
	[11] = { Kind = "Speed", Amount = 40_000_000 },
	[12] = { Kind = "Wins",  Amount = 150_000 },
	[13] = { Kind = "Speed", Amount = 300_000_000 },
	[14] = { Kind = "Mount", MountName = "Droth" },
	[15] = { Kind = "Wins",  Amount = 400_000 },
	[16] = { Kind = "Speed", Amount = 2_000_000_000 },
	[17] = { Kind = "Wins",  Amount = 800_000 },
	[18] = { Kind = "Speed", Amount = 15_000_000_000 },
	[19] = { Kind = "Wins",  Amount = 1_500_000 },
	[20] = { Kind = "Speed", Amount = 100_000_000_000 },
	[21] = { Kind = "Mount", MountName = "Pyrax" },
	[22] = { Kind = "Wins",  Amount = 250_000 },
}

DailyConfig.Days = Days
DailyConfig.TotalDays = 22

-- ── Tiempo ───────────────────────────────────────────────────────────────────

-- Número de día absoluto en UTC. Cambia a medianoche UTC para todos a la vez.
function DailyConfig.getDayNumber(unixTime: number): number
	return math.floor(unixTime / 86400)
end

function DailyConfig.getSecondsUntilReset(unixTime: number): number
	return 86400 - (unixTime % 86400)
end

-- ── Progresión ───────────────────────────────────────────────────────────────

-- Siguiente día a reclamar dado el último reclamado. Tras el 21 se queda en el
-- día repetible para siempre.
function DailyConfig.getNextDay(lastClaimedDay: number): number
	local nextDay = lastClaimedDay + 1
	if nextDay > DailyConfig.RepeatDay then
		return DailyConfig.RepeatDay
	end
	return nextDay
end

function DailyConfig.getReward(day: number): DayReward?
	return DailyConfig.Days[day]
end

-- ── Formato ──────────────────────────────────────────────────────────────────

local UNITS = {
	{ 1e15, "Q" },
	{ 1e12, "T" },
	{ 1e9,  "B" },
	{ 1e6,  "M" },
	{ 1e3,  "K" },
}

function DailyConfig.abbreviate(n: number): string
	for _, unit in UNITS do
		local threshold = unit[1] :: number
		local suffix    = unit[2] :: string
		if n >= threshold then
			local value = n / threshold
			if value % 1 == 0 then
				return string.format("%d%s", value, suffix)
			end
			return string.format("%.1f%s", value, suffix)
		end
	end
	return tostring(n)
end

function DailyConfig.getRewardLabel(day: number): string
	local reward = DailyConfig.Days[day]
	if not reward then return "" end
	if reward.Label then return reward.Label end

	if reward.Kind == "Mount" then
		-- A diferencia del Index, el calendario sí enseña la montura sin desbloquear:
		-- ver el premio del día 7/14/21 es lo que engancha a volver.
		local mountName = reward.MountName
		if not mountName or mountName == "" then return "??????" end
		return mountName
	end

	return DailyConfig.abbreviate(reward.Amount or 0) .. " " .. reward.Kind
end

function DailyConfig.getRewardIcon(day: number): string
	local reward = DailyConfig.Days[day]
	if not reward then return "" end
	if reward.Kind == "Wins"  then return DailyConfig.WinsIcon end
	if reward.Kind == "Speed" then return DailyConfig.SpeedIcon end

	local mountName = reward.MountName
	local mountData = (mountName and mountName ~= "") and MountsConfig.getMountData(mountName) or nil
	return mountData and mountData.Image or "rbxassetid://0"
end

return DailyConfig
