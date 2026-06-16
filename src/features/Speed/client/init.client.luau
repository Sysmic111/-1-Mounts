--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Packets = require(ReplicatedStorage.Shared.Packets)
local FormatNumber = require(ReplicatedStorage.Packages.FormatNumber)
local DataService = require(ReplicatedStorage.Packages.DataService).client
local SpeedConfig = require(ReplicatedStorage.Shared.SpeedConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local uiSounds = SoundService:WaitForChild("SFX"):WaitForChild("UI")
local popupSounds = {
	uiSounds:WaitForChild("ui_menu_popup_01"),
	uiSounds:WaitForChild("ui_menu_popup_02"),
	uiSounds:WaitForChild("ui_menu_popup_03"),
	uiSounds:WaitForChild("ui_menu_popup_04"),
}

local sfx = SoundService:WaitForChild("SFX")
local levelUpSoundPower = sfx:WaitForChild("sci-fi_power_up_05")
local levelUpSoundSparkle = sfx:WaitForChild("collect_item_sparkle_pop_09")

local function getUI()
	local generalTemplates = playerGui:FindFirstChild("GeneralTemplates")
	local temporal = playerGui:FindFirstChild("Temporal")
	local speedTemplate = generalTemplates and generalTemplates:FindFirstChild("SpeedTemplate")
	return speedTemplate, temporal
end

local function showSpeedGain(amount: number)
	local speedTemplate, temporal = getUI()
	if not speedTemplate or not temporal then return end

	local clone = speedTemplate:Clone()
	local speedLabel = clone:FindFirstChild("Speed") :: TextLabel?
	if not speedLabel then clone:Destroy() return end

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
		{ Size = speedTemplate.Size }
	):Play()

	task.delay(2, function()
		if not clone or not clone.Parent then return end
		local fadeInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(speedLabel, fadeInfo, { TextTransparency = 1 }):Play()
		TweenService:Create(uiStroke, fadeInfo, { Transparency = 1 }):Play()
		TweenService:Create(imageLabel, fadeInfo, { ImageTransparency = 1 }):Play()
		task.delay(1, function()
			if clone and clone.Parent then clone:Destroy() end
		end)
	end)
end

local function isAboveTreadmill(hrp: BasePart): boolean
	for _, model in CollectionService:GetTagged("Treadmill") do
		local pp = (model :: Model).PrimaryPart
		if not pp then continue end
		local localPos = pp.CFrame:PointToObjectSpace(hrp.Position)
		local half = pp.Size / 2
		if math.abs(localPos.X) <= half.X
			and math.abs(localPos.Z) <= half.Z
			and localPos.Y >= -1
			and localPos.Y <= half.Y + 8 then
			return true
		end
	end
	return false
end

-- Movement tracking
local lastPosition: Vector3? = nil
local distanceRemainder = 0
local treadmillDistanceRemainder = 0
local lastPacketTime = 0

local function resetTracking()
	lastPosition = nil
	distanceRemainder = 0
	treadmillDistanceRemainder = 0
end

player.CharacterAdded:Connect(resetTracking)

RunService.Heartbeat:Connect(function(dt: number)
	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid?
	if not rootPart or not humanoid or humanoid.Health <= 0 then
		lastPosition = nil
		return
	end

	local now = os.clock()

	local onTreadmill = isAboveTreadmill(rootPart)
	local wasOnTreadmill = character:GetAttribute("OnTreadmill") == true
	if onTreadmill ~= wasOnTreadmill then
		character:SetAttribute("OnTreadmill", onTreadmill)
	end

	if onTreadmill then
		treadmillDistanceRemainder += humanoid.WalkSpeed * dt
		if treadmillDistanceRemainder >= SpeedConfig.StudsPerSpeed and (now - lastPacketTime) >= SpeedConfig.MovementCheckInterval then
			treadmillDistanceRemainder -= SpeedConfig.StudsPerSpeed
			lastPacketTime = now
			Packets.RequestSpeedGain:Fire()
			showSpeedGain(math.ceil((player:GetAttribute("TotalMultiplier") or 1) :: number))
		end
		lastPosition = rootPart.Position
		return
	end

	treadmillDistanceRemainder = 0

	local currentPosition = rootPart.Position
	if not lastPosition then
		lastPosition = currentPosition
		return
	end

	local moved = (currentPosition - lastPosition).Magnitude
	lastPosition = currentPosition

	if moved == 0 then return end

	distanceRemainder += moved

	if distanceRemainder >= SpeedConfig.StudsPerSpeed and (now - lastPacketTime) >= SpeedConfig.MovementCheckInterval then
		distanceRemainder -= SpeedConfig.StudsPerSpeed
		lastPacketTime = now
		Packets.RequestSpeedGain:Fire()
		showSpeedGain(math.ceil((player:GetAttribute("TotalMultiplier") or 1) :: number))
	end
end)

-- Level up effects
local function emitLevelUpParticles()
	local character = player.Character
	if not character then
		return
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return
	end

	local burstEmitter = Instance.new("ParticleEmitter")
	burstEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	burstEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 50)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 150)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	})
	burstEmitter.LightEmission = 1
	burstEmitter.LightInfluence = 0
	burstEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(0.3, 1.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	burstEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	burstEmitter.Speed = NumberRange.new(18, 30)
	burstEmitter.SpreadAngle = Vector2.new(50, 50)
	burstEmitter.Lifetime = NumberRange.new(0.6, 1.2)
	burstEmitter.Rate = 0
	burstEmitter.RotSpeed = NumberRange.new(-200, 200)
	burstEmitter.Rotation = NumberRange.new(0, 360)
	burstEmitter.Parent = rootPart
	burstEmitter:Emit(70)

	local ringEmitter = Instance.new("ParticleEmitter")
	ringEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	ringEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 220, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	})
	ringEmitter.LightEmission = 1
	ringEmitter.LightInfluence = 0
	ringEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	ringEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.7, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	ringEmitter.Speed = NumberRange.new(25, 40)
	ringEmitter.SpreadAngle = Vector2.new(180, 0)
	ringEmitter.Lifetime = NumberRange.new(0.3, 0.5)
	ringEmitter.Rate = 0
	ringEmitter.Parent = rootPart
	ringEmitter:Emit(40)

	task.delay(3, function()
		burstEmitter:Destroy()
		ringEmitter:Destroy()
	end)
end

-- Progress bar
local fillTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function getProgressUI()
	local bot = playerGui:FindFirstChild("Bot")
	if not bot then return nil, nil, nil, nil end
	local content = bot:FindFirstChild("Content")
	local progress = content and content:FindFirstChild("Progress")
	if not progress then return nil, nil, nil, nil end
	local levelLabel = progress:FindFirstChild("Level") :: TextLabel?
	local innerContent = progress:FindFirstChild("Content")
	local speedLabel = innerContent and innerContent:FindFirstChild("Speed") :: TextLabel?
	local fill = progress:FindFirstChild("Fill") :: Frame?
	return progress, levelLabel, speedLabel, fill
end

local totalMultiplierLabel = playerGui:WaitForChild("Bot")
	:WaitForChild("Content"):WaitForChild("Total Multiplier") :: TextLabel

local function updateTotalMultiplierLabel()
	local val = (player:GetAttribute("TotalMultiplier") or 1) :: number
	totalMultiplierLabel.Text = "Total Multiplier: x" .. tostring(math.floor(val * 100 + 0.5) / 100)
end

updateTotalMultiplierLabel()
player:GetAttributeChangedSignal("TotalMultiplier"):Connect(updateTotalMultiplierLabel)

local progressOriginalSize = playerGui:WaitForChild("Bot")
	:WaitForChild("Content"):WaitForChild("Progress").Size

local function animateLevelUp()
	local progress = getProgressUI()
	if not progress then return end

	local punchSize = UDim2.new(
		progressOriginalSize.X.Scale,
		progressOriginalSize.X.Offset,
		progressOriginalSize.Y.Scale * 1.25,
		math.round(progressOriginalSize.Y.Offset * 1.25)
	)
	TweenService:Create(progress, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = punchSize,
	}):Play()
	task.delay(0.1, function()
		TweenService:Create(
			progress,
			TweenInfo.new(0.35, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
			{ Size = progressOriginalSize }
		):Play()
	end)

	levelUpSoundPower:Play()
	levelUpSoundSparkle:Play()

	emitLevelUpParticles()
end

local function updateProgress(animateFill: boolean)
	local progress, levelLabel, speedLabel, fill = getProgressUI()
	if not progress or not levelLabel or not speedLabel or not fill then return end

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
		animateLevelUp()
	end)
end)
