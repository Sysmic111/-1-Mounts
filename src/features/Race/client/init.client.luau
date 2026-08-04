--!strict

-- Cliente de las carreras contra NPC. No decide nada: el servidor manda cuándo abrir
-- el menú (RaceOpen), qué número toca (RaceCountdown) y quién ganó (RaceResult).
-- Aquí solo se pinta.
--
-- El menú Menus.Race vive en el .rbxl (Title, Description, botón Race, Right.Close);
-- la cuenta atrás y el texto de resultado se crean por código.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService      = game:GetService("SoundService")
local TweenService      = game:GetService("TweenService")

local Packets     = require(ReplicatedStorage.Shared.Packets)
local RaceConfig  = require(ReplicatedStorage.Shared.RaceConfig)
local MenuManager = require(ReplicatedStorage.Shared.MenuManager)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local menus    = playerGui:WaitForChild("Menus")
local menuRace = menus:WaitForChild("Race") :: Frame
local title    = menuRace:WaitForChild("Title") :: TextLabel
local btnRace  = menuRace:WaitForChild("Race") :: ImageButton
local btnClose = menuRace:WaitForChild("Right"):WaitForChild("Close") :: ImageButton

local uiSounds     = SoundService:WaitForChild("SFX"):WaitForChild("UI")
local countSound   = uiSounds:WaitForChild("ui_menu_popup_01") :: Sound
local startSound   = SoundService:WaitForChild("SFX"):WaitForChild("sci-fi_power_up_05") :: Sound

local WHITE = Color3.fromRGB(255, 255, 255)
local GREEN = Color3.fromRGB(85, 255, 0)   -- el verde del botón Race del menú
local RED   = Color3.fromRGB(255, 75, 75)

local POP_TIME    = 0.25 -- entrada de cada número
local NUMBER_HOLD = 0.55 -- cuánto se queda antes de desvanecerse
local FADE_TIME   = 0.25
local RESULT_HOLD = 2

-- Stage cuyo menú está abierto. Se manda de vuelta en el RaceAccept.
local pendingStage: number? = nil

--------------------------------------------------------------------------------
-- Overlay de cuenta atrás / resultado
--------------------------------------------------------------------------------

-- Un único ScreenGui con un único TextLabel, reusado para los números y para el
-- texto final. DisplayOrder 280: por encima del banner de AdminAbuse (260) y por
-- debajo del aviso de NewPlayerBonus (300).
local function buildOverlay(): TextLabel
	local gui = Instance.new("ScreenGui")
	gui.Name = "RaceCountdown"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 280
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	local label = Instance.new("TextLabel")
	label.Name = "Value"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.6, 0.3)
	label.FontFace = Font.fromName("FredokaOne")
	label.Text = ""
	label.TextColor3 = WHITE
	label.TextScaled = true
	-- El contorno va con UIStroke, no con el TextStroke nativo (mismo criterio que
	-- AdminAbuse y NewPlayerBonus: se controla el grosor).
	label.TextStrokeTransparency = 1
	label.TextTransparency = 1
	label.Visible = false
	label.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 3
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label

	local sizeConstraint = Instance.new("UITextSizeConstraint")
	sizeConstraint.MinTextSize = 40
	sizeConstraint.MaxTextSize = 180
	sizeConstraint.Parent = label

	return label
end

local overlay = buildOverlay()
local overlayStroke = overlay:FindFirstChildOfClass("UIStroke") :: UIStroke

-- Invalida la animación anterior: si llega un número nuevo (o el resultado) antes de
-- que el anterior termine de desvanecerse, el viejo se abandona sin tocar el label.
local generation = 0

local function showOverlay(text: string, color: Color3, hold: number): ()
	generation += 1
	local myGen = generation

	overlay.Text = text
	overlay.TextColor3 = color
	overlay.Visible = true
	overlay.TextTransparency = 0
	overlayStroke.Transparency = 0
	-- Mismo easing que MenuAnimations.open: entra con un rebote corto.
	overlay.Size = UDim2.fromScale(0.36, 0.18)

	TweenService:Create(
		overlay,
		TweenInfo.new(POP_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(0.6, 0.3) }
	):Play()

	task.delay(hold, function()
		if myGen ~= generation then return end

		local fadeInfo = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(overlay, fadeInfo, { TextTransparency = 1 }):Play()
		TweenService:Create(overlayStroke, fadeInfo, { Transparency = 1 }):Play()

		task.delay(FADE_TIME, function()
			if myGen ~= generation then return end
			overlay.Visible = false
		end)
	end)
end

--------------------------------------------------------------------------------
-- Menú
--------------------------------------------------------------------------------

Packets.RaceOpen.OnClientEvent:Connect(function(stage: number, npcName: string)
	pendingStage = stage
	title.Text = `Race {npcName}?`

	MenuManager.open(menuRace, {
		onClose = function()
			pendingStage = nil
		end,
	})
end)

btnRace.MouseButton1Click:Connect(function()
	local stage = pendingStage
	if not stage then return end

	-- Cerrar antes de disparar: MenuManager.close limpia pendingStage por el onClose,
	-- así que el stage se lee primero.
	MenuManager.close(menuRace)
	Packets.RaceAccept:Fire(stage)
end)

btnClose.MouseButton1Click:Connect(function()
	MenuManager.close(menuRace)
end)

--------------------------------------------------------------------------------
-- Carrera
--------------------------------------------------------------------------------

local lastCountdownStep = RaceConfig.CountdownSteps[#RaceConfig.CountdownSteps]

Packets.RaceCountdown.OnClientEvent:Connect(function(text: string)
	local isStart = text == lastCountdownStep

	if isStart then
		startSound:Play()
		showOverlay(text, GREEN, NUMBER_HOLD)
	else
		countSound:Play()
		showOverlay(text, WHITE, NUMBER_HOLD)
	end
end)

Packets.RaceResult.OnClientEvent:Connect(function(won: boolean, _earned: number)
	if won then
		showOverlay("You Won", GREEN, RESULT_HOLD)
	else
		showOverlay("You Lost", RED, RESULT_HOLD)
	end
end)
