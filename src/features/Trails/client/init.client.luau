--!strict

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MenuAnimations = require(ReplicatedStorage.Shared.MenuAnimations)
local MenuManager    = require(ReplicatedStorage.Shared.MenuManager)
local TrailsData     = require(ReplicatedStorage.Shared.TrailsData)
local Packets        = require(ReplicatedStorage.Shared.Packets)
local FormatNumber   = require(ReplicatedStorage.Packages.FormatNumber)
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

-- Imagen base común a todos los trails; el color lo da el UIGradient por trail.
local TRAIL_IMAGE = "rbxassetid://109820878267213"

-- Imagen del icono de la card "Remove" (la misma de dentro del botón de cerrar).
local REMOVE_IMAGE = "rbxassetid://113114987656737"

-- Etiqueta del multiplicador (arriba de la card). Se crea por código porque el
-- template de Studio no la trae. Idempotente al re-poblar.
local function setMultiplierLabel(card: Instance, multiplier: number)
	local label = card:FindFirstChild("MultiplierLabel") :: TextLabel?
	if not label then
		label = Instance.new("TextLabel")
		label.Name                   = "MultiplierLabel"
		label.AnchorPoint            = Vector2.new(0.5, 0.5)
		label.Position               = UDim2.fromScale(0.5, 0.1)
		label.Size                   = UDim2.fromScale(0.9, 0.13)
		label.BackgroundTransparency = 1
		label.TextScaled             = true
		label.TextColor3             = Color3.fromRGB(255, 236, 120)
		label.FontFace               = Font.fromName("ComicNeueAngular", Enum.FontWeight.Bold)
		label.ZIndex                 = 6

		local stroke = Instance.new("UIStroke")
		stroke.Color     = Color3.fromRGB(0, 0, 0)
		stroke.Thickness = 2
		stroke.Parent    = label

		label.Parent = card
	end
	label.Text = string.format("x%.2f", multiplier)
end

-- Degradado del trail: el explícito (Rainbow) o uno derivado claro→color→oscuro
-- desde su Color, que da un acabado con brillo y representa su color.
local function trailGradient(trail: TrailsData.TrailData): ColorSequence
	if trail.Gradient then return trail.Gradient end
	local c = trail.Color
	local light = Color3.new(
		c.R + (1 - c.R) * 0.55,
		c.G + (1 - c.G) * 0.55,
		c.B + (1 - c.B) * 0.55
	)
	local dark = Color3.new(c.R * 0.5, c.G * 0.5, c.B * 0.5)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, light),
		ColorSequenceKeypoint.new(0.5, c),
		ColorSequenceKeypoint.new(1, dark),
	})
end


-- ── Utilidades ───────────────────────────────────────────────────────────────

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

	setMultiplierLabel(card, trail.Multiplier)

	-- Preview: la imagen común coloreada con el degradado del trail (sin viewport 3D)
	local viewport = card:FindFirstChild("ViewportFrame") :: ViewportFrame?
	if viewport then viewport.Visible = false end

	local image1 = card:FindFirstChild("Image1") :: ImageLabel?
	if image1 then
		image1.Visible = true
		image1.Image = TRAIL_IMAGE
		-- Blanco: para que el UIGradient muestre sus colores reales sin tinte previo.
		image1.ImageColor3 = Color3.new(1, 1, 1)

		local gradient = image1:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
		gradient.Color = trailGradient(trail)
		gradient.Rotation = 90
		gradient.Parent = image1
	end

	-- Estado equipado
	local equippedFrame = card:FindFirstChild("Equipped") :: Frame?
	if equippedFrame then equippedFrame.Visible = equipped end

	-- Estado de compra (precio) — solo si no se posee
	local unlock = card:FindFirstChild("Unlock") :: Frame?
	if unlock then
		unlock.Visible = not owned
		local quantity = unlock:FindFirstChild("Quantity") :: TextLabel?
		if quantity then quantity.Text = FormatNumber:formatNumberCoins(trail.Price) end
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

	-- Icono: la misma imagen del botón de cerrar del menú
	local image1 = card:FindFirstChild("Image1") :: ImageLabel?
	if image1 then
		image1.Visible = true
		image1.Image = REMOVE_IMAGE
		image1.ImageColor3 = Color3.new(1, 1, 1)
	end
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

btnTrails.MouseButton1Click:Connect(function()
	MenuManager.toggle(menuTrails, {
		onOpen = function()
			task.spawn(function()
				DataService:waitForData()
				populate()
			end)
		end,
	})
end)

closeTrails.MouseButton1Click:Connect(function()
	MenuManager.close(menuTrails)
end)

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
		if MenuManager.isOpen(menuTrails) then populate() end
	end
	DataService:getChangedSignal({ "Trails" }):Connect(refreshIfOpen)
	DataService:getChangedSignal({ "EquippedTrail" }):Connect(refreshIfOpen)
end)
