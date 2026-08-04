--!strict

-- Totems giratorios de los Stages.
--
-- Cada Model taggeado "Totem" gira infinitamente sobre su eje Y local.
-- La velocidad angular está calibrada al WalkSpeed de nivel 80: un jugador
-- más lento no puede cruzar a tiempo.
-- El ángulo se deriva de GetServerTimeNow() para que todos los clientes
-- estén sincronizados sin replicar nada.
-- Si el jugador toca cualquier parte del totem, se notifica al servidor
-- con WallHit para que aplique la muerte.

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpeedConfig     = require(ReplicatedStorage.Shared.SpeedConfig)
local Packets         = require(ReplicatedStorage.Shared.Packets)
local ObstaclesConfig = require(ReplicatedStorage.Shared.ObstaclesConfig)

local player = Players.LocalPlayer

-- ── Tunables ──────────────────────────────────────────────────────────────────
-- Calibración por mundo (ver ObstaclesConfig).
local REFERENCE_LEVEL    = ObstaclesConfig.get("Totem").Level
local ROT_DEG_PER_SEC    = SpeedConfig.getWalkSpeedForLevel(REFERENCE_LEVEL)  -- °/s
local ROT_RAD_PER_SEC    = ROT_DEG_PER_SEC * math.pi / 180
local PLAYER_RADIUS      = 2.5

-- ── Estado ────────────────────────────────────────────────────────────────────
type Totem = {
	model:    Model,
	baseCF:   CFrame,       -- pivote base completo (posición + orientación)
	parts:    { BasePart },
	spawnTime: number,      -- tiempo de servidor en que apareció/se registró
}

local totems: { [Model]: Totem } = {}

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function collectParts(model: Model): { BasePart }
	local parts: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	return parts
end

-- ── Registro ──────────────────────────────────────────────────────────────────
local function registerTotem(inst: Instance)
	if not inst:IsA("Model") then return end
	local model = inst :: Model

	task.spawn(function()
		-- Esperar PrimaryPart si existe; si no llega en 10s, continuar sin ella.
		local deadline = os.clock() + 10
		while not model.PrimaryPart and model.Parent ~= nil and os.clock() < deadline do
			task.wait()
		end
		if model.Parent == nil then return end

		-- Usar el pivote del modelo como referencia: es exactamente el punto sobre
		-- el que opera PivotTo, así que rotar alrededor de él mantiene el totem en
		-- su sitio (solo gira, no se traslada). GetPivot() respeta el PrimaryPart y
		-- su PivotOffset si existen.
		local baseCF: CFrame = model:GetPivot()

		local parts = collectParts(model)
		for _, part in parts do
			part.Anchored = true
		end

		-- Anclar el inicio del giro al momento en que el totem aparece, para que
		-- arranque desde su orientación base en vez de saltar al ángulo global.
		-- Si el servidor replica un atributo "SpawnTime", lo usamos para que todos
		-- los clientes queden perfectamente sincronizados; si no, caemos al tiempo
		-- de servidor local de este cliente.
		local spawnAttr = model:GetAttribute("SpawnTime")
		local spawnTime = if typeof(spawnAttr) == "number"
			then spawnAttr :: number
			else Workspace:GetServerTimeNow()

		totems[model] = {
			model     = model,
			baseCF    = baseCF,
			parts     = parts,
			spawnTime = spawnTime,
		}

		model.DescendantAdded:Connect(function(d)
			local t = totems[model]
			if t and d:IsA("BasePart") then
				d.Anchored = true
				table.insert(t.parts, d)
			end
		end)
	end)
end

for _, inst in CollectionService:GetTagged("Totem") do
	registerTotem(inst)
end

CollectionService:GetInstanceAddedSignal("Totem"):Connect(registerTotem)
CollectionService:GetInstanceRemovedSignal("Totem"):Connect(function(inst)
	if inst:IsA("Model") then
		totems[inst :: Model] = nil
	end
end)

-- ── Personaje local ───────────────────────────────────────────────────────────
local hrp:      BasePart? = nil
local humanoid: Humanoid? = nil
local dead = false

local function onCharacterAdded(character: Model)
	dead     = false
	hrp      = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	humanoid = character:FindFirstChildOfClass("Humanoid")
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end

-- ── Colisión ──────────────────────────────────────────────────────────────────
local function touchesTotem(t: Totem, pos: Vector3): boolean
	for _, part in t.parts do
		local lp = part.CFrame:PointToObjectSpace(pos)
		local s  = part.Size
		if  math.abs(lp.X) <= s.X / 2 + PLAYER_RADIUS
		and math.abs(lp.Y) <= s.Y / 2 + PLAYER_RADIUS
		and math.abs(lp.Z) <= s.Z / 2 + PLAYER_RADIUS then
			return true
		end
	end
	return false
end

-- ── Loop principal ────────────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
	local now = Workspace:GetServerTimeNow()

	-- 1) Rotar cada totem a su ángulo determinista, relativo a su aparición:
	--    al aparecer (now == spawnTime) el ángulo es 0, o sea su orientación base.
	for _, t in totems do
		local elapsed = now - t.spawnTime
		local angle = (elapsed * ROT_RAD_PER_SEC) % (math.pi * 2)
		-- Girar sobre el eje Y del mundo (vertical), fijando la posición del pivote
		-- y conservando la orientación base del modelo.
		t.model:PivotTo(
			CFrame.new(t.baseCF.Position)
			* CFrame.Angles(0, angle, 0)
			* t.baseCF.Rotation
		)
	end

	-- 2) Detectar contacto del jugador.
	if dead then return end
	local root = hrp
	local hum  = humanoid
	if not root or not hum or hum.Health <= 0 then return end

	local pos = root.Position
	for _, t in totems do
		if touchesTotem(t, pos) then
			dead = true
			Packets.WallHit:Fire()
			break
		end
	end
end)
