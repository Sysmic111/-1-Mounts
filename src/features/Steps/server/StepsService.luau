--!strict
local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Packets = require(game.ReplicatedStorage.Shared.Packets)

type DataServiceServer = {
	waitForData: (self: DataServiceServer, player: Player) -> any,
	hasProfile:  (self: DataServiceServer, player: Player) -> boolean,
	get:         (self: DataServiceServer, player: Player, path: { string }) -> any,
	set:         (self: DataServiceServer, player: Player, path: { string }, value: any, dontReplicate: boolean?) -> (),
}

local StepsService = {
	_dataService      = nil :: DataServiceServer?,
	_stepsMap         = {} :: { [number]: number }, -- stepsIncrement -> winsQuantity
	_lastActivateTime = {} :: { [Player]: number },
}

local stepsButtonsFolder: Folder

local function buildStepsMap(stepsMap: { [number]: number }): ()
	for _, child in stepsButtonsFolder:GetChildren() do
		if child.ClassName ~= "Model" or child.Name ~= "Steps" then continue end
		local model = child :: Model
		local inc   = model:GetAttribute("StepsIncresement") :: number?
		local wins  = model:GetAttribute("WinsQuantity")     :: number?
		if inc and wins then
			stepsMap[inc] = wins
		end
	end
end

function StepsService:init(dataService: DataServiceServer): ()
	self._dataService = dataService
	stepsButtonsFolder = Workspace:WaitForChild("StepsButtons") :: Folder
	buildStepsMap(self._stepsMap)

	local function setupPlayer(player: Player)
		task.spawn(function()
			dataService:waitForData(player)
			if not player:IsDescendantOf(Players) then return end

			-- Garantizar que el primer step siempre esté desbloqueado
			if dataService:get(player, { "StepUnlocked_1" }) ~= true then
				dataService:set(player, { "StepUnlocked_1" }, true)
			end

			local equipped = (dataService:get(player, { "StepsEquipped" }) or 0) :: number
			if equipped == 0 then
				equipped = 1
				dataService:set(player, { "StepsEquipped" }, 1)
			end

			player:SetAttribute("EquippedSteps", equipped)
		end)
	end

	Players.PlayerAdded:Connect(setupPlayer)
	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		self._lastActivateTime[player] = nil
	end)

	Packets.ActivateStep.OnServerEvent:Connect(function(player: Player, stepsIncrement: number)
		self:_handleActivate(player, stepsIncrement)
	end)
end

function StepsService:_handleActivate(player: Player, stepsIncrement: number): ()
	local now = os.clock()
	local last = self._lastActivateTime[player] or 0
	if now - last < 0.5 then return end
	self._lastActivateTime[player] = now

	local ds = self._dataService
	if not ds or not ds:hasProfile(player) then return end

	-- Validate stepsIncrement is a real button in the game
	local winsQuantity = self._stepsMap[stepsIncrement]
	if winsQuantity == nil then return end

	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local flatKey = "StepUnlocked_" .. tostring(stepsIncrement)

	if ds:get(player, { flatKey }) ~= true then
		local winCurrency = (ds:get(player, { "WinCurrency" }) or 0) :: number
		if winCurrency < winsQuantity then return end
		ds:set(player, { "WinCurrency" }, winCurrency - winsQuantity)
		ds:set(player, { flatKey }, true)
	end

	ds:set(player, { "StepsEquipped" }, stepsIncrement)
	player:SetAttribute("EquippedSteps", stepsIncrement)
	Packets.StepActivated:FireClient(player, stepsIncrement)
end

return StepsService
