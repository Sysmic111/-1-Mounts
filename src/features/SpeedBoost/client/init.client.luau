--!strict

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local SpeedBoostConfig = require(ReplicatedStorage.Shared.SpeedBoostConfig)
local DataService      = require(ReplicatedStorage.Packages.DataService).client
local CheckoutAnalytics = require(ReplicatedStorage.Shared.CheckoutAnalytics)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local right = playerGui:WaitForChild("Right")
local line1 = right:WaitForChild("Main"):WaitForChild("Line1")

local speedBtn  = line1:WaitForChild("Speed")                           :: ImageButton
local titleLabel = speedBtn:WaitForChild("Button"):WaitForChild("Title") :: TextLabel
local priceLabel = speedBtn:WaitForChild("Price"):WaitForChild("Title")  :: TextLabel

-- ── Precio en vivo (GetProductInfo) con fallback al config ────────────────────

-- Roblox no expone el precio regional del jugador antes del prompt; GetProductInfo
-- devuelve el precio base del dashboard. Se pide una vez por producto y se cachea,
-- y mientras tanto se muestra el precio del config para no dejar el botón vacío.
local priceCache: { [number]: number } = {}

local function fetchPrice(tier: SpeedBoostConfig.TierData, onResolved: (number) -> ())
	local cached = priceCache[tier.ProductId]
	if cached then
		onResolved(cached)
		return
	end

	-- Fallback inmediato mientras llega la respuesta.
	onResolved(tier.Price)

	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(tier.ProductId, Enum.InfoType.Product)
		end)
		if ok and info and typeof(info.PriceInRobux) == "number" then
			priceCache[tier.ProductId] = info.PriceInRobux
			onResolved(info.PriceInRobux)
		end
	end)
end

-- ── Estado del botón ─────────────────────────────────────────────────────────

local function currentTier(): number
	return (DataService:get({ "SpeedTier" }) or 0) :: number
end

-- El botón muestra SIEMPRE el siguiente tier a comprar. Con todos comprados
-- (SpeedTier == MaxTier) desaparece.
local function refresh()
	local nextTier = currentTier() + 1
	local data = SpeedBoostConfig.getByTier(nextTier)

	if not data then
		speedBtn.Visible = false
		return
	end

	speedBtn.Visible = true
	titleLabel.Text  = "x" .. tostring(data.Multiplier) .. " Speed"
	CheckoutAnalytics.show(data.ProductId, "x" .. tostring(data.Multiplier))

	fetchPrice(data, function(price)
		-- La data pudo cambiar mientras se resolvía el precio async.
		if currentTier() + 1 == data.Tier then
			priceLabel.Text = tostring(price)
		end
	end)
end

speedBtn.Activated:Connect(function()
	local data = SpeedBoostConfig.getByTier(currentTier() + 1)
	if not data then return end
	CheckoutAnalytics.prompt(data.ProductId, "x" .. tostring(data.Multiplier))
end)

task.spawn(function()
	DataService:waitForData()
	refresh()
	DataService:getChangedSignal({ "SpeedTier" }):Connect(refresh)
end)
