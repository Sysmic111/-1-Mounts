--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Packets      = require(ReplicatedStorage.Shared.Packets)
local FormatNumber = require(ReplicatedStorage.Packages.FormatNumber)
local DataService  = require(ReplicatedStorage.Packages.DataService).client
local SpeedConfig  = require(ReplicatedStorage.Shared.SpeedConfig)
local RobuxConfig  = require(ReplicatedStorage.Shared.RobuxConfig)

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

local NOTIFICATION_HOLD_TIME = 3
local NOTIFICATION_FADE_TIME = 1
local activeLevelUpBanner: CanvasGroup? = nil
local levelUpNotificationGeneration = 0

local function createTextLabel(parent: Instance, name: string, text: string, maxTextSize: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Font.fromName("FredokaOne")
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextStrokeColor3 = Color3.fromRGB(16, 20, 30)
	label.TextStrokeTransparency = 0.6
	label.ZIndex = 103
	label.Parent = parent

	local textSizeConstraint = Instance.new("UITextSizeConstraint")
	textSizeConstraint.MinTextSize = 12
	textSizeConstraint.MaxTextSize = maxTextSize
	textSizeConstraint.Parent = label
	return label
end

local function getLevelUpNotificationGui(): ScreenGui
	local existing = playerGui:FindFirstChild("LevelUpNotifications")
	if existing and existing:IsA("ScreenGui") then
		return existing
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LevelUpNotifications"
	screenGui.DisplayOrder = 100
	screenGui.IgnoreGuiInset = false
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui
	return screenGui
end

local function createLevelUpBanner(previousLevel: number, newLevel: number): CanvasGroup
	local banner = Instance.new("CanvasGroup")
	banner.Name = "LevelUpBanner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.BackgroundTransparency = 1
	banner.BorderSizePixel = 0
	banner.ClipsDescendants = true
	banner.Position = UDim2.new(0.5, 0, 0, 12)
	banner.Size = UDim2.new(0.9, 0, 0, 116)
	banner.GroupTransparency = 0
	banner.ZIndex = 100
	banner.Parent = getLevelUpNotificationGui()

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(260, 116)
	sizeConstraint.MaxSize = Vector2.new(620, 116)
	sizeConstraint.Parent = banner

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = banner

	-- El fondo va en su propio Frame, no en el CanvasGroup: un UIGradient sobre un
	-- CanvasGroup se aplica al grupo ya compuesto (texto incluido) y teñía las
	-- letras del mismo azul oscuro que el fondo, dejándolas ilegibles.
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.BackgroundColor3 = Color3.fromRGB(52, 72, 105)
	background.BackgroundTransparency = 0.15
	background.BorderSizePixel = 0
	background.Size = UDim2.fromScale(1, 1)
	background.ZIndex = 100
	background.Parent = banner

	local backgroundCorner = Instance.new("UICorner")
	backgroundCorner.CornerRadius = UDim.new(0, 18)
	backgroundCorner.Parent = background

	-- El stroke sí va en el CanvasGroup: dentro lo recortaría ClipsDescendants, y
	-- sobre el grupo solo dibuja el contorno de la silueta (no tiñe el relleno).
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 203, 64)
	stroke.Thickness = 3
	stroke.Transparency = 0.05
	stroke.Parent = banner

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(76, 94, 137)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(48, 67, 101)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(33, 91, 112)),
	})
	gradient.Rotation = 12
	gradient.Parent = background

	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.AnchorPoint = Vector2.new(0.5, 1)
	accent.BackgroundColor3 = Color3.fromRGB(79, 224, 255)
	accent.BorderSizePixel = 0
	accent.Position = UDim2.fromScale(0.5, 1)
	accent.Size = UDim2.new(0.78, 0, 0, 4)
	accent.ZIndex = 101
	accent.Parent = banner

	local accentCorner = Instance.new("UICorner")
	accentCorner.CornerRadius = UDim.new(1, 0)
	accentCorner.Parent = accent

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Position = UDim2.new(0, 18, 0, 9)
	content.Size = UDim2.new(1, -36, 1, -18)
	content.ZIndex = 102
	content.Parent = banner

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 1)
	layout.Parent = content

	local titleHolder = Instance.new("Frame")
	titleHolder.Name = "TitleHolder"
	titleHolder.BackgroundTransparency = 1
	titleHolder.LayoutOrder = 1
	titleHolder.Size = UDim2.new(1, 0, 0, 31)
	titleHolder.ZIndex = 102
	titleHolder.Parent = content
	createTextLabel(titleHolder, "Title", "LEVEL UP!", 30, Color3.fromRGB(255, 216, 79))

	local levelHolder = Instance.new("Frame")
	levelHolder.Name = "LevelHolder"
	levelHolder.BackgroundTransparency = 1
	levelHolder.LayoutOrder = 2
	levelHolder.Size = UDim2.new(1, 0, 0, 23)
	levelHolder.ZIndex = 102
	levelHolder.Parent = content
	createTextLabel(
		levelHolder,
		"Level",
		string.format("LEVEL %d  →  LEVEL %d", previousLevel, newLevel),
		20,
		Color3.fromRGB(255, 255, 255)
	)

	local previousSpeed = SpeedConfig.getWalkSpeedForLevel(previousLevel)
	local newSpeed = SpeedConfig.getWalkSpeedForLevel(newLevel)
	local speedTitleHolder = Instance.new("Frame")
	speedTitleHolder.Name = "SpeedTitleHolder"
	speedTitleHolder.BackgroundTransparency = 1
	speedTitleHolder.LayoutOrder = 3
	speedTitleHolder.Size = UDim2.new(1, 0, 0, 17)
	speedTitleHolder.ZIndex = 102
	speedTitleHolder.Parent = content
	createTextLabel(
		speedTitleHolder,
		"MovementSpeedTitle",
		"MOVEMENT SPEED",
		15,
		Color3.fromRGB(105, 226, 255)
	)

	local speedHolder = Instance.new("Frame")
	speedHolder.Name = "SpeedHolder"
	speedHolder.BackgroundTransparency = 1
	speedHolder.LayoutOrder = 4
	speedHolder.Size = UDim2.new(1, 0, 0, 23)
	speedHolder.ZIndex = 102
	speedHolder.Parent = content
	createTextLabel(
		speedHolder,
		"MovementSpeedValues",
		string.format("%.1f  →  %.1f", previousSpeed, newSpeed),
		21,
		Color3.fromRGB(255, 255, 255)
	)

	local scale = Instance.new("UIScale")
	scale.Name = "EntranceScale"
	scale.Scale = 0.82
	scale.Parent = banner

	TweenService:Create(
		banner,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, 0, 0, 28) }
	):Play()
	TweenService:Create(
		scale,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()

	return banner
end

local function showLevelUpNotification(previousLevel: number, newLevel: number)
	levelUpNotificationGeneration += 1
	local generation = levelUpNotificationGeneration

	if activeLevelUpBanner then
		activeLevelUpBanner:Destroy()
		activeLevelUpBanner = nil
	end

	local banner = createLevelUpBanner(previousLevel, newLevel)
	activeLevelUpBanner = banner

	task.delay(NOTIFICATION_HOLD_TIME, function()
		if generation ~= levelUpNotificationGeneration or activeLevelUpBanner ~= banner or not banner.Parent then
			return
		end

		local fadeInfo = TweenInfo.new(NOTIFICATION_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(
			banner,
			fadeInfo,
			{
				BackgroundTransparency = 1,
				GroupTransparency = 1,
				Position = UDim2.new(0.5, 0, 0, 18),
			}
		):Play()

		for _, descendant in banner:GetDescendants() do
			if descendant:IsA("TextLabel") then
				TweenService:Create(descendant, fadeInfo, {
					TextTransparency = 1,
					TextStrokeTransparency = 1,
				}):Play()
			elseif descendant:IsA("UIStroke") then
				TweenService:Create(descendant, fadeInfo, { Transparency = 1 }):Play()
			elseif descendant:IsA("Frame") then
				TweenService:Create(descendant, fadeInfo, { BackgroundTransparency = 1 }):Play()
			end
		end

		task.delay(NOTIFICATION_FADE_TIME, function()
			if generation ~= levelUpNotificationGeneration or activeLevelUpBanner ~= banner then
				return
			end
			activeLevelUpBanner = nil
			banner:Destroy()
		end)
	end)
end

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
	if not speedLabel then
		clone:Destroy()
		return
	end

	local uiStroke = speedLabel:FindFirstChildOfClass("UIStroke") :: UIStroke
	local imageLabel = clone:FindFirstChild("ImageLabel") :: ImageLabel

	speedLabel.Text = "+ " .. FormatNumber:formatNumberCoins(amount)

	local randomX = 0.5 + (math.random() * 2 - 1) * 0.40
	local randomY = 0.5 + (math.random() * 2 - 1) * 0.40
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
			if clone and clone.Parent then
				clone:Destroy()
			end
		end)
	end)
end

-- Returns the Multiplier attribute of the treadmill the HRP is above, or nil if not on any.
-- Skips treadmills the player can't access (rebirth gate or unowned Robux tier).
local function getTreadmillMultiplier(hrp: BasePart): number?
	local rebirthCount = (DataService:get({ "Rebirth" }) or 0) :: number

	for _, model in CollectionService:GetTagged("Treadmill") do
		local tier = (model :: Model):GetAttribute("Robux") :: string?
		if tier then
			-- Robux-gated: only active when the player owns this tier
			if DataService:get({ RobuxConfig.treadmillKey(tier) }) ~= true then continue end
		else
			-- Rebirth-gated
			local rebirthReq = ((model :: Model):GetAttribute("Rebirth") or 0) :: number
			if rebirthCount < rebirthReq then continue end
		end

		local pp = (model :: Model).PrimaryPart
		if not pp then continue end
		local localPos = pp.CFrame:PointToObjectSpace(hrp.Position)
		local half = pp.Size / 2
		if math.abs(localPos.X) <= half.X
			and math.abs(localPos.Z) <= half.Z
			and localPos.Y >= -1
			and localPos.Y <= half.Y + 8 then
			return (model :: Model):GetAttribute("Multiplier") or 1
		end
	end
	return nil
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

	local treadmillMultiplier = getTreadmillMultiplier(rootPart)
	local onTreadmill = treadmillMultiplier ~= nil
	local wasOnTreadmill = character:GetAttribute("OnTreadmill") == true
	if onTreadmill ~= wasOnTreadmill then
		character:SetAttribute("OnTreadmill", onTreadmill)
	end

	if onTreadmill then
		treadmillDistanceRemainder += humanoid.WalkSpeed * dt
		if treadmillDistanceRemainder >= SpeedConfig.StudsPerSpeed and (now - lastPacketTime) >= SpeedConfig.MovementCheckInterval then
			treadmillDistanceRemainder -= SpeedConfig.StudsPerSpeed
			lastPacketTime = now
			local tm = treadmillMultiplier :: number
			Packets.RequestSpeedGain:Fire(tm)
			showSpeedGain(math.ceil(
				(player:GetAttribute("TotalMultiplier") or 1) :: number
				* (player:GetAttribute("EquippedSteps")    or 1) :: number
				* tm
			))
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

	if humanoid.MoveDirection.Magnitude == 0 then
		lastPosition = currentPosition
		return
	end

	-- Solo se gana speed pisando suelo: caer del cielo o saltar mueve la posición
	-- (incluido el eje vertical) y acumularía speed sin caminar. FloorMaterial es
	-- Air en caída libre/salto. Mantenemos lastPosition al día para que el salto de
	-- posición de la caída no se cuente de golpe al aterrizar.
	if humanoid.FloorMaterial == Enum.Material.Air then
		lastPosition = currentPosition
		return
	end

	local moved = (currentPosition - lastPosition).Magnitude
	lastPosition = currentPosition

	distanceRemainder += moved

	if distanceRemainder >= SpeedConfig.StudsPerSpeed and (now - lastPacketTime) >= SpeedConfig.MovementCheckInterval then
		distanceRemainder -= SpeedConfig.StudsPerSpeed
		lastPacketTime = now
		Packets.RequestSpeedGain:Fire(1)
		showSpeedGain(math.ceil(
			(player:GetAttribute("TotalMultiplier") or 1) :: number
			* (player:GetAttribute("EquippedSteps")    or 1) :: number
		))
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
	local previousLevel = (DataService:get({ "Level" }) or 1) :: number
	updateProgress(false)
	DataService:getChangedSignal({ "SpeedCurrency" }):Connect(function()
		updateProgress(true)
	end)
	DataService:getChangedSignal({ "Level" }):Connect(function()
		local newLevel = (DataService:get({ "Level" }) or previousLevel) :: number
		updateProgress(true)
		if newLevel > previousLevel then
			animateLevelUp()
			showLevelUpNotification(previousLevel, newLevel)
		end
		previousLevel = newLevel
	end)
end)
