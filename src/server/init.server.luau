local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local DataService = require(ReplicatedStorage.Packages.DataService).server
local EnvironmentService = require(ServerScriptService.Environment.EnvironmentService)
local SpeedService    = require(ServerScriptService.Speed.SpeedService)
local WinsService     = require(ServerScriptService.Wins.WinsService)
local MountsService   = require(ServerScriptService.Mounts.MountsService)
local DeathEffectService = require(ServerScriptService.Mounts.DeathEffectService)
local RebirthService  = require(ServerScriptService.Rebirth.RebirthService)
local PlayTimeService  = require(ServerScriptService.PlayTime.PlayTimeService)
local AgilityService   = require(ServerScriptService.Agility.AgilityService)
local StagesService    = require(ServerScriptService.Stages.StagesService)
local LavaService      = require(ServerScriptService.Stages.LavaService)
local IceService       = require(ServerScriptService.Stages.IceService)
local RingEnemyService = require(ServerScriptService.Stages.RingEnemyService)
local RobuxService     = require(ServerScriptService.Robux.RobuxService)
local StepsService     = require(ServerScriptService.Steps.StepsService)
local PremiumMountsService = require(ServerScriptService.PremiumMounts.PremiumMountsService)
local NewPlayerBonusService = require(ServerScriptService.NewPlayerBonus.NewPlayerBonusService)
local HatsService      = require(ServerScriptService.Hats.HatsService)
local TrailsService    = require(ServerScriptService.Trails.TrailsService)
local DailyService     = require(ServerScriptService.Daily.DailyService)
local EconomyService   = require(ServerScriptService.Economy.EconomyService)
local StarterPackService = require(ServerScriptService.StarterPack.StarterPackService)
local SpeedBoostService = require(ServerScriptService.SpeedBoost.SpeedBoostService)
local SpeedBuyService   = require(ServerScriptService.SpeedBuy.SpeedBuyService)
local LeaderboardService = require(ServerScriptService.Leaderboard.LeaderboardService)
local BadgesService     = require(ServerScriptService.Badges.BadgesService)
local FriendsBoostService = require(ServerScriptService.FriendsBoost.FriendsBoostService)
local GroupBonusService = require(ServerScriptService.GroupBonus.GroupBonusService)
local MorphService     = require(ServerScriptService.Mounts.MorphService)
local AdminService     = require(ServerScriptService.Admin.AdminService)
local WeatherService   = require(ServerScriptService.Weather.WeatherService)
local RaceService      = require(ServerScriptService.Race.RaceService)
local WorldsService    = require(ServerScriptService.Worlds.WorldsService)
local FunnelService    = require(script.FunnelService)

DataService:init({
	--useMock = true,
	--resetData = true,
	--dontSave = false,
	--viewedUserId = 111,
	--overridenUserId = 111,
	template = {
		SpeedCurrency    = 0,
		WinCurrency      = 0,
		Level            = 1,
		Rebirth          = 0,
		EquippedMount    = "Chonk",
		Mounts           = { Chonk = true },
		TreadmillGold    = false,
		TreadmillDiamond = false,
		TreadmillEmerald = false,
		TreadmillRuby    = false,
		StepsEquipped    = 1,
		StepUnlocked_1   = true,
		PendingPremiumWins = 0,
		Hats             = {},
		EquippedHat      = "",
		Trails           = {},
		EquippedTrail    = "",
		DailyClaimedDay    = 0,
		DailyLastClaimDate = 0,
		StarterPackBought  = false,
		InfiniteRevives    = false,
		SpeedTier          = 0,
		-- Bonus permanente por pertenecer al grupo (fuente aditiva del TotalMultiplier).
		GroupBonusClaimed  = false,
		-- Contador de por vida de entradas al juego. Se incrementa una vez por sesión
		-- (GroupBonusService). Sirve para el gate "like the game and rejoin": la 1ª
		-- entrada queda en 1, así que >=2 = ha reconectado al menos una vez.
		TimesJoined        = 0,
		-- Contador de por vida de claims de Wins. En el 2º se lanza el prompt de favoritos.
		WinsClaimCount     = 0,
		-- Estadísticas de por vida (para leaderboard): acumulan todo lo ganado,
		-- nunca bajan al gastar Wins ni al rebirthear.
		TotalSpeedEarned   = 0,
		TotalWinsEarned    = 0,
		-- Segundos jugados de por vida (PlayTimeService). Se acredita cada minuto y
		-- al salir, así un crash pierde <1 min en vez de la sesión entera. OJO: es
		-- distinto del playtime de SESIÓN que da el multiplicador, que no se guarda.
		TotalPlayTime      = 0,
		AnalyticsCohort           = "",
		AnalyticsSchemaVersion    = 0,
		AnalyticsOnboardingStep   = 0,
		-- Contador monótono del funnel del tutorial guiado (FunnelService:_advanceTutorial).
		-- Persistido para que el funnel no se repita al reconectar a mitad.
		AnalyticsTutorialStep     = 0,
		AnalyticsBackfillVersion  = 0,
		AnalyticsRebirthCycle     = 0,
		AnalyticsRebirthCycleStep = 0,
		AnalyticsDailyLoggedDay    = 0,
		-- Progreso de stages POR MUNDO. World 1 conserva la clave sin sufijo para no
		-- invalidar los datos ya guardados ni los dashboards; los demás mundos llevan
		-- "HighestStageReached_<Key>" (ver FunnelService.highestStageKey).
		HighestStageReached        = 1,
		HighestStageReached_World2 = 1,
		-- Desbloqueo de mundos para el menú Teleport (WorldsConfig.unlockKey). Una
		-- clave por mundo que declare RequiresWorld; el mundo de entrada no lleva.
		-- Va en el template y no on-demand como los StepUnlocked_<N> para que el
		-- cliente pueda leerla y pintar la tarjeta bloqueada sin preguntar nada.
		-- Se gana pisando Workspace.Teleport.Teleport con la cadena de steps del
		-- mundo actual completa (WorldsService:_handleTeleportTouch).
		WorldUnlocked_World2 = false,
		-- Bonus de jugador nuevo (15 min seguidos = montura Premium gratis).
		-- Cuenta las sesiones en las que YA se ofreció: al alcanzar
		-- NewPlayerBonusConfig.MaxSessions la oferta caduca para siempre. El reloj
		-- de los 15 minutos NO se guarda a propósito: es de sesión y reinicia al
		-- reconectar, que es lo que hace real el aviso al salir.
		NewPlayerBonusSessions = 0,
		NewPlayerBonusClaimed  = false,
	},
})

-- PRIMERO de todo: sembrar los valores económicos en los atributos de Workspace.
-- WinsService y StepsService los leen una única vez en su init y los cachean, así
-- que esto tiene que ir antes que ellos o se quedarían con los valores viejos.
EconomyService:seedWorkspace()

-- Puerta de entrada al mundo: en World 1 no hace nada (no tiene RequiresWorld);
-- en World 2 devuelve a World 1 a quien no traiga su cadena de steps completa.
-- Va pronto para atajar antes de que el resto de servicios le monten la sesión.
WorldsService:init(DataService)

FunnelService:init(DataService)

MountsService:init(DataService)
SpeedService:init(DataService)
SpeedService:setMountsService(MountsService)
MountsService:setSpeedService(SpeedService)
RebirthService:init(DataService)
RebirthService:setSpeedService(SpeedService)
WinsService:init(DataService, RobuxService)
-- Después de WinsService: las carreras pagan a través de él (awardWins/teleportToSpawn).
RaceService:init(DataService, WinsService)
EnvironmentService:init()
-- Necesita DataService para acumular TotalPlayTime (estadística de por vida).
PlayTimeService:init(DataService)
PlayTimeService:setSpeedService(SpeedService)
SpeedService:setPlayTimeService(PlayTimeService)
AgilityService:init(DataService)
StagesService:init(DataService, RobuxService)
LavaService:init()
IceService:init()
RingEnemyService:init()
DeathEffectService:init()
RobuxService:init(DataService)
SpeedService:setRobuxService(RobuxService)
StepsService:init(DataService)
PremiumMountsService:init(DataService, RobuxService)
NewPlayerBonusService:init(DataService)
StarterPackService:init(DataService, RobuxService)
SpeedBoostService:init(DataService, RobuxService, SpeedService)
SpeedBuyService:init(DataService, RobuxService, SpeedService)
LeaderboardService:init(DataService)
BadgesService:init()
FriendsBoostService:init()
FriendsBoostService:setSpeedService(SpeedService)
GroupBonusService:init(DataService)
GroupBonusService:setSpeedService(SpeedService)
MorphService.setDataService(DataService)
HatsService:init(DataService)
HatsService:setSpeedService(SpeedService)
HatsService:setMorphService(MorphService)
SpeedService:setHatsService(HatsService)
TrailsService:init(DataService)
TrailsService:setSpeedService(SpeedService)
TrailsService:setMorphService(MorphService)
SpeedService:setTrailsService(TrailsService)
DailyService:init(DataService)
AdminService:init(DataService)
-- Weather: reparte su bonus vía atributos (WeatherBoost / WeatherWinsBoost) y llama
-- a updateTotalMultiplier, así que el SpeedService tiene que estar ya inicializado.
WeatherService:setSpeedService(SpeedService)
WeatherService:init()

-- ── Leaderstats ───────────────────────────────────────────────────────────────

local function setupLeaderstats(player: Player)
	task.spawn(function()
		while not DataService:hasProfile(player) do
			task.wait(0.5)
		end

		local leaderstats = Instance.new("Folder")
		leaderstats.Name   = "leaderstats"
		leaderstats.Parent = player

		local levelStat = Instance.new("IntValue")
		levelStat.Name   = "Level"
		levelStat.Value  = DataService:get(player, { "Level" }) or 1
		levelStat.Parent = leaderstats

		local rebirthStat = Instance.new("IntValue")
		rebirthStat.Name   = "Rebirth"
		rebirthStat.Value  = DataService:get(player, { "Rebirth" }) or 0
		rebirthStat.Parent = leaderstats

		while player.Parent do
			task.wait(2)
			if DataService:hasProfile(player) then
				levelStat.Value   = DataService:get(player, { "Level" })   or 1
				rebirthStat.Value = DataService:get(player, { "Rebirth" }) or 0
			end
		end
	end)
end

Players.PlayerAdded:Connect(setupLeaderstats)
for _, player in Players:GetPlayers() do
	setupLeaderstats(player)
end

-- ── Stages ────────────────────────────────────────────────────────────────────

local stagesFolder = Workspace:FindFirstChild("Stages")
if stagesFolder then
	for _, stage in stagesFolder:GetChildren() do
		local pp = (stage :: Model).PrimaryPart
		local label = pp
			and pp:FindFirstChild("SurfaceGui")
			and (pp:FindFirstChild("SurfaceGui") :: SurfaceGui):FindFirstChild("Title") :: TextLabel?
		if label then
			label.Text = stage.Name
		end
	end
end
