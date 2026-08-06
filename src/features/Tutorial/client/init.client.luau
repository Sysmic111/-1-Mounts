--!strict

-- Tutorial guiado de 7 pasos para el jugador nuevo: treadmill -> wins -> evolve ->
-- steps, que es el bucle completo del juego.
--
-- Es 100% CLIENTE: no hay clave de datos nueva, ni packet nuevo, ni servicio de
-- servidor. El paso actual se DERIVA de datos que ya existen (Level,
-- TotalWinsEarned, Mounts, StepUnlocked_2), así que:
--   · el progreso sobrevive a un rejoin sin guardar nada,
--   · un jugador veterano ya los cumple todos y no ve el tutorial jamás,
--   · el rebirth (que resetea Level a 1) no lo revive, porque para entonces
--     StepUnlocked_2 ya es true.
--
-- Los contadores son ABSOLUTOS, no incrementales ("TotalWinsEarned >= 4", no "3 más
-- desde que empezó el paso"). Un baseline por paso habría que persistirlo.
--
-- Cada paso pinta su título arriba de la pantalla y señala su objetivo de una de dos
-- formas: un Beam de flechas del jugador al objeto del mundo, o una flecha 2D sobre
-- el botón de UI. Las dos usan la misma imagen.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService      = game:GetService("TweenService")

local Packets     = require(ReplicatedStorage.Shared.Packets)
local MenuManager = require(ReplicatedStorage.Shared.MenuManager)
local DataService = require(ReplicatedStorage.Packages.DataService).client

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--------------------------------------------------------------------------------
-- Constantes
--------------------------------------------------------------------------------

local ARROW_ASSET = "rbxassetid://133172207697852"

-- Rotación de la flecha 2D. La imagen se coloca ENCIMA del botón objetivo, así que
-- tiene que apuntar hacia abajo — y las flechas del asset YA apuntan hacia abajo
-- (medido en Studio), así que aquí no hay que girar nada.
--
-- OJO: esa orientación nativa es justo la mala para el Beam. Un Beam mapea la
-- textura con el ancho de la imagen a lo LARGO del haz, así que unas flechas que
-- corren por el eje Y de la imagen salen perpendiculares al haz. Ver applyWorldTarget.
local ARROW_ROTATION = 0

local YELLOW      = Color3.fromRGB(255, 209, 46)
local BLACK       = Color3.fromRGB(0, 0, 0)

-- Nivel/wins objetivo de cada paso.
local LEVEL_GOAL      = 5
local WINS_GOAL_FIRST = 1 -- Stage 2 da exactamente 1 win
local WINS_GOAL_SECOND = 3 -- Stage 3 da exactamente 3 wins
local TUTORIAL_MOUNT  = "Moru" -- MountsConfig.World1[2]
local TUTORIAL_STEP_INCREMENT = 2 -- el step x2, Price = 3 en EconomyConfig
local STEP_UNLOCKED_KEY = "StepUnlocked_" .. tostring(TUTORIAL_STEP_INCREMENT)

local FINAL_HOLD = 5 -- segundos que se queda el mensaje final

local FADE_IN  = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE_OUT = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local BOB      = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

--------------------------------------------------------------------------------
-- Lecturas de datos
--------------------------------------------------------------------------------

local function getLevel(): number
	return (DataService:get({ "Level" }) or 1) :: number
end

local function getTotalWins(): number
	return (DataService:get({ "TotalWinsEarned" }) or 0) :: number
end

local function hasTutorialMount(): boolean
	local mounts = (DataService:get({ "Mounts" }) or {}) :: { [string]: boolean }
	return mounts[TUTORIAL_MOUNT] == true
end

-- StepUnlocked_<N> es una clave PLANA creada on-demand al comprar: no está en el
-- template salvo StepUnlocked_1, así que no es fiable suscribirse a su changed
-- signal. La compra se detecta con Packets.StepActivated (ver más abajo) y esta
-- lectura solo se usa para derivar el paso al entrar.
local stepBoughtThisSession = false
local function hasTutorialStep(): boolean
	return stepBoughtThisSession or DataService:get({ STEP_UNLOCKED_KEY }) == true
end

--------------------------------------------------------------------------------
-- HUD: el título de arriba
--------------------------------------------------------------------------------

-- DisplayOrder 240: por debajo del banner de AdminAbuse (260), la cuenta atrás de
-- Race (280) y el aviso de NewPlayerBonus (300); por encima del LevelUp (100).
local gui = Instance.new("ScreenGui")
gui.Name = "Tutorial"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 240
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.BackgroundTransparency = 1
titleLabel.AnchorPoint = Vector2.new(0.5, 0)
titleLabel.Position = UDim2.fromScale(0.5, 0.06)
titleLabel.Size = UDim2.fromScale(0.6, 0.09)
titleLabel.FontFace = Font.fromName("FredokaOne")
titleLabel.Text = ""
-- Blanco + UIGradient amarillo: el gradient MULTIPLICA, así que sobre blanco da el
-- amarillo limpio. Con el TextColor3 ya amarillo saldría apagado.
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextScaled = true
titleLabel.TextTransparency = 1
-- El contorno va con UIStroke, no con el TextStroke nativo (mismo criterio que Race
-- y AdminAbuse: así se controla el grosor).
titleLabel.TextStrokeTransparency = 1
titleLabel.Visible = false
titleLabel.Parent = gui

local titleGradient = Instance.new("UIGradient")
titleGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 150)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 200, 40)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(238, 150, 25)),
})
titleGradient.Rotation = 90
titleGradient.Parent = titleLabel

local titleStroke = Instance.new("UIStroke")
titleStroke.Color = BLACK
titleStroke.Thickness = 4
titleStroke.Transparency = 1
titleStroke.LineJoinMode = Enum.LineJoinMode.Round
titleStroke.Parent = titleLabel

local titleSize = Instance.new("UITextSizeConstraint")
titleSize.MinTextSize = 22
titleSize.MaxTextSize = 52
titleSize.Parent = titleLabel

local shownText = ""

local function setTitle(text: string): ()
	if text == shownText then return end
	local firstTime = shownText == ""
	shownText = text
	titleLabel.Text = text
	titleLabel.Visible = true
	if firstTime then
		TweenService:Create(titleLabel, FADE_IN, { TextTransparency = 0 }):Play()
		TweenService:Create(titleStroke, FADE_IN, { Transparency = 0 }):Play()
	end
end

--------------------------------------------------------------------------------
-- Flecha 2D sobre un botón de UI (pasos 3 y 4)
--------------------------------------------------------------------------------

-- La flecha se PARENTEA al botón objetivo, igual que hace NotifyBadge con el badge
-- "!". Todo va en escala relativa al botón (posición, tamaño y el vaivén), así que se
-- mueve y se redimensiona con él sin importar la resolución. La versión anterior la
-- colocaba en píxeles absolutos desde AbsolutePosition y en pantallas distintas
-- acababa más arriba o más abajo, hasta parecer que señalaba al botón de al lado.
--
-- `Left.Main.Line1` es un UIListLayout vertical con Padding = 0 y botones del 10% de
-- alto: no hay hueco entre ellos, así que la COLA de la flecha sobresale sobre el
-- botón vecino. Lo que no puede salirse es la PUNTA (la flecha apunta hacia abajo, así
-- que la punta es el borde inferior = la Position, con AnchorPoint 1 en Y): mientras
-- caiga dentro del rect de Evolve, se lee sin ambigüedad. Por eso el vaivén se mueve
-- entre 0.40 y 0.24 del alto del botón y no más arriba: por encima de ~0.20 la punta
-- se sale por arriba y vuelve a parecer que señala al botón vecino.
local ARROW_LOW  = UDim2.fromScale(0.5, 0.40)
local ARROW_HIGH = UDim2.fromScale(0.5, 0.24)

-- Alto de la flecha en fracción del alto del botón. La del menú Evolve es mayor: ese
-- botón es más grande y la flecha se pierde con la proporción del panel.
local ARROW_SCALE_PANEL = 1.1
local ARROW_SCALE_MENU  = 1.6

-- `Menus` tiene ZIndexBehavior = Sibling, así que el ZIndex de la flecha SOLO compite
-- dentro del subárbol del botón del que cuelga: subirlo no la saca por delante de los
-- hermanos del botón dentro del menú. Para eso hay que subir el ZIndex del BOTÓN
-- mientras está señalado, y restaurarlo al quitar la flecha.
local ARROW_ZINDEX  = 90
local TARGET_ZINDEX = 90

local arrow = Instance.new("ImageLabel")
arrow.Name = "TutorialArrow"
arrow.BackgroundTransparency = 1
arrow.Image = ARROW_ASSET
arrow.ImageColor3 = YELLOW
-- Fit: la imagen conserva SU proporción dentro del cuadro, así que no se estira aunque
-- el asset no sea cuadrado.
arrow.ScaleType = Enum.ScaleType.Fit
-- Anclada por abajo: la Position marca el borde INFERIOR de la flecha, así que la
-- separación con el botón se mide desde su parte de arriba.
arrow.AnchorPoint = Vector2.new(0.5, 1)
arrow.Rotation = ARROW_ROTATION
arrow.ZIndex = ARROW_ZINDEX
arrow.Visible = false

local arrowRatio = Instance.new("UIAspectRatioConstraint")
arrowRatio.AspectRatio = 1
arrowRatio.DominantAxis = Enum.DominantAxis.Height
arrowRatio.Parent = arrow

local arrowTween: Tween? = nil
local arrowTarget: GuiObject? = nil
local targetZIndex = 1 -- el ZIndex original del botón señalado, para devolvérselo

local function hideArrow(): ()
	if arrowTween then
		arrowTween:Cancel()
		arrowTween = nil
	end
	if arrowTarget then
		arrowTarget.ZIndex = targetZIndex
	end
	arrowTarget = nil
	arrow.Visible = false
	arrow.Parent = nil
end

local function showArrowOn(target: GuiObject, heightScale: number): ()
	if arrowTarget == target then return end
	hideArrow()
	arrowTarget = target
	targetZIndex = target.ZIndex
	target.ZIndex = TARGET_ZINDEX
	arrow.Size = UDim2.fromScale(1, heightScale)
	arrow.Parent = target
	arrow.Visible = true

	-- Vaivén vertical pegado al borde superior del botón: el extremo bajo incluso lo
	-- solapa, porque los botones del panel van en columna y separarla más la hacía
	-- leer como si señalase al de arriba.
	arrow.Position = ARROW_LOW
	local tween = TweenService:Create(arrow, BOB, { Position = ARROW_HIGH })
	arrowTween = tween
	tween:Play()
end

--------------------------------------------------------------------------------
-- Beam hacia un objeto del mundo (pasos 1, 2, 5 y 6)
--------------------------------------------------------------------------------

local originAtt: Attachment? = nil
local targetAtt: Attachment? = nil
local beam: Beam? = nil
local currentTargetPart: BasePart? = nil

-- Recrea el attachment de origen si el personaje cambió (respawn, o el morph de
-- MorphService que sustituye el Character entero por el rig de la montura).
local function ensureBeam(): boolean
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return false end

	if originAtt and originAtt.Parent == hrp and beam then return true end

	if beam then
		beam:Destroy()
	end
	if originAtt then
		originAtt:Destroy()
	end

	local att = Instance.new("Attachment")
	att.Name = "TutorialBeamOrigin"
	att.Parent = hrp
	originAtt = att

	local newBeam = Instance.new("Beam")
	newBeam.Name = "TutorialBeam"
	newBeam.Attachment0 = att
	newBeam.Texture = ARROW_ASSET
	-- Static: las flechas conservan su tamaño real y se repiten a lo largo del
	-- recorrido, en vez de estirarse una sola de punta a punta.
	newBeam.TextureMode = Enum.TextureMode.Static
	newBeam.TextureLength = 4
	newBeam.TextureSpeed = 2 -- fluyen hacia el objetivo
	newBeam.Width0 = 1.6
	newBeam.Width1 = 1.6
	newBeam.FaceCamera = true
	newBeam.LightInfluence = 0
	newBeam.CurveSize0 = 0
	newBeam.CurveSize1 = 0
	newBeam.Segments = 10
	newBeam.Color = ColorSequence.new(YELLOW)
	newBeam.Enabled = false
	newBeam.Parent = att
	beam = newBeam

	-- El attachment de destino no cuelga del personaje, así que sobrevive al
	-- respawn: solo hay que re-enlazarlo al Beam nuevo.
	if targetAtt then
		newBeam.Attachment1 = targetAtt
		newBeam.Enabled = true
	end
	return true
end

local function clearWorldTarget(): ()
	currentTargetPart = nil
	if targetAtt then
		targetAtt:Destroy()
		targetAtt = nil
	end
	if beam then
		beam.Attachment1 = nil
		beam.Enabled = false
	end
end

local function applyWorldTarget(part: BasePart?): ()
	if part == currentTargetPart then
		-- Mismo objetivo: solo hay que asegurar que el beam sigue vivo tras un
		-- respawn y que el objetivo no salió por streaming.
		if part and part.Parent == nil then
			clearWorldTarget()
		end
		return
	end

	clearWorldTarget()
	if not part then return end
	if not ensureBeam() then return end

	local att = Instance.new("Attachment")
	att.Name = "TutorialBeamTarget"
	att.Parent = part
	targetAtt = att
	currentTargetPart = part

	local activeBeam = beam :: Beam
	-- La textura de un Beam se orienta sola a lo largo del haz y no tiene propiedad
	-- de rotación: lo único que se puede hacer es invertir el sentido cambiando de
	-- orden estos dos.
	--
	-- Las flechas de este asset corren por el eje Y de la imagen (apuntan hacia
	-- abajo), y el Beam mapea el eje X a lo largo del haz: van a salir
	-- PERPENDICULARES. El arreglo es re-subir el asset girado 90° — no lo hay por
	-- código. Cuando se re-suba, ARROW_ROTATION pasa a 90 para que la flecha 2D siga
	-- apuntando hacia abajo.
	activeBeam.Attachment1 = att
	activeBeam.Enabled = true
end

--------------------------------------------------------------------------------
-- Resolución de los objetivos del mundo
--------------------------------------------------------------------------------

-- La treadmill gratis más cercana. Mismos filtros que getTreadmillMultiplier en
-- Speed/client: se descartan las de Robux y las que piden rebirths.
local function findStarterTreadmill(): BasePart?
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return nil end

	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, instance in CollectionService:GetTagged("Treadmill") do
		local model = instance :: Model
		if model:GetAttribute("Robux") ~= nil then continue end
		if ((model:GetAttribute("Rebirth") or 0) :: number) > 0 then continue end
		local pp = model.PrimaryPart
		if not pp then continue end
		local distance = (pp.Position - hrp.Position).Magnitude
		if distance < bestDistance then
			bestDistance = distance
			best = pp
		end
	end
	return best
end

-- El TouchPart del botón de Wins NORMAL (no el premium) de un stage. El stage se
-- localiza por el número dentro del nombre, igual que EconomyService:_seedStages, en
-- vez de componer "Stage N": así no depende de cómo esté escrito en el .rbxl. El
-- TouchPart se busca recursivo, igual que WinsService.
local function findStageWinsTouchPart(stageNumber: number): BasePart?
	local stages = workspace:FindFirstChild("Stages")
	if not stages then return nil end
	for _, stage in stages:GetChildren() do
		if tonumber(stage.Name:match("%d+")) ~= stageNumber then continue end
		local button = stage:FindFirstChild("Wins")
		if not button then return nil end
		return button:FindFirstChild("TouchPart", true) :: BasePart?
	end
	return nil
end

local function findStepTouchPart(): BasePart?
	local folder = workspace:FindFirstChild("StepsButtons")
	if not folder then return nil end
	for _, child in folder:GetChildren() do
		if child:GetAttribute("StepsIncresement") == TUTORIAL_STEP_INCREMENT then
			return child:FindFirstChild("TouchPart") :: BasePart?
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- Botones de UI de los pasos 3 y 4
--------------------------------------------------------------------------------

local left  = playerGui:WaitForChild("Left")
local menus = playerGui:WaitForChild("Menus")
local btnEvolve    = left:WaitForChild("Main"):WaitForChild("Line1"):WaitForChild("Evolve") :: ImageButton
local menuEvolve   = menus:WaitForChild("Evolve") :: Frame
local evolveButton = menuEvolve:WaitForChild("Evolve") :: ImageButton

--------------------------------------------------------------------------------
-- Máquina de pasos
--------------------------------------------------------------------------------

local STEP_TREADMILL = 1
local STEP_FIRST_WIN = 2
local STEP_OPEN_MENU = 3
local STEP_EVOLVE    = 4
local STEP_MORE_WINS = 5
local STEP_BUY_STEP  = 6
local STEP_FINAL     = 7

local function computeStep(): number
	if hasTutorialStep() then return STEP_FINAL end
	if hasTutorialMount() then
		return getTotalWins() >= (WINS_GOAL_FIRST + WINS_GOAL_SECOND) and STEP_BUY_STEP or STEP_MORE_WINS
	end
	if getLevel() >= LEVEL_GOAL then
		if getTotalWins() >= WINS_GOAL_FIRST then
			-- El único paso que no se deriva de datos: es estado de UI. Si el
			-- jugador cierra el menú se vuelve a pedir que lo abra.
			return MenuManager.isOpen(menuEvolve) and STEP_EVOLVE or STEP_OPEN_MENU
		end
		return STEP_FIRST_WIN
	end
	return STEP_TREADMILL
end

local finished = false
local finalScheduled = false
local running = false

-- Paso 4 del funnel del tutorial ("Evolve Menu Opened"). Es el único que el servidor
-- no puede derivar del perfil, porque abrir un menú es estado de UI. Se manda una
-- sola vez por sesión; FunnelService lo valida contra su whitelist, lo pasa por el
-- rate limit y lo ignora si el paso ya estaba registrado.
local FUNNEL_STEP_MENU_OPENED = 4
local menuOpenedReported = false

local function reportMenuOpened(): ()
	if menuOpenedReported then return end
	menuOpenedReported = true
	Packets.TutorialFunnelStep:Fire(FUNNEL_STEP_MENU_OPENED)
end

local function finish(): ()
	if finished then return end
	finished = true
	hideArrow()
	-- La flecha cuelga del botón del .rbxl, no del ScreenGui del tutorial: destruir
	-- `gui` no se la lleva.
	arrow:Destroy()
	clearWorldTarget()

	local fade = TweenService:Create(titleLabel, FADE_OUT, { TextTransparency = 1 })
	TweenService:Create(titleStroke, FADE_OUT, { Transparency = 1 }):Play()
	fade.Completed:Connect(function()
		if beam then
			beam:Destroy()
		end
		if originAtt then
			originAtt:Destroy()
		end
		beam, originAtt = nil, nil
		gui:Destroy()
	end)
	fade:Play()
end

local function refresh(): ()
	if finished or not running then return end

	local step = computeStep()

	if step == STEP_TREADMILL then
		setTitle(("Train on treadmill until you reach level (%d/%d)")
			:format(math.min(getLevel(), LEVEL_GOAL), LEVEL_GOAL))
		hideArrow()
		applyWorldTarget(findStarterTreadmill())

	elseif step == STEP_FIRST_WIN then
		setTitle(("Collect (%d/%d) Wins")
			:format(math.min(getTotalWins(), WINS_GOAL_FIRST), WINS_GOAL_FIRST))
		hideArrow()
		applyWorldTarget(findStageWinsTouchPart(2))

	elseif step == STEP_OPEN_MENU then
		setTitle("Click the evolve button")
		clearWorldTarget()
		showArrowOn(btnEvolve, ARROW_SCALE_PANEL)

	elseif step == STEP_EVOLVE then
		setTitle("Evolve (0/1) time")
		clearWorldTarget()
		showArrowOn(evolveButton, ARROW_SCALE_MENU)
		reportMenuOpened()

	elseif step == STEP_MORE_WINS then
		setTitle(("Collect (%d/%d) Wins")
			:format(math.clamp(getTotalWins() - WINS_GOAL_FIRST, 0, WINS_GOAL_SECOND), WINS_GOAL_SECOND))
		hideArrow()
		applyWorldTarget(findStageWinsTouchPart(3))

	elseif step == STEP_BUY_STEP then
		setTitle("Buy a step upgrade")
		hideArrow()
		applyWorldTarget(findStepTouchPart())

	else
		setTitle("Enjoy the game, don't forget to rebirth!")
		hideArrow()
		clearWorldTarget()
		if not finalScheduled then
			finalScheduled = true
			task.delay(FINAL_HOLD, finish)
		end
	end
end

--------------------------------------------------------------------------------
-- Arranque
--------------------------------------------------------------------------------

local function start(): ()
	running = true
	gui.Parent = playerGui

	DataService:getChangedSignal({ "Level" }):Connect(refresh)
	DataService:getChangedSignal({ "TotalWinsEarned" }):Connect(refresh)
	DataService:getChangedSignal({ "Mounts" }):Connect(refresh)

	-- Señal directa del evolve, por si el changed signal de Mounts (tabla anidada)
	-- llega tarde: el paso 4 no puede quedarse colgado con la montura ya concedida.
	Packets.EvolveMountResult.OnClientEvent:Connect(function()
		task.defer(refresh)
	end)

	-- La compra del step llega por packet, no por la clave plana StepUnlocked_2.
	Packets.StepActivated.OnClientEvent:Connect(function(increment: number)
		if increment == TUTORIAL_STEP_INCREMENT then
			stepBoughtThisSession = true
		end
		refresh()
	end)

	-- MenuManager no expone una señal de apertura; MenuAnimations mueve Visible en
	-- los dos sentidos, así que sirve para alternar entre los pasos 3 y 4.
	menuEvolve:GetPropertyChangedSignal("Visible"):Connect(refresh)
	btnEvolve.MouseButton1Click:Connect(function()
		task.defer(refresh)
	end)

	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		refresh()
	end)

	refresh()

	-- Con StreamingEnabled el objetivo puede no existir todavía o desaparecer al
	-- alejarse, y el personaje cambia de instancia al morphear. Re-resolver en
	-- bucle es lo único robusto: el título sigue visible mientras tanto.
	task.spawn(function()
		while not finished do
			task.wait(0.5)
			if finished then break end
			ensureBeam()
			refresh()
		end
	end)
end

task.spawn(function()
	DataService:waitForData()
	-- Cuenta veterana: ya compró el step x2, no se construye nada.
	if hasTutorialStep() then
		gui:Destroy()
		arrow:Destroy()
		return
	end
	start()
end)
