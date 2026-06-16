--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packets = require(ReplicatedStorage.Shared.Packets)
local FormatNumber = require(ReplicatedStorage.Packages.FormatNumber)
local DataService = require(ReplicatedStorage.Packages.DataService).client
local SpeedConfig = require(ReplicatedStorage.Shared.SpeedConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local temporal = playerGui:WaitForChild("Temporal")
local generalTemplates = playerGui:WaitForChild("GeneralTemplates")
local speedTemplate = generalTemplates:WaitForChild("SpeedTemplate")

local uiSounds = SoundService:WaitForChild("SFX"):WaitForChild("UI")
local popupSounds = {
	uiSounds:WaitForChild("ui_menu_popup_01"),
	uiSounds:WaitForChild("ui_menu_popup_02"),
	uiSounds:WaitForChild("ui_menu_popup_03"),
	uiSounds:WaitForChild("ui_menu_popup_04"),
}

local ORIGINAL_SIZE = speedTemplate.Size

local function showSpeedGain(amount: number)
	local clone = speedTemplate:Clone()
	local speedLabel = clone:FindFirstChild("Speed") :: TextLabel
	local uiStroke = speedLabel:FindFirstChildOfClass("UIStroke") :: UIStroke
	local imageLabel = clone:FindFirstChild("ImageLabel") :: ImageLabel

	speedLabel.Text = "+ " .. FormatNumber:formatNumberCoins(amount)

	local randomX = 0.5 + (math.random() * 2 - 1) * 0.25
	local randomY = 0.5 + (math.random() * 2 - 1) * 0.25
	clone.Size = UDim2.new(0, 0, 0, 0)
	clone.Position = UDim2.fromScale(randomX, randomY)
	clone.Rotation = math.random(-30, 30)
	clone.Parent = temporal

	popupSounds[math.random(1, 4)]:Play()

	TweenService:Create(
		clone,
		TweenInfo.new(0.4, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
		{ Size = ORIGINAL_SIZE }
	):Play()

	task.delay(2, function()
		if not clone or not clone.Parent then
			return
		end
		local fadeInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(speedLabel, fadeInfo, { TextTransparency = 1 }):Play()
		TweenService:Create(uiStroke, fadeInfo, { Transparency = 1 }):Play()
		TweenService:Create(imageLabel, fadeInfo, { ImageTransparency = 1 }):Play()
		task.delay(1, function()
			if clone and clone.Parent then
				clone:Destroy()
			end
		end)
	end)
end

Packets.SpeedGained.OnClientEvent:Connect(showSpeedGain)

-- Progress bar
local bot = playerGui:WaitForChild("Bot")
local progress = bot:WaitForChild("Content"):WaitForChild("Progress")
local levelLabel = progress:WaitForChild("Level") :: TextLabel
local speedLabel = progress:WaitForChild("Content"):WaitForChild("Speed") :: TextLabel
local fill = progress:WaitForChild("Fill") :: Frame

local fillTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function updateProgress(animateFill: boolean)
	local level = DataService:get({ "Level" }) or 1
	local speedCurrency = DataService:get({ "SpeedCurrency" }) or 0
	local required = SpeedConfig.getRequiredSpeedForLevel(level)
	local ratio = math.clamp(speedCurrency / required, 0, 1)

	levelLabel.Text = "Level " .. level
	speedLabel.Text = FormatNumber:formatNumberCoins(speedCurrency) .. "/" .. FormatNumber:formatNumberCoins(required)

	local targetSize = UDim2.fromScale(ratio, 1)
	if animateFill then
		TweenService:Create(fill, fillTweenInfo, { Size = targetSize }):Play()
	else
		fill.Size = targetSize
	end
end

task.spawn(function()
	DataService:waitForData()
	updateProgress(false)
	DataService:getChangedSignal({ "SpeedCurrency" }):Connect(function()
		updateProgress(true)
	end)
	DataService:getChangedSignal({ "Level" }):Connect(function()
		updateProgress(true)
	end)
end)
