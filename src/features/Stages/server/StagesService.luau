--!strict

local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Packets = require(game.ReplicatedStorage.Shared.Packets)

local StagesService = {}

local stagesFolder = Workspace:WaitForChild("Stages") :: Folder

local function getStageNumber(stageName: string): number
	return tonumber(stageName:match("%d+")) or 0
end

function StagesService:init(): ()
	-- Touch detection wired once per stage at startup
	for _, child in stagesFolder:GetChildren() do
		local stage = child :: Model
		local pp = stage.PrimaryPart
		if not pp then continue end
		local stageNum = getStageNumber(stage.Name)
		if stageNum == 0 then continue end

		pp.Touched:Connect(function(hit: BasePart)
			local character = hit:FindFirstAncestorOfClass("Model")
			if not character then return end
			local player = Players:GetPlayerFromCharacter(character)
			if not player then return end
			if player:GetAttribute("LastStage") ~= stageNum then
				player:SetAttribute("LastStage", stageNum)
			end
		end)
	end

	local function setupPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			self:_onCharacterAdded(player, character)
		end)
		if player.Character then
			task.spawn(self._onCharacterAdded, self, player, player.Character)
		end
	end

	Players.PlayerAdded:Connect(setupPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(setupPlayer, player)
	end

	Packets.RequestRevive.OnServerEvent:Connect(function(player: Player)
		self:_handleRevive(player)
	end)
end

function StagesService:_onCharacterAdded(player: Player, character: Model): ()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
		or character:WaitForChild("Humanoid", 5) :: Humanoid?
	if not humanoid then return end

	(humanoid :: Humanoid).Died:Once(function()
		local lastStage = (player:GetAttribute("LastStage") or 0) :: number
		if lastStage < 2 then return end

		task.spawn(function()
			-- Wait for the player to respawn naturally at the base
			local newChar = player.CharacterAdded:Wait()
			;(newChar :: Model):WaitForChild("HumanoidRootPart", 10)
			task.wait(0.3)

			if not player:IsDescendantOf(Players) then return end
			local hum = (newChar :: Model):FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 then return end

			Packets.ShowRevive:FireClient(player)
		end)
	end)
end

function StagesService:_handleRevive(player: Player): ()
	local lastStage = (player:GetAttribute("LastStage") or 0) :: number
	if lastStage < 2 then return end

	local stageModel = stagesFolder:FindFirstChild("Stage " .. lastStage) :: Model?
	if not stageModel then return end
	local pp = stageModel.PrimaryPart
	if not pp then return end

	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	hrp.CFrame = pp.CFrame * CFrame.new(0, 5, -10)
end

return StagesService
