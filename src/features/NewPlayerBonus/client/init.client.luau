--!strict

-- Botón de la oferta de jugador nuevo (clon de ReplicatedStorage.NewPlayerBonus)
-- dentro del ScreenGui Temporal, más el aviso al intentar salir del juego.
--
-- La cuenta regresiva se pinta contra el os.time() ABSOLUTO que manda el servidor,
-- no contando segundos localmente: un tab en segundo plano o un frame drop harían
-- que un contador local se fuera quedando corto, y el jugador vería 00:00 antes o
-- después de que el servidor lo dé por bueno.
--
-- SOBRE EL AVISO AL SALIR: Roblox NO deja interceptar ni cancelar el botón "Leave
-- Game" — vive en CoreGui y no expone callback. Lo único enganchable es
-- GuiService.MenuOpened, que dispara al abrir el menú de Roblox, que es el paso
-- previo obligatorio para pulsar Leave. Por eso el aviso sale ahí y se retira al
-- cerrar el menú. Si el jugador cierra la app o pierde conexión no hay aviso
-- posible; no es una limitación de este código.

local GuiService        = game:GetService("GuiService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local Packets = require(ReplicatedStorage.Shared.Packets)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local template = ReplicatedStorage:WaitForChild("NewPlayerBonus") :: ImageButton
local temporal = playerGui:WaitForChild("Temporal") :: ScreenGui

local PULSE_PERIOD = 0.6 -- segundos por medio ciclo del latido cuando ya es reclamable

-- ── Estado ───────────────────────────────────────────────────────────────────

-- os.time() absoluto en que el bonus pasa a reclamable. nil = no hay oferta activa.
local readyTime: number? = nil
local claiming = false
-- Invalida el loop de cuenta regresiva anterior cuando llega un estado nuevo.
local generation = 0

local button: ImageButton? = nil
local titleLabel: TextLabel? = nil
local pulseTween: Tween? = nil

-- Tamaño de la plantilla y su versión "inflada" para el latido. Se calculan una vez
-- porque UDim2 no soporta multiplicación: hay que rearmarlo componente a componente.
local BASE_SIZE = template.Size
local PULSE_SIZE = UDim2.new(
	BASE_SIZE.X.Scale * 1.1, BASE_SIZE.X.Offset * 1.1,
	BASE_SIZE.Y.Scale * 1.1, BASE_SIZE.Y.Offset * 1.1
)

local function secondsLeft(): number
	if not readyTime then return 0 end
	return math.max(0, (readyTime :: number) - os.time())
end

local function formatClock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- ── Banner superior (aviso al salir + confirmación del claim) ────────────────

-- ScreenGui propio y no el Temporal: necesita IgnoreGuiInset y un DisplayOrder muy
-- alto para quedar por encima del resto de la UI. Aun así el panel del menú de
-- Roblox oscurece el centro de la pantalla, de ahí que el banner vaya pegado arriba.
local bannerGui = Instance.new("ScreenGui")
bannerGui.Name = "NewPlayerBonusWarning"
bannerGui.ResetOnSpawn = false
bannerGui.IgnoreGuiInset = true
bannerGui.DisplayOrder = 300 -- por encima de AdminAbuse (260) y Broadcast (250)
bannerGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
bannerGui.Enabled = false
bannerGui.Parent = playerGui

local bannerLabel = Instance.new("TextLabel")
bannerLabel.Name = "Message"
bannerLabel.AnchorPoint = Vector2.new(0.5, 0)
bannerLabel.Position = UDim2.new(0.5, 0, 0, 12)
bannerLabel.Size = UDim2.new(0.9, 0, 0, 76)
bannerLabel.BackgroundTransparency = 1
bannerLabel.Font = Enum.Font.FredokaOne
bannerLabel.Text = ""
bannerLabel.TextColor3 = Color3.fromRGB(255, 230, 120)
bannerLabel.TextScaled = true
bannerLabel.TextWrapped = true
bannerLabel.TextStrokeTransparency = 1
bannerLabel.Parent = bannerGui

local bannerConstraint = Instance.new("UITextSizeConstraint")
bannerConstraint.MaxTextSize = 38
bannerConstraint.MinTextSize = 14
bannerConstraint.Parent = bannerLabel

local bannerStroke = Instance.new("UIStroke")
bannerStroke.Color = Color3.fromRGB(0, 0, 0)
bannerStroke.Thickness = 3
bannerStroke.Parent = bannerLabel

local bannerGeneration = 0
-- true mientras el banner está mostrando el aviso de salida (y no, por ejemplo, la
-- confirmación del claim). Distinguirlos importa: el aviso hay que refrescarlo cada
-- segundo y retirarlo al cerrar el menú, la confirmación no.
local exitWarningActive = false

local function exitWarningText(left: number): string
	return ("You're only %s away from a FREE Premium Mount. Leave now and you lose it forever!")
		:format(formatClock(left))
end

local function hideBanner()
	bannerGeneration += 1
	exitWarningActive = false
	bannerGui.Enabled = false
end

-- Cualquier banner nuevo apaga el flag del aviso de salida; quien lo quiera activo
-- lo vuelve a poner después (ver MenuOpened).
local function showBanner(text: string, color: Color3, duration: number?)
	bannerGeneration += 1
	exitWarningActive = false
	local myGen = bannerGeneration
	bannerLabel.Text = text
	bannerLabel.TextColor3 = color
	bannerGui.Enabled = true

	if duration then
		task.delay(duration, function()
			if myGen == bannerGeneration then
				bannerGui.Enabled = false
			end
		end)
	end
end

-- ── Botón ────────────────────────────────────────────────────────────────────

local function stopPulse()
	if pulseTween then
		pulseTween:Cancel()
		pulseTween = nil
	end
end

local function destroyButton()
	stopPulse()
	if button then
		button:Destroy()
		button = nil
		titleLabel = nil
	end
end

local function ensureButton(): TextLabel?
	if titleLabel then return titleLabel end

	destroyButton()

	local clone = template:Clone()
	local frame = clone:FindFirstChild("Button")
	local title = frame and frame:FindFirstChild("Title") :: TextLabel?
	if not title then
		clone:Destroy()
		warn("[NewPlayerBonus] la plantilla no tiene Button.Title; no se muestra el botón")
		return nil
	end

	-- Posición y tamaño son los que se autorizaron en Studio: no se tocan desde aquí.
	clone.Parent = temporal

	clone.MouseButton1Click:Connect(function()
		-- Solo se puede reclamar con la cuenta a 0; antes el botón es informativo.
		if claiming or not readyTime or secondsLeft() > 0 then return end
		claiming = true
		Packets.NewPlayerBonusClaim:Fire()
		-- Rearme por si el servidor rechaza (perfil aún sin cargar, p.ej.): sin esto
		-- un solo fallo dejaría el botón muerto para el resto de la sesión.
		task.delay(2, function()
			claiming = false
		end)
	end)

	button = clone
	titleLabel = title
	return title
end

-- ── Cuenta regresiva ─────────────────────────────────────────────────────────

local function runCountdown()
	generation += 1
	local myGen = generation

	local title = ensureButton()
	if not title then return end

	stopPulse()

	task.spawn(function()
		while myGen == generation and titleLabel do
			local left = secondsLeft()
			if left <= 0 then
				title.Text = "Claim Free Premium Mount"
				-- Latido infinito para que el cambio de estado no pase desapercibido
				-- si el jugador estaba mirando a otro lado.
				if button then
					local info = TweenInfo.new(PULSE_PERIOD, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
					pulseTween = TweenService:Create(button, info, { Size = PULSE_SIZE })
					;(pulseTween :: Tween):Play()
				end
				-- Ya no queda nada que perder: el aviso de "si te vas la pierdes"
				-- dejaría de ser cierto.
				hideBanner()
				break
			end
			title.Text = "Free Premium Mount in: " .. formatClock(left)
			-- El menú de Roblox puede quedarse abierto un buen rato: si no se
			-- refrescara aquí, el aviso mostraría el tiempo congelado del momento
			-- en que se abrió.
			if exitWarningActive then
				bannerLabel.Text = exitWarningText(left)
			end
			task.wait(1)
		end
	end)
end

-- ── Packets ──────────────────────────────────────────────────────────────────

Packets.NewPlayerBonusState.OnClientEvent:Connect(function(active: boolean, serverReadyTime: number)
	if type(active) ~= "boolean" or type(serverReadyTime) ~= "number" then return end

	if not active then
		generation += 1
		readyTime = nil
		claiming = false
		destroyButton()
		-- Solo el aviso de salida. State(false) y Result(true) viajan por remotes
		-- distintos y no tienen orden garantizado entre sí: un hideBanner() a secas
		-- se comería la confirmación del claim si llegaran al revés.
		if exitWarningActive then
			hideBanner()
		end
		return
	end

	readyTime = serverReadyTime
	runCountdown()
end)

Packets.NewPlayerBonusResult.OnClientEvent:Connect(function(success: boolean, message: string)
	if type(success) ~= "boolean" or type(message) ~= "string" then return end

	claiming = false
	if success then
		showBanner(
			("%s unlocked! Check your Index."):format(message),
			Color3.fromRGB(140, 255, 160),
			5
		)
	end
end)

-- ── Aviso al intentar salir ──────────────────────────────────────────────────

GuiService.MenuOpened:Connect(function()
	local left = secondsLeft()
	if not readyTime or left <= 0 then return end

	showBanner(exitWarningText(left), Color3.fromRGB(255, 230, 120))
	exitWarningActive = true
end)

GuiService.MenuClosed:Connect(function()
	-- Solo retira el aviso de salida. La confirmación del claim tiene duración
	-- propia y cerrar el menú no debería tragársela.
	if exitWarningActive then
		hideBanner()
	end
end)
