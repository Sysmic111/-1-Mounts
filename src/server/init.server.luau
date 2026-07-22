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
local RingEnemyService = require(ServerScriptService.Stages.RingEnemyService)
local RobuxService     = require(ServerScriptService.Robux.RobuxService)
local StepsService     = require(ServerScriptService.Steps.StepsService)
local PremiumMountsService = require(ServerScriptService.PremiumMounts.PremiumMountsService)
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
		AnalyticsCohort           = "",
		AnalyticsSchemaVersion    = 0,
		AnalyticsOnboardingStep   = 0,
		AnalyticsBackfillVersion  = 0,
		AnalyticsRebirthCycle     = 0,
		AnalyticsRebirthCycleStep = 0,
		AnalyticsDailyLoggedDay    = 0,
		HighestStageReached       = 1,
	},
})

-- PRIMERO de todo: sembrar los valores económicos en los atributos de Workspace.
-- WinsService y StepsService los leen una única vez en su init y los cachean, así
-- que esto tiene que ir antes que ellos o se quedarían con los valores viejos.
EconomyService:seedWorkspace()

FunnelService:init(DataService)

MountsService:init(DataService)
SpeedService:init(DataService)
SpeedService:setMountsService(MountsService)
MountsService:setSpeedService(SpeedService)
RebirthService:init(DataService)
RebirthService:setSpeedService(SpeedService)
WinsService:init(DataService, RobuxService)
EnvironmentService:init()
PlayTimeService:init()
PlayTimeService:setSpeedService(SpeedService)
SpeedService:setPlayTimeService(PlayTimeService)
AgilityService:init(DataService)
StagesService:init(DataService, RobuxService)
LavaService:init()
RingEnemyService:init()
DeathEffectService:init()
RobuxService:init(DataService)
SpeedService:setRobuxService(RobuxService)
StepsService:init(DataService)
PremiumMountsService:init(DataService, RobuxService)
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
