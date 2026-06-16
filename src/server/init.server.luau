local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local DataService = require(ReplicatedStorage.Packages.DataService).server
local EnvironmentService = require(ServerScriptService.Environment.EnvironmentService)
local SpeedService = require(ServerScriptService.Speed.SpeedService)
local WinsService    = require(ServerScriptService.Wins.WinsService)
local MountsService  = require(ServerScriptService.Mounts.MountsService)
local RebirthService = require(ServerScriptService.Rebirth.RebirthService)

DataService:init({
	--useMock = true,
	--resetData = true,
	--dontSave = false,
	--viewedUserId = 111,
	--overridenUserId = 111,
	template = {
		SpeedCurrency = 0,
		WinCurrency = 0,
		Level = 1,
		Rebirth = 0,
		EquippedMount = "Chonk",
		Mounts = { Chonk = true },
	},
})

MountsService:init(DataService)
SpeedService:init(DataService)
SpeedService:setMountsService(MountsService)
MountsService:setSpeedService(SpeedService)
RebirthService:init(DataService)
RebirthService:setSpeedService(SpeedService)
WinsService:init(DataService)
EnvironmentService:init()

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
