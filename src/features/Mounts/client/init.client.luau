--!strict

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local _BASE_FOV = 70
local _ZOOM_FOV = 90

local LIGHT_BLUE   = Color3.fromRGB(100, 210, 255)
local SPHERE_COLOR = Color3.fromRGB(60, 180, 255)

local GROW_TIME    = 1.0
local SHRINK_TIME  = 1.0
local RESTORE_TIME = 2.5

local GROW_TWEEN    = TweenInfo.new(GROW_TIME,    Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SHRINK_TWEEN  = TweenInfo.new(SHRINK_TIME,  Enum.EasingStyle.Quad, Enum.EasingDirection.In)
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

local function playMorphAnimation(character: Model, savedCFrame: CFrame?)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp      = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not hrp then return end

	local origZoomMin = player.CameraMinZoomDistance
	local origZoomMax = player.CameraMaxZoomDistance

	camera.CameraType = Enum.CameraType.Scriptable

	local mountPos     = hrp.CFrame.Position
	local camTargetPos = mountPos - hrp.CFrame.LookVector * 15 + Vector3.new(0, 7, 0)
	local camTargetCFrame = CFrame.new(camTargetPos, mountPos)

	local camCube = Instance.new("Part")
	camCube.Name         = "CamTarget"
	camCube.Anchored     = true
	camCube.CanCollide   = false
	camCube.Transparency = 1
	camCube.Size         = Vector3.new(0.5, 0.5, 0.5)
	camCube.CFrame       = camTargetCFrame
	camCube.Parent       = workspace

	task.spawn(function()
		TweenService:Create(
			camera,
			TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{ CFrame = camTargetCFrame }
		):Play()
	end)

	local origSpeed = humanoid.WalkSpeed
	local origJump  = humanoid.JumpPower
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0

	local _, bboxSize = character:GetBoundingBox()
	local diameter = math.max(bboxSize.X, bboxSize.Y, bboxSize.Z)

	local originalChar = character:FindFirstChild("OriginalCharacter")
	local partData: { { part: BasePart, mat: Enum.Material, col: Color3, transp: number } } = {}
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart")
			and (not originalChar or not part:IsDescendantOf(originalChar)) then
			table.insert(partData, { part = part, mat = part.Material, col = part.Color, transp = part.Transparency })
			part.Transparency = 1
		end
	end

	local sphere = Instance.new("Part")
	sphere.Shape        = Enum.PartType.Ball
	sphere.Material     = Enum.Material.Neon
	sphere.Color        = SPHERE_COLOR
	sphere.Anchored     = true
	sphere.CanCollide   = false
	sphere.CastShadow   = false
	sphere.Size         = Vector3.new(0.05, 0.05, 0.05)
	sphere.CFrame       = hrp.CFrame
	sphere.Parent       = workspace

	local sphereLight = Instance.new("PointLight")
	sphereLight.Color      = LIGHT_BLUE
	sphereLight.Brightness = 8
	sphereLight.Range      = 26
	sphereLight.Parent     = sphere

	local att: Attachment?
	local hrpLight: PointLight?
	local ball: BasePart?
	local shock: BasePart?
	local vfxConn: RBXScriptConnection?

	local earlyCleanup = character.AncestryChanged:Connect(function()
		if vfxConn                      then vfxConn:Disconnect()  end
		if sphere   and sphere.Parent   then sphere:Destroy()      end
		if ball     and ball.Parent     then ball:Destroy()        end
		if shock    and shock.Parent    then shock:Destroy()       end
		if att      and att.Parent      then att:Destroy()         end
		if hrpLight and hrpLight.Parent then hrpLight:Destroy()    end
		if camCube  and camCube.Parent  then camCube:Destroy()     end
		if camera.CameraType == Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Custom
		end
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = origSpeed
			humanoid.JumpPower = origJump
		end
	end)

	local ballTargetSize = Vector3.new(0.001, 0.001, 0.001)
	local vfxFolder = ReplicatedStorage:FindFirstChild("Models")
		and (ReplicatedStorage:FindFirstChild("Models") :: Instance):FindFirstChild("VFX")

	local ballTemplate = vfxFolder and (vfxFolder :: Instance):FindFirstChild("Ball")
	if ballTemplate then
		ball = (ballTemplate :: BasePart):Clone()
		ball.Material   = Enum.Material.Neon
		ball.Color      = SPHERE_COLOR
		ball.CastShadow = false
		ball.CanCollide = false
		ball.Anchored   = true
		local naturalDiam = math.max(ball.Size.X, ball.Size.Y, ball.Size.Z)
		if naturalDiam > 0 then
			ballTargetSize = ball.Size * ((diameter * 1.05) / naturalDiam)
		else
			ballTargetSize = Vector3.new(diameter * 1.05, diameter * 1.05, diameter * 1.05)
		end
		ball.Size   = Vector3.new(0.001, 0.001, 0.001)
		ball.CFrame = hrp.CFrame
		ball.Parent = workspace
	end

	local shockPos = Vector3.new(hrp.Position.X, hrp.Position.Y - humanoid.HipHeight, hrp.Position.Z)
	local shockTemplate = vfxFolder and (vfxFolder :: Instance):FindFirstChild("Shock")
	if shockTemplate then
		shock = (shockTemplate :: BasePart):Clone()
		shock.Material     = Enum.Material.Neon
		shock.Color        = SPHERE_COLOR
		shock.Transparency = 1
		shock.CastShadow   = false
		shock.CanCollide   = false
		shock.Anchored     = true
		shock.CFrame       = CFrame.new(shockPos)
		shock.Parent       = workspace
	end

	local animStart = tick()
	local ballRotY  = 0
	local shockRotY = 0
	vfxConn = RunService.RenderStepped:Connect(function(dt)
		local elapsed  = tick() - animStart
		local inShrink = elapsed >= GROW_TIME

		if ball and ball.Parent then
			local eased
			if not inShrink then
				local t = math.clamp(elapsed / GROW_TIME, 0, 1)
				eased = 1 - (1 - t)^2
			else
				local t = math.clamp((elapsed - GROW_TIME) / SHRINK_TIME, 0, 1)
				eased = 1 - t * t
			end
			ball.Size   = ballTargetSize * math.max(eased, 0.001)
			ballRotY    = ballRotY + dt * math.pi * 2
			ball.CFrame = CFrame.new(hrp.CFrame.Position) * CFrame.Angles(0, ballRotY, 0)
		end

		if shock and shock.Parent then
			local transp
			if not inShrink then
				local t = math.clamp(elapsed / GROW_TIME, 0, 1)
				transp = (1 - t) * (1 - t)
			else
				local t = math.clamp((elapsed - GROW_TIME) / SHRINK_TIME, 0, 1)
				transp = t * t
			end
			shock.Transparency = transp
			shockRotY    = shockRotY + dt * math.pi
			shock.CFrame = CFrame.new(shockPos) * CFrame.Angles(0, shockRotY, 0)
		end
	end)

	TweenService:Create(sphere, GROW_TWEEN,
		{ Size = Vector3.new(diameter, diameter, diameter) }
	):Play()

	task.wait(GROW_TIME)

	for _, d in ipairs(partData) do
		if d.part and d.part.Parent then
			d.part.Transparency = d.transp
			d.part.Material     = Enum.Material.Neon
			d.part.Color        = LIGHT_BLUE
		end
	end

	att = Instance.new("Attachment")
	att.Parent = hrp

	local continuousEmitter = makeEmitter(att, 220)
	local burstEmitter      = makeEmitter(att, 0)
	burstEmitter:Emit(90)

	hrpLight = Instance.new("PointLight")
	hrpLight.Color      = LIGHT_BLUE
	hrpLight.Brightness = 6
	hrpLight.Range      = 20
	hrpLight.Parent     = hrp

	TweenService:Create(sphere, SHRINK_TWEEN,
		{ Size = Vector3.new(0.05, 0.05, 0.05) }
	):Play()

	task.wait(SHRINK_TIME)
	if vfxConn                  then vfxConn:Disconnect()  end
	if sphere and sphere.Parent then sphere:Destroy()      end
	if ball   and ball.Parent   then ball:Destroy()        end
	if shock  and shock.Parent  then shock:Destroy()       end

	if camCube and camCube.Parent then
		local zoom = math.clamp(
			(camera.CFrame.Position - hrp.CFrame.Position).Magnitude,
			0.5, 128
		)
		player.CameraMinZoomDistance = zoom
		player.CameraMaxZoomDistance = zoom
		camera.CameraType = Enum.CameraType.Custom
		task.defer(function()
			player.CameraMinZoomDistance = origZoomMin
			player.CameraMaxZoomDistance = origZoomMax
		end)
		camCube:Destroy()
	end

	if humanoid and humanoid.Parent then
		humanoid.WalkSpeed = origSpeed
		humanoid.JumpPower = origJump
	end

	continuousEmitter.Rate = 0

	for _, d in ipairs(partData) do
		if d.part and d.part.Parent then
			TweenService:Create(d.part, RESTORE_TWEEN, { Color = d.col, Transparency = d.transp }):Play()
		end
	end

	if hrpLight and hrpLight.Parent then
		TweenService:Create(hrpLight, RESTORE_TWEEN, { Brightness = 0 }):Play()
	end

	task.wait(RESTORE_TIME)

	for _, d in ipairs(partData) do
		if d.part and d.part.Parent then
			d.part.Material = d.mat
		end
	end

	if att      and att.Parent      then att:Destroy()      end
	if hrpLight and hrpLight.Parent then hrpLight:Destroy() end

	earlyCleanup:Disconnect()
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
		if idleTrack and idleTrack.IsPlaying then idleTrack:Stop() end
	end

	local function playIdle()
		if walkTrack and walkTrack.IsPlaying then walkTrack:Stop() end
		if idleTrack and not idleTrack.IsPlaying then
			idleTrack:Play(0, 1, idleAnim and idleAnim:GetAttribute("Speed") or 1)
		end
	end

	humanoid.Running:Connect(function(speed)
		if onTreadmill then return end
		if speed > 0.1 then playWalk() else playIdle() end
	end)

	character:GetAttributeChangedSignal("OnTreadmill"):Connect(function()
		onTreadmill = character:GetAttribute("OnTreadmill") == true
		if onTreadmill then playWalk() else playIdle() end
	end)

	-- Seat animation en el OriginalCharacter (el clone del jugador sentado)
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

local preMorphCFrame: CFrame? = nil
local hadCharacter = player.Character ~= nil

player:GetPropertyChangedSignal("Character"):Connect(function()
	local newChar = player.Character
	local prevHad = hadCharacter
	hadCharacter  = newChar ~= nil

	if not newChar or not prevHad then return end

	preMorphCFrame    = camera.CFrame
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame     = preMorphCFrame
end)

player.CharacterAdded:Connect(function(character: Model)
	local savedCFrame = preMorphCFrame
	preMorphCFrame = nil

	if not isMountCharacter(character) then
		if camera.CameraType == Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Custom
		end
		return
	end

	local hrp = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not hrp then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end

	task.spawn(setupMountAnimations, character)
	task.spawn(playMorphAnimation, character, savedCFrame)
end)
