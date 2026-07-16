--!strict

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MenuAnimations = require(ReplicatedStorage.Shared.MenuAnimations)
local TrailsData     = require(ReplicatedStorage.Shared.TrailsData)
local Packets        = require(ReplicatedStorage.Shared.Packets)
local DataService    = require(ReplicatedStorage.Packages.DataService).client

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local left  = playerGui:WaitForChild("Left")
local menus = playerGui:WaitForChild("Menus")

-- Botón de apertura (menú izquierdo, Line2)
local btnTrails = left:WaitForChild("Main"):WaitForChild("Line2"):WaitForChild("Trails") :: ImageButton

-- Menú Trails
local menuTrails   = menus:WaitForChild("Trails")        :: Frame
local closeTrails  = menuTrails:WaitForChild("Right"):WaitForChild("Close") :: ImageButton
local scrolling    = menuTrails:WaitForChild("ScrollingFrame")  :: ScrollingFrame
local templates    = scrolling:WaitForChild("Templates")
local cardTemplate = templates:WaitForChild("CardTemplateNumbered") :: ImageButton

-- Notificación (para alertas de error), compartida con el resto de menús
local notification = menus:WaitForChild("Notification") :: Frame
local closeNotif   = notification:WaitForChild("Close")  :: ImageButton

local isOpen = false

-- ── Utilidades ───────────────────────────────────────────────────────────────

local function abbreviate(n: number): string
	if n >= 1_000_000_000 then
		return string.format("%.1fB", n / 1_000_000_000)
	elseif n >= 1_000_000 then
		return string.format("%.1fM", n / 1_000_000)
	elseif n >= 1_000 then
		return string.format("%.1fK", n / 1_000)
	end
	return tostring(n)
end

local function showAlert(title: string, description: string)
	local titleLabel = notification:FindFirstChild("Title") :: TextLabel?
	local descLabel  = notification:FindFirstChild("Description") :: TextLabel?
	if titleLabel then titleLabel.Text = title end
	if descLabel  then descLabel.Text  = description end

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
end)

-- ── Grid de trails ───────────────────────────────────────────────────────────

local function clearGrid()
	for _, child in scrolling:GetChildren() do
		if child.Name == "Templates"
			or child:IsA("UIGridLayout")
			or child:IsA("UIListLayout")
			or child:IsA("UIAspectRatioConstraint") then
			continue
		end
		child:Destroy()
	end
end

local function buildCard(trail: TrailsData.TrailData, owned: boolean, equipped: boolean, order: number)
	local cardNumbered = cardTemplate:Clone()
	local card = cardNumbered:WaitForChild("CardTemplate") :: ImageButton

	local textName = card:FindFirstChild("TextName") :: TextLabel?
	if textName then textName.Text = trail.Name end

	-- Preview: la textura del trail tinteada por su color (sin viewport 3D)
	local viewport = card:FindFirstChild("ViewportFrame") :: ViewportFrame?
	if viewport then viewport.Visible = false end

	local image1 = card:FindFirstChild("Image1") :: ImageLabel?
	if image1 then
		image1.Visible = true
		image1.Image = trail.Texture
		image1.ImageColor3 = trail.Color
	end

	-- Estado equipado
	local equippedFrame = card:FindFirstChild("Equipped") :: Frame?
	if equippedFrame then equippedFrame.Visible = equipped end

	-- Estado de compra (precio) — solo si no se posee
	local unlock = card:FindFirstChild("Unlock") :: Frame?
	if unlock then
		unlock.Visible = not owned
		local quantity = unlock:FindFirstChild("Quantity") :: TextLabel?
		if quantity then quantity.Text = abbreviate(trail.Price) end
	end

	cardNumbered.LayoutOrder = order
	cardNumbered.Visible = true
	cardNumbered.Parent = scrolling

	cardNumbered.MouseButton1Click:Connect(function()
		if owned then
			if not equipped then
				Packets.EquipTrail:Fire(trail.Name)
			end
		else
			Packets.BuyTrail:Fire(trail.Name)
		end
	end)
end

-- Primera card: quitar el trail (multiplicador 1, siempre disponible)
local function buildRemoveCard(equippedTrail: string, order: number)
	local cardNumbered = cardTemplate:Clone()
	local card = cardNumbered:WaitForChild("CardTemplate") :: ImageButton

	local textName = card:FindFirstChild("TextName") :: TextLabel?
	if textName then textName.Text = "Remove" end

	-- Sin preview
	local image1 = card:FindFirstChild("Image1") :: ImageLabel?
	if image1 then image1.Visible = false end
	local viewport = card:FindFirstChild("ViewportFrame") :: ViewportFrame?
	if viewport then viewport.Visible = false end

	-- Nunca tiene precio
	local unlock = card:FindFirstChild("Unlock") :: Frame?
	if unlock then unlock.Visible = false end

	-- "Equipped" cuando no hay ningún trail puesto
	local equippedFrame = card:FindFirstChild("Equipped") :: Frame?
	if equippedFrame then equippedFrame.Visible = (equippedTrail == "") end

	cardNumbered.LayoutOrder = order
	cardNumbered.Visible = true
	cardNumbered.Parent = scrolling

	cardNumbered.MouseButton1Click:Connect(function()
		if equippedTrail ~= "" then
			Packets.EquipTrail:Fire("None")
		end
	end)
end

local function populate()
	clearGrid()

	local ownedTrails   = (DataService:get({ "Trails" }) or {}) :: { [string]: boolean }
	local equippedTrail = (DataService:get({ "EquippedTrail" }) or "") :: string

	buildRemoveCard(equippedTrail, 1)

	for i, trail in TrailsData.Trails do
		local owned    = ownedTrails[trail.Name] == true
		local equipped = (equippedTrail == trail.Name)
		buildCard(trail, owned, equipped, i + 1)
	end
end

-- ── Open / Close ─────────────────────────────────────────────────────────────

local function openMenu()
	if isOpen then return end
	isOpen = true
	MenuAnimations.blurIn()
	MenuAnimations.open(menuTrails)
	task.spawn(function()
		DataService:waitForData()
		populate()
	end)
end

local function closeMenu()
	if not isOpen then return end
	isOpen = false
	MenuAnimations.close(menuTrails)
	MenuAnimations.blurOut()
end

btnTrails.MouseButton1Click:Connect(function()
	if isOpen then
		closeMenu()
	else
		openMenu()
	end
end)

closeTrails.MouseButton1Click:Connect(closeMenu)

-- ── Resultados y refresh ─────────────────────────────────────────────────────

Packets.BuyTrailResult.OnClientEvent:Connect(function(success: boolean, message: string)
	if not success then
		showAlert("Cannot Buy", message)
	end
end)

Packets.EquipTrailResult.OnClientEvent:Connect(function(success: boolean, message: string)
	if not success then
		showAlert("Cannot Equip", message)
	end
end)

-- Re-render si el menú está abierto y cambia inventario/equipado
task.spawn(function()
	DataService:waitForData()
	local function refreshIfOpen()
		if isOpen then populate() end
	end
	DataService:getChangedSignal({ "Trails" }):Connect(refreshIfOpen)
	DataService:getChangedSignal({ "EquippedTrail" }):Connect(refreshIfOpen)
end)
