local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local DataService = require(ReplicatedStorage.Packages.DataService).server
local EnvironmentService = require(ServerScriptService.Environment.EnvironmentService)
local SpeedService    = require(ServerScriptService.Speed.SpeedService)
local WinsService     = require(ServerScriptService.Wins.WinsService)
local MountsService   = require(ServerScriptService.Mounts.MountsService)
local RebirthService  = require(ServerScriptService.Rebirth.RebirthService)
local PlayTimeService  = require(ServerScriptService.PlayTime.PlayTimeService)
local AgilityService   = require(ServerScriptService.Agility.AgilityService)
local StagesService    = require(ServerScriptService.Stages.StagesService)
local RobuxService     = require(ServerScriptService.Robux.RobuxService)
local StepsService     = require(ServerScriptService.Steps.StepsService)
local PremiumMountsService = require(ServerScriptService.PremiumMounts.PremiumMountsService)

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
	},
})

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
StagesService:init()
RobuxService:init(DataService)
SpeedService:setRobuxService(RobuxService)
StepsService:init(DataService)
PremiumMountsService:init(DataService, RobuxService)

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
