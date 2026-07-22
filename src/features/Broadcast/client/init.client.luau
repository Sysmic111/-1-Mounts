--!strict

-- Receptor del mensaje global admin. Lo corren TODOS los jugadores (no solo
-- admins): escucha ShowBroadcast y muestra un banner en el centro superior de la
-- pantalla. El envío vive en el panel Admin; aquí solo se recibe y se muestra.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local Packets = require(ReplicatedStorage.Shared.Packets)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local HOLD_TIME = 5      -- segundos visible antes de desvanecer
local FADE_TIME = 0.6

local gui = Instance.new("ScreenGui")
gui.Name = "AdminBroadcast"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 250   -- por encima del resto de la UI
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local activeBanner: CanvasGroup? = nil
local generation = 0

-- Escapa los caracteres que RichText interpreta como markup, para que un mensaje
-- con < > & se muestre literal en vez de romper el formato.
local function escapeRich(s: string): string
	s = s:gsub("&", "&amp;")
	s = s:gsub("<", "&lt;")
	s = s:gsub(">", "&gt;")
	return s
end

-- Badge de verificado de Roblox: es un glifo Unicode (privado, 0xE000) que las
-- fuentes de Roblox renderizan como el ícono. Va FUERA del <font> dorado para que
-- conserve su color azul nativo.
local VERIFIED_BADGE = utf8.char(0xE000)

local function showBroadcast(senderName: string, message: string, verified: boolean)
	generation += 1
	local myGen = generation

	if activeBanner then
		activeBanner:Destroy()
		activeBanner = nil
	end

	-- Solo texto: sin fondo, sin borde. El CanvasGroup se mantiene solo para el fade
	-- de grupo (GroupTransparency). El contraste lo da el TextStroke del label.
	local banner = Instance.new("CanvasGroup")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 90)
	banner.Size = UDim2.new(0.8, 0, 0, 110)
	banner.BackgroundTransparency = 1
	banner.BorderSizePixel = 0
	banner.GroupTransparency = 0
	banner.Parent = gui

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(360, 110)
	sizeConstraint.MaxSize = Vector2.new(900, 320)
	sizeConstraint.Parent = banner

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.RichText = true
	-- "Nombre:" en dorado (#FFD700); el resto (TextColor3) en blanco. Ambos escapados
	-- para que el markup no se rompa con < > &. Si el emisor está verificado, el badge
	-- va delante del nombre (fuera del <font> para no teñirlo).
	local badge = if verified then VERIFIED_BADGE .. " " else ""
	label.Text = if senderName ~= ""
		then `{badge}<font color="#FFD700">{escapeRich(senderName)}:</font> {escapeRich(message)}`
		else escapeRich(message)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextWrapped = true
	label.TextScaled = true
	-- Sin fondo: el stroke más marcado mantiene el texto legible sobre cualquier escena.
	label.TextStrokeColor3 = Color3.fromRGB(16, 20, 30)
	label.TextStrokeTransparency = 0.25
	label.Parent = banner

	local textConstraint = Instance.new("UITextSizeConstraint")
	textConstraint.MaxTextSize = 46
	textConstraint.MinTextSize = 18
	textConstraint.Parent = label

	-- Entrada
	local scale = Instance.new("UIScale")
	scale.Scale = 0.85
	scale.Parent = banner
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(banner, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 100),
	}):Play()

	activeBanner = banner

	task.delay(HOLD_TIME, function()
		if myGen ~= generation or activeBanner ~= banner or not banner.Parent then return end
		TweenService:Create(banner, TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			GroupTransparency = 1,
			Position = UDim2.new(0.5, 0, 0, 90),
		}):Play()
		task.delay(FADE_TIME, function()
			if myGen ~= generation or activeBanner ~= banner then return end
			activeBanner = nil
			banner:Destroy()
		end)
	end)
end

Packets.ShowBroadcast.OnClientEvent:Connect(function(senderName: string, message: string, verified: boolean)
	if type(message) ~= "string" or message == "" then return end
	showBroadcast(if type(senderName) == "string" then senderName else "", message, verified == true)
end)
