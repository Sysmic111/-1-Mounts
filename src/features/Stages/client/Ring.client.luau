--!strict

-- Enemy perseguidor dentro de un BasePart taggeado "Ring".
--
-- El BasePart define el área. Dentro como hijo debe haber un Model llamado "Enemy"
-- con Humanoid y HumanoidRootPart (partes ancladas para que PivotTo funcione sin
-- que el servidor anule la posición con física).
--
-- Comportamiento:
--   · Jugador entra al área  → enemy persigue al jugador local (PivotTo cada frame)
--   · Enemy llega a CATCH_RADIUS → WallHit al servidor
--   · Jugador sale del área o respawnea → enemy vuelve instantáneamente a su origen
--
-- Las animaciones se buscan por nombre dentro del model del enemy:
--   "walk"/"run"/"move" → pista de caminar
--   "idle"/"stand"      → pista de idle
-- Si el model no tiene Animation objects, el enemy se mueve sin animación visual.

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpeedConfig = require(ReplicatedStorage.Shared.SpeedConfig)
local Packets     = require(ReplicatedStorage.Shared.Packets)

local player = Players.LocalPlayer

-- ── Tunables ──────────────────────────────────────────────────────────────────
local REFERENCE_LEVEL = 70
local ENEMY_SPEED     = SpeedConfig.getWalkSpeedForLevel(REFERENCE_LEVEL)  -- studs/s
local CATCH_RADIUS    = 4   -- studs para "atrapar" al jugador

-- ── Tipos ─────────────────────────────────────────────────────────────────────
type Ring = {
	part:      BasePart,
	enemy:     Model,
	enemyHRP:  BasePart,
	originCF:  CFrame,          -- pose de reposo del enemy
	walkTrack: AnimationTrack?,
	idleTrack: AnimationTrack?,
	isChasing: boolean,
}

local rings: { [BasePart]: Ring } = {}

-- ── Área ──────────────────────────────────────────────────────────────────────
-- Chequeo solo en XZ: el jugador camina SOBRE la part, no dentro de su volumen.
-- Ignorar Y evita falsos negativos cuando el HRP está encima de la superficie.
local function isInsidePart(part: BasePart, pos: Vector3): boolean
	local lp   = part.CFrame:PointToObjectSpace(pos)
	local half = part.Size / 2
	return math.abs(lp.X) <= half.X and math.abs(lp.Z) <= half.Z
end

-- ── Animaciones ───────────────────────────────────────────────────────────────
local function loadAnimations(enemy: Model): (AnimationTrack?, AnimationTrack?)
	local humanoid = enemy:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil, nil end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local walkTrack: AnimationTrack? = nil
	local idleTrack: AnimationTrack? = nil

	for _, desc in enemy:GetDescendants() do
		if not desc:IsA("Animation") then continue end
		local name = desc.Name:lower()
		if not walkTrack and (name:find("walk") or name:find("run") or name:find("move")) then
			local track = (animator :: Animator):LoadAnimation(desc :: Animation)
			track.Looped   = true
			track.Priority = Enum.AnimationPriority.Movement
			walkTrack = track
		elseif not idleTrack and (name:find("idle") or name:find("stand")) then
			local track = (animator :: Animator):LoadAnimation(desc :: Animation)
			track.Looped   = true
			track.Priority = Enum.AnimationPriority.Idle
			idleTrack = track
		end
	end

	if idleTrack then idleTrack:Play() end

	return walkTrack, idleTrack
end

local function setChaseAnim(ring: Ring, chasing: boolean)
	if chasing then
		if ring.idleTrack and ring.idleTrack.IsPlaying then ring.idleTrack:Stop() end
		if ring.walkTrack and not ring.walkTrack.IsPlaying then ring.walkTrack:Play() end
	else
		if ring.walkTrack and ring.walkTrack.IsPlaying then ring.walkTrack:Stop() end
		if ring.idleTrack and not ring.idleTrack.IsPlaying then ring.idleTrack:Play() end
	end
end

-- ── Registro ──────────────────────────────────────────────────────────────────
local function registerRing(inst: Instance)
	if not inst:IsA("BasePart") then return end
	local part = inst :: BasePart

	task.spawn(function()
		local rawEnemy = part:WaitForChild("Enemy", 10)
		if not rawEnemy or not rawEnemy:IsA("Model") then
			warn(`[Ring] {part:GetFullName()}: necesita un hijo "Enemy" (Model)`)
			return
		end
		local enemy = rawEnemy :: Model

		local enemyHRP = enemy:WaitForChild("HumanoidRootPart", 10) :: BasePart?
		if not enemyHRP then
			warn(`[Ring] {enemy:GetFullName()}: no tiene HumanoidRootPart`)
			return
		end

		-- Esperar un frame para que el servidor replique el CFrame antes de capturar originCF.
		-- Sin esto, originCF puede quedar en (0,0,0) y resetAllEnemies teletransporta el enemy allí.
		task.wait()
		if inst.Parent == nil then return end

		local walkTrack, idleTrack = loadAnimations(enemy)

		rings[part] = {
			part      = part,
			enemy     = enemy,
			enemyHRP  = enemyHRP,
			originCF  = enemyHRP.CFrame,
			walkTrack = walkTrack,
			idleTrack = idleTrack,
			isChasing = false,
		}
	end)
end

for _, inst in CollectionService:GetTagged("Ring") do
	registerRing(inst)
end

CollectionService:GetInstanceAddedSignal("Ring"):Connect(registerRing)
CollectionService:GetInstanceRemovedSignal("Ring"):Connect(function(inst)
	if inst:IsA("BasePart") then
		rings[inst :: BasePart] = nil
	end
end)

-- ── Personaje local ───────────────────────────────────────────────────────────
local localHRP:      BasePart? = nil
local localHumanoid: Humanoid? = nil
local dead = false

local function resetAllEnemies()
	for _, ring in rings do
		if ring.isChasing then
			ring.isChasing = false
			setChaseAnim(ring, false)
			ring.enemy:PivotTo(ring.originCF)
		end
	end
end

local function onCharacterAdded(character: Model)
	dead     = false
	localHRP      = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	localHumanoid = character:FindFirstChildOfClass("Humanoid")
	resetAllEnemies()
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end

-- ── Loop principal ────────────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function(dt: number)
	local root = localHRP
	local hum  = localHumanoid
	if not root or not hum or hum.Health <= 0 or dead then return end

	local playerPos = root.Position

	for _, ring in rings do
		local enemyHRP = ring.enemyHRP
		if not enemyHRP or not enemyHRP.Parent then continue end

		if isInsidePart(ring.part, playerPos) then
			-- Activar persecución al entrar por primera vez
			if not ring.isChasing then
				ring.isChasing = true
				setChaseAnim(ring, true)
			end

			local enemyPos = enemyHRP.Position
			local diff     = playerPos - enemyPos
			local dist     = diff.Magnitude

			-- Atrapar
			if dist <= CATCH_RADIUS then
				dead = true
				Packets.WallHit:Fire()
				break
			end

			-- Avanzar hacia el jugador (sin superar la distancia restante)
			local dir    = diff.Unit
			local newPos = enemyPos + dir * math.min(ENEMY_SPEED * dt, dist)

			-- Rotar en Y solamente (enemy siempre erguido)
			local flatDir = Vector3.new(dir.X, 0, dir.Z)
			local newCF   = if flatDir.Magnitude > 1e-3
				then CFrame.lookAt(newPos, newPos + flatDir)
				else CFrame.new(newPos)

			ring.enemy:PivotTo(newCF)

		else
			-- Volver al origen al salir del área
			if ring.isChasing then
				ring.isChasing = false
				setChaseAnim(ring, false)
				ring.enemy:PivotTo(ring.originCF)
			end
		end
	end
end)
