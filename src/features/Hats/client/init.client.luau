--!strict

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MenuAnimations = require(ReplicatedStorage.Shared.MenuAnimations)
local MenuManager    = require(ReplicatedStorage.Shared.MenuManager)
local HatsData       = require(ReplicatedStorage.Shared.HatsData)
local Packets        = require(ReplicatedStorage.Shared.Packets)
local Utils          = require(ReplicatedStorage.Packages.Utils)
local FormatNumber   = require(ReplicatedStorage.Packages.FormatNumber)
local DataService    = require(ReplicatedStorage.Packages.DataService).client

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local hatsFolder = ReplicatedStorage:WaitForChild("Hats")

local left  = playerGui:WaitForChild("Left")
local menus = playerGui:WaitForChild("Menus")

-- Botón de apertura (menú izquierdo, Line2)
local btnHats = left:WaitForChild("Main"):WaitForChild("Line2"):WaitForChild("Hats") :: ImageButton

-- Menú Hats
local menuHats     = menus:WaitForChild("Hats")         :: Frame
local closeHats    = menuHats:WaitForChild("Right"):WaitForChild("Close") :: ImageButton
local scrolling    = menuHats:WaitForChild("ScrollingFrame")   :: ScrollingFrame
local templates    = scrolling:WaitForChild("Templates")
local cardTemplate = templates:WaitForChild("CardTemplateNumbered") :: ImageButton

-- Notificación (para alertas de error), compartida con el resto de menús
local notification = menus:WaitForChild("Notification") :: Frame
local closeNotif   = notification:WaitForChild("Close")  :: ImageButton


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

-- ── Grid de hats ─────────────────────────────────────────────────────────────

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

local function buildCard(hat: HatsData.HatData, owned: boolean, equipped: boolean, order: number)
	local cardNumbered = cardTemplate:Clone()
	local card = cardNumbered:WaitForChild("CardTemplate") :: ImageButton

	local textName = card:FindFirstChild("TextName") :: TextLabel?
	if textName then textName.Text = hat.Name end

	setMultiplierLabel(card, hat.Multiplier)

	-- Usamos el ViewportFrame para el preview 3D → ocultamos Image1
	local image1 = card:FindFirstChild("Image1") :: ImageLabel?
	if image1 then image1.Visible = false end

	-- Preview 3D en el ViewportFrame
	local viewport = card:FindFirstChild("ViewportFrame") :: ViewportFrame?
	if viewport then
		local model = hatsFolder:FindFirstChild(hat.Name)
		if model and model:IsA("Model") then
			local clone = model:Clone()
			clone.Parent = viewport
			Utils.SetupViewport(viewport, clone)
		end
	end

	-- Estado equipado
	local equippedFrame = card:FindFirstChild("Equipped") :: Frame?
	if equippedFrame then equippedFrame.Visible = equipped end

	-- Estado de compra (precio) — solo si no se posee
	local unlock = card:FindFirstChild("Unlock") :: Frame?
	if unlock then
		unlock.Visible = not owned
		local quantity = unlock:FindFirstChild("Quantity") :: TextLabel?
		if quantity then quantity.Text = FormatNumber:formatNumberCoins(hat.Price) end
	end

	cardNumbered.LayoutOrder = order
	cardNumbered.Visible = true
	cardNumbered.Parent = scrolling

	cardNumbered.MouseButton1Click:Connect(function()
		if owned then
			if not equipped then
				Packets.EquipHat:Fire(hat.Name)
			end
		else
			Packets.BuyHat:Fire(hat.Name)
		end
	end)
end

-- Primera card: quitar el hat (multiplicador 1, siempre disponible)
local function buildRemoveCard(equippedHat: string, order: number)
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

	-- "Equipped" cuando no hay ningún hat puesto
	local equippedFrame = card:FindFirstChild("Equipped") :: Frame?
	if equippedFrame then equippedFrame.Visible = (equippedHat == "") end

	cardNumbered.LayoutOrder = order
	cardNumbered.Visible = true
	cardNumbered.Parent = scrolling

	cardNumbered.MouseButton1Click:Connect(function()
		if equippedHat ~= "" then
			Packets.EquipHat:Fire("None")
		end
	end)
end

local function populate()
	clearGrid()

	local ownedHats   = (DataService:get({ "Hats" }) or {}) :: { [string]: boolean }
	local equippedHat = (DataService:get({ "EquippedHat" }) or "") :: string

	buildRemoveCard(equippedHat, 1)

	for i, hat in HatsData.Hats do
		local owned    = ownedHats[hat.Name] == true
		local equipped = (equippedHat == hat.Name)
		buildCard(hat, owned, equipped, i + 1)
	end
end

-- ── Open / Close ─────────────────────────────────────────────────────────────

btnHats.MouseButton1Click:Connect(function()
	MenuManager.toggle(menuHats, {
		onOpen = function()
			task.spawn(function()
				DataService:waitForData()
				populate()
			end)
		end,
	})
end)

closeHats.MouseButton1Click:Connect(function()
	MenuManager.close(menuHats)
end)

-- ── Resultados y refresh ─────────────────────────────────────────────────────

Packets.BuyHatResult.OnClientEvent:Connect(function(success: boolean, message: string)
	if not success then
		showAlert("Cannot Buy", message)
	end
end)

Packets.EquipHatResult.OnClientEvent:Connect(function(success: boolean, message: string)
	if not success then
		showAlert("Cannot Equip", message)
	end
end)

-- Re-render si el menú está abierto y cambia inventario/equipado
task.spawn(function()
	DataService:waitForData()
	local function refreshIfOpen()
		if MenuManager.isOpen(menuHats) then populate() end
	end
	DataService:getChangedSignal({ "Hats" }):Connect(refreshIfOpen)
	DataService:getChangedSignal({ "EquippedHat" }):Connect(refreshIfOpen)
end)
