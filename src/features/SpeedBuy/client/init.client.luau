--!strict

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local SpeedBuyConfig = require(ReplicatedStorage.Shared.SpeedBuyConfig)
local CheckoutAnalytics = require(ReplicatedStorage.Shared.CheckoutAnalytics)
local DataService = require(ReplicatedStorage.Packages.DataService).client

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Los botones "+100K/+1M/+10M/+100M Speed" viven en el panel inferior. Su texto
-- ("+100K Speed") ya está puesto en Studio; aquí solo se cablea la compra.
local buttons = playerGui:WaitForChild("Bot")
	:WaitForChild("Content")
	:WaitForChild("Buttons")

DataService:waitForData()

for _, data in SpeedBuyConfig.Products do
	local button = buttons:FindFirstChild(data.ButtonName)
	if not button or not button:IsA("GuiButton") then
		warn(`[SpeedBuy] No se encontró el botón {data.ButtonName} en Bot.Content.Buttons`)
		continue
	end

	-- El IsA de arriba ya estrecha `button` a GuiButton, así que no hace falta cast
	-- (y empezar la línea con `(` rompe el parser de Luau: "Ambiguous syntax").
	local productId = data.ProductId
	CheckoutAnalytics.show(productId, data.ButtonName)
	button.Activated:Connect(function()
		CheckoutAnalytics.prompt(productId, data.ButtonName)
	end)
end
