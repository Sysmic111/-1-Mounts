local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

local clickSound = SoundService:WaitForChild("SFX"):WaitForChild("UI"):WaitForChild("ui_button_simple_click_05")
local hoverSound = SoundService:WaitForChild("SFX"):WaitForChild("UI"):WaitForChild("ui_menu_button_scroll_page_05")
local whooshDeepSound = SoundService:WaitForChild("SFX"):WaitForChild("Whoosh"):WaitForChild("whoosh_low_deep_01")

local connections = {}
local tags = {
	MenuButton = {
		Add = function(item)
			local originalSize = item.Size
			local border = item:WaitForChild("Button"):WaitForChild("Border"):WaitForChild("UIGradient")
			local frame = item:WaitForChild("Button"):WaitForChild("Frame"):WaitForChild("UIGradient")
			local icon = item:WaitForChild("Button"):WaitForChild("ImageLabel")
			local framTween =
				TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Offset = Vector2.new(-1, 0),
				})
			item.MouseEnter:Connect(function()
				hoverSound:Play()
				border.Offset = Vector2.new(0, 0)
				TweenService:Create(border, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Offset = Vector2.new(1, 0),
				}):Play()
				frame.Offset = Vector2.new(0, 0)
				framTween:Play()
				icon.Rotation = 0
				TweenService:Create(icon, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Rotation = 10,
				}):Play()
			end)
			item.MouseLeave:Connect(function()
				border.Offset = Vector2.new(0, 0)
				framTween:Cancel()
				frame.Offset = Vector2.new(0, 0)
				TweenService:Create(icon, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Rotation = 0,
				}):Play()
			end)
			item.MouseButton1Down:Connect(function()
				clickSound:Play()
			end)
		end,
		Remove = function(item) end,
	},
	SideMenuButton = {
		Add = function(item)
			local originalSize = item.Size
			local border = item:WaitForChild("Button"):WaitForChild("Border"):WaitForChild("UIGradient")
			local frame = item:WaitForChild("Button"):WaitForChild("Frame"):WaitForChild("UIGradient")
			local icon = item:WaitForChild("Button"):WaitForChild("ImageLabel")
			local framTween =
				TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Offset = Vector2.new(-1, 0),
				})
			item.MouseEnter:Connect(function()
				hoverSound:Play()
				item:TweenSize(UDim2.new(originalSize.X.Scale, originalSize.X.Offset, originalSize.Y.Scale * 1.2, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.1, false)
				border.Offset = Vector2.new(0, 0)
				local tween =
					TweenService:Create(border, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Offset = Vector2.new(1, 0),
					}):Play()
				frame.Offset = Vector2.new(0, 0)
				framTween:Play()
				icon.Rotation = 0
				local tween =
					TweenService:Create(icon, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Rotation = 10,
					}):Play()
			end)
			item.MouseLeave:Connect(function()
				border.Offset = Vector2.new(0, 0)
				framTween:Cancel()
				frame.Offset = Vector2.new(0, 0)
				item:TweenSize(originalSize, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.1, true)
				local tween =
					TweenService:Create(icon, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Rotation = 0,
					}):Play()
			end)
			item.MouseButton1Down:Connect(function()
				clickSound:Play()
				icon:TweenPosition(
					UDim2.new(0.5, 0, 0.3, 0),
					Enum.EasingDirection.Out,
					Enum.EasingStyle.Quad,
					0.1,
					false
				)
			end)
			item.MouseButton1Up:Connect(function()
				icon:TweenPosition(
					UDim2.new(0.5, 0, 0.35, 0),
					Enum.EasingDirection.Out,
					Enum.EasingStyle.Quad,
					0.1,
					true
				)
			end)
		end,
		Remove = function(item) end,
	},
	SideMenuRainbowButton = {
		Add = function(item)
			local originalSize = item.Size
			local border = item:WaitForChild("Button"):WaitForChild("Border"):WaitForChild("UIGradient")
			local frame = item:WaitForChild("Button"):WaitForChild("Frame"):WaitForChild("UIGradient")
			local icon = item:WaitForChild("Button"):WaitForChild("ImageLabel")
			local glare = item:WaitForChild("Button"):WaitForChild("Glare") :: ImageLabel

			local GLARE_NORMAL_SPEED = 25
			local GLARE_HOVER_SPEED  = 70
			local glareSpeed = GLARE_NORMAL_SPEED
			glare.ImageTransparency = 0.4

			local glareConn = RunService.Heartbeat:Connect(function(dt)
				glare.Rotation += glareSpeed * dt
			end)
			connections[item] = glareConn

			local originalFrameColor = frame.Color
			local hueOffset  = 0
			local rainbowConn: RBXScriptConnection?

			local function stopRainbow()
				if rainbowConn then
					rainbowConn:Disconnect()
					rainbowConn = nil
				end
				frame.Color = originalFrameColor
			end

			local function startRainbow()
				stopRainbow()
				rainbowConn = RunService.Heartbeat:Connect(function(dt)
					hueOffset = (hueOffset + dt * 0.4) % 1
					frame.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0,    Color3.fromHSV((0/6 + hueOffset) % 1, 1, 1)),
						ColorSequenceKeypoint.new(0.2,  Color3.fromHSV((1/6 + hueOffset) % 1, 1, 1)),
						ColorSequenceKeypoint.new(0.4,  Color3.fromHSV((2/6 + hueOffset) % 1, 1, 1)),
						ColorSequenceKeypoint.new(0.6,  Color3.fromHSV((3/6 + hueOffset) % 1, 1, 1)),
						ColorSequenceKeypoint.new(0.8,  Color3.fromHSV((4/6 + hueOffset) % 1, 1, 1)),
						ColorSequenceKeypoint.new(1,    Color3.fromHSV((5/6 + hueOffset) % 1, 1, 1)),
					})
				end)
			end

			item.MouseEnter:Connect(function()
				hoverSound:Play()
				item:TweenSize(UDim2.new(originalSize.X.Scale, originalSize.X.Offset, originalSize.Y.Scale * 1.2, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.1, false)
				border.Offset = Vector2.new(0, 0)
				TweenService:Create(border, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Offset = Vector2.new(1, 0),
				}):Play()
				startRainbow()
				glareSpeed = GLARE_HOVER_SPEED
				TweenService:Create(glare, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					ImageTransparency = 0,
				}):Play()
				icon.Rotation = 0
				TweenService:Create(icon, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Rotation = 10,
				}):Play()
			end)
			item.MouseLeave:Connect(function()
				border.Offset = Vector2.new(0, 0)
				stopRainbow()
				glareSpeed = GLARE_NORMAL_SPEED
				TweenService:Create(glare, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					ImageTransparency = 0.4,
				}):Play()
				item:TweenSize(originalSize, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.1, true)
				TweenService:Create(icon, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Rotation = 0,
				}):Play()
			end)
			item.MouseButton1Down:Connect(function()
				clickSound:Play()
				icon:TweenPosition(
					UDim2.new(0.5, 0, 0.3, 0),
					Enum.EasingDirection.Out,
					Enum.EasingStyle.Quad,
					0.1,
					false
				)
			end)
			item.MouseButton1Up:Connect(function()
				icon:TweenPosition(
					UDim2.new(0.5, 0, 0.35, 0),
					Enum.EasingDirection.Out,
					Enum.EasingStyle.Quad,
					0.1,
					true
				)
			end)
		end,
		Remove = function(item)
			if connections[item] then
				connections[item]:Disconnect()
				connections[item] = nil
			end
		end,
	},
	InternalSideMenuButton = {
		Add = function(item)
			local originalSize = item.Size
			local border = item:WaitForChild("Button"):WaitForChild("Border"):WaitForChild("UIGradient")
			local frame = item:WaitForChild("Button"):WaitForChild("Frame"):WaitForChild("UIGradient")
			local icon = item:WaitForChild("Button"):WaitForChild("ImageLabel")
			local framTween =
				TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Offset = Vector2.new(-1, 0),
				})

			local uiFolder = game:GetService("ReplicatedStorage"):WaitForChild("Models"):WaitForChild("UI")
			local activeFrame    = uiFolder:WaitForChild("ActiveFrame")
			local activeBorder   = uiFolder:WaitForChild("ActiveBorder")
			local inactiveFrame  = uiFolder:WaitForChild("InactiveFrame")
			local inactiveBorder = uiFolder:WaitForChild("InactiveBorder")

			local function applyColors(active: boolean)
				if active then
					frame.Color    = activeFrame.Color
					frame.Rotation = activeFrame.Rotation
					border.Color    = activeBorder.Color
					border.Rotation = activeBorder.Rotation
				else
					frame.Color    = inactiveFrame.Color
					frame.Rotation = inactiveFrame.Rotation
					border.Color    = inactiveBorder.Color
					border.Rotation = inactiveBorder.Rotation
				end
			end

			applyColors(item:GetAttribute("Active") == true)

			item.AttributeChanged:Connect(function(attr)
				if attr ~= "Active" then return end
				applyColors(item:GetAttribute("Active") == true)
			end)

			item.MouseEnter:Connect(function()
				hoverSound:Play()
				item:TweenSize(UDim2.new(originalSize.X.Scale, originalSize.X.Offset, originalSize.Y.Scale * 1.2, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.1, false)
				border.Offset = Vector2.new(0, 0)
				TweenService:Create(border, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Offset = Vector2.new(1, 0),
				}):Play()
				frame.Offset = Vector2.new(0, 0)
				framTween:Play()
				icon.Rotation = 0
				TweenService:Create(icon, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Rotation = 10,
				}):Play()
			end)
			item.MouseLeave:Connect(function()
				border.Offset = Vector2.new(0, 0)
				framTween:Cancel()
				frame.Offset = Vector2.new(0, 0)
				item:TweenSize(originalSize, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.1, true)
				TweenService:Create(icon, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Rotation = 0,
				}):Play()
			end)
			item.MouseButton1Down:Connect(function()
				clickSound:Play()
				icon:TweenPosition(
					UDim2.new(0.5, 0, 0.3, 0),
					Enum.EasingDirection.Out,
					Enum.EasingStyle.Quad,
					0.1,
					false
				)
			end)
			item.MouseButton1Up:Connect(function()
				icon:TweenPosition(
					UDim2.new(0.5, 0, 0.35, 0),
					Enum.EasingDirection.Out,
					Enum.EasingStyle.Quad,
					0.1,
					true
				)
			end)
		end,
		Remove = function(item) end,
	},
	SwitchButton = {
		Add = function(item)
			local fill = item:WaitForChild("Border"):WaitForChild("Fill")
			local originalSize = fill.Size
			local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

			local function applyState(isActive)
				if isActive then
					TweenService:Create(fill, tweenInfo, {
						Position = UDim2.new(0.4, 0, 0.5, 0),
						BackgroundColor3 = Color3.fromRGB(0, 200, 80),
					}):Play()
				else
					TweenService:Create(fill, tweenInfo, {
						Position = UDim2.new(0, 0, 0.5, 0),
						BackgroundColor3 = Color3.fromRGB(200, 50, 50),
					}):Play()
				end
				task.spawn(function()
					local big = UDim2.new(
						originalSize.X.Scale * 1.1, originalSize.X.Offset * 1.1,
						originalSize.Y.Scale * 1.1, originalSize.Y.Offset * 1.1
					)
					local tweenUp = TweenService:Create(fill, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = big })
					tweenUp:Play()
					tweenUp.Completed:Wait()
					TweenService:Create(fill, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = originalSize }):Play()
				end)
			end

			item.MouseButton1Down:Connect(function()
				clickSound:Play()
			end)
			item.AttributeChanged:Connect(function(attr)
				if attr == "IsActive" then
					applyState(item:GetAttribute("IsActive"))
				end
			end)
		end,
		Remove = function(item) end,
	},
	StoreMenuButton = {
		Add = function(item)
			local iconRight = item:WaitForChild("Button"):WaitForChild("right")
			local iconLeft = item:WaitForChild("Button"):WaitForChild("left")

			item.MouseEnter:Connect(function()
				hoverSound:Play()
				local tween =
					TweenService:Create(iconRight, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Rotation = 40,
						Position = UDim2.new(0.75,0,0.35,0)
					}):Play()
					local tween =
					TweenService:Create(iconLeft, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Rotation = -40,
						Position = UDim2.new(0.17,0,0.35,0)
					}):Play()
			end)
			item.MouseButton1Down:Connect(function()
				clickSound:Play()
			end)
			item.MouseLeave:Connect(function()
				local tween =
					TweenService:Create(iconRight, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Rotation = 20,
						Position = UDim2.new(0.67,0,0.35,0)
					}):Play()
					TweenService:Create(iconLeft, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Rotation = -20,
						Position = UDim2.new(0.25,0,0.35,0)
					}):Play()
			end)
		end,
	},
	RollButton = {
		Add = function(item)
			local originalSize = item.Size
			item.MouseEnter:Connect(function()
				whooshDeepSound:Play()
				TweenService:Create(item, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = UDim2.new(
						originalSize.X.Scale * 1.1, originalSize.X.Offset * 1.1,
						originalSize.Y.Scale * 1.1, originalSize.Y.Offset * 1.1
					),
				}):Play()
			end)
			item.MouseLeave:Connect(function()
				TweenService:Create(item, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Size = originalSize,
				}):Play()
			end)
		end,
		Remove = function(_item) end,
	},
	InventoryCard = {
		Add = function(item)
			local originalSize = item.CardTemplate.Image1.Size
			item.MouseEnter:Connect(function()
				whooshDeepSound:Play()
				TweenService:Create(item.CardTemplate.Image1, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = UDim2.new(
						originalSize.X.Scale * 1.1, originalSize.X.Offset * 1.1,
						originalSize.Y.Scale * 1.1, originalSize.Y.Offset * 1.1
					),
				}):Play()
			end)
			item.MouseLeave:Connect(function()
				TweenService:Create(item.CardTemplate.Image1, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Size = originalSize,
				}):Play()
			end)
		end,
		Remove = function(_item) end,
	},
}

for tag, functionTag in tags do
	for _, item in CollectionService:GetTagged(tag) do
		functionTag.Add(item)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(item)
		functionTag.Add(item)
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(item)
		if functionTag.Remove then functionTag.Remove(item) end
	end)
end
