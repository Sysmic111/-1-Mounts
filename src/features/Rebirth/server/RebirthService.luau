--!strict

local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local RebirthConfig = require(game.ReplicatedStorage.Shared.RebirthConfig)
local MorphService  = require(game.ServerScriptService.Mounts.MorphService)
local Packets       = require(game.ReplicatedStorage.Shared.Packets)

type DataServiceServer = {
	waitForData: (self: DataServiceServer, player: Player) -> any,
	hasProfile:  (self: DataServiceServer, player: Player) -> boolean,
	get:         (self: DataServiceServer, player: Player, path: any?) -> any,
	set:         (self: DataServiceServer, player: Player, path: any, value: any, dontReplicate: boolean?) -> (),
}

local RebirthService = {
	_dataService  = nil :: DataServiceServer?,
	_speedService = nil :: any,
}

function RebirthService:setSpeedService(speedService: any): ()
	self._speedService = speedService
end

local function getSpawnLocation(): SpawnLocation?
	return Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
end

function RebirthService:init(dataService: DataServiceServer): ()
	self._dataService = dataService

	Packets.DoRebirth.OnServerEvent:Connect(function(player: Player)
		self:_handleRebirth(player)
	end)
end

function RebirthService:_handleRebirth(player: Player): ()
	local dataService = self._dataService
	if not dataService or not dataService:hasProfile(player) then return end

	local rebirthCount = (dataService:get(player, { "Rebirth" }) or 0) :: number
	local nextData = RebirthConfig.getNextData(rebirthCount)

	if not nextData then
		Packets.RebirthResult:FireClient(player, false, "You already reached the maximum rebirth.")
		return
	end

	local currentLevel = (dataService:get(player, { "Level" }) or 1) :: number
	if currentLevel < nextData.LevelRequired then
		Packets.RebirthResult:FireClient(
			player, false,
			"You need Level " .. nextData.LevelRequired .. " (you have " .. currentLevel .. ")."
		)
		return
	end

	-- Aplicar rebirth
	dataService:set(player, { "Rebirth" },       rebirthCount + 1)
	dataService:set(player, { "Level" },          1)
	dataService:set(player, { "SpeedCurrency" },  0)
	dataService:set(player, { "Mounts" },         { Chonk = true })
	dataService:set(player, { "EquippedMount" },  "Chonk")

	-- Teleportar al spawn
	local character = player.Character
	if character then
		local spawn = getSpawnLocation()
		if spawn then
			character:PivotTo(spawn.CFrame + Vector3.new(0, 5, 0))
		end
	end

	-- Equipar Chonk (morph)
	MorphService.MorphPlayer(player, "Chonk")
	if self._speedService then
		self._speedService:updateTotalMultiplier(player)
	end

	Packets.RebirthResult:FireClient(player, true, "")
end

return RebirthService
