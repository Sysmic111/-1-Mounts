--!strict

-- Enemy perseguidor dentro de un BasePart taggeado "Ring". AUTORITATIVO EN EL
-- SERVIDOR (antes era client-side y fallaba: el enemy venía sin anclar, así que
-- la física del server anulaba el PivotTo del cliente, y el ModelStreamingMode
-- Atomic hacía race con el registro al acercarse desde lejos).
--
-- El BasePart define el área. Dentro, como hijo, un Model "Enemy" con Humanoid y
-- HumanoidRootPart. El servidor lo ancla al arrancar y lo mueve por PivotTo.
--
-- Comportamiento:
--   · Jugador dentro del área → el enemy persigue al MÁS CERCANO
--   · Enemy a <= CATCH_RADIUS  → mata a ese jugador (Humanoid.Health = 0)
--   · Nadie dentro             → el enemy vuelve a su origen
--
-- Animaciones: se buscan por nombre dentro del Model ("walk/run/move" e
-- "idle/stand"). Al reproducirlas en el Animator del server, replican a todos.

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ObstaclesConfig = require(ReplicatedStorage.Shared.ObstaclesConfig)

local TAG          = "Ring"
local CATCH_RADIUS = 4  -- studs para atrapar

-- Velocidad POR MUNDO: los dos places tienen su propio ring y su propio enemy, y el
-- de World 2 persigue a jugadores que corren a 121.8 studs/s en vez de ~98, así que
-- el mismo número no da la misma presión. World 1 conserva su 40 exacto.
--
-- Se resuelve una vez al cargar, como hacen los LocalScripts de los otros
-- obstáculos (`local CONFIG = ObstaclesConfig.get("Tronco")`): el mundo lo fija el
-- PlaceId y no cambia en toda la vida del server. Esto NO es el caso de
-- EconomyConfig.current(), que sí hay que llamar dentro de cada función.
local ENEMY_SPEED = ObstaclesConfig.get(TAG).Speed or 40

type RingEnemy = {
	part:      BasePart,
	enemy:     Model,
	enemyHRP:  BasePart,
	originCF:  CFrame,
	walkTrack: AnimationTrack?,
	walkSpeed: number,
	idleTrack: AnimationTrack?,
	idleSpeed: number,
	isChasing: boolean,
}

local RingEnemyService = {}

local enemies: { RingEnemy } = {}

-- Chequeo solo en XZ: el jugador camina SOBRE la superficie, no dentro del volumen.
local function isInsidePart(part: BasePart, pos: Vector3): boolean
	local lp   = part.CFrame:PointToObjectSpace(pos)
	local half = part.Size / 2
	return math.abs(lp.X) <= half.X and math.abs(lp.Z) <= half.Z
end

-- Devuelve walk/idle track y su velocidad de reproducción (atributo "Speed" de la
-- Animation, default 1). Las animaciones vienen autoradas con Speed (ej. Walk=1.5).
local function loadAnimations(enemy: Model): (AnimationTrack?, number, AnimationTrack?, number)
	local humanoid = enemy:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil, 1, nil, 1 end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local walkTrack: AnimationTrack? = nil
	local idleTrack: AnimationTrack? = nil
	local walkSpeed = 1
	local idleSpeed = 1

	for _, desc in enemy:GetDescendants() do
		if not desc:IsA("Animation") then continue end
		local name = desc.Name:lower()
		if not walkTrack and (name:find("walk") or name:find("run") or name:find("move")) then
			local track = (animator :: Animator):LoadAnimation(desc :: Animation)
			track.Looped   = true
			track.Priority = Enum.AnimationPriority.Movement
			walkTrack = track
			walkSpeed = (desc:GetAttribute("Speed") or 1) :: number
		elseif not idleTrack and (name:find("idle") or name:find("stand")) then
			local track = (animator :: Animator):LoadAnimation(desc :: Animation)
			track.Looped   = true
			track.Priority = Enum.AnimationPriority.Idle
			idleTrack = track
			idleSpeed = (desc:GetAttribute("Speed") or 1) :: number
		end
	end

	if idleTrack then
		idleTrack:Play()
		idleTrack:AdjustSpeed(idleSpeed)
	end
	return walkTrack, walkSpeed, idleTrack, idleSpeed
end

-- Camina → walk; quieto → idle. Reproduce a la velocidad autorada de cada anim.
local function setChaseAnim(e: RingEnemy, chasing: boolean)
	if chasing then
		if e.idleTrack and e.idleTrack.IsPlaying then
			e.idleTrack:Stop()
		end
		if e.walkTrack and not e.walkTrack.IsPlaying then
			e.walkTrack:Play()
			e.walkTrack:AdjustSpeed(e.walkSpeed)
		end
	else
		if e.walkTrack and e.walkTrack.IsPlaying then
			e.walkTrack:Stop()
		end
		if e.idleTrack and not e.idleTrack.IsPlaying then
			e.idleTrack:Play()
			e.idleTrack:AdjustSpeed(e.idleSpeed)
		end
	end
end

local function registerRing(inst: Instance)
	if not inst:IsA("BasePart") then return end
	local part = inst :: BasePart

	local rawEnemy = part:FindFirstChild("Enemy") or part:WaitForChild("Enemy", 10)
	if not rawEnemy or not rawEnemy:IsA("Model") then
		warn(`[RingEnemy] {part:GetFullName()}: falta el Model "Enemy"`)
		return
	end
	local enemy = rawEnemy :: Model

	local enemyHRP = enemy:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not enemyHRP then
		warn(`[RingEnemy] {enemy:GetFullName()}: sin HumanoidRootPart`)
		return
	end

	-- Anclar todas las partes: el movimiento es por PivotTo autoritativo del server,
	-- no por física. (El modelo venía sin anclar; por eso el cliente no lo movía.)
	for _, d in enemy:GetDescendants() do
		if d:IsA("BasePart") then
			(d :: BasePart).Anchored = true
		end
	end

	local walkTrack, walkSpeed, idleTrack, idleSpeed = loadAnimations(enemy)

	table.insert(enemies, {
		part      = part,
		enemy     = enemy,
		enemyHRP  = enemyHRP,
		originCF  = enemyHRP.CFrame,
		walkTrack = walkTrack,
		walkSpeed = walkSpeed,
		idleTrack = idleTrack,
		idleSpeed = idleSpeed,
		isChasing = false,
	})
end

function RingEnemyService:init(): ()
	for _, inst in CollectionService:GetTagged(TAG) do
		task.spawn(registerRing, inst)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(inst)
		task.spawn(registerRing, inst)
	end)

	RunService.Heartbeat:Connect(function(dt: number)
		for _, e in enemies do
			local hrp = e.enemyHRP
			if not hrp or not hrp.Parent then continue end

			-- Jugador vivo más cercano dentro del área.
			local targetHRP:    BasePart? = nil
			local targetPlayer: Player?   = nil
			local bestDist = math.huge

			for _, plr in Players:GetPlayers() do
				local char = plr.Character
				if not char then continue end
				local phrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
				local phum = char:FindFirstChildOfClass("Humanoid")
				if not phrp or not phum or phum.Health <= 0 then continue end
				if not isInsidePart(e.part, phrp.Position) then continue end

				local d = (phrp.Position - hrp.Position).Magnitude
				if d < bestDist then
					bestDist     = d
					targetHRP    = phrp
					targetPlayer = plr
				end
			end

			if targetHRP and targetPlayer then
				if not e.isChasing then
					e.isChasing = true
					setChaseAnim(e, true)
				end

				if bestDist <= CATCH_RADIUS then
					-- Atrapar: matar al jugador (autoritativo, sin confiar en el cliente).
					local char = targetPlayer.Character
					local phum = char and char:FindFirstChildOfClass("Humanoid")
					if phum then phum.Health = 0 end
					e.isChasing = false
					setChaseAnim(e, false)
					e.enemy:PivotTo(e.originCF)
				else
					local diff   = targetHRP.Position - hrp.Position
					local dir    = diff.Unit
					local newPos = hrp.Position + dir * math.min(ENEMY_SPEED * dt, bestDist)

					local flatDir = Vector3.new(dir.X, 0, dir.Z)
					local newCF   = if flatDir.Magnitude > 1e-3
						then CFrame.lookAt(newPos, newPos + flatDir)
						else CFrame.new(newPos)

					e.enemy:PivotTo(newCF)
				end
			else
				if e.isChasing then
					e.isChasing = false
					setChaseAnim(e, false)
					e.enemy:PivotTo(e.originCF)
				end
			end
		end
	end)
end

return RingEnemyService
