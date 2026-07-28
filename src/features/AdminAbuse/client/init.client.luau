--!strict

-- Receptor de Admin Abuse. Lo corren TODOS los jugadores (no solo admins): escucha
-- AdminAbuseState y muestra un banner fijo en la parte superior con la cuenta
-- regresiva en vivo (o el mensaje estático si el preset no tiene duración). El
-- envío/activación vive en el panel Admin; acá solo se recibe y se muestra.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local Packets = require(ReplicatedStorage.Shared.Packets)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Tamaños de fuente: el mensaje estático ("happening now") va más grande que el
-- de cuenta regresiva, para que el efecto arcoíris destaque más.
local NORMAL_MAX_TEXT_SIZE = 22
local STATIC_MAX_TEXT_SIZE = 34
local NORMAL_BANNER_SIZE   = UDim2.fromOffset(360, 40)
local STATIC_BANNER_SIZE   = UDim2.fromOffset(420, 56)
local RAINBOW_SPEED        = 0.6 -- ciclos del gradient por segundo (scroll)

-- Stroke: negro y más angosto en la cuenta regresiva; blanco y más ancho en el
-- mensaje estático ("happening now"), a juego con el gradient arcoíris.
local NORMAL_STROKE_COLOR     = Color3.fromRGB(0, 0, 0)
local NORMAL_STROKE_THICKNESS = 2
local STATIC_STROKE_COLOR     = Color3.fromRGB(255, 255, 255)
local STATIC_STROKE_THICKNESS = 3

-- Rotación lenta del texto (-10° a 10°) solo durante el mensaje estático.
local ROTATION_MAX_DEGREES = 10
local ROTATION_PERIOD_SECONDS = 4

local gui = Instance.new("ScreenGui")
gui.Name = "AdminAbuse"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 260 -- por encima del banner de Broadcast (250)
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- Sin fondo: solo el texto con stroke es lo que se ve.
local banner = Instance.new("Frame")
banner.Name = "Banner"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.BackgroundTransparency = 1
banner.BorderSizePixel = 0
banner.Position = UDim2.fromScale(0.5, 0)
banner.Size = NORMAL_BANNER_SIZE
banner.Visible = false
banner.Parent = gui

-- Label del STROKE: va DEBAJO (ZIndex menor) y solo existe para dibujar el
-- contorno. Su relleno es invisible (TextTransparency=1) y, al no tener el
-- UIGradient como hermano, su UIStroke no se ve teñido por el arcoíris (un
-- UIGradient afecta el color de CUALQUIER UIStroke hermano del mismo objeto,
-- no solo el TextColor3 — por eso van separados en dos labels).
local strokeLabel = Instance.new("TextLabel")
strokeLabel.Name = "StrokeLabel"
strokeLabel.BackgroundTransparency = 1
strokeLabel.Size = UDim2.fromScale(1, 1)
strokeLabel.Font = Enum.Font.FredokaOne
strokeLabel.Text = ""
strokeLabel.TextTransparency = 1
strokeLabel.TextScaled = true
strokeLabel.TextWrapped = true
strokeLabel.ZIndex = 1
strokeLabel.Parent = banner

local strokeTextConstraint = Instance.new("UITextSizeConstraint")
strokeTextConstraint.MaxTextSize = NORMAL_MAX_TEXT_SIZE
strokeTextConstraint.MinTextSize = 12
strokeTextConstraint.Parent = strokeLabel

local stroke = Instance.new("UIStroke")
stroke.Color = NORMAL_STROKE_COLOR
stroke.Thickness = NORMAL_STROKE_THICKNESS
stroke.Parent = strokeLabel

-- Label del RELLENO: va ENCIMA, sin stroke propio (el contorno lo pone el de abajo).
local label = Instance.new("TextLabel")
label.BackgroundTransparency = 1
label.Size = UDim2.fromScale(1, 1)
label.Font = Enum.Font.FredokaOne
label.Text = ""
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.TextStrokeTransparency = 1
label.TextScaled = true
label.TextWrapped = true
label.ZIndex = 2
label.Parent = banner

local textConstraint = Instance.new("UITextSizeConstraint")
textConstraint.MaxTextSize = NORMAL_MAX_TEXT_SIZE
textConstraint.MinTextSize = 12
textConstraint.Parent = label

-- Gradient arcoíris: solo se activa para el mensaje estático ("happening now").
-- Desactivado (Enabled=false), el label se ve con su TextColor3 blanco normal.
-- Vive SOLO en el label de relleno, así el stroke (label separado) no lo hereda.
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
	ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
	ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
	ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
	ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
	ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
})
gradient.Enabled = false
gradient.Parent = label

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingRight = UDim.new(0, 10)
padding.Parent = banner

-- generation invalida el loop de countdown/rainbow anterior cuando llega un
-- estado nuevo.
local generation = 0
local rainbowConnection: RBXScriptConnection? = nil

-- El label del stroke debe quedar SIEMPRE encimado con el de relleno (mismo
-- texto, tamaño y rotación), o el contorno se desalinea del texto visible.
local function setDisplayText(text: string)
	label.Text = text
	strokeLabel.Text = text
end

local function setMaxTextSize(size: number)
	textConstraint.MaxTextSize = size
	strokeTextConstraint.MaxTextSize = size
end

local function setRotation(degrees: number)
	label.Rotation = degrees
	strokeLabel.Rotation = degrees
end

local function stopRainbow()
	if rainbowConnection then
		rainbowConnection:Disconnect()
		rainbowConnection = nil
	end
	gradient.Enabled = false
	setRotation(0)
end

-- Gradient arcoíris en scroll + rotación oscilante (-10° a 10°, lenta) del texto.
local function startRainbow()
	stopRainbow()
	gradient.Enabled = true
	local elapsed = 0
	local angularSpeed = (2 * math.pi) / ROTATION_PERIOD_SECONDS
	rainbowConnection = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		gradient.Offset = Vector2.new((elapsed * RAINBOW_SPEED) % 2 - 1, 0)
		setRotation(math.sin(elapsed * angularSpeed) * ROTATION_MAX_DEGREES)
	end)
end

local function formatClock(secondsLeft: number): string
	secondsLeft = math.max(0, math.floor(secondsLeft))
	local minutes = math.floor(secondsLeft / 60)
	local seconds = secondsLeft % 60
	return string.format("%d:%02d", minutes, seconds)
end

local function hide()
	generation += 1
	stopRainbow()
	banner.Visible = false
end

-- Mensaje estático ("happening now"): texto más grande + gradient arcoíris en
-- movimiento en vez del blanco plano.
local function showStatic(message: string)
	generation += 1
	stopRainbow()
	setDisplayText(message)
	setMaxTextSize(STATIC_MAX_TEXT_SIZE)
	banner.Size = STATIC_BANNER_SIZE
	stroke.Color = STATIC_STROKE_COLOR
	stroke.Thickness = STATIC_STROKE_THICKNESS
	banner.Visible = true
	startRainbow()
end

local function showCountdown(message: string, endTime: number)
	generation += 1
	local myGen = generation
	stopRainbow()
	setMaxTextSize(NORMAL_MAX_TEXT_SIZE)
	banner.Size = NORMAL_BANNER_SIZE
	stroke.Color = NORMAL_STROKE_COLOR
	stroke.Thickness = NORMAL_STROKE_THICKNESS
	banner.Visible = true

	task.spawn(function()
		while myGen == generation do
			local secondsLeft = endTime - os.time()
			if secondsLeft <= 0 then
				setDisplayText(message)
				break
			end
			setDisplayText(string.format("%s %s", message, formatClock(secondsLeft)))
			task.wait(1)
		end
	end)
end

Packets.AdminAbuseState.OnClientEvent:Connect(function(active: boolean, message: string, endTime: number)
	if type(active) ~= "boolean" or type(message) ~= "string" or type(endTime) ~= "number" then return end

	if not active then
		hide()
		return
	end

	if endTime > 0 then
		showCountdown(message, endTime)
	else
		showStatic(message)
	end
end)
