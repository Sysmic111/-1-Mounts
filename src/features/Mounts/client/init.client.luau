--!strict

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local LIGHT_BLUE    = Color3.fromRGB(100, 210, 255)
local GLOW_DURATION = 1.0
local RESTORE_TIME  = 2.5
local RESTORE_TWEEN = TweenInfo.new(RESTORE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function isMountCharacter(character: Model): boolean
	return character:GetAttribute("IsMountCharacter") == true
end

local function makeEmitter(att: Attachment, rate: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,   Color3.fromRGB(210, 240, 255)),
		ColorSequenceKeypoint.new(0.4, LIGHT_BLUE),
		ColorSequenceKeypoint.new(1,   Color3.fromRGB(30, 120, 255)),
	})
	e.LightEmission  = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   0.65),
		NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(1,   0),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime    = NumberRange.new(0.3, 0.65)
	e.Speed       = NumberRange.new(12, 28)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate        = rate
	e.RotSpeed    = NumberRange.new(-270, 270)
	e.Rotation    = NumberRange.new(0, 360)
	e.Parent      = att
	return e
end

local function playMorphAnimation(character: Model)
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return end

	local originalChar = character:FindFirstChild("OriginalCharacter")
	local partData: { { part: BasePart, mat: Enum.Material, col: Color3, transp: number } } = {}
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart")
			and (not originalChar or not part:IsDescendantOf(originalChar)) then
			table.insert(partData, { part = part, mat = part.Material, col = part.Color, transp = part.Transparency })
			part.Material = Enum.Material.Neon
			part.Color    = LIGHT_BLUE
		end
	end

	local att = Instance.new("Attachment")
	att.Parent = hrp

	local continuousEmitter = makeEmitter(att, 220)
	local burstEmitter      = makeEmitter(att, 0)
	burstEmitter:Emit(90)

	local hrpLight = Instance.new("PointLight")
	hrpLight.Color      = LIGHT_BLUE
	hrpLight.Brightness = 6
	hrpLight.Range      = 20
	hrpLight.Parent     = hrp

	task.wait(GLOW_DURATION)
	continuousEmitter.Rate = 0

	for _, d in ipairs(partData) do
		if d.part and d.part.Parent then
			TweenService:Create(d.part, RESTORE_TWEEN, { Color = d.col, Transparency = d.transp }):Play()
		end
	end

	if hrpLight.Parent then
		TweenService:Create(hrpLight, RESTORE_TWEEN, { Brightness = 0 }):Play()
	end

	task.wait(RESTORE_TIME)

	for _, d in ipairs(partData) do
		if d.part and d.part.Parent then
			d.part.Material = d.mat
		end
	end

	if att.Parent then
		att:Destroy()
	end
	if hrpLight.Parent then
		hrpLight:Destroy()
	end
end

local function setupMountAnimations(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local animFolder = character:FindFirstChild("Animations")
	if not animFolder then return end

	local idleAnim = animFolder:FindFirstChild("Idle") :: Animation?
	local walkAnim = animFolder:FindFirstChild("Walk") :: Animation?

	local idleTrack: AnimationTrack? = nil
	local walkTrack: AnimationTrack? = nil

	if idleAnim then
		idleTrack = animator:LoadAnimation(idleAnim)
		idleTrack.Looped = true
		idleTrack:Play(0, 1, idleAnim:GetAttribute("Speed") or 1)
	end

	if walkAnim then
		walkTrack = animator:LoadAnimation(walkAnim)
		walkTrack.Looped = true
	end

	local onTreadmill = false

	local function playWalk()
		if walkTrack and not walkTrack.IsPlaying then
			local baseSpeed = (walkAnim and walkAnim:GetAttribute("Speed") or 1) :: number
			walkTrack:Play(0, 1, baseSpeed * (humanoid.WalkSpeed / 16))
		end
		if idleTrack and idleTrack.IsPlaying then
			idleTrack:Stop()
		end
	end

	local function playIdle()
		if walkTrack and walkTrack.IsPlaying then
			walkTrack:Stop()
		end
		if idleTrack and not idleTrack.IsPlaying then
			idleTrack:Play(0, 1, idleAnim and idleAnim:GetAttribute("Speed") or 1)
		end
	end

	humanoid.Running:Connect(function(speed)
		if onTreadmill then return end
		if speed > 0.1 then
			playWalk()
		else
			playIdle()
		end
	end)

	character:GetAttributeChangedSignal("OnTreadmill"):Connect(function()
		onTreadmill = character:GetAttribute("OnTreadmill") == true
		if onTreadmill then
			playWalk()
		else
			playIdle()
		end
	end)

	local originalChar = character:FindFirstChild("OriginalCharacter")
		or character:WaitForChild("OriginalCharacter", 5) :: Model?
	if not originalChar then return end

	local cloneHum = (originalChar :: Model):FindFirstChildOfClass("Humanoid")
	if not cloneHum then return end

	local cloneAnimator = cloneHum:FindFirstChildOfClass("Animator")
	if not cloneAnimator then
		cloneAnimator = Instance.new("Animator")
		cloneAnimator.Parent = cloneHum
	end

	local seatAnim = animFolder:FindFirstChild("Seat") :: Animation?
	if seatAnim then
		local sitTrack = cloneAnimator:LoadAnimation(seatAnim)
		sitTrack.Looped = true
		sitTrack:Play(0, 1, seatAnim:GetAttribute("Speed") or 1)
	end
end

player.CharacterAdded:Connect(function(character: Model)
	if not isMountCharacter(character) then return end

	local hrp = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not hrp then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end

	task.spawn(setupMountAnimations, character)
	task.spawn(playMorphAnimation, character)
end)
