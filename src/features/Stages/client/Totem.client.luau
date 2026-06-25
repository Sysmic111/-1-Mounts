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

local SpeedConfig = require(ReplicatedStorage.Shared.SpeedConfig)
local Packets     = require(ReplicatedStorage.Shared.Packets)

local player = Players.LocalPlayer

-- ── Tunables ──────────────────────────────────────────────────────────────────
local REFERENCE_LEVEL    = 80
local ROT_DEG_PER_SEC    = SpeedConfig.getWalkSpeedForLevel(REFERENCE_LEVEL)  -- °/s
local ROT_RAD_PER_SEC    = ROT_DEG_PER_SEC * math.pi / 180
local PLAYER_RADIUS      = 2.5

-- ── Estado ────────────────────────────────────────────────────────────────────
type Totem = {
	model:      Model,
	baseOrient: CFrame,       -- rotación base del PrimaryPart (sin posición)
	pivot:      Vector3,      -- posición fija del pivote
	parts:      { BasePart },
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

		-- Con PrimaryPart: usar su CFrame como referencia de orientación y pivote.
		-- Sin PrimaryPart: GetPivot() devuelve el centro del bounding box (orientación
		-- alineada al mundo), lo que hace que la rotación sea en el Y global — correcto
		-- para un totem sin orientación especial.
		local initCF: CFrame = if model.PrimaryPart
			then (model.PrimaryPart :: BasePart).CFrame
			else model:GetPivot()

		local baseOrient = CFrame.fromMatrix(
			Vector3.zero,
			initCF.RightVector,
			initCF.UpVector,
			-initCF.LookVector
		)

		local parts = collectParts(model)
		for _, part in parts do
			part.Anchored = true
		end

		totems[model] = {
			model      = model,
			baseOrient = baseOrient,
			pivot      = initCF.Position,
			parts      = parts,
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
	local now = Workspace:GetServerTimeNow() % 3600

	-- 1) Rotar cada totem a su ángulo determinista.
	for _, t in totems do
		local angle = (now * ROT_RAD_PER_SEC) % (math.pi * 2)
		t.model:PivotTo(CFrame.new(t.pivot) * t.baseOrient * CFrame.Angles(0, angle, 0))
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
