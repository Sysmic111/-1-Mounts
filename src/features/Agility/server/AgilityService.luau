--!strict

local Players = game:GetService("Players")

local SpeedConfig = require(game.ReplicatedStorage.Shared.SpeedConfig)
local Packets     = require(game.ReplicatedStorage.Shared.Packets)

type DataServiceServer = {
	waitForData: (self: DataServiceServer, player: Player) -> any,
	hasProfile:  (self: DataServiceServer, player: Player) -> boolean,
	get:         (self: DataServiceServer, player: Player, path: any?) -> any,
	set:         (self: DataServiceServer, player: Player, path: any, value: any, dontReplicate: boolean?) -> (),
}

local RATE_LIMIT = 0.5

local AgilityService = {
	_dataService      = nil :: DataServiceServer?,
	_lastRequestTimes = {} :: { [Player]: number },
}

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	if not character then return nil end
	return character:FindFirstChildOfClass("Humanoid")
end

function AgilityService:init(dataService: DataServiceServer)
	self._dataService = dataService

	Players.PlayerRemoving:Connect(function(player)
		self._lastRequestTimes[player] = nil
	end)

	Packets.SetAgility.OnServerEvent:Connect(function(player: Player, value: any)
		if type(value) ~= "number" then return end
		if value ~= value then return end
		if value == math.huge or value == -math.huge then return end

		local now = os.clock()
		if (now - (self._lastRequestTimes[player] or 0)) < RATE_LIMIT then return end
		self._lastRequestTimes[player] = now

		local dataService = self._dataService
		if not dataService or not dataService:hasProfile(player) then return end

		local humanoid     = getHumanoid(player)
		local currentSpeed = humanoid and math.floor(humanoid.WalkSpeed) or SpeedConfig.BaseWalkSpeed

		local requested = math.floor(value)
		if requested < 1 then
			Packets.SetAgilityResult:FireClient(player, false, currentSpeed)
			return
		end

		-- Compute max from server-side level — never trust client
		local level    = (dataService:get(player, { "Level" }) or 1) :: number
		local maxSpeed = math.floor(SpeedConfig.getWalkSpeedForLevel(level))
		local final    = math.min(requested, maxSpeed)

		if not humanoid then
			Packets.SetAgilityResult:FireClient(player, false, currentSpeed)
			return
		end

		humanoid.WalkSpeed = final
		Packets.SetAgilityResult:FireClient(player, true, final)
	end)
end

return AgilityService
