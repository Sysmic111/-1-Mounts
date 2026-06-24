--!strict

-- Hachas colgantes (péndulo) de los Stages.
--
-- Cada modelo está taggeado "Axe": es un hacha colgada de una cadena. Oscila como
-- péndulo tomando como pivote el PUNTO MÁS ALTO del modelo (el extremo superior de
-- la cadena) y rota sobre el eje X del mundo entre -150° y +150°.
--
-- El movimiento es local en cada cliente, pero el ángulo se calcula a partir de un
-- reloj absoluto sincronizado (Workspace:GetServerTimeNow()), así todos los
-- jugadores ven exactamente lo mismo sin replicar nada (igual que las Walls).
--
-- Si el jugador toca cualquier parte del hacha, se detecta por posición y se avisa
-- al servidor (Packets.WallHit) para que aplique la muerte (autoridad de servidor).

local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packets = require(ReplicatedStorage.Shared.Packets)

local player = Players.LocalPlayer

-- ── Tunables ──────────────────────────────────────────────────────────────────
local TAG           = "Axe"   -- tag de CollectionService de los modelos de hacha
local SWING_MAX     = 150     -- amplitud en grados: oscila de -150° a +150° sobre el eje X
local PERIOD        = 3       -- segundos de un vaivén completo (-150 → +150 → -150)
local PLAYER_RADIUS = 2.5     -- margen del cuerpo del jugador para la colisión
local PHASE_FREQ    = 0.15    -- desfase espacial por stud en X (0 = todas en sincronía)

-- ── Estado ────────────────────────────────────────────────────────────────────
type Axe = {
	model:      Model,
	restPivot:  CFrame,   -- pose de reposo (ángulo 0) capturada al registrar
	pivotPoint: CFrame,   -- punto de giro: tope del modelo, alineado al mundo
	phase:      number,   -- desfase del péndulo (deriva de la posición en X)
	parts:      { BasePart },
}

local axes: { [Model]: Axe } = {}

-- ── Geometría ───────────────────────────────────────────────────────────────────
local function collectParts(model: Model): { BasePart }
	local parts: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	return parts
end

-- ── Registro de hachas (robusto ante StreamingEnabled) ─────────────────────────
-- Con streaming las partes llegan en distinto orden, así que esperamos al
-- PrimaryPart antes de capturar la pose de reposo y calcular el bounding box.
local function registerAxe(model: Model)
	task.spawn(function()
		-- Esperar a que el PrimaryPart exista (streaming puede traerlo después).
		local timeout = os.clock() + 10
		while not model.PrimaryPart and model.Parent ~= nil and os.clock() < timeout do
			task.wait()
		end
		if model.Parent == nil then return end  -- streameó fuera mientras esperábamos

		local parts = collectParts(model)

		-- Anclar las partes: el movimiento es por PivotTo, no por física. Evita que
		-- el hacha caiga o tiemble al rotar cada frame.
		for _, part in parts do
			part.Anchored = true
		end

		-- Pose de reposo (ángulo 0) y punto de giro = tope del bounding box.
		local restPivot   = model:GetPivot()
		local cf, size    = model:GetBoundingBox()
		local topCenter   = Vector3.new(cf.Position.X, cf.Position.Y + size.Y / 2, cf.Position.Z)
		local pivotPoint  = CFrame.new(topCenter)   -- alineado al mundo → giro limpio sobre eje X

		axes[model] = {
			model      = model,
			restPivot  = restPivot,
			pivotPoint = pivotPoint,
			phase      = topCenter.X * PHASE_FREQ,
			parts      = parts,
		}

		-- Partes que streameen después: anclarlas y sumarlas a la colisión.
		model.DescendantAdded:Connect(function(d)
			local a = axes[model]
			if a and d:IsA("BasePart") then
				d.Anchored = true
				table.insert(a.parts, d)
			end
		end)
	end)
end

for _, inst in CollectionService:GetTagged(TAG) do
	if inst:IsA("Model") then
		registerAxe(inst :: Model)
	end
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(function(inst)
	if inst:IsA("Model") then
		registerAxe(inst :: Model)
	end
end)

CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(inst)
	if inst:IsA("Model") then
		axes[inst :: Model] = nil
	end
end)

-- ── Personaje local ───────────────────────────────────────────────────────────
local hrp:      BasePart? = nil
local humanoid: Humanoid? = nil
local dead = false

local function onCharacterAdded(character: Model)
	dead = false
	hrp = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	humanoid = character:FindFirstChildOfClass("Humanoid")
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end

-- ── Colisión por posición ─────────────────────────────────────────────────────
local function touchesAxe(a: Axe, pos: Vector3): boolean
	for _, part in a.parts do
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

	-- 1) Rotar cada hacha a su ángulo determinista de este instante.
	--    Péndulo: el seno hace que oscile de -SWING_MAX a +SWING_MAX y se frene
	--    suavemente en los extremos. Gira sobre el eje X del mundo a través del tope.
	for _, a in axes do
		local angle = math.rad(SWING_MAX) * math.sin((now / PERIOD) * (2 * math.pi) + a.phase)
		local rot   = a.pivotPoint * CFrame.Angles(angle, 0, 0) * a.pivotPoint:Inverse()
		a.model:PivotTo(rot * a.restPivot)
	end

	-- 2) Detectar contacto del jugador con cualquier hacha (ya en su pose actual).
	if dead then return end
	local root = hrp
	local hum  = humanoid
	if not root or not hum or hum.Health <= 0 then return end

	local pos = root.Position
	for _, a in axes do
		if touchesAxe(a, pos) then
			dead = true
			Packets.WallHit:Fire()
			break
		end
	end
end)
