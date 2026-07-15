--!strict

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MenuAnimations = require(ReplicatedStorage.Shared.MenuAnimations)
local HatsData       = require(ReplicatedStorage.Shared.HatsData)
local Packets        = require(ReplicatedStorage.Shared.Packets)
local Utils          = require(ReplicatedStorage.Packages.Utils)
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
	if buySection then buySection.Visible = false end

	MenuAnimations.open(notification)
end

closeNotif.MouseButton1Click:Connect(function()
	MenuAnimations.close(notification)
end)

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
		if quantity then quantity.Text = abbreviate(hat.Price) end
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

	-- Sin ícono ni preview 3D
	local image1 = card:FindFirstChild("Image1") :: ImageLabel?
	if image1 then image1.Visible = false end
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

local function openMenu()
	if isOpen then return end
	isOpen = true
	MenuAnimations.blurIn()
	MenuAnimations.open(menuHats)
	task.spawn(function()
		DataService:waitForData()
		populate()
	end)
end

local function closeMenu()
	if not isOpen then return end
	isOpen = false
	MenuAnimations.close(menuHats)
	MenuAnimations.blurOut()
end

btnHats.MouseButton1Click:Connect(function()
	if isOpen then
		closeMenu()
	else
		openMenu()
	end
end)

closeHats.MouseButton1Click:Connect(closeMenu)

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
		if isOpen then populate() end
	end
	DataService:getChangedSignal({ "Hats" }):Connect(refreshIfOpen)
	DataService:getChangedSignal({ "EquippedHat" }):Connect(refreshIfOpen)
end)
