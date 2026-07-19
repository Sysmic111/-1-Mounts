--!strict

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local MenuManager       = require(ReplicatedStorage.Shared.MenuManager)
local StarterPackConfig = require(ReplicatedStorage.Shared.StarterPackConfig)
local FormatNumber      = require(ReplicatedStorage.Packages.FormatNumber)
local DataService       = require(ReplicatedStorage.Packages.DataService).client
local CheckoutAnalytics = require(ReplicatedStorage.Shared.CheckoutAnalytics)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local right = playerGui:WaitForChild("Right")
local menus = playerGui:WaitForChild("Menus")

-- Botón de apertura (menú derecho)
local btnStarter = right:WaitForChild("Main"):WaitForChild("Line1"):WaitForChild("Starter") :: ImageButton

local menuStarter = menus:WaitForChild("StarterPack")                          :: Frame
local closeStarter = menuStarter:WaitForChild("Right"):WaitForChild("Close")   :: ImageButton
local scrolling   = menuStarter:WaitForChild("ScrollingFrame")                 :: ScrollingFrame
local buyButton   = menuStarter:WaitForChild("Buy")                            :: ImageButton

-- ── Utilidades ───────────────────────────────────────────────────────────────

-- ── Cards ────────────────────────────────────────────────────────────────────

local function forEachCard(fn: (card: ImageButton, icon: ImageLabel, rewardText: TextLabel, claimed: ImageLabel) -> ())
	for _, child in scrolling:GetChildren() do
		if not child:IsA("ImageButton") then continue end

		local ct = child:FindFirstChild("CardTemplate") :: ImageButton?
		if not ct then continue end

		local icon       = ct:FindFirstChild("ImageLabel") :: ImageLabel?
		local rewardText = ct:FindFirstChild("RewardText") :: TextLabel?
		local claimed    = ct:FindFirstChild("Claimed")    :: ImageLabel?
		if not icon or not rewardText or not claimed then continue end

		fn(child, icon, rewardText, claimed)
	end
end

-- El config manda sobre los textos: las cards se identifican por su icono porque
-- comparten nombre y LayoutOrder. Si el icono no es ninguno de los dos conocidos,
-- se respeta el texto puesto a mano en Studio.
local function applyRewardTexts()
	forEachCard(function(_card, icon, rewardText, _claimed)
		if icon.Image == StarterPackConfig.WinsIcon then
			rewardText.Text = "x" .. FormatNumber:formatNumberCoins(StarterPackConfig.Wins) .. " Wins"
		elseif icon.Image == StarterPackConfig.SpeedIcon then
			rewardText.Text = "x" .. FormatNumber:formatNumberCoins(StarterPackConfig.Speed) .. " Speed"
		end
	end)
end

-- ── Estado ───────────────────────────────────────────────────────────────────

local function isBought(): boolean
	return DataService:get({ "StarterPackBought" }) == true
end

-- Es una oferta única: una vez comprada, el botón del menú derecho desaparece.
-- Si el menú está abierto en ese momento NO se cierra a la fuerza: las cards pasan
-- a mostrar el check y así el jugador ve qué acaba de recibir. Al cerrarlo ya no
-- podrá volver a abrirlo.
local function refreshState()
	local bought = isBought()

	btnStarter.Visible = not bought
	buyButton.Visible  = not bought

	forEachCard(function(_card, _icon, _rewardText, claimed)
		claimed.Visible = bought
	end)
end

-- ── Open / Close / Buy ───────────────────────────────────────────────────────

btnStarter.MouseButton1Click:Connect(function()
	if isBought() then return end
	MenuManager.toggle(menuStarter, {
		onOpen = function()
			applyRewardTexts()
			CheckoutAnalytics.show(StarterPackConfig.ProductId, "StarterPack")
		end,
	})
end)

closeStarter.MouseButton1Click:Connect(function()
	MenuManager.close(menuStarter)
end)

buyButton.MouseButton1Click:Connect(function()
	-- El cliente solo lanza el prompt; quien concede es StarterPackService desde
	-- ProcessReceipt. Nunca se confía en el cliente para dar las recompensas.
	if isBought() then return end
	CheckoutAnalytics.prompt(StarterPackConfig.ProductId, "StarterPack")
end)

-- ── Init ─────────────────────────────────────────────────────────────────────

task.spawn(function()
	DataService:waitForData()
	applyRewardTexts()
	refreshState()
	-- Al confirmarse la compra, el servidor setea StarterPackBought y la data
	-- replicada dispara esto: no hace falta packet de respuesta.
	DataService:getChangedSignal({ "StarterPackBought" }):Connect(refreshState)
end)
