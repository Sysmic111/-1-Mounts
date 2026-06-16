--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local EnvironmentConfig = require(script.Parent.EnvironmentConfig)

type LavalState = {
	connections: { RBXScriptConnection },
	debounceByPlayer: { [Player]: boolean },
}

local EnvironmentService = {
	_lavalStates = {} :: { [Instance]: LavalState },
}

local function getCharacterFromTouchedPart(part: BasePart): Model?
	local character = part:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end

	if not character:FindFirstChildOfClass("Humanoid") then
		return nil
	end

	return character
end

local function getTouchParts(instance: Instance): { BasePart }
	if instance:IsA("BasePart") then
		return { instance }
	end

	if not instance:IsA("Model") then
		return {}
	end

	local touchParts = {}
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(touchParts, descendant)
		end
	end

	return touchParts
end

function EnvironmentService:init(): ()
	for _, lavalInstance in ipairs(CollectionService:GetTagged(EnvironmentConfig.LavalTagName)) do
		self:_setupLaval(lavalInstance)
	end

	CollectionService:GetInstanceAddedSignal(EnvironmentConfig.LavalTagName):Connect(function(lavalInstance)
		self:_setupLaval(lavalInstance)
	end)

	CollectionService:GetInstanceRemovedSignal(EnvironmentConfig.LavalTagName):Connect(function(lavalInstance)
		self:_cleanupLaval(lavalInstance)
	end)
end

function EnvironmentService:_setupLaval(lavalInstance: Instance): ()
	if self._lavalStates[lavalInstance] then
		return
	end

	local touchParts = getTouchParts(lavalInstance)
	if #touchParts == 0 then
		return
	end

	local state: LavalState = {
		connections = {},
		debounceByPlayer = {},
	}

	self._lavalStates[lavalInstance] = state

	for _, touchPart in ipairs(touchParts) do
		table.insert(state.connections, touchPart.Touched:Connect(function(touchedPart)
			self:_onLavalTouched(lavalInstance, touchedPart)
		end))
	end
end

function EnvironmentService:_onLavalTouched(lavalInstance: Instance, touchedPart: BasePart): ()
	local state = self._lavalStates[lavalInstance]
	if not state then
		return
	end

	local character = getCharacterFromTouchedPart(touchedPart)
	if not character then
		return
	end

	local player = Players:GetPlayerFromCharacter(character)
	if not player or state.debounceByPlayer[player] then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	state.debounceByPlayer[player] = true
	task.delay(EnvironmentConfig.LavalDebounceSeconds, function()
		state.debounceByPlayer[player] = nil
	end)

	humanoid.Health = 0
end

function EnvironmentService:_cleanupLaval(lavalInstance: Instance): ()
	local state = self._lavalStates[lavalInstance]
	if not state then
		return
	end

	for _, connection in ipairs(state.connections) do
		connection:Disconnect()
	end

	self._lavalStates[lavalInstance] = nil
end

return EnvironmentService
