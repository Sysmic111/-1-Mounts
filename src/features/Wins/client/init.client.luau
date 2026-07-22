--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AvatarEditorService = game:GetService("AvatarEditorService")

local DataService = require(ReplicatedStorage.Packages.DataService).client
local FormatNumber = require(ReplicatedStorage.Packages.FormatNumber)
local Packets = require(ReplicatedStorage.Shared.Packets)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local quantity = playerGui
	:WaitForChild("Left")
	:WaitForChild("Main")
	:WaitForChild("Line1")
	:WaitForChild("Currencies")
	:WaitForChild("Trophys")
	:WaitForChild("Quantity") :: TextLabel

task.spawn(function()
	DataService:waitForData()
	quantity.Text = FormatNumber:formatNumberCoins(DataService:get({ "WinCurrency" }) or 0)
	DataService:getChangedSignal({ "WinCurrency" }):Connect(function(newValue: number)
		quantity.Text = FormatNumber:formatNumberCoins(newValue)
	end)
end)

-- En el 2º claim de Wins de por vida, el servidor pide lanzar el prompt nativo de
-- favoritos (no hay API para detectar si ya está marcado; solo se prompea una vez).
-- itemType 1 = experiencia/place.
Packets.PromptFavorite.OnClientEvent:Connect(function()
	pcall(function()
		AvatarEditorService:PromptSetFavorite(game.PlaceId, 1, true)
	end)
end)
