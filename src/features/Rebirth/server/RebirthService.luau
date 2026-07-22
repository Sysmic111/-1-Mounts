--!strict

local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local RebirthConfig = require(game.ReplicatedStorage.Shared.RebirthConfig)
local Packets       = require(game.ReplicatedStorage.Shared.Packets)
local FunnelService = require(game.ServerScriptService.Server.FunnelService)

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

	FunnelService:onRebirthCompleted(player, rebirthCount + 1)

	-- Aplicar rebirth. SOLO se resetean Level y SpeedCurrency: las mounts (todas,
	-- incluidas las Premium y las del Daily) se conservan, igual que WinCurrency,
	-- hats, trails y steps. El jugador sigue montado en su montura equipada.
	dataService:set(player, { "Rebirth" },       rebirthCount + 1)
	dataService:set(player, { "Level" },          1)
	dataService:set(player, { "SpeedCurrency" },  0)
	FunnelService:onRebirthStateChanged(player)

	-- Teleportar al spawn
	local character = player.Character
	if character then
		local spawn = getSpawnLocation()
		if spawn then
			character:PivotTo(spawn.CFrame + Vector3.new(0, 5, 0))
		end
	end

	-- Sin morph: la montura equipada se conserva. Solo recalcular el multiplicador
	-- (cambia el factor de rebirth).
	if self._speedService then
		self._speedService:updateTotalMultiplier(player)
	end

	Packets.RebirthResult:FireClient(player, true, "")
end

return RebirthService
