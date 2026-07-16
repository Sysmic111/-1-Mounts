--!strict

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local MenuAnimations  = require(ReplicatedStorage.Shared.MenuAnimations)
local MountsConfig    = require(ReplicatedStorage.Shared.MountsConfig)
local RebirthConfig   = require(ReplicatedStorage.Shared.RebirthConfig)
local DataService     = require(ReplicatedStorage.Packages.DataService).client
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

local openMenu: Frame? = nil

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

closeNotif.MouseButton1Click:Connect(function()
	MenuAnimations.close(notification)
	if not openMenu then
		MenuAnimations.blurOut()
	end
end)

-- Teleports: aún no implementado → mostrar error "Coming Soon"
btnTeleports.MouseButton1Click:Connect(function()
	AlertsModule.ShowAlertGui("Error", "Coming Soon")
end)

-- ── Menú Evolve ──────────────────────────────────────────────────────────────

local function populateEvolveMenu()
	task.spawn(function()
		DataService:waitForData()

		local equippedName = DataService:get({ "EquippedMount" }) :: string?
		local playerLevel  = (DataService:get({ "Level" }) or 1) :: number
		local playerWins   = (DataService:get({ "WinCurrency" }) or 0) :: number

		-- Encontrar mount actual y siguiente en la progresión
		local currentMount = nil
		local nextMount    = nil
		for i, mount in MountsConfig.World1 do
			if mount.Name == equippedName then
				currentMount = mount
				nextMount    = MountsConfig.World1[i + 1]
				break
			end
		end

		if not currentMount then return end

		-- Multiplicadores
		actualQuantity.Text = "x" .. tostring(currentMount.Multiplier)
		nextQuantity.Text   = nextMount and ("x" .. tostring(nextMount.Multiplier)) or "MAX"

		-- Barras de progreso
		if nextMount and nextMount.EvolveRequirements then
			local reqs = nextMount.EvolveRequirements

			local winsRatio  = math.clamp(playerWins  / reqs.Wins,  0, 1)
			local levelRatio = math.clamp(playerLevel / reqs.Level, 0, 1)

			TweenService:Create(winsFill,   FILL_TWEEN, { Size = UDim2.new(winsRatio,  0, 1, 0) }):Play()
			TweenService:Create(levelsFill, FILL_TWEEN, { Size = UDim2.new(levelRatio, 0, 1, 0) }):Play()

			winsTitle.Text   = playerWins  .. "/" .. reqs.Wins
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
		MenuAnimations.close(menuEvolve)
		MenuAnimations.blurOut()
		openMenu = nil
	else
		showAlert("Cannot Evolve", message)
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

local rebirthPending = false
rebirthButton.MouseButton1Click:Connect(function()
	if rebirthPending then return end
	rebirthPending = true
	Packets.DoRebirth:Fire()
end)

Packets.RebirthResult.OnClientEvent:Connect(function(success: boolean, message: string)
	rebirthPending = false
	if success then
		MenuAnimations.close(menuRebirth)
		MenuAnimations.blurOut()
		openMenu = nil
	else
		showAlert("Cannot Rebirth", message)
	end
end)

-- ── Open / Close ─────────────────────────────────────────────────────────────

local function closeAll()
	if openMenu then
		MenuAnimations.close(openMenu)
		MenuAnimations.blurOut()
		openMenu = nil
	end
end

local function toggleMenu(menu: Frame, onOpen: (() -> ())?)
	if openMenu == menu then
		closeAll()
	else
		closeAll()
		openMenu = menu
		MenuAnimations.blurIn()
		MenuAnimations.open(menu)
		if onOpen then onOpen() end
	end
end

btnEvolve.MouseButton1Click:Connect(function()
	toggleMenu(menuEvolve, populateEvolveMenu)
end)

btnRebirth.MouseButton1Click:Connect(function()
	toggleMenu(menuRebirth, populateRebirthMenu)
end)

closeEvolve.MouseButton1Click:Connect(function()
	closeAll()
end)

closeRebirth.MouseButton1Click:Connect(function()
	closeAll()
end)

closeIndex.MouseButton1Click:Connect(function()
	closeAll()
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

		ct.MouseButton1Click:Connect(function()
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
	toggleMenu(menuIndex, populateIndexMenu)
end)

-- Re-render grid si Index está abierto y cambia montura o inventario
task.spawn(function()
	DataService:waitForData()
	local function refreshIfOpen()
		if openMenu ~= menuIndex then return end
		local equippedName = (DataService:get({ "EquippedMount" }) or "Chonk") :: string
		local ownedMounts  = (DataService:get({ "Mounts" }) or {}) :: {[string]: boolean}
		populateWorldGrid(selectedWorldKey, ownedMounts, equippedName)
	end
	DataService:getChangedSignal({ "EquippedMount" }):Connect(refreshIfOpen)
	DataService:getChangedSignal({ "Mounts" }):Connect(refreshIfOpen)
end)
