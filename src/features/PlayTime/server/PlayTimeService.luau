--!strict

local Players = game:GetService("Players")

local PlayTimeConfig = require(game.ReplicatedStorage.Shared.PlayTimeConfig)

local PlayTimeService = {
	_joinTimes    = {} :: { [Player]: number },
	_speedService = nil :: any,
}

function PlayTimeService:setSpeedService(speedService: any)
	self._speedService = speedService
end

function PlayTimeService:getElapsed(player: Player): number
	local joinTime = self._joinTimes[player]
	if not joinTime then return 0 end
	return os.clock() - joinTime
end

function PlayTimeService:getMultiplier(player: Player): number
	return PlayTimeConfig.getMultiplier(self:getElapsed(player))
end

function PlayTimeService:_scheduleUpdates(player: Player)
	local joinTime = self._joinTimes[player]
	if not joinTime then return end

	for _, tier in PlayTimeConfig.Tiers do
		if tier.MinSeconds == 0 then continue end
		local delay = tier.MinSeconds - (os.clock() - joinTime)
		if delay > 0 then
			task.delay(delay, function()
				if not player:IsDescendantOf(Players) then return end
				if self._speedService then
					self._speedService:updateTotalMultiplier(player)
				end
			end)
		end
	end
end

function PlayTimeService:init()
	Players.PlayerAdded:Connect(function(player)
		self._joinTimes[player] = os.clock()
		self:_scheduleUpdates(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self._joinTimes[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		self._joinTimes[player] = os.clock()
		self:_scheduleUpdates(player)
	end
end

return PlayTimeService
