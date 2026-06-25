--!strict

-- Walls móviles de los Stages.
--
-- Cada modelo está taggeado WallR1..WallR4 / WallL1..WallL4. Se deslizan por
-- CFrame para "abrirse" (WallR por su eje derecho, WallL por su eje izquierdo),
-- se quedan abiertas un rato y se cierran, en secuencia: primero el par 1
-- (R1 y L1 a la vez), luego el par 2, etc.
--
-- El movimiento es local en cada cliente, pero la posición se calcula a partir
-- de un reloj absoluto sincronizado (Workspace:GetServerTimeNow(), la versión
-- de alta precisión de os.time()), así todos los jugadores ven exactamente lo
-- mismo sin replicar nada.
--
-- Si el jugador toca cualquier parte de una wall, se detecta por posición y se
-- avisa al servidor para que aplique la muerte (autoridad de servidor).

local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packets     = require(ReplicatedStorage.Shared.Packets)
local SpeedConfig = require(ReplicatedStorage.Shared.SpeedConfig)

local player = Players.LocalPlayer

-- ── Tunables ──────────────────────────────────────────────────────────────────
local SIDES            = { "R", "L" }
local WALL_COUNT       = 4
local OPEN_DISTANCE    = 60                     -- studs que la wall se desliza al abrir
local REFERENCE_LEVEL  = 10                     -- nivel para el que se calibra el timing
local OPEN_HOLD        = 2.5                    -- segundos que la wall queda totalmente abierta
local RESET_GAP        = 0                    -- pausa antes de reiniciar el ciclo
local PLAYER_RADIUS    = 2.5                    -- margen del cuerpo del jugador para la colisión
local FALLBACK_SPACING = 160 / WALL_COUNT       -- studs entre walls si falta alguna posición

-- Velocidad de un jugador nivel 10 (= 21.25 studs/s con la config actual).
-- De aquí salen tanto el escalonado entre walls como la velocidad de deslizamiento.
local REF_SPEED       = SpeedConfig.getWalkSpeedForLevel(REFERENCE_LEVEL)
local SLIDE_DURATION  = OPEN_DISTANCE / REF_SPEED

-- ── Estado ────────────────────────────────────────────────────────────────────
type Wall = {
	model:        Model,
	side:         string,
	index:        number,
	closedCFrame: CFrame,
	moveDir:      Vector3,
	parts:        { BasePart },
}

local walls: { [string]: Wall } = {}                 -- keyed por tag, ej. "WallR1"
local openTimes  = table.create(WALL_COUNT, 0)       -- offset de apertura por índice (1..4)
local cyclePeriod = 1                                  -- duración total del ciclo

-- ── Geometría / dirección ─────────────────────────────────────────────────────
local function collectParts(model: Model): { BasePart }
	local parts: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	return parts
end

-- ── Dirección de apertura ─────────────────────────────────────────────────────
-- Eje izquierda→derecha del mundo, derivado de la POSICIÓN real de los pares R/L
-- (no de su rotación, que puede ser arbitraria). El vector de una WallL a su WallR
-- apunta de izquierda a derecha; lo forzamos horizontal para que nunca suban/bajen.
local function getReferenceAxis(): Vector3
	local sum   = Vector3.zero
	local count = 0
	for i = 1, WALL_COUNT do
		local r = walls["WallR" .. i]
		local l = walls["WallL" .. i]
		if r and l then
			local d = r.closedCFrame.Position - l.closedCFrame.Position
			d = Vector3.new(d.X, 0, d.Z)   -- sin componente vertical
			if d.Magnitude > 1e-3 then
				sum += d.Unit
				count += 1
			end
		end
	end
	if count > 0 then
		return (sum / count).Unit
	end
	return Vector3.xAxis   -- fallback hasta que carguen ambos lados (se recalcula al registrar)
end

local function applyDirections()
	local refAxis = getReferenceAxis()
	for _, w in walls do
		w.moveDir = (w.side == "R") and refAxis or -refAxis
	end
end

-- ── Schedule ──────────────────────────────────────────────────────────────────
-- El par i abre cuando un runner nivel 10 que cruzó el par 1 llega al par i.
-- La distancia entre walls se mide de las posiciones reales (lado R como referencia).
local function recomputeSchedule()
	local cum = 0
	openTimes[1] = 0
	for i = 2, WALL_COUNT do
		local cur  = walls["WallR" .. i]
		local prev = walls["WallR" .. (i - 1)]
		local step = FALLBACK_SPACING
		if cur and prev then
			step = (cur.closedCFrame.Position - prev.closedCFrame.Position).Magnitude
		end
		cum += step
		openTimes[i] = cum / REF_SPEED
	end
	-- El ciclo dura hasta que la última wall abre, sostiene y cierra, más un respiro.
	cyclePeriod = openTimes[WALL_COUNT] + SLIDE_DURATION * 2 + OPEN_HOLD + RESET_GAP

	-- El eje de referencia depende de qué walls existen ahora mismo.
	applyDirections()
end

-- Fracción de apertura [0..1] de una wall según su offset, dentro del ciclo.
local function opennessAt(localTime: number, openTime: number): number
	local rel = localTime - openTime
	if rel < 0 then return 0 end                          -- aún cerrada
	if rel < SLIDE_DURATION then return rel / SLIDE_DURATION end  -- abriendo
	rel -= SLIDE_DURATION
	if rel < OPEN_HOLD then return 1 end                  -- abierta
	rel -= OPEN_HOLD
	if rel < SLIDE_DURATION then return 1 - rel / SLIDE_DURATION end -- cerrando
	return 0                                              -- cerrada de nuevo
end

-- ── Registro de walls (robusto ante StreamingEnabled) ─────────────────────────
-- Con streaming las partes de un modelo llegan en distinto orden, así que el
-- bounding box puede estar incompleto al cargar y model:GetPivot() devolvería una
-- pose cerrada equivocada (la wall "volvería" a un lugar distinto del original).
-- Anclamos al PrimaryPart (una sola parte, CFrame estable) y esperamos a que se
-- haya replicado antes de capturar la pose cerrada.
local function registerWall(model: Model, side: string, index: number, tag: string)
	task.spawn(function()
		-- Esperar a que el PrimaryPart exista (streaming puede traerlo después).
		local timeout = os.clock() + 10
		while not model.PrimaryPart and model.Parent ~= nil and os.clock() < timeout do
			task.wait()
		end
		if model.Parent == nil then return end  -- streameó fuera mientras esperábamos

		local anchor = model.PrimaryPart
		local closedCFrame: CFrame
		if anchor then
			closedCFrame = anchor.CFrame
		else
			warn(`[Walls] {model.Name} sin PrimaryPart; uso bounding box (puede descuadrarse con streaming). Asígnale un PrimaryPart o ModelStreamingMode = Atomic.`)
			closedCFrame = model:GetPivot()
		end

		-- Corrección de rotación en el eje X: WallR +90°, WallL +90°.
		local rotX = (side == "R") and 90 or 90
		closedCFrame = closedCFrame * CFrame.Angles(math.rad(rotX), 0, 0)

		walls[tag] = {
			model        = model,
			side         = side,
			index        = index,
			closedCFrame = closedCFrame,
			moveDir      = Vector3.zero,   -- recomputeSchedule() asigna la dirección real
			parts        = collectParts(model),
		}

		-- Partes que streameen después: sumarlas a la detección de colisión.
		model.DescendantAdded:Connect(function(d)
			local w = walls[tag]
			if w and w.model == model and d:IsA("BasePart") then
				table.insert(w.parts, d)
			end
		end)

		recomputeSchedule()
	end)
end

for _, side in SIDES do
	for i = 1, WALL_COUNT do
		local tag = "Wall" .. side .. i

		for _, inst in CollectionService:GetTagged(tag) do
			if inst:IsA("Model") then
				registerWall(inst :: Model, side, i, tag)
			end
		end

		CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst)
			if inst:IsA("Model") then
				registerWall(inst :: Model, side, i, tag)
			end
		end)

		CollectionService:GetInstanceRemovedSignal(tag):Connect(function(inst)
			local w = walls[tag]
			if w and w.model == inst then
				walls[tag] = nil
				recomputeSchedule()
			end
		end)
	end
end

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
local function touchesWall(w: Wall, pos: Vector3): boolean
	for _, part in w.parts do
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
	local localTime = Workspace:GetServerTimeNow() % cyclePeriod

	-- 1) Mover todas las walls a su posición determinista de este instante.
	for _, w in walls do
		local f = opennessAt(localTime, openTimes[w.index])
		w.model:PivotTo(w.closedCFrame + w.moveDir * (f * OPEN_DISTANCE))
	end

	-- 2) Detectar contacto del jugador con cualquier wall (ya en su posición actual).
	if dead then return end
	local root = hrp
	local hum  = humanoid
	if not root or not hum or hum.Health <= 0 then return end

	local pos = root.Position
	for _, w in walls do
		if touchesWall(w, pos) then
			dead = true
			Packets.WallHit:Fire()
			break
		end
	end
end)
