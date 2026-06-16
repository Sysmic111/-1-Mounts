--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MorphService = {}

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
