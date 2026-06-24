--!strict

-- Lava: vuelve mortal cualquier instancia taggeada "Lava".
--
-- A diferencia de las Walls (que se mueven localmente vía CFrame y por eso detectan
-- la colisión en el cliente por posición), la lava es estática, así que disparar
-- Touched en el servidor es fiable y autoritativo (kill brick clásico): el servidor
-- aplica la muerte directamente, sin pasar por ningún packet.
--
-- Reglas pedidas:
--   • Si el tag está en una BasePart  → mata a quien toque esa parte.
--   • Si el tag está en un Model      → mata a quien toque CUALQUIER parte del modelo.

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local TAG = "Lava"

local LavaService = {}

-- Conexiones vivas por instancia taggeada, para poder soltarlas si pierde el tag.
local connections: { [Instance]: { RBXScriptConnection } } = {}

-- ── Muerte ──────────────────────────────────────────────────────────────────────
local function killFromHit(hit: BasePart)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then return end
	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = 0
	end
end

-- ── Registro ──────────────────────────────────────────────────────────────────
local function watchPart(inst: Instance, part: BasePart)
	local list = connections[inst]
	if not list then return end
	table.insert(list, part.Touched:Connect(killFromHit))
end

local function registerLava(inst: Instance)
	if connections[inst] then return end
	connections[inst] = {}

	if inst:IsA("BasePart") then
		-- El tag está en la parte misma.
		watchPart(inst, inst)
	elseif inst:IsA("Model") then
		-- El tag está en el modelo: vigilar todas sus BaseParts (presentes y futuras).
		for _, d in inst:GetDescendants() do
			if d:IsA("BasePart") then
				watchPart(inst, d)
			end
		end
		table.insert(connections[inst], inst.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") then
				watchPart(inst, d)
			end
		end))
	end
end

local function unregisterLava(inst: Instance)
	local list = connections[inst]
	if not list then return end
	for _, conn in list do
		conn:Disconnect()
	end
	connections[inst] = nil
end

function LavaService:init(): ()
	for _, inst in CollectionService:GetTagged(TAG) do
		registerLava(inst)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(registerLava)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(unregisterLava)
end

return LavaService
