--!strict

-- Cubos de hielo: emisores que sueltan clones en línea recta.
--
-- Una BasePart taggeada es un EMISOR, no un cubo: se queda quieta donde esté y cada
-- `Interval` segundos suelta un clon que recorre `Distance` studs en su dirección y
-- se destruye al llegar. El emisor no se toca (ni se oculta ni se mueve): si no
-- quieres verlo, ponlo transparente y sin colisión en Studio.
--
-- Dos variantes, misma maquinaria:
--   IceCube   -> avanza en -Z del MUNDO, a la velocidad de un jugador del nivel de
--                diseño (World 2 = 150 -> 121.8 studs/s).
--   IceCube2  -> sube en +Y del MUNDO, a 10 studs/s fijos.
--
-- Las direcciones son ejes del MUNDO, no del emisor: girar la part en Studio cambia
-- cómo se ve el cubo, nunca hacia dónde va. Es lo predecible cuando el pasillo está
-- alineado con los ejes, que es el caso. Si algún día hace falta un pasillo torcido,
-- la línea a tocar es el `direction` de VARIANTS (usar `part.CFrame.LookVector`).
--
-- Van en el cliente como el resto de obstáculos: se mueven suave y no gastan réplica.
--
-- LETALIDAD: los clones llevan el tag "Lava", pero ese tag NO es lo que mata aquí.
-- `LavaService` es de servidor y conecta `Touched` sobre instancias del servidor; un
-- clon creado en el cliente no existe para él, así que su señal nunca se conectaría.
-- La muerte se resuelve como en Walls, Laser, Totem y Axes: se detecta el contacto
-- por POSICIÓN en el cliente y se avisa con `Packets.WallHit`, que es quien tiene la
-- autoridad para aplicarla. El tag se mantiene porque describe lo que la part ES y
-- porque cualquier lógica futura que barra "Lava" en el cliente los encontrará.

local CollectionService = game:GetService("CollectionService")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpeedConfig     = require(ReplicatedStorage.Shared.SpeedConfig)
local ObstaclesConfig = require(ReplicatedStorage.Shared.ObstaclesConfig)
local Packets         = require(ReplicatedStorage.Shared.Packets)

local player = Players.LocalPlayer

-- Margen del cuerpo del jugador para la colisión. El mismo 2.5 que Walls, Laser,
-- Totem y Axes: si aquí fuera distinto, el mismo roce mataría en un obstáculo y no
-- en otro.
local PLAYER_RADIUS = 2.5

-- ── Variantes ─────────────────────────────────────────────────────────────────
local VARIANTS = {
	{ tag = "IceCube",  direction = Vector3.new(0, 0, -1) },
	{ tag = "IceCube2", direction = Vector3.new(0, 1,  0) },
}

type Variant = {
	tag:       string,
	direction: Vector3,
	speed:     number,
	interval:  number,
	distance:  number,
	lifetime:  number,
}

-- Carpeta propia para los clones: así no ensucian el Workspace ni aparecen en los
-- escaneos por nombre de otros features (Stages, Steps, WinButtons...).
local cubesFolder = Instance.new("Folder")
cubesFolder.Name   = "IceCubes"
cubesFolder.Parent = Workspace

-- ── Estado ────────────────────────────────────────────────────────────────────
type Emitter = {
	part:     BasePart,
	origin:   CFrame,
	variant:  Variant,
	lastSlot: number,  -- último índice de tiempo en el que ya se emitió
}

type Cube = {
	part:      BasePart,
	origin:    CFrame,
	variant:   Variant,
	spawnedAt: number,
}

local emitters: { [BasePart]: Emitter } = {}
local cubes: { Cube } = {}

-- Reloj compartido: todos los clientes emiten en el MISMO instante, así dos
-- jugadores en el mismo pasillo ven los cubos en la misma posición. Con un
-- temporizador local cada uno vería una fase distinta.
local function now(): number
	return Workspace:GetServerTimeNow()
end

-- ── Emisión ───────────────────────────────────────────────────────────────────
local function spawnCube(emitter: Emitter, at: number)
	local clone = emitter.part:Clone()

	-- CRÍTICO: Clone() copia los tags de CollectionService. Sin quitarlo, cada cubo
	-- se registraría como emisor nuevo y empezaría a soltar cubos él mismo — un
	-- crecimiento exponencial que tumba el cliente en segundos.
	CollectionService:RemoveTag(clone, emitter.variant.tag)

	-- El cubo es lava. Ver la nota de LETALIDAD arriba: quien mata es la detección
	-- por posición de este mismo script, no LavaService.
	CollectionService:AddTag(clone, "Lava")

	-- Anclado: la posición la lleva el bucle por CFrame. Sin anclar, la física lo
	-- haría caer y pelearía con cada asignación.
	clone.Anchored = true
	clone.Name     = emitter.variant.tag
	clone.CFrame   = emitter.origin
	clone.Parent   = cubesFolder

	table.insert(cubes, {
		part      = clone,
		origin    = emitter.origin,
		variant   = emitter.variant,
		spawnedAt = at,
	})
end

-- ── Registro ──────────────────────────────────────────────────────────────────
local function setupVariant(spec: { tag: string, direction: Vector3 })
	local config = ObstaclesConfig.get(spec.tag)

	-- `Speed` manda sobre el nivel: un obstáculo que no debe seguir el ritmo del
	-- jugador (IceCube2, que sube siempre igual) lo declara y su `Level` se queda
	-- solo como documentación de dónde encaja en el juego.
	local speed    = config.Speed or SpeedConfig.getWalkSpeedForLevel(config.Level)
	local interval = config.Interval or 4
	local distance = config.Distance or 1800

	local variant: Variant = {
		tag       = spec.tag,
		direction = spec.direction,
		speed     = speed,
		interval  = interval,
		distance  = distance,
		lifetime  = distance / speed,
	}

	local function register(inst: Instance)
		if not inst:IsA("BasePart") then
			warn(`[{spec.tag}] {inst:GetFullName()}: el tag va en una BasePart, no en un {inst.ClassName}`)
			return
		end

		local part = inst :: BasePart
		emitters[part] = {
			part     = part,
			origin   = part.CFrame,
			variant  = variant,
			-- Arranca en el slot actual: el primer cubo sale al siguiente múltiplo de
			-- `interval`, no de golpe al entrar al stage.
			lastSlot = math.floor(now() / interval),
		}
	end

	for _, inst in CollectionService:GetTagged(spec.tag) do
		register(inst)
	end

	CollectionService:GetInstanceAddedSignal(spec.tag):Connect(register)
	CollectionService:GetInstanceRemovedSignal(spec.tag):Connect(function(inst)
		if inst:IsA("BasePart") then
			emitters[inst :: BasePart] = nil
		end
	end)
end

for _, spec in VARIANTS do
	setupVariant(spec)
end

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
local function touchesCube(cube: Cube, pos: Vector3): boolean
	local part = cube.part
	local lp   = part.CFrame:PointToObjectSpace(pos)
	local s    = part.Size
	return math.abs(lp.X) <= s.X / 2 + PLAYER_RADIUS
		and math.abs(lp.Y) <= s.Y / 2 + PLAYER_RADIUS
		and math.abs(lp.Z) <= s.Z / 2 + PLAYER_RADIUS
end

-- ── Loop principal ────────────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
	local t = now()

	-- Emitir: se compara el "slot" de tiempo actual contra el último emitido, en vez
	-- de acumular dt. Así un frame largo (carga de stage, lag) no se salta un cubo ni
	-- suelta dos pegados.
	for _, emitter in emitters do
		local interval = emitter.variant.interval
		local slot     = math.floor(t / interval)
		if slot > emitter.lastSlot then
			emitter.lastSlot = slot
			spawnCube(emitter, slot * interval)
		end
	end

	-- Mover y retirar. Se recorre hacia atrás para poder quitar del array sobre la
	-- marcha sin saltarse elementos.
	for i = #cubes, 1, -1 do
		local cube = cubes[i]
		local age  = t - cube.spawnedAt

		if age >= cube.variant.lifetime or cube.part.Parent == nil then
			cube.part:Destroy()
			table.remove(cubes, i)
			continue
		end

		-- Posición absoluta desde el instante de emisión, no un `+= speed * dt`: así
		-- no acumula deriva y dos clientes con distinto framerate ven el cubo en el
		-- mismo sitio.
		cube.part.CFrame = cube.origin + cube.variant.direction * (age * cube.variant.speed)
	end

	-- Detectar contacto con el jugador, DESPUÉS de haberlos movido: se mide contra la
	-- posición de este frame, no la del anterior. Mismo criterio que Walls y Totem.
	if dead then return end
	local root = hrp
	local hum  = humanoid
	if not root or not hum or hum.Health <= 0 then return end

	local pos = root.Position
	for _, cube in cubes do
		if touchesCube(cube, pos) then
			dead = true
			Packets.WallHit:Fire()
			break
		end
	end
end)
