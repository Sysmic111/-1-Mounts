--!strict

local TweenService = game:GetService("TweenService")
local Lighting     = game:GetService("Lighting")

local OPEN_INFO  = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE_INFO = TweenInfo.new(0.2,  Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local BLUR_INFO  = TweenInfo.new(0.4,  Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local BLUR_SIZE  = 30

local blur = Lighting:FindFirstChild("DialogueBlur") :: BlurEffect?
if not blur then
	blur = Instance.new("BlurEffect")
	blur.Name   = "DialogueBlur"
	blur.Size   = 0
	blur.Parent = Lighting
end

local MenuAnimations = {}

function MenuAnimations.open(frame: Frame, endSize: UDim2?)
	local targetSize = endSize or frame.Size
	frame.Visible = true
	frame.Size = UDim2.new(
		targetSize.X.Scale  * 0.9, targetSize.X.Offset * 0.9,
		targetSize.Y.Scale  * 0.9, targetSize.Y.Offset * 0.9
	)
	TweenService:Create(frame, OPEN_INFO, { Size = targetSize }):Play()
end

function MenuAnimations.close(frame: Frame, callback: (() -> ())?)
	local originalSize = frame.Size
	local smallSize = UDim2.new(
		originalSize.X.Scale  * 0.9, originalSize.X.Offset * 0.9,
		originalSize.Y.Scale  * 0.9, originalSize.Y.Offset * 0.9
	)
	local tween = TweenService:Create(frame, CLOSE_INFO, { Size = smallSize })
	tween:Play()
	tween.Completed:Once(function()
		frame.Visible = false
		frame.Size    = originalSize
		if callback then callback() end
	end)
end

function MenuAnimations.blurIn(callback: (() -> ())?)
	TweenService:Create(blur :: BlurEffect, BLUR_INFO, { Size = BLUR_SIZE }):Play()
	if callback then task.delay(0.4, callback) end
end

function MenuAnimations.blurOut(callback: (() -> ())?)
	TweenService:Create(blur :: BlurEffect, BLUR_INFO, { Size = 0 }):Play()
	if callback then task.delay(0.4, callback) end
end

return MenuAnimations
