--!strict

-- Lava ascendente de los Stages.
--
-- Cada instancia taggeada "LavaRise" crece en su eje Y desde su tamaño base
-- (≈50) hasta 200 y luego baja de golpe, en un ciclo continuo.
--   • Solo crece HACIA ARRIBA: la base (cara inferior) queda fija y solo sube
--     la cara superior, ajustando la posición para compensar el cambio de Size.
--   • La velocidad de subida está calibrada al WalkSpeed de nivel 90: un jugador
--     de ese nivel puede mantenerse por delante de la lava; uno más lento no.
--   • Espera WAIT_TIME en su tamaño base antes de empezar a crecer.
--   • La bajada es a la MISMA velocidad que la subida.
-- La fase se deriva de GetServerTimeNow() para que todos los clientes estén
-- sincronizados sin replicar nada.
--
-- Nota: se asume que la parte está alineada al mundo (sin rotación), como es
-- habitual para un bloque de lava. La muerte la sigue aplicando el tag "Lava".

local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpeedConfig = require(ReplicatedStorage.Shared.SpeedConfig)

-- ── Tunables ──────────────────────────────────────────────────────────────────
local REFERENCE_LEVEL = 90
local MAX_SIZE_Y      = 200                                          -- altura máxima
local RISE_SPEED      = SpeedConfig.getWalkSpeedForLevel(REFERENCE_LEVEL) /2 -- studs/s
local WAIT_TIME       = 1.5                                          -- s de espera antes de crecer

-- ── Estado ────────────────────────────────────────────────────────────────────
type Lava = {
	part:      BasePart,
	baseSize:  Vector3,  -- tamaño original (X y Z se mantienen)
	basePos:   Vector3,  -- posición original (X y Z se mantienen)
	bottomY:   number,   -- Y mundial de la cara inferior (fija)
	growthY:   number,   -- cuánto crece en Y (MAX_SIZE_Y - baseSize.Y)
	moveTime:  number,   -- s en subir (o bajar) de base a máximo
	period:    number,   -- s del ciclo completo (espera + subida + bajada)
}

local lavas: { [BasePart]: Lava } = {}

-- ── Resolución de la parte ──────────────────────────────────────────────────────
-- El tag puede estar en la BasePart directamente o en un Model (usamos su
-- PrimaryPart, o la primera BasePart que encontremos).
local function resolvePart(inst: Instance): BasePart?
	if inst:IsA("BasePart") then
		return inst
	elseif inst:IsA("Model") then
		if inst.PrimaryPart then
			return inst.PrimaryPart
		end
		for _, d in inst:GetDescendants() do
			if d:IsA("BasePart") then
				return d :: BasePart
			end
		end
	end
	return nil
end

-- ── Registro ──────────────────────────────────────────────────────────────────
local function registerLava(inst: Instance)
	task.spawn(function()
		-- Para Models, esperar a que haya una parte utilizable.
		local deadline = os.clock() + 10
		local part = resolvePart(inst)
		while not part and inst.Parent ~= nil and os.clock() < deadline do
			task.wait()
			part = resolvePart(inst)
		end
		if not part or inst.Parent == nil then return end

		part.Anchored = true

		local baseSize = part.Size
		local basePos  = part.Position
		local growthY  = MAX_SIZE_Y - baseSize.Y
		if growthY <= 0 then
			warn(`[LavaRise] {inst:GetFullName()}: el tamaño base en Y ya es >= {MAX_SIZE_Y}`)
			return
		end

		local moveTime = growthY / RISE_SPEED
		lavas[part] = {
			part     = part,
			baseSize = baseSize,
			basePos  = basePos,
			bottomY  = basePos.Y - baseSize.Y / 2,
			growthY  = growthY,
			moveTime = moveTime,
			period   = WAIT_TIME + moveTime * 2,
		}
	end)
end

local function unregisterLava(inst: Instance)
	local part = resolvePart(inst)
	if part then
		lavas[part] = nil
	end
end

for _, inst in CollectionService:GetTagged("LavaRise") do
	registerLava(inst)
end

CollectionService:GetInstanceAddedSignal("LavaRise"):Connect(registerLava)
CollectionService:GetInstanceRemovedSignal("LavaRise"):Connect(unregisterLava)

-- ── Loop principal ────────────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
	-- % 3600 reduce la magnitud del timestamp para evitar pérdida de precisión.
	local now = Workspace:GetServerTimeNow() % 3600

	for _, l in lavas do
		local t = now % l.period

		local sizeY: number
		if t < WAIT_TIME then
			-- Espera en el tamaño base antes de empezar a crecer.
			sizeY = l.baseSize.Y
		elseif t < WAIT_TIME + l.moveTime then
			-- Subida lineal a RISE_SPEED studs/s.
			local f = (t - WAIT_TIME) / l.moveTime
			sizeY = l.baseSize.Y + f * l.growthY
		else
			-- Bajada a la misma velocidad que la subida.
			local f = (t - WAIT_TIME - l.moveTime) / l.moveTime
			sizeY = l.baseSize.Y + l.growthY * (1 - f)
		end

		-- Solo crece hacia arriba: base fija, centro = bottomY + sizeY/2.
		l.part.Size     = Vector3.new(l.baseSize.X, sizeY, l.baseSize.Z)
		l.part.Position = Vector3.new(l.basePos.X, l.bottomY + sizeY / 2, l.basePos.Z)
	end
end)
