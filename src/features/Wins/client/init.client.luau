--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(ReplicatedStorage.Packages.DataService).client
local FormatNumber = require(ReplicatedStorage.Packages.FormatNumber)

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
