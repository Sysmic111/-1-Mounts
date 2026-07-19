--!strict

local HttpService       = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnalyticsConfig = require(ReplicatedStorage.Shared.AnalyticsConfig)
local Packets         = require(ReplicatedStorage.Shared.Packets)

type CheckoutSession = {
	Id: string,
	OfferId: string,
}

local player = Players.LocalPlayer
local sessions: { [number]: CheckoutSession } = {}

local CheckoutAnalytics = {}

local function fire(action: string, productId: number, session: CheckoutSession): ()
	Packets.AnalyticsCheckoutAction:Fire(action, productId, session.Id, session.OfferId)
end

function CheckoutAnalytics.show(productId: number, offerId: string?): string?
	local product = AnalyticsConfig.getProduct(productId)
	if not product then return nil end

	local resolvedOffer = offerId or product.Variant
	local current = sessions[productId]
	if current and current.OfferId == resolvedOffer then
		return current.Id
	end

	local session = {
		Id = HttpService:GenerateGUID(false),
		OfferId = resolvedOffer,
	}
	sessions[productId] = session
	fire("OfferShown", productId, session)
	return session.Id
end

function CheckoutAnalytics.prompt(productId: number, offerId: string?): ()
	CheckoutAnalytics.show(productId, offerId)
	local session = sessions[productId]
	if not session then return end

	fire("OfferSelected", productId, session)
	fire("PromptOpened", productId, session)
	MarketplaceService:PromptProductPurchase(player, productId)
end

Packets.AnalyticsCheckoutSession.OnClientEvent:Connect(function(productId: number, sessionId: string, offerId: string)
	if not AnalyticsConfig.isValidOffer(productId, offerId) then return end
	sessions[productId] = { Id = sessionId, OfferId = offerId }
end)

MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, productId: number, isPurchased: boolean)
	if userId ~= player.UserId then return end
	local session = sessions[productId]
	if not session then return end
	if isPurchased then
		fire("PurchaseConfirmed", productId, session)
	end
	sessions[productId] = nil
end)

return CheckoutAnalytics
