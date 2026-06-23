--!strict

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(ReplicatedStorage.Packages.DataService).client
local SpeedConfig = require(ReplicatedStorage.Shared.SpeedConfig)
local Packets     = require(ReplicatedStorage.Shared.Packets)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local btn = playerGui
	:WaitForChild("Right")
	:WaitForChild("Main")
	:WaitForChild("Line1")
	:WaitForChild("Agility") :: ImageButton

local textBox  = btn:WaitForChild("Button"):WaitForChild("TextBox") :: TextBox
local maxLabel = btn:WaitForChild("Button"):WaitForChild("Max")     :: TextLabel

textBox.ClearTextOnFocus = false
maxLabel.Visible = false

local displayedSpeed = SpeedConfig.BaseWalkSpeed

local function getMaxSpeed(): number
	local level = (DataService:get({ "Level" }) or 1) :: number
	return math.floor(SpeedConfig.getWalkSpeedForLevel(level))
end

local function setDisplay(speed: number)
	displayedSpeed = math.floor(speed)
	textBox.Text   = "Agility: " .. tostring(displayedSpeed)
end

local function syncWithCharacter(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid?
	if not humanoid then return end
	setDisplay(humanoid.WalkSpeed)
	humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if not textBox:IsFocused() then
			setDisplay(humanoid.WalkSpeed)
		end
	end)
end

task.spawn(function()
	DataService:waitForData()
	local character = player.Character or player.CharacterAdded:Wait()
	syncWithCharacter(character)
end)

player.CharacterAdded:Connect(syncWithCharacter)

textBox.Focused:Connect(function()
	maxLabel.Visible = true
	maxLabel.Text    = "Max: " .. tostring(getMaxSpeed())
	textBox.Text     = tostring(displayedSpeed)
end)

textBox.FocusLost:Connect(function(_enterPressed: boolean)
	maxLabel.Visible = false

	local value = tonumber(textBox.Text)

	local invalid = value == nil
		or value ~= value
		or value == math.huge
		or value == -math.huge
		or math.floor(value) < 1

	if invalid then
		textBox.Text = "Agility: " .. tostring(displayedSpeed)
		return
	end

	local requested = math.floor(value)
	local clamped   = math.min(requested, getMaxSpeed())
	textBox.Text    = "Agility: " .. tostring(clamped)

	Packets.SetAgility:Fire(requested)
end)

Packets.SetAgilityResult.OnClientEvent:Connect(function(success: boolean, actualSpeed: number)
	if success then
		setDisplay(actualSpeed)
	else
		textBox.Text = "Agility: " .. tostring(displayedSpeed)
	end
end)
