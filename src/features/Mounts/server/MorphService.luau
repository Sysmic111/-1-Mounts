--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MorphService = {}

-- DataService inyectado (para leer el hat equipado en cada morph)
local dataService: any = nil

function MorphService.setDataService(ds: any): ()
	dataService = ds
end

local HAT_BASE_SIZE = 9 -- tamaño estándar de referencia para escalar el hat

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

	local scale = hrp.Size.Y / HAT_BASE_SIZE
	hat:ScaleTo(scale)

	hat.Parent = character
end

-- Lee el hat equipado del jugador (o "")
local function getEquippedHat(player: Player): string
	if dataService and dataService:hasProfile(player) then
		return (dataService:get(player, { "EquippedHat" }) or "") :: string
	end
	return ""
end

-- Re-aplica el hat equipado sobre el character-montura actual (sin re-morphear)
function MorphService.ApplyHat(player: Player): ()
	local character = player.Character
	if not character or not character:GetAttribute("IsMountCharacter") then return end
	attachHat(character, getEquippedHat(player))
end

function MorphService.MorphPlayer(player: Player, mountName: string): ()
	local mountsFolder = ReplicatedStorage:FindFirstChild("Mounts")
	if not mountsFolder then
		warn("[MorphService] No se encontró ReplicatedStorage.Mounts")
		return
	end

	local mountTemplate = mountsFolder:FindFirstChild(mountName)
	if not mountTemplate then
		warn(`[MorphService] No se encontró el modelo de mount: {mountName}`)
		return
	end

	local oldCharacter = player.Character
	if not oldCharacter then return end

	-- Si ya es un mount, usar el OriginalCharacter interno para no anidar mounts
	local existingOriginal = oldCharacter:FindFirstChild("OriginalCharacter")
	local sourceCharacter = existingOriginal or oldCharacter

	local oldHRP = oldCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not oldHRP then return end

	local spawnCFrame = oldHRP.CFrame

	local newChar = (mountTemplate :: Model):Clone()
	newChar.Name = player.Name
	newChar:SetAttribute("IsMountCharacter", true)

	local newHRP = newChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not newHRP then
		warn(`[MorphService] El modelo {mountName} no tiene HumanoidRootPart`)
		newChar:Destroy()
		return
	end

	newHRP.CFrame = spawnCFrame

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

	-- Clonar el character original y sentarlo en el mount
	sourceCharacter.Archivable = true
	local cloneCharacter = (sourceCharacter :: Model):Clone()
	cloneCharacter.Name = "OriginalCharacter"

	local animateScript = cloneCharacter:FindFirstChild("Animate")
	if animateScript then animateScript:Destroy() end

	cloneCharacter.Parent = newChar

	local cloneHumanoid = cloneCharacter:FindFirstChildOfClass("Humanoid")
	if cloneHumanoid then
		seat:Sit(cloneHumanoid)
		cloneHumanoid.WalkSpeed = 0
		cloneHumanoid.JumpPower = 0
		cloneHumanoid.AutoRotate = false
	end

	-- Destruir el mount anterior si había uno
	if existingOriginal then
		oldCharacter:Destroy()
	end

	player.Character = newChar
end

return MorphService
