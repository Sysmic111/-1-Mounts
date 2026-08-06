--!strict

-- Cliente del admin panel. Se construye SOLO si el UserId local está en el
-- allowlist. Esto es puramente cosmético: la seguridad la garantiza AdminService,
-- que revalida en el servidor. Si un no-admin editara su cliente para mostrar el
-- panel y disparar los remotes, el servidor los rechazaría igual.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminConfig          = require(ReplicatedStorage.Shared.AdminConfig)
local MountsConfig         = require(ReplicatedStorage.Shared.MountsConfig)
local AdminAbuseConfig     = require(ReplicatedStorage.Shared.AdminAbuseConfig)
local AdminTreadmillConfig = require(ReplicatedStorage.Shared.AdminTreadmillConfig)
local WeatherConfig        = require(ReplicatedStorage.Shared.WeatherConfig)
local Packets              = require(ReplicatedStorage.Shared.Packets)

local player = Players.LocalPlayer

-- Gate cosmético: si no sos admin, el script no crea nada y termina.
if not AdminConfig.isAdmin(player.UserId) then
	return
end

local playerGui = player:WaitForChild("PlayerGui")

-- Presets de Wins (label -> monto). Por décadas hasta 1T: la economía de World 2
-- se mueve en miles de millones (la cadena de steps son 79.9B y la última montura
-- 40B), así que sin los tramos de arriba el botón no sirve para probar ese mundo.
-- El servidor satura contra MAX_WINS_PER_GRANT.
local WIN_PRESETS = {
	{ label = "+1K",   amount = 1e3 },
	{ label = "+10K",  amount = 1e4 },
	{ label = "+100K", amount = 1e5 },
	{ label = "+1M",   amount = 1e6 },
	{ label = "+10M",  amount = 1e7 },
	{ label = "+100M", amount = 1e8 },
	{ label = "+1B",   amount = 1e9 },
	{ label = "+10B",  amount = 1e10 },
	{ label = "+100B", amount = 1e11 },
	{ label = "+1T",   amount = 1e12 },
}

-- Presets de niveles. El servidor satura contra su propio tope (MAX_LEVEL).
local LEVEL_PRESETS = {
	{ label = "+1",   amount = 1 },
	{ label = "+5",   amount = 5 },
	{ label = "+10",  amount = 10 },
	{ label = "+50",  amount = 50 },
	{ label = "+100", amount = 100 },
}

-- Target seleccionado (por UserId). Arranca en uno mismo.
local selectedUserId: number = player.UserId

-- ── Helpers de UI ────────────────────────────────────────────────────────────

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function makeButton(parent: Instance, text: string, color: Color3): TextButton
	local btn = Instance.new("TextButton")
	btn.BackgroundColor3 = color
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = true
	btn.Font = Enum.Font.FredokaOne
	btn.Text = text
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextScaled = true
	btn.Parent = parent
	corner(btn, 6)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = btn
	local con = Instance.new("UITextSizeConstraint")
	con.MaxTextSize = 18
	con.Parent = btn
	return btn
end

local function makeLabel(parent: Instance, text: string): TextLabel
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.FredokaOne
	lbl.Text = text
	lbl.TextColor3 = Color3.fromRGB(180, 200, 230)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextScaled = true
	lbl.Size = UDim2.new(1, 0, 0, 20)
	lbl.Parent = parent
	local con = Instance.new("UITextSizeConstraint")
	con.MaxTextSize = 16
	con.Parent = lbl
	return lbl
end

-- ── Construcción del ScreenGui ───────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name = "AdminPanel"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 200
gui.Parent = playerGui

-- Ventana de confirmación reutilizable. Bloquea con un overlay para no tocar nada
-- de atrás por accidente. Confirm ejecuta onConfirm; Cancel solo cierra.
local function confirmAction(message: string, confirmLabel: string, confirmColor: Color3, onConfirm: () -> ())
	local overlay = Instance.new("Frame")
	overlay.Name = "ConfirmOverlay"
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.45
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 50
	overlay.Parent = gui

	local box = Instance.new("Frame")
	box.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
	box.BorderSizePixel = 0
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.fromOffset(300, 170)
	box.ZIndex = 51
	box.Parent = overlay
	corner(box, 10)
	do
		local s = Instance.new("UIStroke")
		s.Color = confirmColor
		s.Thickness = 2
		s.Parent = box
	end

	local msg = Instance.new("TextLabel")
	msg.BackgroundTransparency = 1
	msg.Font = Enum.Font.FredokaOne
	msg.Text = message
	msg.TextColor3 = Color3.fromRGB(235, 240, 250)
	msg.TextWrapped = true
	msg.TextScaled = true
	msg.AnchorPoint = Vector2.new(0.5, 0)
	msg.Position = UDim2.new(0.5, 0, 0, 16)
	msg.Size = UDim2.new(1, -28, 0, 80)
	msg.ZIndex = 52
	msg.Parent = box
	do
		local con = Instance.new("UITextSizeConstraint")
		con.MaxTextSize = 18
		con.Parent = msg
	end

	local cancelBtn = makeButton(box, "Cancel", Color3.fromRGB(70, 78, 96))
	cancelBtn.AnchorPoint = Vector2.new(0, 1)
	cancelBtn.Position = UDim2.new(0, 16, 1, -16)
	cancelBtn.Size = UDim2.new(0.5, -22, 0, 38)
	cancelBtn.ZIndex = 52

	local confirmBtn = makeButton(box, confirmLabel, confirmColor)
	confirmBtn.AnchorPoint = Vector2.new(1, 1)
	confirmBtn.Position = UDim2.new(1, -16, 1, -16)
	confirmBtn.Size = UDim2.new(0.5, -22, 0, 38)
	confirmBtn.ZIndex = 52

	cancelBtn.MouseButton1Click:Connect(function()
		overlay:Destroy()
	end)
	confirmBtn.MouseButton1Click:Connect(function()
		overlay:Destroy()
		onConfirm()
	end)
end

-- Botón toggle en la esquina
local toggleBtn = makeButton(gui, "ADMIN", Color3.fromRGB(200, 60, 60))
toggleBtn.Name = "AdminToggle"
toggleBtn.Size = UDim2.new(0, 90, 0, 34)
toggleBtn.Position = UDim2.new(0, 12, 0, 120)
toggleBtn.AnchorPoint = Vector2.new(0, 0)

-- Panel
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
panel.BorderSizePixel = 0
-- AutomaticSize.Y: el panel siempre envuelve su contenido, así ninguna sección se
-- desborda ni se pisa aunque cambie el número de botones.
panel.Size = UDim2.fromOffset(548, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.Position = UDim2.new(0, 12, 0, 160)
panel.Visible = false
panel.Parent = gui
corner(panel, 10)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(200, 60, 60)
stroke.Thickness = 2
stroke.Parent = panel

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 9)
layout.Parent = panel

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 10)
padding.PaddingBottom = UDim.new(0, 10)
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingRight = UDim.new(0, 10)
padding.Parent = panel

local order = 0
local function nextOrder(): number
	order += 1
	return order
end

-- Título
local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Font = Enum.Font.FredokaOne
title.Text = "ADMIN PANEL"
title.TextColor3 = Color3.fromRGB(255, 90, 90)
title.TextScaled = true
title.Size = UDim2.new(1, 0, 0, 26)
title.LayoutOrder = nextOrder()
title.Parent = panel
do
	local con = Instance.new("UITextSizeConstraint")
	con.MaxTextSize = 22
	con.Parent = title
end

-- ── Pestañas ──────────────────────────────────────────────────────────────────
-- El panel tiene dos páginas: GENERAL (moderación y herramientas de siempre) y
-- EVENTS (todo lo que es un evento en vivo: admin abuse, weather, treadmill de
-- prueba y el reward). Solo una es visible a la vez; el resto del archivo se limita
-- a parentar cada sección a la columna de la página que le toca.
--
-- Cada página tiene su PROPIO body de dos columnas: si compartieran uno, ocultar una
-- página dejaría huecos en la otra.

local tabBar = Instance.new("Frame")
tabBar.Name = "Tabs"
tabBar.BackgroundTransparency = 1
tabBar.Size = UDim2.new(1, 0, 0, 30)
tabBar.LayoutOrder = nextOrder()
tabBar.Parent = panel
do
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, 8)
	l.Parent = tabBar
end

local function makePage(): (Frame, Frame, Frame)
	local page = Instance.new("Frame")
	page.BackgroundTransparency = 1
	page.Size = UDim2.new(1, 0, 0, 0)
	page.AutomaticSize = Enum.AutomaticSize.Y
	page.LayoutOrder = nextOrder()
	page.Parent = panel
	do
		local l = Instance.new("UIListLayout")
		l.FillDirection = Enum.FillDirection.Horizontal
		l.HorizontalAlignment = Enum.HorizontalAlignment.Left
		l.VerticalAlignment = Enum.VerticalAlignment.Top
		l.Padding = UDim.new(0, 12)
		l.SortOrder = Enum.SortOrder.LayoutOrder
		l.Parent = page
	end

	local function makeColumn(columnOrder: number): Frame
		local col = Instance.new("Frame")
		col.BackgroundTransparency = 1
		col.Size = UDim2.new(0, 258, 0, 0)
		col.AutomaticSize = Enum.AutomaticSize.Y
		col.LayoutOrder = columnOrder
		col.Parent = page
		local l = Instance.new("UIListLayout")
		l.FillDirection = Enum.FillDirection.Vertical
		l.SortOrder = Enum.SortOrder.LayoutOrder
		l.Padding = UDim.new(0, 9)
		l.Parent = col
		return col
	end

	return page, makeColumn(1), makeColumn(2)
end

-- GENERAL: moderación y herramientas de siempre. EVENTS: todo lo que es un evento
-- en vivo (admin abuse, weather, treadmill de prueba, reward).
local generalPage, leftCol, rightCol = makePage()
local eventsPage, eventsLeftCol, eventsRightCol = makePage()

local TAB_ACTIVE   = Color3.fromRGB(200, 60, 60)
local TAB_INACTIVE = Color3.fromRGB(52, 58, 74)

local generalTabBtn = makeButton(tabBar, "GENERAL", TAB_ACTIVE)
generalTabBtn.Size = UDim2.new(0.5, -4, 1, 0)
generalTabBtn.LayoutOrder = 1

local eventsTabBtn = makeButton(tabBar, "EVENTS", TAB_INACTIVE)
eventsTabBtn.Size = UDim2.new(0.5, -4, 1, 0)
eventsTabBtn.LayoutOrder = 2

local function selectTab(showEvents: boolean)
	generalPage.Visible = not showEvents
	eventsPage.Visible = showEvents
	generalTabBtn.BackgroundColor3 = if showEvents then TAB_INACTIVE else TAB_ACTIVE
	eventsTabBtn.BackgroundColor3 = if showEvents then TAB_ACTIVE else TAB_INACTIVE
end

generalTabBtn.MouseButton1Click:Connect(function()
	selectTab(false)
end)
eventsTabBtn.MouseButton1Click:Connect(function()
	selectTab(true)
end)

selectTab(false)

-- ── Sección Target ───────────────────────────────────────────────────────────

local targetHeader = makeLabel(leftCol, "TARGET")
targetHeader.LayoutOrder = nextOrder()

local targetList = Instance.new("ScrollingFrame")
targetList.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
targetList.BorderSizePixel = 0
targetList.Size = UDim2.new(1, 0, 0, 110)
targetList.CanvasSize = UDim2.new(0, 0, 0, 0)
targetList.AutomaticCanvasSize = Enum.AutomaticSize.Y
targetList.ScrollBarThickness = 4
targetList.LayoutOrder = nextOrder()
targetList.Parent = leftCol
corner(targetList, 6)
do
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, 3)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = targetList
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, 4)
	p.PaddingBottom = UDim.new(0, 4)
	p.PaddingLeft = UDim.new(0, 4)
	p.PaddingRight = UDim.new(0, 4)
	p.Parent = targetList
end

-- Botones de target (se re-crean al entrar/salir jugadores). Guardamos las refs
-- para poder resaltar el seleccionado.
local targetButtons: { [number]: TextButton } = {}

local function refreshTargetHighlight()
	for userId, btn in targetButtons do
		if userId == selectedUserId then
			btn.BackgroundColor3 = Color3.fromRGB(70, 130, 220)
		else
			btn.BackgroundColor3 = Color3.fromRGB(45, 52, 68)
		end
	end
end

local function rebuildTargetList()
	for _, child in targetList:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	targetButtons = {}

	local ord = 0
	local function addEntry(userId: number, label: string)
		ord += 1
		local btn = makeButton(targetList, label, Color3.fromRGB(45, 52, 68))
		btn.Size = UDim2.new(1, 0, 0, 24)
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.LayoutOrder = ord
		btn.MouseButton1Click:Connect(function()
			selectedUserId = userId
			refreshTargetHighlight()
		end)
		targetButtons[userId] = btn
	end

	-- "Me" primero
	addEntry(player.UserId, "Me (" .. player.Name .. ")")
	for _, p in Players:GetPlayers() do
		if p ~= player then
			addEntry(p.UserId, p.Name)
		end
	end

	-- Si el target seleccionado se fue, volver a uno mismo.
	if not targetButtons[selectedUserId] then
		selectedUserId = player.UserId
	end
	refreshTargetHighlight()
end

Players.PlayerAdded:Connect(rebuildTargetList)
Players.PlayerRemoving:Connect(function()
	-- Diferir un frame para que GetPlayers ya no incluya al que sale.
	task.defer(rebuildTargetList)
end)

-- ── Sección Give Premium Mount ───────────────────────────────────────────────

local mountHeader = makeLabel(leftCol, "GIVE PREMIUM MOUNT")
mountHeader.LayoutOrder = nextOrder()

local mountGrid = Instance.new("Frame")
mountGrid.BackgroundTransparency = 1
-- AutomaticSize.Y para que crezca según las filas reales (5 mounts = 3 filas): con
-- alto fijo la última fila se desbordaba y se pisaba con la sección de abajo.
mountGrid.Size = UDim2.new(1, 0, 0, 0)
mountGrid.AutomaticSize = Enum.AutomaticSize.Y
mountGrid.LayoutOrder = nextOrder()
mountGrid.Parent = leftCol
do
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.new(0.5, -4, 0, 30)
	g.CellPadding = UDim2.new(0, 8, 0, 6)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = mountGrid
end

for _, mount in MountsConfig.Premium do
	local btn = makeButton(mountGrid, mount.Name, Color3.fromRGB(120, 70, 200))
	btn.MouseButton1Click:Connect(function()
		Packets.AdminGiveMount:Fire(selectedUserId, mount.Name)
	end)
end

-- ── Sección Give Wins ────────────────────────────────────────────────────────

local winsHeader = makeLabel(leftCol, "GIVE WINS")
winsHeader.LayoutOrder = nextOrder()

-- Rejilla y no una fila: son 10 presets y en una sola línea quedan ilegibles.
-- Alto automático, igual que la rejilla de mounts, para que al añadir o quitar un
-- preset no haya que recalcular nada a mano.
local winsGrid = Instance.new("Frame")
winsGrid.BackgroundTransparency = 1
winsGrid.Size = UDim2.new(1, 0, 0, 0)
winsGrid.AutomaticSize = Enum.AutomaticSize.Y
winsGrid.LayoutOrder = nextOrder()
winsGrid.Parent = leftCol
do
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.new(0.2, -5, 0, 28)
	g.CellPadding = UDim2.new(0, 6, 0, 6)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = winsGrid
end

for i, preset in WIN_PRESETS do
	local btn = makeButton(winsGrid, preset.label, Color3.fromRGB(210, 170, 40))
	btn.LayoutOrder = i
	btn.MouseButton1Click:Connect(function()
		Packets.AdminGiveWins:Fire(selectedUserId, preset.amount)
	end)
end

-- ── Sección Give Levels ──────────────────────────────────────────────────────
-- Sube el Level directamente, sin pasar por el Speed. El servidor reaplica el
-- WalkSpeed; el SpeedCurrency que llevara encima no se toca.

local levelsHeader = makeLabel(leftCol, "GIVE LEVELS")
levelsHeader.LayoutOrder = nextOrder()

local levelsRow = Instance.new("Frame")
levelsRow.BackgroundTransparency = 1
levelsRow.Size = UDim2.new(1, 0, 0, 30)
levelsRow.LayoutOrder = nextOrder()
levelsRow.Parent = leftCol
do
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.Padding = UDim.new(0, 6)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = levelsRow
end

for i, preset in LEVEL_PRESETS do
	local btn = makeButton(levelsRow, preset.label, Color3.fromRGB(90, 180, 110))
	-- Son 5 botones (los de Wins son 4): 0.2 de ancho en vez de 0.25.
	btn.Size = UDim2.new(0.2, -5, 1, 0)
	btn.LayoutOrder = i
	btn.MouseButton1Click:Connect(function()
		Packets.AdminGiveLevels:Fire(selectedUserId, preset.amount)
	end)
end

-- ── Sección Slow ─────────────────────────────────────────────────────────────

local slowBtn = makeButton(leftCol, "SLOW (10s → speed 1)", Color3.fromRGB(60, 160, 180))
slowBtn.Size = UDim2.new(1, 0, 0, 34)
slowBtn.LayoutOrder = nextOrder()
slowBtn.MouseButton1Click:Connect(function()
	Packets.AdminSlow:Fire(selectedUserId)
end)

-- ── Sección Treadmill de prueba (ServerStorage.AdminAbuse.Treadmill) ────────
-- Config-driven: los multiplicadores salen de AdminTreadmillConfig, así que
-- agregar/quitar un preset es tocar esa lista, no este archivo.
--
-- Es CROSS-SERVER y persistido, igual que el reward: aparece en todos los servers,
-- incluidos los que Roblox cree durante el evento. Por eso pide confirmación —
-- multiplica el Speed de TODO el juego mientras esté puesta.

local treadmillHeader = makeLabel(eventsLeftCol, "TEST TREADMILL (all servers)")
treadmillHeader.LayoutOrder = nextOrder()

local treadmillGrid = Instance.new("Frame")
treadmillGrid.BackgroundTransparency = 1
treadmillGrid.Size = UDim2.new(1, 0, 0, 0)
treadmillGrid.AutomaticSize = Enum.AutomaticSize.Y
treadmillGrid.LayoutOrder = nextOrder()
treadmillGrid.Parent = eventsLeftCol
do
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.new(1 / 3, -6, 0, 30)
	g.CellPadding = UDim2.new(0, 8, 0, 6)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = treadmillGrid
end

for i, multiplier in AdminTreadmillConfig.Multipliers do
	local btn = makeButton(treadmillGrid, "x" .. tostring(multiplier), Color3.fromRGB(60, 160, 180))
	btn.LayoutOrder = i
	btn.MouseButton1Click:Connect(function()
		local msg = string.format(
			"Spawn a x%s treadmill in ALL servers?\nAuto-returns after 3h if you forget.",
			tostring(multiplier)
		)
		confirmAction(msg, "Spawn", Color3.fromRGB(60, 160, 180), function()
			Packets.AdminTreadmillSpawn:Fire(multiplier)
		end)
	end)
end

local treadmillReturnBtn = makeButton(eventsLeftCol, "Return treadmill (all servers)", Color3.fromRGB(70, 78, 96))
treadmillReturnBtn.Size = UDim2.new(1, 0, 0, 30)
treadmillReturnBtn.LayoutOrder = nextOrder()
treadmillReturnBtn.MouseButton1Click:Connect(function()
	Packets.AdminTreadmillReturn:Fire()
end)

-- ── Sección Ban (sistema propio de Roblox) ───────────────────────────────────

local BAN_OPTIONS = {
	{ label = "Ban 1 Day",   human = "1 day",     seconds = 86400 },
	{ label = "Ban 1 Week",  human = "1 week",    seconds = 604800 },
	{ label = "Ban Forever", human = "permanent", seconds = -1 },
}

local function targetName(): string
	local target = Players:GetPlayerByUserId(selectedUserId)
	return target and target.Name or ("UserId " .. tostring(selectedUserId))
end

local banHeader = makeLabel(rightCol, "BAN (Roblox)")
banHeader.LayoutOrder = nextOrder()

local banRow = Instance.new("Frame")
banRow.BackgroundTransparency = 1
banRow.Size = UDim2.new(1, 0, 0, 34)
banRow.LayoutOrder = nextOrder()
banRow.Parent = rightCol
do
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.Padding = UDim.new(0, 6)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = banRow
end

for i, opt in BAN_OPTIONS do
	local btn = makeButton(banRow, opt.label, Color3.fromRGB(170, 40, 40))
	btn.Size = UDim2.new(1 / 3, -4, 1, 0)
	btn.LayoutOrder = i
	btn.MouseButton1Click:Connect(function()
		local msg = string.format("Ban %s?\nDuration: %s", targetName(), opt.human)
		confirmAction(msg, "Confirm Ban", Color3.fromRGB(200, 50, 50), function()
			Packets.AdminBan:Fire(selectedUserId, opt.seconds)
		end)
	end)
end

-- ── Sección Ban/Unban por UserId ─────────────────────────────────────────────
-- Para jugadores que NO están en la sala: se escribe el UserId a mano.

local byIdHeader = makeLabel(rightCol, "BY USERID (offline)")
byIdHeader.LayoutOrder = nextOrder()

local idBox = Instance.new("TextBox")
idBox.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
idBox.BorderSizePixel = 0
idBox.Font = Enum.Font.FredokaOne
idBox.PlaceholderText = "Enter UserId..."
idBox.PlaceholderColor3 = Color3.fromRGB(120, 130, 150)
idBox.Text = ""
idBox.TextColor3 = Color3.fromRGB(235, 240, 250)
idBox.TextScaled = true
idBox.ClearTextOnFocus = false
idBox.Size = UDim2.new(1, 0, 0, 30)
idBox.LayoutOrder = nextOrder()
idBox.Parent = rightCol
corner(idBox, 6)
do
	local con = Instance.new("UITextSizeConstraint")
	con.MaxTextSize = 16
	con.Parent = idBox
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = idBox
end

-- Devuelve el UserId escrito como entero positivo, o nil si es inválido.
local function parseEnteredId(): number?
	local n = tonumber(idBox.Text)
	if not n then return nil end
	if n ~= n or n == math.huge then return nil end
	n = math.floor(n)
	if n < 1 then return nil end
	return n
end

-- Fila de bans por UserId (mismas tres duraciones)
local byIdBanRow = Instance.new("Frame")
byIdBanRow.BackgroundTransparency = 1
byIdBanRow.Size = UDim2.new(1, 0, 0, 30)
byIdBanRow.LayoutOrder = nextOrder()
byIdBanRow.Parent = rightCol
do
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.Padding = UDim.new(0, 6)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = byIdBanRow
end

for i, opt in BAN_OPTIONS do
	local btn = makeButton(byIdBanRow, opt.label, Color3.fromRGB(170, 40, 40))
	btn.Size = UDim2.new(1 / 3, -4, 1, 0)
	btn.LayoutOrder = i
	btn.MouseButton1Click:Connect(function()
		local id = parseEnteredId()
		if not id then
			idBox.Text = ""
			idBox.PlaceholderText = "Invalid UserId!"
			return
		end
		local msg = string.format("Ban UserId %d?\nDuration: %s", id, opt.human)
		confirmAction(msg, "Confirm Ban", Color3.fromRGB(200, 50, 50), function()
			Packets.AdminBan:Fire(id, opt.seconds)
		end)
	end)
end

-- Botón de unban
local unbanBtn = makeButton(rightCol, "UNBAN (by UserId)", Color3.fromRGB(60, 170, 90))
unbanBtn.Size = UDim2.new(1, 0, 0, 34)
unbanBtn.LayoutOrder = nextOrder()
unbanBtn.MouseButton1Click:Connect(function()
	local id = parseEnteredId()
	if not id then
		idBox.Text = ""
		idBox.PlaceholderText = "Invalid UserId!"
		return
	end
	local msg = string.format("Unban UserId %d?", id)
	confirmAction(msg, "Confirm Unban", Color3.fromRGB(50, 170, 80), function()
		Packets.AdminUnban:Fire(id)
	end)
end)

-- ── Sección Mensaje global ───────────────────────────────────────────────────

local msgHeader = makeLabel(rightCol, "GLOBAL MESSAGE (top banner)")
msgHeader.LayoutOrder = nextOrder()

local msgBox = Instance.new("TextBox")
msgBox.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
msgBox.BorderSizePixel = 0
msgBox.Font = Enum.Font.FredokaOne
msgBox.PlaceholderText = "Enter message..."
msgBox.PlaceholderColor3 = Color3.fromRGB(120, 130, 150)
msgBox.Text = ""
msgBox.TextColor3 = Color3.fromRGB(235, 240, 250)
msgBox.TextScaled = true
msgBox.ClearTextOnFocus = false
msgBox.TextWrapped = true
msgBox.Size = UDim2.new(1, 0, 0, 44)
msgBox.LayoutOrder = nextOrder()
msgBox.Parent = rightCol
corner(msgBox, 6)
do
	local con = Instance.new("UITextSizeConstraint")
	con.MaxTextSize = 16
	con.Parent = msgBox
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = msgBox
end

-- Envía el broadcast leyendo el mensaje del TextBox. scope: "global" | "server" |
-- "player" (con targetUserId).
local function sendBroadcast(scope: string, targetUserId: number)
	local text = (msgBox.Text:gsub("^%s+", ""):gsub("%s+$", ""))
	if text == "" then
		msgBox.Text = ""
		msgBox.PlaceholderText = "Message is empty!"
		return
	end
	Packets.AdminBroadcast:Fire(text, scope, targetUserId)
end

local msgGrid = Instance.new("Frame")
msgGrid.BackgroundTransparency = 1
msgGrid.Size = UDim2.new(1, 0, 0, 0)
msgGrid.AutomaticSize = Enum.AutomaticSize.Y
msgGrid.LayoutOrder = nextOrder()
msgGrid.Parent = rightCol
do
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.new(0.5, -4, 0, 30)
	g.CellPadding = UDim2.new(0, 8, 0, 6)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = msgGrid
end

-- Los cuatro destinos. "Selected Player" usa el target de la lista; "By UserId" el
-- campo de arriba (mismo parseEnteredId de la sección de ban).
local MSG_TARGETS = {
	{ label = "All Servers",     order = 1, send = function() sendBroadcast("global", 0) end },
	{ label = "This Server",     order = 2, send = function() sendBroadcast("server", 0) end },
	{ label = "Selected Player", order = 3, send = function() sendBroadcast("player", selectedUserId) end },
	{ label = "By UserId",       order = 4, send = function()
		local id = parseEnteredId()
		if not id then
			idBox.Text = ""
			idBox.PlaceholderText = "Invalid UserId!"
			return
		end
		sendBroadcast("player", id)
	end },
}

for _, t in MSG_TARGETS do
	local btn = makeButton(msgGrid, t.label, Color3.fromRGB(60, 120, 190))
	btn.LayoutOrder = t.order
	btn.MouseButton1Click:Connect(t.send)
end

-- ── Sección Admin Abuse ──────────────────────────────────────────────────────
-- Config-driven: los botones salen de AdminAbuseConfig.Presets, así que agregar
-- uno nuevo es agregar una entrada ahí, sin tocar este archivo. Todo lo que ve el
-- jugador se dispara global (todos los servers) — por eso pasa por confirmAction.

local abuseHeader = makeLabel(eventsLeftCol, "ADMIN ABUSE (all servers)")
abuseHeader.LayoutOrder = nextOrder()

local abuseGrid = Instance.new("Frame")
abuseGrid.BackgroundTransparency = 1
abuseGrid.Size = UDim2.new(1, 0, 0, 0)
abuseGrid.AutomaticSize = Enum.AutomaticSize.Y
abuseGrid.LayoutOrder = nextOrder()
abuseGrid.Parent = eventsLeftCol
do
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.new(1, 0, 0, 30)
	g.CellPadding = UDim2.new(0, 0, 0, 6)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = abuseGrid
end

for i, preset in AdminAbuseConfig.Presets do
	local btn = makeButton(abuseGrid, preset.ButtonLabel, Color3.fromRGB(150, 50, 130))
	btn.LayoutOrder = i
	btn.MouseButton1Click:Connect(function()
		local msg = string.format("Trigger \"%s\" for ALL servers?", preset.ButtonLabel)
		confirmAction(msg, "Confirm", Color3.fromRGB(150, 50, 130), function()
			Packets.AdminAbuseTrigger:Fire(preset.Id)
		end)
	end)
end

local abuseDeactivateBtn = makeButton(eventsLeftCol, "Deactivate (all servers)", Color3.fromRGB(70, 78, 96))
abuseDeactivateBtn.Size = UDim2.new(1, 0, 0, 30)
abuseDeactivateBtn.LayoutOrder = nextOrder()
abuseDeactivateBtn.MouseButton1Click:Connect(function()
	Packets.AdminAbuseCancel:Fire()
end)

-- ── Sección Weather Events ───────────────────────────────────────────────────
-- Config-driven igual que Admin Abuse: los botones salen de WeatherConfig.Presets.
-- Cada uno usa el UIColor de su preset para reconocerlos de un vistazo. El evento
-- NO caduca solo: queda activo hasta que alguien pulse "Remove weather".

local weatherHeader = makeLabel(eventsRightCol, "WEATHER EVENT (all servers)")
weatherHeader.LayoutOrder = nextOrder()

local weatherGrid = Instance.new("Frame")
weatherGrid.BackgroundTransparency = 1
weatherGrid.Size = UDim2.new(1, 0, 0, 0)
weatherGrid.AutomaticSize = Enum.AutomaticSize.Y
weatherGrid.LayoutOrder = nextOrder()
weatherGrid.Parent = eventsRightCol
do
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.new(0.5, -4, 0, 30)
	g.CellPadding = UDim2.new(0, 8, 0, 6)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = weatherGrid
end

for i, preset in WeatherConfig.Presets do
	local btn = makeButton(weatherGrid, preset.ButtonLabel, preset.UIColor)
	btn.LayoutOrder = i
	btn.MouseButton1Click:Connect(function()
		local msg = string.format(
			"Activate %s in ALL servers?\nx%s Speed, x%s Wins.",
			preset.DisplayName,
			tostring(preset.Multiplier),
			tostring(preset.WinsMultiplier)
		)
		confirmAction(msg, "Activate", preset.UIColor, function()
			Packets.AdminWeatherTrigger:Fire(preset.Id)
		end)
	end)
end

local weatherClearBtn = makeButton(eventsRightCol, "Remove weather (all servers)", Color3.fromRGB(70, 78, 96))
weatherClearBtn.Size = UDim2.new(1, 0, 0, 30)
weatherClearBtn.LayoutOrder = nextOrder()
weatherClearBtn.MouseButton1Click:Connect(function()
	Packets.AdminWeatherClear:Fire()
end)

-- ── Sección Reward de Admin Abuse (Workspace.AdminUtils) ─────────────────────
-- Abrir quita el Barrier (se guarda en ServerStorage) y habilita el Reward del final
-- del obby, que concede la montura Vezkitt al tocarlo. Cerrar devuelve el Barrier a
-- su sitio y el Reward deja de conceder nada.
--
-- Es la ÚNICA forma de conseguir esa montura, así que ambas acciones piden
-- confirmación: abrirlo sin querer regala contenido exclusivo en todos los servers.
--
-- El estado se persiste, así que los servers que Roblox cree DURANTE el evento (que
-- son muchos: el evento mismo es lo que trae la avalancha de gente) arrancan ya con
-- el obby abierto. La duración y el auto-cierre los decide el servidor.

local rewardHeader = makeLabel(eventsRightCol, "VEZKITT REWARD (all servers)")
rewardHeader.LayoutOrder = nextOrder()

local rewardOpenBtn = makeButton(eventsRightCol, "Open obby (remove barrier)", Color3.fromRGB(60, 170, 90))
rewardOpenBtn.Size = UDim2.new(1, 0, 0, 30)
rewardOpenBtn.LayoutOrder = nextOrder()
rewardOpenBtn.MouseButton1Click:Connect(function()
	confirmAction(
		"Remove the barrier and enable the Vezkitt reward in ALL servers?\nAuto-closes after 3h if you forget.",
		"Open",
		Color3.fromRGB(60, 170, 90),
		function()
			Packets.AdminRewardSet:Fire(true)
		end
	)
end)

local rewardCloseBtn = makeButton(eventsRightCol, "Close obby (restore barrier)", Color3.fromRGB(70, 78, 96))
rewardCloseBtn.Size = UDim2.new(1, 0, 0, 30)
rewardCloseBtn.LayoutOrder = nextOrder()
rewardCloseBtn.MouseButton1Click:Connect(function()
	confirmAction(
		"Restore the barrier and disable the Vezkitt reward in ALL servers?",
		"Close",
		Color3.fromRGB(70, 78, 96),
		function()
			Packets.AdminRewardSet:Fire(false)
		end
	)
end)

-- ── Toggle ───────────────────────────────────────────────────────────────────

toggleBtn.MouseButton1Click:Connect(function()
	panel.Visible = not panel.Visible
	if panel.Visible then
		rebuildTargetList()
	end
end)

rebuildTargetList()
