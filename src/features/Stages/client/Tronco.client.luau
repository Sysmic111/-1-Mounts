--!strict

-- Troncos rodantes de los Stages.
--
-- Cada modelo taggeado "Tronco" tiene en su padre dos BaseParts hermanas:
--   PuntoA → posición de inicio, PuntoB → posición de fin.
-- El tronco hace ping-pong A→B→A a la velocidad de un jugador nivel 60.
-- La rotación respeta la orientación base del PrimaryPart y aplica el giro
-- sobre el eje X LOCAL del modelo (independiente del eje X del mundo).

local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpeedConfig = require(ReplicatedStorage.Shared.SpeedConfig)

-- ── Tunables ──────────────────────────────────────────────────────────────────
local REFERENCE_LEVEL = 60
local MOVE_SPEED      = SpeedConfig.getWalkSpeedForLevel(REFERENCE_LEVEL)  -- studs/s
local ROLL_RPS        = 1.5  -- rotaciones por segundo

-- ── Estado ────────────────────────────────────────────────────────────────────
type Tronco = {
	model:      Model,
	posA:       Vector3,
	posB:       Vector3,
	distance:   number,
	period:     number,  -- tiempo de A→B en segundos (= dist / MOVE_SPEED)
	baseOrient: CFrame,  -- rotación base del PrimaryPart (sin posición)
}

local troncos: { [Model]: Tronco } = {}

-- ── Registro ──────────────────────────────────────────────────────────────────
local function registerTronco(inst: Instance)
	if not inst:IsA("Model") then return end
	local model  = inst :: Model
	local parent = model.Parent
	if not parent then return end

	task.spawn(function()
		local deadline = os.clock() + 10
		while not model.PrimaryPart and model.Parent ~= nil and os.clock() < deadline do
			task.wait()
		end
		if model.Parent == nil then return end
		if not model.PrimaryPart then
			warn(`[Tronco] {model:GetFullName()}: sin PrimaryPart asignado`)
			return
		end

		local rawA = parent:WaitForChild("PuntoA", 15)
		local rawB = parent:WaitForChild("PuntoB", 15)
		if not rawA or not rawB or not rawA:IsA("BasePart") or not rawB:IsA("BasePart") then
			warn(`[Tronco] {model:GetFullName()}: falta PuntoA o PuntoB (BasePart) en "{parent.Name}"`)
			return
		end

		local posA = (rawA :: BasePart).Position
		local posB = (rawB :: BasePart).Position
		local dist = (posB - posA).Magnitude
		if dist < 0.01 then
			warn(`[Tronco] {model:GetFullName()}: PuntoA y PuntoB están en el mismo lugar`)
			return
		end

		-- Capturar la orientación inicial del PrimaryPart como CFrame sin posición.
		-- Así CFrame.new(pos) * baseOrient * CFrame.Angles(angle,0,0) aplica el roll
		-- sobre el eje X LOCAL del modelo (no el X del mundo).
		local pp      = model.PrimaryPart :: BasePart
		local initCF  = pp.CFrame
		local baseOrient = CFrame.fromMatrix(
			Vector3.zero,
			initCF.RightVector,
			initCF.UpVector,
			-initCF.LookVector
		)

		troncos[model] = {
			model      = model,
			posA       = posA,
			posB       = posB,
			distance   = dist,
			period     = dist / MOVE_SPEED,
			baseOrient = baseOrient,
		}
	end)
end

for _, inst in CollectionService:GetTagged("Tronco") do
	registerTronco(inst)
end

CollectionService:GetInstanceAddedSignal("Tronco"):Connect(registerTronco)
CollectionService:GetInstanceRemovedSignal("Tronco"):Connect(function(inst)
	if inst:IsA("Model") then
		troncos[inst :: Model] = nil
	end
end)

-- ── Loop principal ────────────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
	-- % 3600 reduce la magnitud del timestamp para evitar pérdida de precisión
	-- float64 al operar módulo con períodos pequeños.
	local now = Workspace:GetServerTimeNow() % 3600

	for _, t in troncos do
		-- Posición: A→B en línea recta, teleport a A al llegar.
		local frac = (now % t.period) / t.period
		local pos  = t.posA:Lerp(t.posB, frac)

		-- Rotación: eje X LOCAL del modelo (baseOrient lo gira al espacio correcto).
		local angle = (now % (1 / ROLL_RPS)) * (ROLL_RPS * math.pi * 2)

		t.model:PivotTo(CFrame.new(pos) * t.baseOrient * CFrame.Angles(angle, 0, 0))
	end
end)
