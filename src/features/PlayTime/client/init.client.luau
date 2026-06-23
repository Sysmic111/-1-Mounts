--!strict

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MenuAnimations = require(ReplicatedStorage.Shared.MenuAnimations)
local PlayTimeConfig = require(ReplicatedStorage.Shared.PlayTimeConfig)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local btn = playerGui
	:WaitForChild("Right")
	:WaitForChild("Main")
	:WaitForChild("Line1")
	:WaitForChild("PlayTime") :: ImageButton

local description     = btn:WaitForChild("Description")     :: Frame
local speedBoostLabel = description:WaitForChild("SpeedBoost") :: TextLabel
local progressLevels  = description:WaitForChild("ProgressLevels") :: Frame
local fill            = progressLevels:WaitForChild("Fill")   :: Frame
local levelsTitle     = progressLevels:WaitForChild("Levels"):WaitForChild("Title") :: TextLabel
local boostLabel      = btn:WaitForChild("Button"):WaitForChild("Boost") :: TextLabel

local FILL_OPEN_TWEEN = TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local sessionStart = os.clock()
local isOpen       = false

local function formatTime(seconds: number): string
	local m = math.floor(seconds / 60)
	local s = math.floor(seconds % 60)
	return string.format("%02d:%02d", m, s)
end

local function setFill(elapsed: number)
	fill.Size = UDim2.new(PlayTimeConfig.getProgress(elapsed), 0, 1, 0)
end

local function refreshDescription(elapsed: number, mult: number)
	levelsTitle.Text     = formatTime(elapsed)
	speedBoostLabel.Text = "Speed Boost: x" .. tostring(mult)
end

btn.MouseButton1Click:Connect(function()
	if isOpen then
		isOpen = false
		MenuAnimations.close(description)
	else
		isOpen = true
		local elapsed = os.clock() - sessionStart
		local mult    = PlayTimeConfig.getMultiplier(elapsed)
		refreshDescription(elapsed, mult)
		fill.Size = UDim2.new(0, 0, 1, 0)
		MenuAnimations.open(description)
		TweenService:Create(fill, FILL_OPEN_TWEEN, {
			Size = UDim2.new(PlayTimeConfig.getProgress(elapsed), 0, 1, 0),
		}):Play()
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		local elapsed = os.clock() - sessionStart
		local mult    = PlayTimeConfig.getMultiplier(elapsed)

		boostLabel.Text = "x" .. tostring(mult)

		if isOpen then
			refreshDescription(elapsed, mult)
			setFill(elapsed)
		end
	end
end)
