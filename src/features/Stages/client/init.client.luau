--!strict

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packets     = require(ReplicatedStorage.Shared.Packets)
local MenuManager = require(ReplicatedStorage.Shared.MenuManager)

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

-- Corta el temporizador y suelta las conexiones de los botones. MenuManager la
-- llama al cerrar el Revive venga de donde venga el cierre — incluido que el
-- jugador abra otro menú — para que el timer no siga corriendo de fondo.
local function cleanup()
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
end

local function closeRevive()
	MenuManager.close(reviveFrame)
end

local function openRevive()
	cleanup()

	fill.Size = FULL_SIZE

	MenuManager.open(reviveFrame, { onClose = cleanup })

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
