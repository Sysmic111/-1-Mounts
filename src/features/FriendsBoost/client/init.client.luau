--!strict

local Players       = game:GetService("Players")
local SocialService = game:GetService("SocialService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local frame       = playerGui:WaitForChild("Bot"):WaitForChild("FriendsBoost") :: Frame
local actualBoost = frame:WaitForChild("ActualBoost") :: TextLabel
local inviteBtn   = frame:WaitForChild("Invite")      :: ImageButton

-- El boost llega como atributo del Player (lo setea FriendsBoostService y replica).
local function refresh()
	local boost = (player:GetAttribute("FriendsBoost") or 1) :: number
	-- Los valores son múltiplos exactos de 0.25, así que tostring los muestra limpio
	-- (x1, x1.25, x1.5, x3.25…).
	actualBoost.Text = "Friends Boost: x" .. tostring(boost)
end

refresh()
player:GetAttributeChangedSignal("FriendsBoost"):Connect(refresh)

-- Botón Add: abre el modal nativo de Roblox para invitar amigos.
inviteBtn.MouseButton1Click:Connect(function()
	local canInvite = false
	local ok, result = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	if ok then canInvite = result end
	if not canInvite then return end

	pcall(function()
		SocialService:PromptGameInvite(player)
	end)
end)
