--!strict

local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local DataService  = require(ReplicatedStorage.Packages.DataService).client
local MountsConfig = require(ReplicatedStorage.Shared.MountsConfig)
local CheckoutAnalytics = require(ReplicatedStorage.Shared.CheckoutAnalytics)

local player = Players.LocalPlayer

local PROMPT_COOLDOWN = 5 -- segundos entre prompts por montura
local lastPromptTime: { [number]: number } = {}

local folder = workspace:WaitForChild("PremiumMounts") :: Folder

-- Resuelve el TextLabel del precio dentro de un Detail<i>
-- Resuelve el TextLabel del precio dentro de un sub-frame del Detail
local function getPriceLabel(detail: Instance, frameName: string): TextLabel?
	local sg = detail:FindFirstChildOfClass("SurfaceGui")
	if not sg then return nil end
	local frame = sg:FindFirstChild(frameName)
	if not frame then return nil end
	return frame:FindFirstChild("RequiredWins") :: TextLabel?
end

-- Configura el precio regional (localizado) en el cartel. GetProductInfoAsync DEBE
-- correr en el cliente para que PriceInRobux refleje la región y los descuentos
-- por usuario (ej. Premium). FrameFinalPrice = precio final; Frame = precio original.
local function applyRegionalPrice(detail: Instance, productId: number): ()
	local finalLabel    = getPriceLabel(detail, "FrameFinalPrice")
	local originalLabel = getPriceLabel(detail, "Frame")
	if not finalLabel and not originalLabel then
		warn("[PremiumMounts] No se encontró RequiredWins en", detail:GetFullName())
		return
	end

	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfoAsync(productId, Enum.InfoType.Product)
	end)

	if not (ok and info and info.PriceInRobux) then
		warn("[PremiumMounts] GetProductInfoAsync falló para", productId, info)
		return
	end

	local finalPrice = info.PriceInRobux
	local basePrice  = info.UserBasePriceInRobux or finalPrice
	local hasDiscount = basePrice > finalPrice

	if finalLabel then
		finalLabel.Text = tostring(finalPrice)
	end
	if originalLabel then
		originalLabel.Text = tostring(basePrice)
		-- Sin descuento: ocultar el precio original y su línea de tachado,
		-- dejando solo el precio final.
		local originalFrame = originalLabel.Parent :: GuiObject?
		if originalFrame then
			originalFrame.Visible = hasDiscount
		end
	end

	local sg = detail:FindFirstChildOfClass("SurfaceGui")
	local line = sg and sg:FindFirstChild("Line") :: GuiObject?
	if line then
		line.Visible = hasDiscount
	end
end

-- Conecta una part de compra (Buy<i>) al prompt del Developer Product
local function setupBuyButton(buyPart: BasePart, mount: { Name: string, ProductId: number? }): ()
	local productId = mount.ProductId
	if not productId then return end

	buyPart.Touched:Connect(function(hit: BasePart)
		local character = player.Character
		if not character then return end
		if not hit:IsDescendantOf(character) then return end

		-- Ya es dueño: no volver a ofrecer
		if DataService:get({ "Mounts", mount.Name }) == true then return end

		local now = os.clock()
		if (now - (lastPromptTime[productId] or 0)) < PROMPT_COOLDOWN then return end
		lastPromptTime[productId] = now

		CheckoutAnalytics.prompt(productId, mount.Name)
	end)
end

-- El número del pedestal (Detail<n> / Buy<n>) es la posición entre las monturas
-- VENDIBLES, NO el índice dentro de MountsConfig.Premium.
--
-- Esa lista mezcla las de pago con las del Daily Login y la del obby de Admin
-- Abuse, así que los dos números solo coinciden mientras las de pago estén las
-- primeras. Al mover el ProductId de Phantom Chopper (índice 2) a Frostak
-- (índice 7), el script se puso a buscar Buy7/Detail7 —que no existen en el
-- Workspace— y el pedestal dejó de lanzar el modal sin dar ningún error.
--
-- Con un contador propio, el orden de los pedestales es el orden de aparición de
-- las monturas con ProductId, y da igual dónde caigan dentro del array.
local slot = 0
for _, mount in MountsConfig.Premium do
	local productId = mount.ProductId
	if not productId then continue end

	slot += 1

	local detail = folder:WaitForChild("Detail" .. slot, 10)
	if detail then
		task.spawn(applyRegionalPrice, detail, productId)
	else
		warn(`[PremiumMounts] Falta Detail{slot} en Workspace.PremiumMounts para "{mount.Name}"`)
	end

	local buyPart = folder:WaitForChild("Buy" .. slot, 10) :: BasePart?
	if buyPart then
		setupBuyButton(buyPart, mount)
	else
		warn(`[PremiumMounts] Falta Buy{slot} en Workspace.PremiumMounts — "{mount.Name}" no se puede comprar desde el mundo`)
	end
end
