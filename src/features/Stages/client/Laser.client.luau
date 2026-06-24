--!strict

-- Láseres barredores del Stage 5.
--
-- Cada modelo está taggeado "Laser". Parte de su posición actual y avanza en +X
-- 150 studs a la velocidad de caminata de un jugador nivel 50: así, para "pasar"
-- (dejar atrás el láser antes de que recorra los 150) hay que ser nivel >50; por
-- debajo, el láser te alcanza. Al completar los 150 studs reinicia al instante
-- desde el origen (ciclo continuo).
--
-- Hay dos modelos con el mismo tag, superpuestos en el origen. Se lanzan
-- escalonados: cuando uno llega al centro (75 studs) el otro arranca, o sea con
-- medio ciclo de desfase (en general, repartidos uniformemente en el ciclo).
--
-- El movimiento es local en cada cliente pero determinista a partir de un reloj
-- absoluto sincronizado (Workspace:GetServerTimeNow()), así todos ven lo mismo sin
-- replicar nada (igual que las Walls).
--
-- Solo la parte "Death" (el plano invisible del rayo) mata: si el jugador la toca
-- se detecta por posición y se avisa al servidor (Packets.WallHit) para que aplique
-- la muerte (autoridad de servidor).

local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packets     = require(ReplicatedStorage.Shared.Packets)
local SpeedConfig = require(ReplicatedStorage.Shared.SpeedConfig)

local player = Players.LocalPlayer

-- ── Tunables ──────────────────────────────────────────────────────────────────
local TAG            = "Laser"
local DISTANCE       = 150                 -- studs que avanza el láser en +X
local REQUIRED_LEVEL = 50                  -- nivel necesario para alcanzar a pasarlo
local MOVE_DIR       = Vector3.xAxis       -- +X del mundo
local PLAYER_RADIUS  = 2.5                 -- margen del cuerpo del jugador para la colisión

-- Velocidad = caminata de un jugador nivel 50; recorrer DISTANCE tarda TRAVEL_TIME.
local LASER_SPEED  = SpeedConfig.getWalkSpeedForLevel(REQUIRED_LEVEL)
local TRAVEL_TIME  = DISTANCE / LASER_SPEED

-- ── Estado ────────────────────────────────────────────────────────────────────
type Laser = {
	model:      Model,
	startPivot: CFrame,      -- pose en el origen, capturada al registrar
	deaths:     { BasePart },-- partes letales ("Death")
}

local lasers: { Laser } = {}

-- ── Geometría ───────────────────────────────────────────────────────────────────
local function collectDeaths(model: Model): { BasePart }
	local parts: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Death" then
			table.insert(parts, d)
		end
	end
	return parts
end

-- ── Registro de láseres (robusto ante StreamingEnabled) ────────────────────────
local function registerLaser(model: Model)
	task.spawn(function()
		-- Esperar a que exista al menos una parte "Death" (streaming puede traerla
		-- después). El WorldPivot del modelo es estable aunque falten partes.
		local timeout = os.clock() + 10
		while #collectDeaths(model) == 0 and model.Parent ~= nil and os.clock() < timeout do
			task.wait()
		end
		if model.Parent == nil then return end  -- streameó fuera mientras esperábamos

		-- Anclar todas las partes: el movimiento es por PivotTo, no por física.
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end

		local entry: Laser = {
			model      = model,
			startPivot = model:GetPivot(),
			deaths     = collectDeaths(model),
		}
		table.insert(lasers, entry)

		-- Partes "Death" que streameen después: sumarlas y anclarlas.
		model.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") then
				d.Anchored = true
				if d.Name == "Death" then
					table.insert(entry.deaths, d :: BasePart)
				end
			end
		end)
	end)
end

for _, inst in CollectionService:GetTagged(TAG) do
	if inst:IsA("Model") then
		registerLaser(inst :: Model)
	end
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(function(inst)
	if inst:IsA("Model") then
		registerLaser(inst :: Model)
	end
end)

CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(inst)
	for i, l in lasers do
		if l.model == inst then
			table.remove(lasers, i)
			break
		end
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

-- ── Colisión por posición (solo partes "Death") ───────────────────────────────
local function touchesLaser(l: Laser, pos: Vector3): boolean
	for _, part in l.deaths do
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
	local now   = Workspace:GetServerTimeNow()
	local count = #lasers

	-- 1) Mover cada láser a su posición determinista de este instante.
	--    Desfase uniforme por índice: con 2 láseres, medio ciclo (cuando uno está
	--    en el origen el otro está en el centro y viceversa).
	for i, l in lasers do
		local f = ((now / TRAVEL_TIME) + ((i - 1) / count)) % 1
		l.model:PivotTo(l.startPivot + MOVE_DIR * (f * DISTANCE))
	end

	-- 2) Detectar contacto del jugador con la parte letal de cualquier láser.
	if dead then return end
	local root = hrp
	local hum  = humanoid
	if not root or not hum or hum.Health <= 0 then return end

	local pos = root.Position
	for _, l in lasers do
		if touchesLaser(l, pos) then
			dead = true
			Packets.WallHit:Fire()
			break
		end
	end
end)
