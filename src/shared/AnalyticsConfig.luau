--!strict

local MountsConfig     = require(script.Parent.MountsConfig)
local ReviveConfig     = require(script.Parent.ReviveConfig)
local RobuxConfig      = require(script.Parent.RobuxConfig)
local SpeedBoostConfig = require(script.Parent.SpeedBoostConfig)
local SpeedBuyConfig   = require(script.Parent.SpeedBuyConfig)
local StarterPackConfig = require(script.Parent.StarterPackConfig)

export type ProductAnalytics = {
	Category: string,
	Variant: string,
}

local AnalyticsConfig = {
	SchemaVersion = 1,
	StageWinsProductId = 3606256299,

	Funnels = {
		Onboarding = "NewPlayerOnboardingV1",
		Stages = "World1StagesV1",
		Mounts = "MountEvolutionV1",
		RebirthProgression = "RebirthProgressionV1",
		RebirthCycle = "RebirthCycleV1",
		Steps = "StepsProgressionV1",
		Daily = "DailyClaimsV1",
		Checkout = "DeveloperProductCheckoutV1",
	},
}

local products: { [number]: ProductAnalytics } = {}

local function addProduct(productId: number, category: string, variant: string): ()
	products[productId] = { Category = category, Variant = variant }
end

addProduct(StarterPackConfig.ProductId, "StarterPack", "StarterPack")
addProduct(ReviveConfig.ReviveOnceProductId, "Revive", "ReviveOnce")
addProduct(ReviveConfig.InfiniteRevivesProductId, "Revive", "InfiniteRevives")
addProduct(AnalyticsConfig.StageWinsProductId, "StageWins", "StageWins")

for tier, data in RobuxConfig.Treadmills do
	addProduct(data.ProductId, "Treadmill", tier)
end

for _, mount in MountsConfig.Premium do
	if mount.ProductId then
		addProduct(mount.ProductId, "PremiumMount", mount.Name)
	end
end

for _, data in SpeedBoostConfig.Tiers do
	addProduct(data.ProductId, "SpeedBoost", "x" .. tostring(data.Multiplier))
end

for _, data in SpeedBuyConfig.Products do
	addProduct(data.ProductId, "SpeedBuy", data.ButtonName)
end

function AnalyticsConfig.getProduct(productId: number): ProductAnalytics?
	return products[productId]
end

function AnalyticsConfig.isValidOffer(productId: number, offerId: string): boolean
	local product = products[productId]
	if not product then return false end
	if productId == AnalyticsConfig.StageWinsProductId then
		return offerId:match("^StageWins:%d+$") ~= nil
	end
	return offerId == product.Variant
end

return AnalyticsConfig
