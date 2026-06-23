--!strict

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packets        = require(ReplicatedStorage.Shared.Packets)
local MenuAnimations = require(ReplicatedStorage.Shared.MenuAnimations)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local menus       = playerGui:WaitForChild("Menus")
local reviveFrame = menus:WaitForChild("Revive") :: Frame
local fill        = reviveFrame:WaitForChild("Progress"):WaitForChild("Fill") :: Frame
local reviveBtn   = reviveFrame:WaitForChild("Revive") :: ImageButton
local closeBtn    = reviveFrame:WaitForChild("Right"):WaitForChild("Close") :: ImageButton

local TIMER_INFO = TweenInfo.new(5, Enum.EasingStyle.Linear)
local FULL_SIZE  = UDim2.new(1, 0, 1, 0)
local EMPTY_SIZE = UDim2.new(0, 0, 1, 0)

local activeTween: Tween?               = nil
local reviveConn:  RBXScriptConnection? = nil
local closeConn:   RBXScriptConnection? = nil

local function closeRevive()
	if not reviveFrame.Visible then return end

	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end
	if reviveConn then
		reviveConn:Disconnect()
		reviveConn = nil
	end
	if closeConn then
		closeConn:Disconnect()
		closeConn = nil
	end

	MenuAnimations.close(reviveFrame)
	MenuAnimations.blurOut()
end

local function openRevive()
	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end
	if reviveConn then
		reviveConn:Disconnect()
		reviveConn = nil
	end
	if closeConn then
		closeConn:Disconnect()
		closeConn = nil
	end

	fill.Size = FULL_SIZE

	MenuAnimations.blurIn()
	MenuAnimations.open(reviveFrame)

	local tween = TweenService:Create(fill, TIMER_INFO, { Size = EMPTY_SIZE })
	activeTween = tween
	tween:Play()

	tween.Completed:Once(function(state: Enum.PlaybackState)
		if state == Enum.PlaybackState.Completed and activeTween == tween then
			activeTween = nil
			closeRevive()
		end
	end)

	reviveConn = reviveBtn.Activated:Connect(function()
		Packets.RequestRevive:Fire()
		closeRevive()
	end)

	closeConn = closeBtn.Activated:Connect(closeRevive)
end

Packets.ShowRevive.OnClientEvent:Connect(openRevive)
