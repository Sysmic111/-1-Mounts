--!strict

-- Receptor de Admin Abuse. Lo corren TODOS los jugadores (no solo admins): escucha
-- AdminAbuseState y muestra un banner fijo en la parte superior con la cuenta
-- regresiva en vivo (o el mensaje estático si el preset no tiene duración). El
-- envío/activación vive en el panel Admin; acá solo se recibe y se muestra.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packets = require(ReplicatedStorage.Shared.Packets)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "AdminAbuse"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 260 -- por encima del banner de Broadcast (250)
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local banner = Instance.new("Frame")
banner.Name = "Banner"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
banner.BorderSizePixel = 0
banner.Position = UDim2.fromScale(0.5, 0)
banner.Size = UDim2.fromOffset(360, 40)
banner.Visible = false
banner.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = banner

local label = Instance.new("TextLabel")
label.BackgroundTransparency = 1
label.Size = UDim2.fromScale(1, 1)
label.Font = Enum.Font.FredokaOne
label.Text = ""
label.TextColor3 = Color3.fromRGB(255, 235, 235)
label.TextScaled = true
label.TextWrapped = true
label.Parent = banner

local textConstraint = Instance.new("UITextSizeConstraint")
textConstraint.MaxTextSize = 22
textConstraint.MinTextSize = 12
textConstraint.Parent = label

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingRight = UDim.new(0, 10)
padding.Parent = banner

-- generation invalida el loop de countdown anterior cuando llega un estado nuevo.
local generation = 0

local function formatClock(secondsLeft: number): string
	secondsLeft = math.max(0, math.floor(secondsLeft))
	local minutes = math.floor(secondsLeft / 60)
	local seconds = secondsLeft % 60
	return string.format("%d:%02d", minutes, seconds)
end

local function hide()
	generation += 1
	banner.Visible = false
end

local function showStatic(message: string)
	generation += 1
	label.Text = message
	banner.Visible = true
end

local function showCountdown(message: string, endTime: number)
	generation += 1
	local myGen = generation
	banner.Visible = true

	task.spawn(function()
		while myGen == generation do
			local secondsLeft = endTime - os.time()
			if secondsLeft <= 0 then
				label.Text = message
				break
			end
			label.Text = string.format("%s %s", message, formatClock(secondsLeft))
			task.wait(1)
		end
	end)
end

Packets.AdminAbuseState.OnClientEvent:Connect(function(active: boolean, message: string, endTime: number)
	if type(active) ~= "boolean" or type(message) ~= "string" or type(endTime) ~= "number" then return end

	if not active then
		hide()
		return
	end

	if endTime > 0 then
		showCountdown(message, endTime)
	else
		showStatic(message)
	end
end)
