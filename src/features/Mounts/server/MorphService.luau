--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HatsData = require(ReplicatedStorage.Shared.HatsData)
local TrailsData = require(ReplicatedStorage.Shared.TrailsData)

local MorphService = {}

-- DataService inyectado (para leer el hat equipado en cada morph)
local dataService: any = nil

function MorphService.setDataService(ds: any): ()
	dataService = ds
end

local HAT_BASE_SIZE = 9 -- Y del HRP de la montura de referencia (mountScale = 1)

-- Distancia del HumanoidRootPart al suelo en un avatar R15 estándar. Solo se usa
-- si el rider no trae HRP (no debería pasar); lo normal es medirlo del rider real,
-- que es quien define dónde está el suelo en ese momento.
local DEFAULT_RIDER_DROP = 3

-- Cuánto baja la geometría de un modelo por debajo del centro de su root: del
-- centro del root al punto más bajo de su caja envolvente.
--
-- Es lo que hace falta para apoyar un rig en el suelo, y no el `Size` de ninguna
-- part suelta: las monturas son meshes unidos por Motor6D, así que el único dato
-- fiable de "cuánto ocupa" es la caja del modelo entero.
local function dropBelowRoot(model: Model, root: BasePart): number
	local boxCFrame, boxSize = model:GetBoundingBox()
	return root.Position.Y - (boxCFrame.Position.Y - boxSize.Y / 2)
end

-- Animación en loop que corre el rider (la copia del personaje sentada sobre la
-- montura) mientras la montura está equipada.
local RIDER_ANIMATION_ID = "rbxassetid://76086496385671"

-- Reproduce la animación del rider en loop sobre el humanoid de la copia. Su
-- script Animate se destruyó antes de llamar aquí, así que nada compite con esta.
local function playRiderAnimation(humanoid: Humanoid): ()
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = RIDER_ANIMATION_ID

	local track = (animator :: Animator):LoadAnimation(animation)
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Action
	track:Play()
end

-- Busca el attachment "Hat" del rig de la montura (variante Head o Neck.Head)
local function findMountHatAttachment(hrp: Instance): Attachment?
	local root = hrp:FindFirstChild("Root")
	local torso = root and root:FindFirstChild("Torso")
	if not torso then return nil end

	local head = torso:FindFirstChild("Head")
	local headHat = head and head:FindFirstChild("Hat")
	if headHat and headHat:IsA("Attachment") then return headHat :: Attachment end

	local neck = torso:FindFirstChild("Neck")
	local neckHead = neck and neck:FindFirstChild("Head")
	local neckHat = neckHead and neckHead:FindFirstChild("Hat")
	if neckHat and neckHat:IsA("Attachment") then return neckHat :: Attachment end

	return nil
end

-- Quita el hat actual (si hay) y coloca el nuevo sobre la montura.
-- hatName == "" => solo quitar.
local function attachHat(character: Model, hatName: string): ()
	-- Quitar hat anterior
	local existing = character:FindFirstChild("Hat")
	if existing and existing:IsA("Model") then
		existing:Destroy()
	end

	if hatName == "" then return end

	local hatsFolder = ReplicatedStorage:FindFirstChild("Hats")
	local template = hatsFolder and hatsFolder:FindFirstChild(hatName)
	if not template or not template:IsA("Model") then return end

	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return end

	local mountHatAtt = findMountHatAttachment(hrp)
	if not mountHatAtt then return end

	local hat = (template :: Model):Clone()
	hat.Name = "Hat"

	for _, v in hat:GetChildren() do
		if v:IsA("BasePart") then
			v.Massless = true
		end
	end

	local primary = hat.PrimaryPart
	local att = primary and primary:FindFirstChild("Attachment") :: Attachment?
	if not primary or not att then
		hat:Destroy()
		return
	end

	att.CFrame = (att.CFrame + Vector3.new(0, character:GetAttribute("HatHeight") or 0, 0))
		* CFrame.Angles(0, math.rad(character:GetAttribute("HatAlt") or 0), 0)

	local weld = Instance.new("RigidConstraint")
	weld.Attachment0 = att
	weld.Attachment1 = mountHatAtt
	weld.Parent = primary

	-- Escala = tamaño de la montura × ajuste opcional por gorro (Scale en HatsData).
	-- Cada gorro está modelado con proporciones distintas, así que el tamaño fino
	-- se calibra por gorro con su campo Scale (default 1).
	local mountScale = hrp.Size.Y / HAT_BASE_SIZE
	local hatData = HatsData.getHatData(hatName)
	local override = (hatData and hatData.Scale) or 1

	hat:ScaleTo(mountScale * override)

	hat.Parent = character
end

-- Lee el hat equipado del jugador (o "")
local function getEquippedHat(player: Player): string
	if dataService and dataService:hasProfile(player) then
		return (dataService:get(player, { "EquippedHat" }) or "") :: string
	end
	return ""
end

local TRAIL_NAME = "EquippedTrail" -- nombre del Trail y de sus attachments sobre la montura

-- Quita el trail actual (si hay) y coloca el nuevo, vertical (arriba→abajo) en la
-- parte trasera de la montura. trailName == "" => solo quitar.
local function attachTrail(character: Model, trailName: string): ()
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return end

	-- Quitar trail y attachments anteriores
	for _, child in hrp:GetChildren() do
		if child.Name == TRAIL_NAME and (child:IsA("Trail") or child:IsA("Attachment")) then
			child:Destroy()
		end
	end

	if trailName == "" then return end

	local trailData = TrailsData.getTrailData(trailName)
	if not trailData then return end

	-- Posición: parte trasera, extremos arriba y abajo (tuneable por atributos de la
	-- montura). El span vertical usa TrailWidth como longitud (o el alto del HRP).
	local back   = (character:GetAttribute("TrailBack")   or (hrp.Size.Z * 0.5)) :: number
	local center = (character:GetAttribute("TrailHeight") or 0) :: number
	local half   = ((character:GetAttribute("TrailWidth") or hrp.Size.Y) :: number) / 2

	local attTop = Instance.new("Attachment")
	attTop.Name = TRAIL_NAME
	attTop.Position = Vector3.new(0, center + half, back)
	attTop.Parent = hrp

	local attBottom = Instance.new("Attachment")
	attBottom.Name = TRAIL_NAME
	attBottom.Position = Vector3.new(0, center - half, back)
	attBottom.Parent = hrp

	local trail = Instance.new("Trail")
	trail.Name = TRAIL_NAME
	trail.Attachment0 = attTop
	trail.Attachment1 = attBottom
	-- Trail.Color es un ColorSequence: si el trail define un Gradient (Rainbow), se
	-- usa tal cual para que la cinta muestre todo el espectro; el resto son color sólido.
	trail.Color = trailData.Gradient or ColorSequence.new(trailData.Color)
	trail.Texture = trailData.Texture
	trail.Lifetime = 0.6
	trail.LightEmission = 1
	trail.FaceCamera = false
	trail.Parent = hrp
end

-- Lee el trail equipado del jugador (o "")
local function getEquippedTrail(player: Player): string
	if dataService and dataService:hasProfile(player) then
		return (dataService:get(player, { "EquippedTrail" }) or "") :: string
	end
	return ""
end

-- Re-aplica el hat equipado sobre el character-montura actual (sin re-morphear)
function MorphService.ApplyHat(player: Player): ()
	local character = player.Character
	if not character or not character:GetAttribute("IsMountCharacter") then return end
	attachHat(character, getEquippedHat(player))
end

-- Re-aplica el trail equipado sobre el character-montura actual (sin re-morphear)
function MorphService.ApplyTrail(player: Player): ()
	local character = player.Character
	if not character or not character:GetAttribute("IsMountCharacter") then return end
	attachTrail(character, getEquippedTrail(player))
end

-- Monta `rider` (un rig cualquiera: el avatar de un jugador o un NPC) sobre una copia
-- del modelo de `mountName`, colocada en `cframe`, y devuelve el modelo resultante ya
-- parenteado a Workspace.
--
-- NO toca player.Character ni pone el atributo IsMountCharacter: eso es cosa de
-- MorphPlayer. Así el mismo rigging (Seat invisible + RigidConstraint al attachment
-- Root.Torso.Seat + animación del rider) sirve para el morph del jugador y para los
-- NPC de las carreras, sin duplicar el código de los attachments.
-- Los rigs de las monturas viven en RojoShared.Mounts (RojoShared/Mounts/ en el
-- repo, como archivos .rbxm) y no sueltos en ReplicatedStorage: así Rojo los
-- sincroniza en los dos places sin que haya que copiarlos a mano en cada uno.
function MorphService.BuildMountRig(mountName: string, rider: Model, cframe: CFrame): Model?
	local rojoShared = ReplicatedStorage:FindFirstChild("RojoShared")
	local mountsFolder = rojoShared and rojoShared:FindFirstChild("Mounts")
	if not mountsFolder then
		warn("[MorphService] No se encontró ReplicatedStorage.RojoShared.Mounts")
		return nil
	end

	local mountTemplate = mountsFolder:FindFirstChild(mountName)
	if not mountTemplate or not mountTemplate:IsA("Model") then
		warn(`[MorphService] No se encontró el modelo de mount: {mountName}`)
		return nil
	end

	local newChar = (mountTemplate :: Model):Clone()

	local newHRP = newChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not newHRP then
		warn(`[MorphService] El modelo {mountName} no tiene HumanoidRootPart`)
		newChar:Destroy()
		return nil
	end

	-- Se mueve el MODELO ENTERO, no solo el HumanoidRootPart.
	--
	-- Poner `newHRP.CFrame = cframe` a pelo movía una única part. Los meshes del rig
	-- daba igual, porque van por Bones/Motor6D y se recolocan solos al entrar al
	-- DataModel — pero el "HitBox" (el collider de la montura) se une con un
	-- WeldConstraint, que NO tiene offset explícito: se queda donde estaba en la
	-- plantilla y al parentear congela esa separación. Resultado: la caja de
	-- colisión de la montura quedaba a cientos de studs del jugador.
	--
	-- PrimaryPart se fija al HRP para que el pivot sea exactamente el mismo punto que
	-- se usaba antes: así PivotTo(cframe) deja el HRP donde lo dejaba la línea vieja,
	-- pero arrastrando rígidamente todo lo demás, esté unido por lo que esté unido.
	newChar.PrimaryPart = newHRP
	newChar:PivotTo(cframe)

	-- Apoyar el rig en el suelo según su TAMAÑO REAL.
	--
	-- `cframe` es el CFrame del HumanoidRootPart del jugador, que está a ~3 studs del
	-- suelo. Dejar ahí el HRP de la montura vale mientras el rig baje lo mismo desde
	-- su propio root; en cuanto la montura es más grande, la diferencia se la come el
	-- suelo y se ve medio bicho enterrado.
	--
	-- Se mide AHORA, con dos condiciones que importan: antes de meter al rider dentro
	-- (que ampliaría la caja envolvente con el avatar) y antes de parentear a
	-- workspace (para que nadie llegue a ver el frame mal colocado).
	local mountDrop = dropBelowRoot(newChar, newHRP)

	-- El suelo lo define el rider: la distancia de SU root a SUS pies. Se saca de él
	-- y no de una constante para que valga igual con avatares escalados y con los
	-- rigs de los NPC de las carreras, que no miden lo mismo que un jugador.
	local riderRoot = rider:FindFirstChild("HumanoidRootPart") :: BasePart?
	local riderDrop = if riderRoot then dropBelowRoot(rider, riderRoot) else DEFAULT_RIDER_DROP
	local groundY   = cframe.Position.Y - riderDrop

	-- El root sube (o baja) hasta que el punto más bajo del rig toque ese suelo.
	newChar:PivotTo(cframe + Vector3.new(0, (groundY + mountDrop) - cframe.Position.Y, 0))

	-- Y que la física lo MANTENGA ahí. Sin esto el Humanoid vuelve a colocar el root
	-- a la HipHeight que trajera la plantilla en cuanto toca el suelo, y la montura
	-- se re-hunde sola un instante después de aparecer bien.
	local mountHumanoid = newChar:FindFirstChildOfClass("Humanoid")
	if mountHumanoid then
		mountHumanoid.HipHeight = math.max(0, mountDrop - newHRP.Size.Y / 2)
	end

	for _, part in newChar:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanTouch = true
		end
	end

	newChar.Parent = workspace

	-- Crear el Seat invisible y weldearlo al attachment del mount
	local seat = Instance.new("Seat")
	seat.CanCollide = false
	seat.Transparency = 1
	seat.Massless = true

	local seatAtt = Instance.new("Attachment")
	seatAtt.CFrame = CFrame.new(0, newChar:GetAttribute("SeatHeight") or 1, 0)
		* CFrame.Angles(0, math.rad(newChar:GetAttribute("SeatAlt") or 0), 0)
	seatAtt.Parent = seat

	-- Buscar el attachment del mount al que weldear el seat
	local mountSeatAtt = newHRP:FindFirstChild("Root")
		and (newHRP:FindFirstChild("Root") :: Instance):FindFirstChild("Torso")
		and ((newHRP:FindFirstChild("Root") :: Instance):FindFirstChild("Torso") :: Instance):FindFirstChild("Seat")

	if mountSeatAtt then
		local weld = Instance.new("RigidConstraint")
		weld.Attachment0 = seatAtt
		weld.Attachment1 = mountSeatAtt :: Attachment
		weld.Parent = seat
	end

	seat.Parent = newChar

	-- Clonar el rider y sentarlo en el mount
	rider.Archivable = true
	local cloneCharacter = rider:Clone()
	cloneCharacter.Name = "OriginalCharacter"

	local animateScript = cloneCharacter:FindFirstChild("Animate")
	if animateScript then animateScript:Destroy() end

	-- Un rig anclado no se puede sentar: el SeatWeld no lo movería y se quedaría
	-- plantado donde estaba. Los avatares de jugador nunca vienen anclados, pero los
	-- NPC del mundo sí (RaceService los ancla para que no deambulen), así que se
	-- desanclan aquí antes del Sit.
	for _, part in cloneCharacter:GetDescendants() do
		if part:IsA("BasePart") then
			(part :: BasePart).Anchored = false
		end
	end

	cloneCharacter.Parent = newChar

	local cloneHumanoid = cloneCharacter:FindFirstChildOfClass("Humanoid")
	if cloneHumanoid then
		seat:Sit(cloneHumanoid)
		cloneHumanoid.WalkSpeed = 0
		cloneHumanoid.JumpPower = 0
		cloneHumanoid.AutoRotate = false
		playRiderAnimation(cloneHumanoid)
	end

	return newChar
end

function MorphService.MorphPlayer(player: Player, mountName: string): ()
	local oldCharacter = player.Character
	if not oldCharacter then return end

	-- Si ya es un mount, usar el OriginalCharacter interno para no anidar mounts
	local existingOriginal = oldCharacter:FindFirstChild("OriginalCharacter")
	local sourceCharacter = (existingOriginal or oldCharacter) :: Model

	local oldHRP = oldCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not oldHRP then return end

	local newChar = MorphService.BuildMountRig(mountName, sourceCharacter, oldHRP.CFrame)
	if not newChar then return end

	newChar.Name = player.Name
	newChar:SetAttribute("IsMountCharacter", true)

	-- Destruir el mount anterior si había uno
	if existingOriginal then
		oldCharacter:Destroy()
	end

	-- Equipar el gorro actual sobre la nueva montura (inicio, evolve, cambio de montura)
	attachHat(newChar, getEquippedHat(player))
	attachTrail(newChar, getEquippedTrail(player))

	player.Character = newChar
end

return MorphService
