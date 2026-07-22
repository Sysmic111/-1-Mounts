--!strict

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local SoundService      = game:GetService("SoundService")
local Workspace         = game:GetService("Workspace")

local AlertsModule   = require(ReplicatedStorage.Packages.AlertsModule)
local MenuManager    = require(ReplicatedStorage.Shared.MenuManager)
local NotifyBadge    = require(ReplicatedStorage.Shared.NotifyBadge)
local DailyConfig    = require(ReplicatedStorage.Shared.DailyConfig)
local Packets        = require(ReplicatedStorage.Shared.Packets)
local DataService    = require(ReplicatedStorage.Packages.DataService).client

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local left  = playerGui:WaitForChild("Left")
local menus = playerGui:WaitForChild("Menus")

local btnDaily = left:WaitForChild("Main"):WaitForChild("Line1"):WaitForChild("Daily") :: ImageButton

local menuDaily  = menus:WaitForChild("Daily")                            :: Frame
local closeDaily = menuDaily:WaitForChild("Right"):WaitForChild("Close")  :: ImageButton
local scrolling  = menuDaily:WaitForChild("ScrollingFrame")               :: ScrollingFrame
local templates  = scrolling:WaitForChild("Templates")
local cardTemplate = templates:WaitForChild("DayCardTemplate")            :: ImageButton
local nextReward = menuDaily:WaitForChild("NextReward")                   :: TextLabel

local sfx = SoundService:WaitForChild("SFX")
-- Las monturas de los días 7/14/21 son el premio gordo: se anuncian con el sonido
-- de pull legendario en vez del de recoger moneda.
local claimSound = sfx:WaitForChild("collect_item_sparkle_pop_09") :: Sound
local mountSound = sfx:WaitForChild("pull_Legendary")              :: Sound

local CLAIMABLE_STROKE = Color3.fromRGB(255, 221, 0)
-- El color de la card vive en BackgroundColor3 (el Image del template es una
-- textura tileada encima), así que el atenuado de los días futuros va ahí.
local LOCKED_COLOR = Color3.fromRGB(96, 118, 133)
local NORMAL_TINT  = Color3.fromRGB(255, 255, 255)

local claimPending  = false
local cardsByDay    = {} :: { [number]: ImageButton }
local pulseTween: Tween? = nil

-- ── Utilidades ───────────────────────────────────────────────────────────────

-- Reloj UTC del servidor: el cliente nunca decide el día, solo lo muestra.
local function serverTime(): number
	return Workspace:GetServerTimeNow()
end

local function formatCountdown(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours = seconds // 3600
	local mins  = (seconds % 3600) // 60
	local secs  = seconds % 60
	return string.format("%02d:%02d:%02d", hours, mins, secs)
end

-- Estado del jugador leído de la data replicada.
local function getState(): (number, boolean)
	local claimedDay    = (DataService:get({ "DailyClaimedDay" }) or 0) :: number
	local lastClaimDate = (DataService:get({ "DailyLastClaimDate" }) or 0) :: number
	local claimedToday  = lastClaimDate >= DailyConfig.getDayNumber(serverTime())
	return claimedDay, claimedToday
end

-- ── Indicador "!" del botón Daily ────────────────────────────────────────────

local function refreshBadge()
	local _, claimedToday = getState()
	NotifyBadge.setVisible(btnDaily, not claimedToday)
end

-- ── Cards ────────────────────────────────────────────────────────────────────

local function clearCards()
	if pulseTween then
		pulseTween:Cancel()
		pulseTween = nil
	end
	for _, child in scrolling:GetChildren() do
		if child.Name == "Templates" or child:IsA("UIListLayout") or child:IsA("UIAspectRatioConstraint") then continue end
		child:Destroy()
	end
	table.clear(cardsByDay)
end

local function buildCard(day: number, claimedDay: number, claimableDay: number?): ImageButton
	local card = cardTemplate:Clone()
	card.LayoutOrder = day

	local ct = card:WaitForChild("CardTemplate") :: ImageButton
	local dayText    = ct:WaitForChild("DayText")    :: TextLabel
	local rewardText = ct:WaitForChild("RewardText") :: TextLabel
	local icon       = ct:WaitForChild("ImageLabel") :: ImageLabel
	local claimed    = ct:WaitForChild("Claimed")    :: ImageLabel
	local stroke     = ct:WaitForChild("UIStroke")   :: UIStroke

	dayText.Text = (day == DailyConfig.RepeatDay) and "Day 22+" or ("Day " .. day)
	rewardText.Text = DailyConfig.getRewardLabel(day)

	icon.Image       = DailyConfig.getRewardIcon(day)
	icon.ImageColor3 = NORMAL_TINT

	-- El día repetible solo se marca como reclamado mientras dure el día en curso;
	-- mañana vuelve a estar disponible.
	local isClaimed = day <= claimedDay and (day ~= DailyConfig.RepeatDay or claimableDay == nil)
	claimed.Visible = isClaimed

	if day == claimableDay then
		stroke.Color = CLAIMABLE_STROKE
		card.Active = true
		card.Interactable = true

		pulseTween = TweenService:Create(
			stroke,
			TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Thickness = stroke.Thickness * 2 }
		)
		if pulseTween then pulseTween:Play() end

		card.MouseButton1Click:Connect(function()
			if claimPending then return end
			claimPending = true
			Packets.ClaimDaily:Fire()
		end)
	else
		card.Active = false
		card.Interactable = false
		if not isClaimed then
			-- Días futuros: atenuados para que el reclamable destaque.
			ct.BackgroundColor3 = LOCKED_COLOR
		end
	end

	card.Visible = true
	return card
end

-- focusOverride fuerza a qué día se desplaza el scroll. Tras un claim se pasa el
-- día reclamado para que el efecto ocurra a la vista y no se vaya de pantalla.
local function populate(focusOverride: number?)
	clearCards()

	local claimedDay, claimedToday = getState()
	local claimableDay: number? = if claimedToday then nil else DailyConfig.getNextDay(claimedDay)

	for day = 1, DailyConfig.TotalDays do
		local card = buildCard(day, claimedDay, claimableDay)
		card.Parent = scrolling
		cardsByDay[day] = card
	end

	-- Dejar a la vista el día que toca (o el siguiente si ya reclamó hoy).
	local focusDay = focusOverride or claimableDay or DailyConfig.getNextDay(claimedDay)
	task.defer(function()
		local card = cardsByDay[focusDay]
		if not card or not MenuManager.isOpen(menuDaily) then return end
		local cardWidth = card.AbsoluteSize.X
		if cardWidth <= 0 then return end
		local target = (focusDay - 1) * cardWidth - (scrolling.AbsoluteSize.X - cardWidth) / 2
		scrolling.CanvasPosition = Vector2.new(math.max(0, target), 0)
	end)
end

-- ── Countdown ────────────────────────────────────────────────────────────────

task.spawn(function()
	while true do
		if MenuManager.isOpen(menuDaily) then
			local _, claimedToday = getState()
			if claimedToday then
				nextReward.Text = "Next reward in: "
					.. formatCountdown(DailyConfig.getSecondsUntilReset(serverTime()))
			else
				nextReward.Text = "Reward available!"
			end
		end
		task.wait(1)
	end
end)

-- Cruzar la medianoche UTC con el menú abierto debe habilitar el claim sin relog.
task.spawn(function()
	DataService:waitForData()
	local lastDay = DailyConfig.getDayNumber(serverTime())
	while true do
		task.wait(5)
		local today = DailyConfig.getDayNumber(serverTime())
		if today ~= lastDay then
			lastDay = today
			refreshBadge()
			if MenuManager.isOpen(menuDaily) then populate() end
		end
	end
end)

-- ── Open / Close ─────────────────────────────────────────────────────────────

btnDaily.MouseButton1Click:Connect(function()
	MenuManager.toggle(menuDaily, { onOpen = populate })
end)

closeDaily.MouseButton1Click:Connect(function()
	MenuManager.close(menuDaily)
end)

-- ── Efecto de claim ──────────────────────────────────────────────────────────

-- Las partículas y el texto cuelgan del menú, no de la card: la ScrollingFrame
-- tiene ClipsDescendants y recortaría cualquier cosa que se salga de la card.
local function spawnBurst(center: Vector2, image: string)
	for i = 1, 8 do
		local particle = Instance.new("ImageLabel")
		particle.BackgroundTransparency = 1
		particle.Image                  = image
		particle.Size                   = UDim2.fromOffset(28, 28)
		particle.AnchorPoint            = Vector2.new(0.5, 0.5)
		particle.Position               = UDim2.fromOffset(center.X, center.Y)
		particle.ZIndex                 = 20
		particle.Parent                 = menuDaily

		local angle    = (i / 8) * math.pi * 2 + math.random() * 0.4
		local distance = math.random(70, 120)
		local endPos   = UDim2.fromOffset(
			center.X + math.cos(angle) * distance,
			center.Y + math.sin(angle) * distance
		)

		local info = TweenInfo.new(0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		TweenService:Create(particle, info, {
			Position         = endPos,
			ImageTransparency = 1,
			Rotation          = math.random(-180, 180),
			Size              = UDim2.fromOffset(10, 10),
		}):Play()

		task.delay(0.75, function()
			particle:Destroy()
		end)
	end
end

local function spawnRewardText(center: Vector2, text: string)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint            = Vector2.new(0.5, 0.5)
	label.Position               = UDim2.fromOffset(center.X, center.Y)
	label.Size                   = UDim2.fromOffset(200, 40)
	label.Text                   = "+ " .. text
	label.TextScaled             = true
	label.TextColor3             = Color3.fromRGB(255, 240, 130)
	label.FontFace               = Font.fromName("ComicNeueAngular", Enum.FontWeight.Bold)
	label.ZIndex                 = 21
	label.Parent                 = menuDaily

	local stroke = Instance.new("UIStroke")
	stroke.Color        = Color3.fromRGB(0, 0, 0)
	stroke.Thickness    = 2
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent       = label

	local riseInfo = TweenInfo.new(1.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	TweenService:Create(label, riseInfo, {
		Position = UDim2.fromOffset(center.X, center.Y - 90),
	}):Play()

	local fadeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.7, function()
		if not label.Parent then return end
		TweenService:Create(label, fadeInfo, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, fadeInfo, { Transparency = 1 }):Play()
	end)

	task.delay(1.3, function()
		label:Destroy()
	end)
end

-- Se llama DESPUÉS de populate(), sobre la card ya reconstruida del día reclamado.
local function playClaimEffect(day: number)
	local reward  = DailyConfig.getReward(day)
	local isMount = reward ~= nil and reward.Kind == "Mount"

	if isMount then
		mountSound:Play()
	else
		claimSound:Play()
	end

	-- La card acaba de recrearse en populate() y su AbsolutePosition aún es 0
	-- hasta que el layout corre; además el scroll se ajusta en un defer. Esperar
	-- un frame da las coordenadas ya definitivas.
	RunService.Heartbeat:Wait()

	local card = cardsByDay[day]
	if not card then return end
	local ct = card:FindFirstChild("CardTemplate") :: ImageButton?
	if not ct then return end

	-- Golpe de escala en la card
	local baseSize = ct.Size
	ct.Size = UDim2.new(
		baseSize.X.Scale * 1.15, baseSize.X.Offset,
		baseSize.Y.Scale * 1.15, baseSize.Y.Offset
	)
	TweenService:Create(
		ct,
		TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = baseSize }
	):Play()

	-- El check entra rebotando en vez de aparecer de golpe
	local check = ct:FindFirstChild("Claimed") :: ImageLabel?
	if check and check.Visible then
		local checkSize = check.Size
		check.Size     = UDim2.fromScale(0, 0)
		check.Rotation = -40
		TweenService:Create(
			check,
			TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = checkSize, Rotation = 0 }
		):Play()
	end

	-- Restar la posición del menú convierte coordenadas de pantalla en locales
	-- (y de paso cancela el inset de la topbar).
	local center = card.AbsolutePosition + card.AbsoluteSize / 2 - menuDaily.AbsolutePosition

	spawnBurst(center, DailyConfig.getRewardIcon(day))
	spawnRewardText(center, DailyConfig.getRewardLabel(day))
end

-- ── Resultado del claim ──────────────────────────────────────────────────────

Packets.ClaimDailyResult.OnClientEvent:Connect(function(success: boolean, day: number, message: string)
	claimPending = false
	if success then
		refreshBadge()
		if MenuManager.isOpen(menuDaily) then
			populate(day)
			-- playClaimEffect espera un frame: fuera del handler del packet.
			task.spawn(playClaimEffect, day)
		end
	else
		AlertsModule.ShowAlertGui("Error", message)
	end
end)

-- ── Init ─────────────────────────────────────────────────────────────────────

task.spawn(function()
	DataService:waitForData()
	refreshBadge()

	local function onDataChanged()
		refreshBadge()
		if MenuManager.isOpen(menuDaily) then populate() end
	end
	DataService:getChangedSignal({ "DailyClaimedDay" }):Connect(onDataChanged)
	DataService:getChangedSignal({ "DailyLastClaimDate" }):Connect(onDataChanged)
end)
