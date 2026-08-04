--!strict

-- Carreras 1v1 contra el NPC de un stage. AUTORITATIVO EN EL SERVIDOR: el NPC, la
-- cuenta atrás y la detección de meta viven aquí. El cliente solo pinta el menú, los
-- números y el resultado que le llega por packet.
--
-- Geometría que espera dentro de un `Workspace.Stages.Stage N` (hoy solo el Stage 2,
-- pero cualquier stage que la reciba entra solo, sin tocar código):
--   Npc                → rig del NPC con el ProximityPrompt
--   Race.Player        → marcador de salida del jugador
--   Race.Npc           → marcador de salida del NPC
--   Race.Goal          → meta
-- (Race tiene además seis hijos llamados "Baseplate" — el suelo y las paredes de la
--  pista. Solo se buscan los tres de arriba, que sí son únicos.)
--
-- Una pista solo admite un corredor a la vez: el NPC es un objeto físico compartido,
-- no una copia por jugador. Los demás ven la carrera.

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace         = game:GetService("Workspace")

local RaceConfig    = require(game.ReplicatedStorage.Shared.RaceConfig)
local EconomyConfig = require(game.ReplicatedStorage.Shared.EconomyConfig)
local SpeedConfig   = require(game.ReplicatedStorage.Shared.SpeedConfig)
local Packets       = require(game.ReplicatedStorage.Shared.Packets)
local MorphService  = require(ServerScriptService.Mounts.MorphService)

local FREEZE_REFRESH = 0.2 -- cada cuánto se re-clampea el WalkSpeed durante el freeze

type DataServiceServer = {
	hasProfile: (self: DataServiceServer, player: Player) -> boolean,
	get: (self: DataServiceServer, player: Player, path: any?) -> any,
	set: (self: DataServiceServer, player: Player, path: any, value: any, dontReplicate: boolean?) -> (),
}

type WinsServiceLike = {
	-- Devuelve lo acreditado de verdad, que NO es `amount`: WinsService le aplica el
	-- multiplicador de rebirth y el WeatherWinsBoost.
	awardWins: (self: any, player: Player, amount: number) -> number,
	teleportToSpawn: (self: any, player: Player) -> (),
}

-- Pista registrada al arrancar (una por stage con geometría de carrera).
type Track = {
	stage: number,
	npcModel: Model,
	playerMarker: BasePart,
	npcMarker: BasePart,
	goal: BasePart,
	-- Eje horizontal salida → meta. Todo el progreso se mide proyectando sobre él, así
	-- que la pista puede estar orientada de cualquier forma (la del Stage 2 va en +Z).
	axis: Vector3,
	goalPlane: number, -- proyección de la meta sobre el eje
}

-- Carrera en curso.
type ActiveRace = {
	player: Player,
	track: Track,
	racer: Model?,
	freezing: boolean,
	savedJumpPower: number?,
	savedJumpHeight: number?,
	heartbeat: RBXScriptConnection?,
	startedAt: number,
	over: boolean,
}

local RaceService = {
	_dataService = nil :: DataServiceServer?,
	_winsService = nil :: WinsServiceLike?,
	_tracks = {} :: { [number]: Track },
	_active = {} :: { [Player]: ActiveRace },
	_busy = {} :: { [number]: Player },       -- pista ocupada por stage
	_cooldown = {} :: { [Player]: { [number]: number } },
}

-- Mismo criterio que StagesService/EconomyService: el stage se saca del nombre.
local function getStageNumber(stageName: string): number
	return tonumber(stageName:match("%d+")) or 0
end

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	if not character then return nil end
	return character:FindFirstChildOfClass("Humanoid")
end

local function isAlive(player: Player): boolean
	local humanoid = getHumanoid(player)
	return humanoid ~= nil and humanoid.Health > 0
end

-- Progreso a lo largo de la pista. Se cruza la meta cuando alcanza goalPlane
-- (menos la tolerancia de GoalRadius, porque el HumanoidRootPart nunca llega justo).
local function progressOf(track: Track, position: Vector3): number
	return position:Dot(track.axis)
end

local function hasFinished(track: Track, position: Vector3): boolean
	return progressOf(track, position) >= (track.goalPlane - RaceConfig.GoalRadius)
end

-- Registra un stage si tiene la geometría completa. Devuelve nil si le falta algo.
local function buildTrack(stage: Model, stageNumber: number): Track?
	local npcModel = stage:FindFirstChild(RaceConfig.NpcModelName)
	local raceModel = stage:FindFirstChild(RaceConfig.RaceModelName)
	if not npcModel or not npcModel:IsA("Model") then return nil end
	if not raceModel or not raceModel:IsA("Model") then return nil end

	local playerMarker = raceModel:FindFirstChild(RaceConfig.PlayerMarkerName) :: BasePart?
	local npcMarker    = raceModel:FindFirstChild(RaceConfig.NpcMarkerName)    :: BasePart?
	local goal         = raceModel:FindFirstChild(RaceConfig.GoalName)         :: BasePart?

	if not (playerMarker and playerMarker:IsA("BasePart")) then
		warn(`[Race] {stage.Name}: falta la parte "{RaceConfig.PlayerMarkerName}" dentro de Race`)
		return nil
	end
	if not (npcMarker and npcMarker:IsA("BasePart")) then
		warn(`[Race] {stage.Name}: falta la parte "{RaceConfig.NpcMarkerName}" dentro de Race`)
		return nil
	end
	if not (goal and goal:IsA("BasePart")) then
		warn(`[Race] {stage.Name}: falta la parte "{RaceConfig.GoalName}" dentro de Race`)
		return nil
	end

	local flat = (goal.Position - playerMarker.Position) * Vector3.new(1, 0, 1)
	if flat.Magnitude < 1 then
		warn(`[Race] {stage.Name}: la meta y la salida están en el mismo sitio`)
		return nil
	end
	local axis = flat.Unit

	return {
		stage        = stageNumber,
		npcModel     = npcModel,
		playerMarker = playerMarker,
		npcMarker    = npcMarker,
		goal         = goal,
		axis         = axis,
		goalPlane    = goal.Position:Dot(axis),
	}
end

function RaceService:init(dataService: DataServiceServer, winsService: WinsServiceLike): ()
	self._dataService = dataService
	self._winsService = winsService

	local stagesFolder = Workspace:FindFirstChild("Stages")
	if not stagesFolder then
		warn("[Race] No se encontró Workspace.Stages")
		return
	end

	for _, child in stagesFolder:GetChildren() do
		if not child:IsA("Model") then continue end
		local stageNumber = getStageNumber(child.Name)
		if stageNumber == 0 then continue end

		-- Sin montura asignada no se registra la pista: no entra en _tracks, así que
		-- _canRace la rechaza y ni siquiera se conecta el ProximityPrompt. Es el
		-- estado de World 2 hasta que existan las monturas de esos niveles, y es
		-- preferible a montar el NPC sobre una montura equivocada o a que
		-- BuildMountRig falle al no encontrar el modelo.
		local cfg = RaceConfig.get(stageNumber)
		if cfg.Mount == "" then
			warn(`[Race] Stage {stageNumber}: sin montura asignada — carrera deshabilitada`)
			continue
		end

		local track = buildTrack(child, stageNumber)
		if track then
			self._tracks[stageNumber] = track
			self:_setupTrack(track)
		end
	end

	Packets.RaceAccept.OnServerEvent:Connect(function(player: Player, stage: number)
		if typeof(stage) ~= "number" then return end
		self:_handleAccept(player, math.floor(stage))
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		local race = self._active[player]
		if race then
			self:_abort(race)
		end
		self._cooldown[player] = nil
	end)
end

-- Viste al NPC con el outfit de su stage. Se llama UNA sola vez por rig, al
-- arrancar el server: el corredor de cada carrera es un clon de este mismo rig
-- (MorphService.BuildMountRig clona track.npcModel), así que hereda la ropa sin
-- que haya que vestirlo otra vez en cada carrera.
--
-- Se parte de GetAppliedDescription() y no de una HumanoidDescription vacía: así
-- se respeta la anatomía que el rig trae del .rbxl (meshes de las partes del
-- cuerpo y escalas) y el config manda solo sobre el vestuario. Todos los slots de
-- ropa/accesorio se escriben siempre, incluso vacíos, para que el config sea la
-- verdad completa: quitar un id de RaceConfig le quita la prenda al NPC.
--
-- CEDE (ApplyDescription hace llamadas web), por eso corre en su propia corrutina
-- desde _setupTrack: un stage con la web lenta no puede retrasar el registro de
-- las demás pistas ni la conexión de los packets.
local function applyOutfit(npcModel: Model, stage: number): ()
	local humanoid = npcModel:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn(`[Race] Stage {stage}: el Npc no tiene Humanoid, no se le puede aplicar el outfit`)
		return
	end

	local outfit = RaceConfig.getOutfit(stage)

	-- HumanoidDescription guarda los accesorios como ids separados por comas.
	local function idList(ids: { number }): string
		local parts = {}
		for _, id in ids do
			if id > 0 then
				table.insert(parts, tostring(id))
			end
		end
		return table.concat(parts, ",")
	end

	local ok, applied = pcall(function()
		return humanoid:GetAppliedDescription()
	end)
	local desc = if ok and applied then applied :: HumanoidDescription else Instance.new("HumanoidDescription")

	desc.Shirt         = outfit.Shirt
	desc.Pants         = outfit.Pants
	desc.GraphicTShirt = outfit.TShirt
	desc.Face          = outfit.Face

	desc.HairAccessory      = idList(outfit.Hair)
	desc.HatAccessory       = idList(outfit.Hats)
	desc.FaceAccessory      = idList(outfit.FaceAccessories)
	desc.FrontAccessory     = idList(outfit.Front)
	desc.BackAccessory      = idList(outfit.Back)
	desc.NeckAccessory      = idList(outfit.Neck)
	desc.ShouldersAccessory = idList(outfit.Shoulders)
	desc.WaistAccessory     = idList(outfit.Waist)

	local skin = outfit.SkinColor
	if skin then
		desc.HeadColor     = skin
		desc.TorsoColor    = skin
		desc.LeftArmColor  = skin
		desc.RightArmColor = skin
		desc.LeftLegColor  = skin
		desc.RightLegColor = skin
	end

	local scale = outfit.Scale
	if scale then
		desc.HeightScale     = scale.Height     or desc.HeightScale
		desc.WidthScale      = scale.Width      or desc.WidthScale
		desc.HeadScale       = scale.Head       or desc.HeadScale
		desc.DepthScale      = scale.Depth      or desc.DepthScale
		desc.BodyTypeScale   = scale.BodyType   or desc.BodyTypeScale
		desc.ProportionScale = scale.Proportion or desc.ProportionScale
	end

	local applyOk, err = pcall(function()
		humanoid:ApplyDescription(desc)
	end)
	if not applyOk then
		warn(`[Race] Stage {stage}: falló ApplyDescription — {err}`)
	end
end

-- Deja al NPC clavado en su sitio pero ANIMABLE: se ancla solo el
-- HumanoidRootPart y se desancla el resto.
--
-- Anclar todas las partes (que es lo que se hacía antes) mata la animación: un
-- BasePart anclado no lo mueve nadie, tampoco el Animator, así que el rig se
-- queda en pose T por mucho que el track esté sonando. Con solo el root anclado
-- el ensamblado entero sigue sin caerse ni deambular —cuelga de él por las
-- juntas— y las extremidades quedan libres para que las pose la animación.
local function anchorRootOnly(npcModel: Model): ()
	local hrp = npcModel:FindFirstChild("HumanoidRootPart") :: BasePart?
	for _, d in npcModel:GetDescendants() do
		if d:IsA("BasePart") then
			(d :: BasePart).Anchored = (d == hrp)
		end
	end
	if hrp then
		hrp.Anchored = true
	end
end

-- El saludo en bucle del NPC de escaparate. Va DESPUÉS de applyOutfit:
-- ApplyDescription reconstruye las partes del cuerpo, y un track cargado antes
-- se quedaría animando partes que ya no existen.
local function playIdle(npcModel: Model, stage: number): ()
	local humanoid = npcModel:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = RaceConfig.NpcIdleAnimation

	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(animation)
	end)
	if not ok or not track then
		warn(`[Race] Stage {stage}: no se pudo cargar la animación idle — {track}`)
		return
	end

	local animTrack = track :: AnimationTrack
	animTrack.Looped = true
	animTrack.Priority = Enum.AnimationPriority.Idle
	animTrack:Play()
end

-- Baja el corredor hasta que las patas de la MONTURA toquen la cara superior del
-- marcador.
--
-- BuildMountRig planta el HumanoidRootPart de la montura en el CFrame que se le
-- pasa, pero ese root está en mitad del rig y cada montura mide una cosa distinta
-- (Chonk no ocupa lo que Nyxion). Colocarlo a pelo sobre el marcador deja a las
-- grandes flotando, así que hay que medir el rig y posarlo.
--
-- Lo que NO sirve aquí es model:GetBoundingBox(): el modelo lleva dentro el
-- OriginalCharacter (el jinete), y el jinete es un clon del NPC de escaparate que
-- nace en la posición de ESE rig, a decenas de studs de la pista, hasta que el
-- SeatWeld lo trae encima. Si se mide antes de que llegue —o si ese frame se
-- retrasa— la caja abarca pista y escaparate a la vez, su fondo cae por el suelo
-- del stage y la cuenta manda SUBIR la montura al cielo. Por eso se recorren solo
-- las partes propias de la montura y se calcula el mínimo a mano: así el resultado
-- no depende de que la física haya llegado a tiempo.
local function dropOntoMarker(racer: Model, marker: BasePart): ()
	local rider = racer:FindFirstChild("OriginalCharacter")
	local lowest: number? = nil

	for _, d in racer:GetDescendants() do
		if not d:IsA("BasePart") then continue end
		local part = d :: BasePart
		-- El jinete y el Seat invisible no cuentan: el suelo lo tocan las patas.
		if rider and part:IsDescendantOf(rider) then continue end
		if part:IsA("Seat") then continue end

		-- Media altura de la part proyectada al mundo, para que valga aunque el rig
		-- venga girado (la pista puede tener cualquier orientación).
		local cf = part.CFrame
		local half = part.Size / 2
		local extentY = math.abs(cf.RightVector.Y) * half.X
			+ math.abs(cf.UpVector.Y) * half.Y
			+ math.abs(cf.LookVector.Y) * half.Z

		local bottom = cf.Position.Y - extentY
		if not lowest or bottom < lowest then
			lowest = bottom
		end
	end

	if not lowest then return end

	local groundY = marker.Position.Y + (marker.Size.Y / 2)
	racer:PivotTo(racer:GetPivot() + Vector3.new(0, groundY - lowest, 0))
end

-- Lanza la animación de andar de la montura sobre el corredor.
--
-- Para el jugador esto lo hace el cliente de Mounts (setupMountAnimations, colgado
-- de humanoid.Running), pero el corredor NO es el personaje de nadie: ningún
-- cliente lo mira, así que si no lo lanza el servidor no lo lanza nadie y la
-- montura cruza la pista rígida. Desde el servidor se replica a todos los que
-- estén viendo la carrera.
local function playMountWalk(racer: Model, speed: number): ()
	-- Ambos FindFirstChild son NO recursivos a propósito: el modelo lleva dentro el
	-- OriginalCharacter (el jinete), que tiene su propio Humanoid. Se quiere el de
	-- la montura, que es hijo directo.
	local humanoid = racer:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animFolder = racer:FindFirstChild("Animations")
	local walkAnim = animFolder and animFolder:FindFirstChild("Walk") :: Animation?
	if not walkAnim or not walkAnim:IsA("Animation") then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(walkAnim :: Animation)
	end)
	if not ok or not track then return end

	local animTrack = track :: AnimationTrack
	animTrack.Looped = true
	animTrack.Priority = Enum.AnimationPriority.Movement

	-- Mismo criterio que el cliente: el ritmo sigue a la velocidad real tomando 16
	-- studs/s como la del asset, para que no patine a 95 studs/s en el stage 14.
	local base = ((walkAnim :: Animation):GetAttribute("Speed") or 1) :: number
	animTrack:Play(0, 1, base * (speed / 16))
end

function RaceService:_setupTrack(track: Track): ()
	local cfg = RaceConfig.get(track.stage)

	-- El NPC de escaparate no debe deambular ni caerse: se queda quieto en su sitio.
	anchorRootOnly(track.npcModel)

	-- ApplyDescription sustituye las partes del cuerpo por otras nuevas (que vienen
	-- sin anclar) y añade los accesorios, así que hay que repetir el anclado después.
	-- Mientras tanto el rig no se cae: cuelga del HumanoidRootPart, que sigue anclado
	-- y ancla todo el ensamblado.
	task.spawn(function()
		applyOutfit(track.npcModel, track.stage)
		anchorRootOnly(track.npcModel)
		playIdle(track.npcModel, track.stage)
	end)

	local prompt = track.npcModel:FindFirstChildWhichIsA("ProximityPrompt", true) :: ProximityPrompt?
	if not prompt then
		warn(`[Race] Stage {track.stage}: el Npc no tiene ProximityPrompt`)
		return
	end

	-- El prompt se queda DONDE LO PUSO el .rbxl (hoy: hijo directo del Model Npc). No
	-- se reparenta: colgado del HumanoidRootPart la posición no sirve, y colgado del
	-- Model funciona igual de bien porque un ProximityPrompt hijo de un Model se ancla
	-- a su PrimaryPart. Lo único que hace falta es que esa PrimaryPart exista — si el
	-- rig viniera sin ella, el prompt no se renderizaría ni se dispararía nunca, así
	-- que se rellena con el HumanoidRootPart en vez de mover el prompt.
	if not track.npcModel.PrimaryPart then
		local hrp = track.npcModel:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then
			warn(`[Race] Stage {track.stage}: el Npc no tiene PrimaryPart ni HumanoidRootPart; el prompt no se verá`)
			return
		end
		track.npcModel.PrimaryPart = hrp
	end

	prompt.ObjectText = cfg.NpcName

	prompt.Triggered:Connect(function(player: Player)
		if not self:_canRace(player, track.stage) then return end
		Packets.RaceOpen:FireClient(player, track.stage, cfg.NpcName)
	end)
end

-- Todas las condiciones para poder correr. Se comprueba tanto al activar el prompt
-- como al recibir el RaceAccept: el cliente puede mandar el packet a mano sin haber
-- pasado por el prompt, así que la segunda comprobación no es redundante.
function RaceService:_canRace(player: Player, stage: number): boolean
	local track = self._tracks[stage]
	if not track then return false end
	if self._busy[stage] then return false end
	if self._active[player] then return false end

	local dataService = self._dataService
	if not dataService or not dataService:hasProfile(player) then return false end
	if not isAlive(player) then return false end

	if RaceConfig.CooldownSeconds > 0 then
		local byStage = self._cooldown[player]
		local last = byStage and byStage[stage]
		if last and (os.clock() - last) < RaceConfig.CooldownSeconds then
			return false
		end
	end

	return true
end

function RaceService:_handleAccept(player: Player, stage: number): ()
	if not self:_canRace(player, stage) then return end
	local track = self._tracks[stage]
	if not track then return end

	local race: ActiveRace = {
		player    = player,
		track     = track,
		racer     = nil,
		freezing  = false,
		heartbeat = nil,
		startedAt = os.clock(),
		over      = false,
	}

	self._active[player] = race
	self._busy[stage] = player
	player:SetAttribute("Racing", true)

	task.spawn(function()
		self:_run(race)
	end)
end

-- Coloca a los dos corredores, congela al jugador, lanza la cuenta atrás y arranca
-- la carrera. Corre en su propia corrutina porque la cuenta atrás usa task.wait.
function RaceService:_run(race: ActiveRace): ()
	local player = race.player
	local track  = race.track
	local cfg    = RaceConfig.get(track.stage)

	local character = player.Character
	if not character then
		self:_abort(race)
		return
	end

	-- Salida del jugador. El character puede ser el modelo de la montura (atributo
	-- IsMountCharacter), así que se mueve con PivotTo sobre el modelo entero, no
	-- asumiendo un rig R15.
	local playerStart = track.playerMarker.Position + Vector3.new(0, RaceConfig.SpawnHeight, 0)
	character:PivotTo(CFrame.lookAt(playerStart, playerStart + track.axis))

	self:_freeze(race)

	-- El NPC corredor: el rig de escaparate del stage, montado sobre la montura del
	-- stage. Mismo rigging que el morph del jugador (Seat + RigidConstraint), pero sin
	-- IsMountCharacter, así que DeathEffectService y el cliente de Mounts lo ignoran.
	local npcStart = track.npcMarker.Position + Vector3.new(0, RaceConfig.SpawnHeight, 0)
	local racer = MorphService.BuildMountRig(
		cfg.Mount,
		track.npcModel,
		CFrame.lookAt(npcStart, npcStart + track.axis)
	)
	if not racer then
		warn(`[Race] Stage {track.stage}: no se pudo construir el NPC con la montura {cfg.Mount}`)
		self:_abort(race)
		return
	end

	racer.Name = RaceConfig.RacerName
	race.racer = racer

	-- El jinete es un clon del NPC de escaparate, y ese rig lleva colgando el
	-- ProximityPrompt. Sin borrarlo, el corredor se pasea por la pista con un prompt
	-- activable encima: cualquiera podría lanzar otra carrera desde él. Se quita del
	-- clon (el original no se toca, sigue en su sitio para el resto de jugadores).
	for _, d in racer:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			d:Destroy()
		end
	end

	-- Un paso de física antes de anclar: el SeatWeld que acaba de crear el Sit coloca
	-- al NPC sobre la montura en el siguiente Heartbeat. Anclando en el mismo frame se
	-- quedaría flotando al lado en vez de encima.
	RunService.Heartbeat:Wait()
	if race.over then return end

	-- Anclado: se mueve por PivotTo autoritativo, no por física. Sin anclar, la física
	-- del server pelea con el PivotTo (mismo motivo que en RingEnemyService).
	--
	-- Pero se ancla SOLO el HumanoidRootPart de la montura, no todas las partes: un
	-- BasePart anclado no lo mueve el Animator, así que anclarlo todo congelaba tanto
	-- la animación de andar de la montura como la del jinete. Con el root anclado el
	-- conjunto sigue siendo autoritativo (el resto cuelga de él por las juntas, el
	-- Seat y el SeatWeld) y las extremidades quedan libres para animarse.
	anchorRootOnly(racer)

	-- Posado sobre el marcador, ya con todo quieto: se mide DESPUÉS de anclar para que
	-- ninguna part siga cayendo mientras se calcula el mínimo.
	dropOntoMarker(racer, track.npcMarker)

	-- Cuenta atrás. El último paso ("Start!") da la salida.
	for index, text in RaceConfig.CountdownSteps do
		if race.over then return end
		if not isAlive(player) or not player:IsDescendantOf(Players) then
			self:_abort(race)
			return
		end

		Packets.RaceCountdown:FireClient(player, text)

		if index < #RaceConfig.CountdownSteps then
			task.wait(RaceConfig.CountdownStep)
		end
	end

	if race.over then return end

	self:_unfreeze(race)
	race.startedAt = os.clock()

	-- La montura echa a andar justo cuando empieza a moverse, no antes: durante la
	-- cuenta atrás está parada en la línea de salida.
	playMountWalk(racer, cfg.NpcSpeed)

	race.heartbeat = RunService.Heartbeat:Connect(function(dt: number)
		self:_step(race, dt)
	end)
end

function RaceService:_step(race: ActiveRace, dt: number): ()
	if race.over then return end

	local player = race.player
	local track  = race.track
	local racer  = race.racer

	-- Abandono: muerte, desconexión o character perdido. Sin premio.
	if not player:IsDescendantOf(Players) or not isAlive(player) or not racer or not racer.Parent then
		self:_abort(race)
		return
	end

	-- Corte de seguridad: nadie llega a meta (jugador atascado, NPC bloqueado). Se
	-- cierra como derrota para no dejar la pista ocupada el resto de la partida.
	if (os.clock() - race.startedAt) > RaceConfig.MaxRaceSeconds then
		self:_finish(race, false)
		return
	end

	-- El jugador primero: si los dos cruzan en el mismo frame, gana él.
	-- El character se re-resuelve cada frame a propósito: un evolve a mitad de carrera
	-- lo sustituye por otro modelo (MorphService reasigna player.Character).
	local character = player.Character
	local hrp = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if hrp and hasFinished(track, hrp.Position) then
		self:_finish(race, true)
		return
	end

	-- Traslación pura sobre el pivot actual: `CFrame + Vector3` no toca la rotación, que
	-- ya viene mirando al eje desde BuildMountRig. Se mueve por el pivot (así no importa
	-- dónde lo tenga el modelo de cada montura, no hay deriva) pero la meta se mide con
	-- el HumanoidRootPart, que es el cuerpo real del corredor.
	local cfg = RaceConfig.get(track.stage)
	racer:PivotTo(racer:GetPivot() + track.axis * cfg.NpcSpeed * dt)

	local racerHRP = racer:FindFirstChild("HumanoidRootPart") :: BasePart?
	if racerHRP and hasFinished(track, racerHRP.Position) then
		self:_finish(race, false)
	end
end

-- WalkSpeed = 0 no basta: SpeedService lo reaplica en cada level-up y en cada morph.
-- Se re-clampea en bucle mientras dure el freeze (mismo truco que la ventana de
-- slow-down de AdminService).
function RaceService:_freeze(race: ActiveRace): ()
	local humanoid = getHumanoid(race.player)
	if not humanoid then return end

	race.savedJumpPower  = humanoid.JumpPower
	race.savedJumpHeight = humanoid.JumpHeight
	race.freezing = true

	task.spawn(function()
		while race.freezing and not race.over do
			local h = getHumanoid(race.player)
			if h then
				h.WalkSpeed  = 0
				h.JumpPower  = 0
				h.JumpHeight = 0
			end
			task.wait(FREEZE_REFRESH)
		end
	end)
end

function RaceService:_unfreeze(race: ActiveRace): ()
	race.freezing = false

	local humanoid = getHumanoid(race.player)
	if not humanoid then return end

	local dataService = self._dataService
	local level = 1
	if dataService and dataService:hasProfile(race.player) then
		level = (dataService:get(race.player, { "Level" }) or 1) :: number
	end

	humanoid.WalkSpeed  = SpeedConfig.getWalkSpeedForLevel(level)
	humanoid.JumpPower  = race.savedJumpPower or humanoid.JumpPower
	humanoid.JumpHeight = race.savedJumpHeight or humanoid.JumpHeight
end

-- Fin normal: paga y devuelve al spawn. Ganar = el doble de los Wins del stage,
-- perder = la mitad. Pasa por WinsService:awardWins para heredar el multiplicador de
-- rebirth y el WeatherWinsBoost, igual que un botón de Wins normal.
function RaceService:_finish(race: ActiveRace, won: boolean): ()
	if race.over then return end

	local player = race.player
	local winsService = self._winsService

	local base   = EconomyConfig.current().StageWins[race.track.stage] or 0
	local factor = if won then RaceConfig.WinFactor else RaceConfig.LoseFactor
	local earned = math.max(1, math.round(base * factor))

	self:_cleanup(race)

	if winsService and player:IsDescendantOf(Players) then
		-- Se manda al cliente lo ACREDITADO, no `earned`: awardWins le aplica encima el
		-- multiplicador de rebirth y el del weather, así que enseñar `earned` diría
		-- "+2 Wins" a un jugador que acaba de recibir 52.
		local credited = winsService:awardWins(player, earned)
		Packets.RaceResult:FireClient(player, won, credited)
		winsService:teleportToSpawn(player)
	end
end

-- Fin anormal (muerte, desconexión, geometría rota): libera todo sin pagar nada.
function RaceService:_abort(race: ActiveRace): ()
	if race.over then return end
	self:_cleanup(race)
end

-- Único sitio que suelta los recursos de una carrera. Lo llaman _finish y _abort, así
-- que ningún camino puede dejar la pista ocupada o el NPC colgado en Workspace.
function RaceService:_cleanup(race: ActiveRace): ()
	race.over = true
	race.freezing = false

	if race.heartbeat then
		race.heartbeat:Disconnect()
		race.heartbeat = nil
	end

	if race.racer then
		race.racer:Destroy()
		race.racer = nil
	end

	self:_unfreeze(race)

	local player = race.player
	player:SetAttribute("Racing", nil)

	self._active[player] = nil
	if self._busy[race.track.stage] == player then
		self._busy[race.track.stage] = nil
	end

	if RaceConfig.CooldownSeconds > 0 then
		local byStage = self._cooldown[player]
		if not byStage then
			byStage = {}
			self._cooldown[player] = byStage
		end
		byStage[race.track.stage] = os.clock()
	end
end

return RaceService
