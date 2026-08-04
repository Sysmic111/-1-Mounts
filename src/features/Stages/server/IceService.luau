--!strict

-- Ice: vuelve resbaladiza cualquier instancia taggeada "Ice".
--
-- No hay bucle ni Touched: se hace bajando el ROZAMIENTO de la parte con
-- CustomPhysicalProperties. El motor de físicas ya sabe deslizar, así que el
-- efecto sale gratis y es autoritativo — las propiedades de la parte replican
-- solas del servidor al cliente, y el personaje (que simula el cliente por tener
-- la network ownership) las lee de ahí. No hace falta nada en el cliente.
--
-- Reglas, iguales que las de LavaService:
--   • Si el tag está en una BasePart  → resbala esa parte.
--   • Si el tag está en un Model      → resbalan TODAS sus partes.
--
-- ── Por qué FrictionWeight tan alto ─────────────────────────────────────────
-- Roblox no usa el rozamiento de una sola superficie: mezcla las dos que se
-- tocan, ponderadas por su FrictionWeight:
--
--     friction = (f_hielo × w_hielo + f_personaje × w_personaje) / (w_hielo + w_personaje)
--
-- Un personaje de plástico por defecto trae Friction 0.3 con FrictionWeight 1.
-- Con el hielo a 0.02 y peso 100 la mezcla queda en (2 + 0.3) / 101 ≈ 0.023: el
-- hielo manda. Bajando SOLO el Friction y dejando el peso a 1, la media saldría
-- ≈ 0.16 y apenas se notaría — el peso es lo que hace que esto funcione.
local CollectionService = game:GetService("CollectionService")

local TAG = "Ice"

-- Las dos palancas del "cuánto resbala". Menos Friction = más patinazo; el
-- FrictionWeight decide cuánto ignora el rozamiento del personaje.
local ICE_FRICTION        = 0.02
local ICE_FRICTION_WEIGHT = 100

local IceService = {}

-- PhysicalProperties original de cada parte tocada, para poder devolverla a su
-- estado si pierde el tag. El valor puede ser nil (la parte usaba las del
-- material), y ese nil también hay que recordarlo: por eso se guarda envuelto en
-- una tabla y no a pelo, o no se distinguiría de "no registrada".
type Saved = { properties: PhysicalProperties? }

local savedProperties: { [BasePart]: Saved } = {}
-- Conexiones vivas por instancia taggeada (solo los Model necesitan una).
local connections: { [Instance]: { RBXScriptConnection } } = {}
-- Qué partes aportó cada instancia taggeada, para restaurarlas al quitar el tag.
local ownedParts: { [Instance]: { BasePart } } = {}

local function makeSlippery(inst: Instance, part: BasePart)
	-- Ya registrada (p. ej. dos Model taggeados anidados): no se vuelve a guardar
	-- el original o se guardaría el hielo como si fuera el estado de partida.
	if savedProperties[part] then return end

	savedProperties[part] = { properties = part.CustomPhysicalProperties }

	-- Se conservan densidad y elasticidad de lo que ya tuviera (CurrentPhysicalProperties
	-- resuelve las del material cuando no hay custom): esto es un cambio de rozamiento,
	-- no de masa ni de rebote.
	local current = part.CurrentPhysicalProperties
	part.CustomPhysicalProperties = PhysicalProperties.new(
		current.Density,
		ICE_FRICTION,
		current.Elasticity,
		ICE_FRICTION_WEIGHT,
		current.ElasticityWeight
	)

	local list = ownedParts[inst]
	if list then
		table.insert(list, part)
	end
end

local function registerIce(inst: Instance)
	if ownedParts[inst] then return end
	ownedParts[inst] = {}
	connections[inst] = {}

	if inst:IsA("BasePart") then
		makeSlippery(inst, inst)
	elseif inst:IsA("Model") then
		for _, d in inst:GetDescendants() do
			if d:IsA("BasePart") then
				makeSlippery(inst, d)
			end
		end
		-- Partes que lleguen después (streaming, o piezas añadidas en runtime).
		table.insert(connections[inst], inst.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") then
				makeSlippery(inst, d)
			end
		end))
	end
end

local function unregisterIce(inst: Instance)
	local conns = connections[inst]
	if conns then
		for _, conn in conns do
			conn:Disconnect()
		end
		connections[inst] = nil
	end

	local parts = ownedParts[inst]
	if not parts then return end

	for _, part in parts do
		local saved = savedProperties[part]
		if saved and part.Parent then
			-- nil devuelve la parte a las propiedades de su material, que es justo lo
			-- que tenía si nunca se le puso un custom.
			part.CustomPhysicalProperties = saved.properties
		end
		savedProperties[part] = nil
	end

	ownedParts[inst] = nil
end

function IceService:init(): ()
	for _, inst in CollectionService:GetTagged(TAG) do
		registerIce(inst)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(registerIce)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(unregisterIce)
end

return IceService
