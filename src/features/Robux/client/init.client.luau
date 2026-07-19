--!strict

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local CollectionService  = game:GetService("CollectionService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local DataService = require(ReplicatedStorage.Packages.DataService).client
local RobuxConfig = require(ReplicatedStorage.Shared.RobuxConfig)
local CheckoutAnalytics = require(ReplicatedStorage.Shared.CheckoutAnalytics)

local player = Players.LocalPlayer

local PROMPT_COOLDOWN = 30 -- seconds between prompts per tier
local lastPromptTime: { [string]: number } = {}

local function isOnTreadmill(hrp: BasePart, pp: BasePart): boolean
	local localPos = pp.CFrame:PointToObjectSpace(hrp.Position)
	local half     = pp.Size / 2
	return math.abs(localPos.X) <= half.X
		and math.abs(localPos.Z) <= half.Z
		and localPos.Y >= -1
		and localPos.Y <= half.Y + 8
end

RunService.Heartbeat:Connect(function()
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid?
	if not humanoid or humanoid.Health <= 0 then return end

	for _, model in CollectionService:GetTagged("Treadmill") do
		local tier = (model :: Model):GetAttribute("Robux") :: string?
		if not tier then continue end

		local tierConfig = RobuxConfig.Treadmills[tier]
		if not tierConfig then continue end

		-- Already owned — nothing to prompt
		if DataService:get({ RobuxConfig.treadmillKey(tier) }) == true then continue end

		local pp = (model :: Model).PrimaryPart
		if not pp then continue end
		if not isOnTreadmill(hrp, pp) then continue end

		-- Player is standing on a locked Robux treadmill — prompt purchase
		local now = os.clock()
		if (now - (lastPromptTime[tier] or 0)) < PROMPT_COOLDOWN then continue end

		lastPromptTime[tier] = now
		CheckoutAnalytics.prompt(tierConfig.ProductId, tier)
	end
end)
