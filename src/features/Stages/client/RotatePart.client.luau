--!strict

-- Partes giratorias de los Stages (rotación continua sobre el eje X propio).
--
-- Tag "RotatePart" en un Model. Gira sobre su eje X LOCAL de forma continua.
-- El sentido se controla con el atributo booleano "Reverse":
--   · Reverse = false (o ausente) → sentido positivo
--   · Reverse = true              → sentido contrario
--
-- El ángulo se calcula a partir de GetServerTimeNow() (igual que LavaRise y Axes)
-- para que todos los clientes estén sincronizados sin replicar nada.
-- Se usa % 3600 para reducir la magnitud del timestamp y evitar pérdida de precisión.
--
-- NO mata al jugador: es puramente decorativo/obstáculo visual.

local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

-- ── Tunables ──────────────────────────────────────────────────────────────────
local TAG            = "RotatePart"
local ROTATION_SPEED = math.rad(90)  -- rad/s  (90°/s = 1 vuelta cada 4 segundos)

-- ── Estado ────────────────────────────────────────────────────────────────────
type Rotor = {
	model:     Model,
	restPivot: CFrame,  -- pose capturada al registrar; su eje X local define el eje de rotación
	direction: number,  -- +1 normal, -1 si el atributo Reverse está activo
}

local rotors: { [Model]: Rotor } = {}

-- ── Geometría ─────────────────────────────────────────────────────────────────
-- model:GetPivot() devuelve PrimaryPart.CFrame cuando hay PrimaryPart (rotación correcta).
-- Sin PrimaryPart devuelve rotación identidad, lo que haría girar el modelo sobre el eje X
-- del MUNDO en vez de su propio eje X. Para evitarlo, tomamos la rotación de cualquier
-- BasePart hija y la combinamos con la posición del bounding box.
local function getRestPivot(model: Model): CFrame
	if model.PrimaryPart then
		return model:GetPivot()
	end
	local centerPos = model:GetPivot().Position
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local cf = (d :: BasePart).CFrame
			return CFrame.fromMatrix(centerPos, cf.XVector, cf.YVector, cf.ZVector)
		end
	end
	warn(`[RotatePart] {model.Name}: sin partes, usando eje X del mundo como fallback`)
	return CFrame.new(centerPos)
end

local function directionFromAttr(model: Model): number
	return if model:GetAttribute("Reverse") == true then -1 else 1
end

-- ── Registro ──────────────────────────────────────────────────────────────────
local function registerRotor(model: Model)
	task.spawn(function()
		-- Esperar PrimaryPart para obtener la rotación correcta del modelo.
		-- Sin PrimaryPart, getRestPivot() usará la primera BasePart que encuentre.
		local timeout = os.clock() + 10
		while not model.PrimaryPart and model.Parent ~= nil and os.clock() < timeout do
			task.wait()
		end
		if model.Parent == nil then return end

		-- Anclar partes: el movimiento es por PivotTo, no por física.
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end

		-- Un frame de margen para que los CFrames del servidor se repliquen antes de
		-- capturar restPivot (sin esto podría quedar en la pose por defecto del modelo).
		task.wait()
		if model.Parent == nil then return end

		rotors[model] = {
			model     = model,
			restPivot = getRestPivot(model),
			direction = directionFromAttr(model),
		}

		-- Permite cambiar el sentido en caliente desde Studio/servidor.
		model:GetAttributeChangedSignal("Reverse"):Connect(function()
			local r = rotors[model]
			if r then
				r.direction = directionFromAttr(model)
			end
		end)

		-- Anclar partes que lleguen después por streaming.
		model.DescendantAdded:Connect(function(d)
			if rotors[model] and d:IsA("BasePart") then
				d.Anchored = true
			end
		end)
	end)
end

for _, inst in CollectionService:GetTagged(TAG) do
	if inst:IsA("Model") then
		registerRotor(inst :: Model)
	end
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(function(inst)
	if inst:IsA("Model") then
		registerRotor(inst :: Model)
	end
end)

CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(inst)
	if inst:IsA("Model") then
		rotors[inst :: Model] = nil
	end
end)

-- ── Loop principal ────────────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
	-- % 3600 reduce la magnitud del timestamp para evitar pérdida de precisión.
	local now = Workspace:GetServerTimeNow() % 3600

	-- Rotar cada modelo a su ángulo determinista de este instante.
	-- restPivot * CFrame.Angles(angle, 0, 0) rota sobre el EJE X LOCAL de restPivot,
	-- que refleja la orientación real del modelo en Studio (no el eje X del mundo).
	for _, r in rotors do
		local angle = r.direction * ROTATION_SPEED * now
		r.model:PivotTo(r.restPivot * CFrame.Angles(angle, 0, 0))
	end
end)
