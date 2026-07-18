--!strict

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local MenuAnimations  = require(ReplicatedStorage.Shared.MenuAnimations)
local MenuManager     = require(ReplicatedStorage.Shared.MenuManager)
local NotifyBadge     = require(ReplicatedStorage.Shared.NotifyBadge)
local MountsConfig    = require(ReplicatedStorage.Shared.MountsConfig)
local RebirthConfig   = require(ReplicatedStorage.Shared.RebirthConfig)
local DataService     = require(ReplicatedStorage.Packages.DataService).client
local FormatNumber    = require(ReplicatedStorage.Packages.FormatNumber)
local Packets         = require(ReplicatedStorage.Shared.Packets)
local AlertsModule    = require(ReplicatedStorage.Packages.AlertsModule)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local left  = playerGui:WaitForChild("Left")
local menus = playerGui:WaitForChild("Menus")

-- Botones del menú izquierdo
local btnEvolve  = left:WaitForChild("Main"):WaitForChild("Line1"):WaitForChild("Evolve")  :: ImageButton
local btnRebirth = left:WaitForChild("Main"):WaitForChild("Line1"):WaitForChild("Rebirth") :: ImageButton
local btnIndex   = left:WaitForChild("Main"):WaitForChild("Line1"):WaitForChild("Index")   :: ImageButton
local btnTeleports = left:WaitForChild("Main"):WaitForChild("Line2"):WaitForChild("Teleports") :: ImageButton
local btnWorlds    = left:WaitForChild("Main"):WaitForChild("Line2"):WaitForChild("Worlds")    :: ImageButton

-- Menús
local menuEvolve   = menus:WaitForChild("Evolve")       :: Frame
local menuRebirth  = menus:WaitForChild("Rebirth")      :: Frame
local menuIndex    = menus:WaitForChild("Index")        :: Frame
local notification = menus:WaitForChild("Notification") :: Frame

-- Botones de cierre
local closeEvolve   = menuEvolve:WaitForChild("Right"):WaitForChild("Close")    :: ImageButton
local closeRebirth  = menuRebirth:WaitForChild("Right"):WaitForChild("Close")   :: ImageButton
local closeIndex    = menuIndex:WaitForChild("Right"):WaitForChild("Close")     :: ImageButton
local closeNotif    = notification:WaitForChild("Close")                         :: ImageButton

-- Referencias del menú Index
local indexLeftPanel    = menuIndex:WaitForChild("Left")              :: ScrollingFrame
local indexScrolling    = menuIndex:WaitForChild("ScrollingFrame")    :: ScrollingFrame
local leftTemplates     = indexLeftPanel:WaitForChild("Templates")
local scrollTemplates   = indexScrolling:WaitForChild("Templates")
local recordTemplate    = leftTemplates:WaitForChild("RecordTemplate")    :: ImageButton
local titleTemplate     = scrollTemplates:WaitForChild("TitleTemplate")   :: Frame
local quantity24Template = scrollTemplates:WaitForChild("Quantity24")     :: Frame
local indexTemplate     = scrollTemplates:WaitForChild("IndexTemplate")   :: ImageButton

-- Elementos del menú Rebirth
local rebirthActualQty  = menuRebirth:WaitForChild("Actual"):WaitForChild("Quantity")              :: TextLabel
local rebirthNextQty    = menuRebirth:WaitForChild("Next"):WaitForChild("Quantity")                :: TextLabel
local rebirthProgress   = menuRebirth:WaitForChild("Progress")                                     :: Frame
local rebirthFill       = rebirthProgress:WaitForChild("Fill")                                     :: Frame
local rebirthCoinsTitle = rebirthProgress:WaitForChild("Coins"):WaitForChild("Title")              :: TextLabel
local rebirthButton     = menuRebirth:WaitForChild("Rebirth")                                      :: ImageButton

-- Barra de progreso del botón Rebirth del menú izquierdo (visible sin abrir el menú)
local rebirthBtnProgress = btnRebirth:WaitForChild("Button"):WaitForChild("Progress")              :: Frame
local rebirthBtnFill     = rebirthBtnProgress:WaitForChild("Fill")                                 :: Frame
local rebirthBtnTitle    = rebirthBtnProgress:WaitForChild("Title")                                :: TextLabel

-- Elementos del menú Evolve
local actualQuantity = menuEvolve:WaitForChild("Actual"):WaitForChild("Quantity")         :: TextLabel
local nextQuantity   = menuEvolve:WaitForChild("Next"):WaitForChild("Quantity")           :: TextLabel
local progressWins   = menuEvolve:WaitForChild("ProgressWins")                            :: Frame
local progressLevels = menuEvolve:WaitForChild("ProgressLevels")                          :: Frame
local winsFill       = progressWins:WaitForChild("Fill")                                  :: Frame
local levelsFill     = progressLevels:WaitForChild("Fill")                                :: Frame
local winsTitle      = progressWins:WaitForChild("Coins"):WaitForChild("Title")           :: TextLabel
local levelsTitle    = progressLevels:WaitForChild("Levels"):WaitForChild("Title")        :: TextLabel
local evolveButton   = menuEvolve:WaitForChild("Evolve")                                  :: ImageButton

-- Currency display
local rebirthsQtyLabel = left:WaitForChild("Main"):WaitForChild("Line1")
	:WaitForChild("Currencies"):WaitForChild("Rebirths"):WaitForChild("Quantity") :: TextLabel

local FILL_TWEEN = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Sincronizar Rebirths display con leaderstats (replicado automáticamente por Roblox)
task.spawn(function()
	local leaderstats  = player:WaitForChild("leaderstats")
	local rebirthVal   = leaderstats:WaitForChild("Rebirth") :: IntValue
	rebirthsQtyLabel.Text = tostring(rebirthVal.Value)
	rebirthVal.Changed:Connect(function(newValue: number)
		rebirthsQtyLabel.Text = tostring(newValue)
	end)
end)

-- ── Alert ────────────────────────────────────────────────────────────────────

local function showAlert(title: string, description: string)
	local titleLabel = notification:FindFirstChild("Title") :: TextLabel?
	local descLabel  = notification:FindFirstChild("Description") :: TextLabel?
	if titleLabel then titleLabel.Text = title end
	if descLabel  then descLabel.Text  = description end

	-- Ocultar BuySection (no aplica para alertas)
	local buySection = notification:FindFirstChild("BuySection")
	if buySection then
		for _, child in buySection:GetChildren() do
			if child:IsA("GuiObject") then child.Visible = false end
		end
	end

	MenuAnimations.open(notification)
end

-- Notification NO lo gestiona MenuManager: es una alerta que va por encima del
-- menú abierto. Al cerrarla, el blur solo se quita si no queda menú detrás.
closeNotif.MouseButton1Click:Connect(function()
	MenuAnimations.close(notification)
	MenuManager.refreshBlur()
end)

-- Teleports y Worlds: aún no implementados → mostrar error "Coming Soon"
btnTeleports.MouseButton1Click:Connect(function()
	AlertsModule.ShowAlertGui("Error", "Coming Soon")
end)

btnWorlds.MouseButton1Click:Connect(function()
	AlertsModule.ShowAlertGui("Error", "Coming Soon")
end)

-- ── Menú Evolve ──────────────────────────────────────────────────────────────

local function getLatestOwnedWorld1Index(ownedMounts: { [string]: boolean }): number?
	for i = #MountsConfig.World1, 1, -1 do
		if ownedMounts[MountsConfig.World1[i].Name] then
			return i
		end
	end
	return nil
end

local function populateEvolveMenu()
	task.spawn(function()
		DataService:waitForData()

		local ownedMounts  = (DataService:get({ "Mounts" }) or {}) :: { [string]: boolean }
		local playerLevel  = (DataService:get({ "Level" }) or 1) :: number
		local playerWins   = (DataService:get({ "WinCurrency" }) or 0) :: number

		-- Evolve siempre continúa desde la montura base más avanzada que posee el
		-- jugador, aunque tenga equipada una inferior o una montura Premium/Daily.
		local currentIndex = getLatestOwnedWorld1Index(ownedMounts)
		if not currentIndex then return end
		local currentMount = MountsConfig.World1[currentIndex]
		local nextMount    = MountsConfig.World1[currentIndex + 1]

		-- Multiplicadores
		actualQuantity.Text = "x" .. tostring(currentMount.Multiplier)
		nextQuantity.Text   = nextMount and ("x" .. tostring(nextMount.Multiplier)) or "MAX"

		-- Barras de progreso
		if nextMount and ownedMounts[nextMount.Name] then
			-- Ya poseída (las mounts persisten tras el rebirth): re-equipar es gratis
			TweenService:Create(winsFill,   FILL_TWEEN, { Size = UDim2.new(1, 0, 1, 0) }):Play()
			TweenService:Create(levelsFill, FILL_TWEEN, { Size = UDim2.new(1, 0, 1, 0) }):Play()
			winsTitle.Text   = "Owned"
			levelsTitle.Text = "Owned"
		elseif nextMount and nextMount.EvolveRequirements then
			local reqs = nextMount.EvolveRequirements

			local winsRatio  = math.clamp(playerWins  / reqs.Wins,  0, 1)
			local levelRatio = math.clamp(playerLevel / reqs.Level, 0, 1)

			TweenService:Create(winsFill,   FILL_TWEEN, { Size = UDim2.new(winsRatio,  0, 1, 0) }):Play()
			TweenService:Create(levelsFill, FILL_TWEEN, { Size = UDim2.new(levelRatio, 0, 1, 0) }):Play()

			winsTitle.Text   = FormatNumber:formatNumberCoins(playerWins)
				.. "/" .. FormatNumber:formatNumberCoins(reqs.Wins)
			levelsTitle.Text = playerLevel .. "/" .. reqs.Level
		else
			-- Sin siguiente montura o sin requisitos
			TweenService:Create(winsFill,   FILL_TWEEN, { Size = UDim2.new(1, 0, 1, 0) }):Play()
			TweenService:Create(levelsFill, FILL_TWEEN, { Size = UDim2.new(1, 0, 1, 0) }):Play()
			winsTitle.Text   = "MAX"
			levelsTitle.Text = "MAX"
		end
	end)
end

local evolvePending = false
evolveButton.MouseButton1Click:Connect(function()
	if evolvePending then return end
	evolvePending = true
	Packets.EvolveMount:Fire()
end)

Packets.EvolveMountResult.OnClientEvent:Connect(function(success: boolean, message: string)
	evolvePending = false
	if success then
		MenuManager.close(menuEvolve)
	else
		-- Fallo de evolve (p. ej. falta nivel): error alert rojo en vez del menú
		-- Notification.
		AlertsModule.ShowAlertGui("Error", message)
	end
end)

-- ── Menú Rebirth ─────────────────────────────────────────────────────────────

local function populateRebirthMenu()
	task.spawn(function()
		DataService:waitForData()

		local rebirthCount = (DataService:get({ "Rebirth" }) or 0) :: number
		local playerLevel  = (DataService:get({ "Level" }) or 1)   :: number

		local currentMultiplier = RebirthConfig.getWinsMultiplier(rebirthCount)
		local nextData          = RebirthConfig.getNextData(rebirthCount)

		rebirthActualQty.Text = "x" .. tostring(currentMultiplier)
		rebirthNextQty.Text   = nextData and ("x" .. tostring(nextData.WinsMultiplier)) or "MAX"

		if nextData then
			local ratio = math.clamp(playerLevel / nextData.LevelRequired, 0, 1)
			TweenService:Create(rebirthFill, FILL_TWEEN, { Size = UDim2.new(ratio, 0, 1, 0) }):Play()
			rebirthCoinsTitle.Text = playerLevel .. "/" .. nextData.LevelRequired
		else
			TweenService:Create(rebirthFill, FILL_TWEEN, { Size = UDim2.new(1, 0, 1, 0) }):Play()
			rebirthCoinsTitle.Text = "MAX"
		end
	end)
end

-- El único requisito para rebirthear es el nivel (ver RebirthService:_handleRebirth),
-- así que el progreso es Level / LevelRequired del siguiente rebirth.
local function refreshRebirthButtonProgress()
	local rebirthCount = (DataService:get({ "Rebirth" }) or 0) :: number
	local playerLevel  = (DataService:get({ "Level" }) or 1)   :: number
	local nextData     = RebirthConfig.getNextData(rebirthCount)

	if not nextData then
		TweenService:Create(rebirthBtnFill, FILL_TWEEN, { Size = UDim2.new(1, 0, 1, 0) }):Play()
		rebirthBtnTitle.Text = "MAX"
		return
	end

	local ratio = math.clamp(playerLevel / nextData.LevelRequired, 0, 1)
	TweenService:Create(rebirthBtnFill, FILL_TWEEN, { Size = UDim2.new(ratio, 0, 1, 0) }):Play()
	-- floor y no round: mostrar 100% sin poder rebirthear todavía sería mentir.
	rebirthBtnTitle.Text = string.format("%d%%", math.floor(ratio * 100))
end

task.spawn(function()
	DataService:waitForData()
	refreshRebirthButtonProgress()
	DataService:getChangedSignal({ "Level" }):Connect(refreshRebirthButtonProgress)
	DataService:getChangedSignal({ "Rebirth" }):Connect(refreshRebirthButtonProgress)
end)

-- ── Indicadores "!" de Evolve y Rebirth ──────────────────────────────────────

-- Condiciones espejo de las del servidor. Si cambian allí, hay que cambiarlas aquí:
-- un badge que promete un evolve que el servidor luego rechaza es peor que no tenerlo.

-- MountsService:_handleEvolve: parte de la montura World1 más avanzada que el
-- jugador posee y exige Level Y Wins para la siguiente.
local function canEvolve(): boolean
	local ownedMounts = (DataService:get({ "Mounts" }) or {}) :: { [string]: boolean }
	local currentIndex = getLatestOwnedWorld1Index(ownedMounts)
	if not currentIndex then return false end

	local nextMount = MountsConfig.World1[currentIndex + 1]
	if not nextMount then return false end

	if ownedMounts[nextMount.Name] then return true end

	local reqs = nextMount.EvolveRequirements
	if not reqs then return false end

	local playerLevel = (DataService:get({ "Level" }) or 1)   :: number
	local playerWins  = (DataService:get({ "WinCurrency" }) or 0) :: number
	return playerLevel >= reqs.Level and playerWins >= reqs.Wins
end

-- RebirthService:_handleRebirth: solo pide nivel.
local function canRebirth(): boolean
	local rebirthCount = (DataService:get({ "Rebirth" }) or 0) :: number
	local nextData     = RebirthConfig.getNextData(rebirthCount)
	if not nextData then return false end

	local playerLevel = (DataService:get({ "Level" }) or 1) :: number
	return playerLevel >= nextData.LevelRequired
end

local function refreshActionBadges()
	NotifyBadge.setVisible(btnEvolve, canEvolve())
	NotifyBadge.setVisible(btnRebirth, canRebirth())
end

task.spawn(function()
	DataService:waitForData()
	refreshActionBadges()
	for _, key in { "Level", "WinCurrency", "EquippedMount", "Rebirth", "Mounts" } do
		DataService:getChangedSignal({ key }):Connect(refreshActionBadges)
	end
end)

local rebirthPending = false
rebirthButton.MouseButton1Click:Connect(function()
	if rebirthPending then return end
	rebirthPending = true
	Packets.DoRebirth:Fire()
end)

Packets.RebirthResult.OnClientEvent:Connect(function(success: boolean, message: string)
	rebirthPending = false
	if success then
		MenuManager.close(menuRebirth)
	else
		showAlert("Cannot Rebirth", message)
	end
end)

-- ── Open / Close ─────────────────────────────────────────────────────────────

btnEvolve.MouseButton1Click:Connect(function()
	MenuManager.toggle(menuEvolve, { onOpen = populateEvolveMenu })
end)

btnRebirth.MouseButton1Click:Connect(function()
	MenuManager.toggle(menuRebirth, { onOpen = populateRebirthMenu })
end)

closeEvolve.MouseButton1Click:Connect(function()
	MenuManager.close(menuEvolve)
end)

closeRebirth.MouseButton1Click:Connect(function()
	MenuManager.close(menuRebirth)
end)

closeIndex.MouseButton1Click:Connect(function()
	MenuManager.close(menuIndex)
end)

-- ── Menú Index ────────────────────────────────────────────────────────────────

local selectedWorldKey = "World1"

local function clearIndexScrolling()
	for _, child in indexScrolling:GetChildren() do
		if child.Name == "Templates" or child:IsA("UIListLayout") or child:IsA("UIAspectRatioConstraint") then continue end
		child:Destroy()
	end
end

local function clearIndexLeft()
	for _, child in indexLeftPanel:GetChildren() do
		if child.Name == "Templates" or child:IsA("UIListLayout") or child:IsA("UIAspectRatioConstraint") then continue end
		child:Destroy()
	end
end

local function buildMountGrid(mountList: { MountsConfig.MountData }, ownedMounts: {[string]: boolean}, equippedName: string): Frame
	local grid = quantity24Template:Clone()
	for _, mount in mountList do
		local owned = ownedMounts[mount.Name] == true
		local card  = indexTemplate:Clone()
		local ct    = card:WaitForChild("CardTemplate") :: ImageButton

		local cardName = ct:FindFirstChild("CardName") :: TextLabel
		cardName.Text = owned and mount.Name or "??????"

		local image1 = ct:FindFirstChild("Image1") :: ImageLabel
		image1.Image          = mount.Image
		image1.ImageColor3    = owned and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(0, 0, 0)

		local oddsLabel = ct:FindFirstChild("Odds") :: TextLabel
		oddsLabel.Text = owned and ("x" .. tostring(mount.Multiplier)) or "x?"

		local equippedFrame = ct:FindFirstChild("Equipped") :: Frame
		equippedFrame.Visible = (mount.Name == equippedName)

		-- IndexTemplate es la tarjeta exterior completa. Escuchar su Activated evita
		-- depender del tamaño/ZIndex/Active del CardTemplate interior en Studio.
		card.Activated:Connect(function()
			if not owned then return end
			Packets.EquipMount:Fire(mount.Name)
		end)

		card.Visible = true
		card.Parent = grid
	end
	grid.Visible = true
	return grid
end

local function buildTitleRow(text: string, owned: number, total: number): Frame
	local t         = titleTemplate:Clone()
	local label     = t:FindFirstChild("TextLabel") :: TextLabel
	local progress  = t:FindFirstChild("Progress")  :: TextLabel
	label.Text      = text
	progress.Text   = owned .. "/" .. total
	t.Visible       = true
	return t
end

local function countOwned(list: { MountsConfig.MountData }, ownedMounts: {[string]: boolean}): number
	local n = 0
	for _, m in list do
		if ownedMounts[m.Name] then
			n += 1
		end
	end
	return n
end

local function populateWorldGrid(worldKey: string, ownedMounts: {[string]: boolean}, equippedName: string)
	clearIndexScrolling()

	local normalMounts = (MountsConfig :: any)[worldKey] :: { MountsConfig.MountData }
	local secretMounts = MountsConfig.Premium
	local order        = 0

	local function nextItem(item: GuiObject)
		order += 1
		item.LayoutOrder = order
		item.Parent = indexScrolling
	end

	nextItem(buildTitleRow("Mounts", countOwned(normalMounts, ownedMounts), #normalMounts))
	nextItem(buildMountGrid(normalMounts, ownedMounts, equippedName))

	if #secretMounts > 0 then
		nextItem(buildTitleRow("Secret Mounts", countOwned(secretMounts, ownedMounts), #secretMounts))
		nextItem(buildMountGrid(secretMounts, ownedMounts, equippedName))
	end
end

local function populateIndexMenu()
	task.spawn(function()
		DataService:waitForData()

		local equippedName = (DataService:get({ "EquippedMount" }) or "Chonk") :: string
		local ownedMounts  = (DataService:get({ "Mounts" }) or {}) :: {[string]: boolean}

		-- World tabs (Left panel)
		clearIndexLeft()
		for _, world in MountsConfig.Worlds do
			local tab      = recordTemplate:Clone()
			local imgLabel = tab:FindFirstChild("ImageLabel") :: ImageLabel?
			local interior = imgLabel and imgLabel:FindFirstChild("Interior") :: ImageLabel?
			if interior then
				interior.Image = world.Image
			end

			local selected   = tab:FindFirstChild("Selected") :: Frame
			selected.Visible = (world.Key == selectedWorldKey)
			tab.Visible      = true
			tab.Parent       = indexLeftPanel

			local worldKey = world.Key
			tab.MouseButton1Click:Connect(function()
				selectedWorldKey = worldKey
				for _, t in indexLeftPanel:GetChildren() do
					if t:IsA("ImageButton") then
						local s = t:FindFirstChild("Selected") :: Frame?
						if s then
							s.Visible = (t == tab)
						end
					end
				end
				local latest = (DataService:get({ "EquippedMount" }) or "Chonk") :: string
				local owned  = (DataService:get({ "Mounts" }) or {}) :: {[string]: boolean}
				populateWorldGrid(worldKey, owned, latest)
			end)
		end

		populateWorldGrid(selectedWorldKey, ownedMounts, equippedName)
	end)
end

btnIndex.MouseButton1Click:Connect(function()
	MenuManager.toggle(menuIndex, { onOpen = populateIndexMenu })
end)

-- Re-render grid si Index está abierto y cambia montura o inventario
task.spawn(function()
	DataService:waitForData()
	local function refreshIfOpen()
		if not MenuManager.isOpen(menuIndex) then return end
		local equippedName = (DataService:get({ "EquippedMount" }) or "Chonk") :: string
		local ownedMounts  = (DataService:get({ "Mounts" }) or {}) :: {[string]: boolean}
		populateWorldGrid(selectedWorldKey, ownedMounts, equippedName)
	end
	DataService:getChangedSignal({ "EquippedMount" }):Connect(refreshIfOpen)
	DataService:getChangedSignal({ "Mounts" }):Connect(refreshIfOpen)
end)
