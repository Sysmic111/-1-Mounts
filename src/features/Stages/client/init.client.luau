--!strict

local Players            = game:GetService("Players")
local TweenService       = game:GetService("TweenService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local Packets      = require(ReplicatedStorage.Shared.Packets)
local MenuManager  = require(ReplicatedStorage.Shared.MenuManager)
local ReviveConfig = require(ReplicatedStorage.Shared.ReviveConfig)
local DataService  = require(ReplicatedStorage.Packages.DataService).client
local CheckoutAnalytics = require(ReplicatedStorage.Shared.CheckoutAnalytics)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local menus       = playerGui:WaitForChild("Menus")
local reviveFrame = menus:WaitForChild("Revive") :: Frame
local fill        = reviveFrame:WaitForChild("Progress"):WaitForChild("Fill") :: Frame
local reviveBtn   = reviveFrame:WaitForChild("Revive") :: ImageButton
local closeBtn    = reviveFrame:WaitForChild("Right"):WaitForChild("Close") :: ImageButton

-- El botón Revive muestra el costo con estos dos hijos (icono de Robux + precio).
-- Para dueños de Infinite Revives se ocultan y el revive es gratis.
local reviveCostIcon  = reviveBtn:WaitForChild("ImageLabel") :: ImageLabel
local reviveCostLabel = reviveBtn:WaitForChild("CardName")   :: TextLabel

local function ownsInfiniteRevives(): boolean
	return DataService:get({ "InfiniteRevives" }) == true
end

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

	-- Dueños de Infinite Revives: sin costo, revive gratis. Resto: se muestra el
	-- icono de Robux + el precio, y el botón lanza la compra por uso.
	local owner = ownsInfiniteRevives()
	reviveCostIcon.Visible = not owner
	reviveCostLabel.Text   = owner and "Revive" or "9"
	if not owner then
		CheckoutAnalytics.show(ReviveConfig.ReviveOnceProductId, "ReviveOnce")
	end

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
		if ownsInfiniteRevives() then
			-- Revive gratis: el servidor valida la propiedad antes de teleportar.
			Packets.RequestRevive:Fire()
			closeRevive()
		else
			-- Revive por uso: el teleport lo hace el servidor al procesar el recibo.
			CheckoutAnalytics.prompt(ReviveConfig.ReviveOnceProductId, "ReviveOnce")
		end
	end)

	closeConn = closeBtn.Activated:Connect(closeRevive)
end

Packets.ShowRevive.OnClientEvent:Connect(openRevive)

-- ── Botón "Infinite Revives" (panel Right) ────────────────────────────────────

task.spawn(function()
	local right  = playerGui:WaitForChild("Right")
	local button = right:WaitForChild("Main"):WaitForChild("Line1")
		:WaitForChild("InfiniteRevives") :: ImageButton

	-- Oferta única: al comprarse, el botón desaparece (la UIListLayout recoloca).
	local function refresh()
		button.Visible = not ownsInfiniteRevives()
		if button.Visible then
			CheckoutAnalytics.show(ReviveConfig.InfiniteRevivesProductId, "InfiniteRevives")
		end
	end

	button.Activated:Connect(function()
		if ownsInfiniteRevives() then return end
		CheckoutAnalytics.prompt(ReviveConfig.InfiniteRevivesProductId, "InfiniteRevives")
	end)

	DataService:waitForData()
	refresh()
	DataService:getChangedSignal({ "InfiniteRevives" }):Connect(refresh)
end)
