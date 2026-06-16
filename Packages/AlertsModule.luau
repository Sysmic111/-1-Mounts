local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local FormatNumber = require(game.ReplicatedStorage:WaitForChild('Packages'):WaitForChild('FormatNumber'))
local Packets = require(game.ReplicatedStorage.Shared.Packets)
local Players = game:GetService("Players")
local player

if RunService:IsClient() then
	player = Players.LocalPlayer
end

local AlertsModule = {}


local dropImages = {
	['Coin'] = 'rbxassetid://134775876662257',
	['Coins'] = 'rbxassetid://134775876662257',
	['Gem'] = 'rbxassetid://135995771792843',
	['Gems'] = 'rbxassetid://135995771792843',
	['ExpStone'] = 'rbxassetid://118882738318553',
	['ExpStones'] = 'rbxassetid://118882738318553',
	['Summoning Crystals'] = 'rbxassetid://103490512397582',
}

local finalPositions = {
	['Coin'] = UDim2.new(0.535,0,0.04,0),
	['Gem'] = UDim2.new(0.405,0,0.04,0),
	['ExpStone'] = UDim2.new(0.5,0,0.05,0),
}

local tweenInfo = TweenInfo.new(0.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut)
local tweenInfo2 = TweenInfo.new(1,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut)

local function incrementePosition(x)
	return 3 * x - 1
end

local notifications = {}

local disappearTimers = {}

local function addNewItemTopBar(topItemBar, itemName, itemImage, itemQuantity)
	local function playAppearAnimation(itemFrame)
		if itemFrame and itemFrame.Parent then
			itemFrame:TweenSize(UDim2.new(1,0,1,0), Enum.EasingDirection.Out, Enum.EasingStyle.Sine, 0.1, true)
		end
		task.delay(0.1, function()
			if itemFrame and itemFrame.Parent then
				itemFrame:TweenSize(UDim2.new(0.9,0,0.9,0), Enum.EasingDirection.Out, Enum.EasingStyle.Sine, 5, false)
			end
		end)
	end

	local function scheduleDisappear(itemFrame)
		if disappearTimers[itemFrame] then
			disappearTimers[itemFrame]:Disconnect()
		end

		local startTime = tick()
		local connection
		connection = game:GetService("RunService").Heartbeat:Connect(function()
			local elapsed = tick() - startTime
			if elapsed >= 6 then
				connection:Disconnect()
				disappearTimers[itemFrame] = nil

				if itemFrame and itemFrame.Parent then
					itemFrame:TweenSize(UDim2.new(0,0,0,0), Enum.EasingDirection.Out, Enum.EasingStyle.Sine, 1, false)
				end

				task.delay(1.1, function()
					if itemFrame and itemFrame.Parent then
						itemFrame:Destroy()
					end
				end)
			end
		end)

		disappearTimers[itemFrame] = connection
	end

	local newItemTemplate = topItemBar:FindFirstChild(itemName)

	if newItemTemplate then
		local oldQuantity = newItemTemplate:GetAttribute("Quantity") or 0
		local newQuantity = oldQuantity + itemQuantity

		newItemTemplate.Quantity.Text = FormatNumber:formatNumberCoins(newQuantity)
		newItemTemplate:SetAttribute("Quantity", newQuantity)

		playAppearAnimation(newItemTemplate)
		scheduleDisappear(newItemTemplate)

	else
		local itemsContainer = game.ReplicatedStorage:WaitForChild('Models'):WaitForChild('UI'):WaitForChild('NewItem')
		newItemTemplate = itemsContainer:Clone()
		newItemTemplate.Name = itemName
		newItemTemplate.Logo.Image = itemImage
		newItemTemplate.Quantity.Text = FormatNumber:formatNumberCoins(itemQuantity)
		newItemTemplate:SetAttribute("Quantity", itemQuantity)
		newItemTemplate.Size = UDim2.new(0,0,0,0)
		newItemTemplate.Parent = topItemBar

		playAppearAnimation(newItemTemplate)
		scheduleDisappear(newItemTemplate)
	end
end



function AlertsModule.ShowAlertGui(AlertType,Message,QuantityDivided,Image,Legendary)
	if AlertType == 'Error' then
		local errorTemplate = game.ReplicatedStorage:WaitForChild('Models'):WaitForChild('UI'):WaitForChild('Error'):Clone()
		errorTemplate:WaitForChild('Main').Text = Message
		errorTemplate.Main.TextTransparency = 1
		errorTemplate.Main.UIStroke.Transparency = 1
		errorTemplate.Main.Position = UDim2.new(0.5,0,0,0)
		errorTemplate.Parent = player.PlayerGui.Temporal
		game.SoundService.SFX.SoundError:Play()
		local tweenInfo22 = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local tweenInfo222 = TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		local tweenInfo33 = TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local tweenInfo333 = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		local tweenInfo44 = TweenInfo.new(1.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(errorTemplate.Main, tweenInfo22, {TextTransparency = 0}):Play()
		TweenService:Create(errorTemplate.Main.UIStroke, tweenInfo222, {Transparency = 0}):Play()
		TweenService:Create(errorTemplate.Main, tweenInfo44, {Position = UDim2.new(0.5,0,1,0)}):Play()

		wait(2)
		TweenService:Create(errorTemplate.Main, tweenInfo33, {TextTransparency = 1}):Play()
		TweenService:Create(errorTemplate.Main.UIStroke, tweenInfo333, {Transparency = 1}):Play()

		wait(1)
		errorTemplate:Destroy()
	elseif AlertType == 'Reward' then
		local rewardTemplate = game.ReplicatedStorage:WaitForChild('Models'):WaitForChild('UI'):WaitForChild('Reward'):Clone()
		local originalPosition = rewardTemplate.Position
		rewardTemplate.Position = UDim2.new(0.5,0,-0.5,0)

		if Message == 'Won' then
			rewardTemplate.Lose.Visible = false
			rewardTemplate.LoseShadow.Visible = false
			rewardTemplate.Winner.Visible = true
			rewardTemplate.WinnerShadow.Visible = true
			game.SoundService.Sounds.SFX.ui_menu_popup_message_04:Play()
		else
			rewardTemplate.Lose.Visible = true
			rewardTemplate.LoseShadow.Visible = true
			rewardTemplate.Winner.Visible = false
			rewardTemplate.WinnerShadow.Visible = false
			game.SoundService.Sounds.SFX.Lose:Play()
		end

		rewardTemplate.Parent = player.PlayerGui.UI.Temporal
		rewardTemplate:TweenPosition(originalPosition,'Out','Back',0.5,false)
		task.delay(5,function()
			rewardTemplate:TweenPosition(UDim2.new(0.5,0,-0.5,0),'In','Sine',0.5,false)
		end)
		Debris:AddItem(rewardTemplate, 5.5)

		wait(0.1)
		if QuantityDivided then
			local rewards = QuantityDivided
			for _,reward in pairs(rewards) do
				if reward.RewardType then
					local imageTexture
					if reward.RewardType == 'Booster' then
						imageTexture = reward.Image
					else
						imageTexture = dropImages[reward.RewardType]
					end
					local rewardItemTemplate = game.ReplicatedStorage:WaitForChild('Models'):WaitForChild('UI'):WaitForChild('RewardItem'):Clone()
					local rewardItemTemplateOriginalSize = rewardItemTemplate.Size
					rewardItemTemplate.ImageLabel.Image = imageTexture
					rewardItemTemplate.RewardsText.Text = reward.RewardQuantity
					rewardItemTemplate.Size = UDim2.new(0,0,0,0)
					rewardItemTemplate.Parent = rewardTemplate.ScrollingFrame
					rewardItemTemplate:TweenSize(rewardItemTemplateOriginalSize,'Out','Sine',0.2,true)
					game.SoundService.Sounds.SFX.ui_menu_button_click_02:Play()
					wait(0.2)
				elseif reward.Next then
					task.delay(3,function()
						local npc = game.Workspace.NPCs:FindFirstChild(Image)
						local PromptsModule = require(game.ReplicatedStorage.Shared.Modules.PromptsModule)
						player:SetAttribute('Busy', true)
						PromptsModule.FirePrompt(npc.HumanoidRootPart.PP.ProximityPrompt,npc)
						player:SetAttribute('Region','None')
					end)
				elseif reward.Blocker then
					local bloquer = game.Workspace.Buildings[reward.Buildings][reward.Blocker]
					bloquer:Destroy()
				end
			end
		end

		local nearestPrompt
		local minDist = 20

		local hrp = player.Character:WaitForChild("HumanoidRootPart", 1)
		if not hrp then return end
		for _, prompt in ipairs(workspace.NPCs:GetDescendants()) do
			if prompt:IsA("ProximityPrompt") and prompt.Enabled then
				local part = prompt.Parent
				if part and part:IsA("BasePart") then
					local dist = (part.Position - hrp.Position).Magnitude
					if dist < minDist then
						minDist = dist
						nearestPrompt = prompt
					end
				end
			end
		end

		if nearestPrompt then
			nearestPrompt:InputHoldBegin()
			wait(0.1)
			nearestPrompt:InputHoldEnd()
		end

	elseif AlertType == 'BattleStart' then
		local image = Instance.new('ImageLabel')
		image.Image = 'rbxassetid://16718821196'
		image.BackgroundTransparency = 1
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.new(0.5,0,0.5,0)
		image.Size = UDim2.new(0,0,0,0)
		image.ScaleType = Enum.ScaleType.Fit
		image.Parent = player.PlayerGui.UI.Temporal
		TweenService:Create(image,tweenInfo2,{Size = UDim2.new(0.5,0,0.5,0)}):Play()
		Debris:AddItem(image, 2)
	elseif AlertType == 'TextCenter' then
		local number = Instance.new('TextLabel')
		number.BackgroundTransparency = 1
		number.AnchorPoint = Vector2.new(0.5, 0.5)
		number.Position = UDim2.new(0.5,0,0.3,0)
		number.Size = UDim2.new(0,0,0,0)
		number.Font = Enum.Font.FredokaOne
		number.TextScaled = true
		number.Text = Message
		number.TextColor3 = Color3.new(1, 1, 1)
		number.TextTransparency = 1
		number.Parent = player.PlayerGui.UI.Temporal
		local stroke = Instance.new('UIStroke')
		stroke.Parent = number
		stroke.Thickness = 3
		stroke.Transparency = 1

		local tween = TweenService:Create(number,tweenInfo2,{TextTransparency = 0,Size = UDim2.new(0.3,0,0.3,0)})
		local tween2 = TweenService:Create(stroke,tweenInfo2,{Transparency = 0})

		tween.Completed:Connect(function()
			task.delay(1,function()
				TweenService:Create(number,tweenInfo2,{Transparency = 1,Size = UDim2.new(0,0,0,0),Position = UDim2.new(0.5,0,0.6,0)}):Play()
				TweenService:Create(stroke,tweenInfo2,{Transparency = 1}):Play()
			end)
		end)

		tween:Play()
		tween2:Play()
		if Message == 'Battle !' then
			game.SoundService.Sounds.SFX.ui_menu_popup_message_07:Play()
		else
			game.SoundService.Sounds.SFX.ui_menu_popup_message_03:Play()
		end

		Debris:AddItem(number, 3)
	elseif AlertType == 'Notification' then
		local lastPosition = 0.9 - (0.06 * #notifications)
		local notificationTemplate = game.ReplicatedStorage:WaitForChild('Models'):WaitForChild('UI'):WaitForChild('Notification'):Clone()
		notificationTemplate.ImageLabel.Image = Image or 'rbxassetid://127491137292837'
		if Legendary then
			--------------
		end
		notificationTemplate.Content.Text = Message
		notificationTemplate.Position = UDim2.new(1.2,0,lastPosition,0)
		notificationTemplate.Parent = player.PlayerGui.UI.Temporal
		table.insert(notifications,notificationTemplate)
		local tween = TweenService:Create(notificationTemplate,tweenInfo2,{Position = UDim2.new(0.85,0,lastPosition,0)})
		tween.Completed:Connect(function()
			wait(2)
			TweenService:Create(notificationTemplate,tweenInfo2,{Position = UDim2.new(1.1,0,lastPosition,0)}):Play()
			wait(1)
			for i,v in ipairs(notifications) do
				if v == notificationTemplate then
					table.remove(notifications,i)
					break
				end
			end
			notificationTemplate:Destroy()
		end)
		tween:Play()
	elseif AlertType == 'Loading' then
		if Message == 'Start' then
			if not player.PlayerGui.UI.Temporal:FindFirstChild('LoadingUI') then
				local loadingUI = game.ReplicatedStorage:WaitForChild('Models'):WaitForChild('UI'):WaitForChild('LoadingUI'):Clone()
				loadingUI.Parent = player.PlayerGui.UI.Temporal
				local tweenInfoLoading = TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1)
				TweenService:Create(loadingUI.ImageLabel, tweenInfoLoading, {Rotation = 360}):Play()
			end
		elseif Message == 'Stop' then
			if player.PlayerGui.UI.Temporal:FindFirstChild('LoadingUI') then
				player.PlayerGui.UI.Temporal:FindFirstChild('LoadingUI'):Destroy()
			end
		end
	elseif AlertType == 'ItemNotification' then
		local itemName     = Message
		local rarity       = QuantityDivided
		local image        = Image
		local subtitleText = Legendary

		local itemsContainer = player.PlayerGui:WaitForChild("Bot"):WaitForChild("Items")
		local itemTemplate   = itemsContainer:WaitForChild("Templates"):WaitForChild("ItemTemplate")
		local colors         = game.ReplicatedStorage:WaitForChild("Models"):WaitForChild("UI"):WaitForChild("Colors")

		local clone = itemTemplate:Clone()
		clone.ImageLabel.Image = image or ""
		clone.Title.Text = itemName or ""

		local subtitleLabel = clone:FindFirstChild("Subtitle")
		if subtitleLabel then
			subtitleLabel.Text = subtitleText or ""
		end

		if rarity then
			local border = clone:FindFirstChild("Border")
			local frame  = clone:FindFirstChild("Frame")

			local borderGradient = colors:FindFirstChild(rarity .. "Border")
			local frameGradient  = colors:FindFirstChild(rarity .. "Frame")

			if border and borderGradient then
				local existing = border:FindFirstChildOfClass("UIGradient")
				if existing then existing:Destroy() end
				borderGradient:Clone().Parent = border
			end
			if frame and frameGradient then
				local existing = frame:FindFirstChildOfClass("UIGradient")
				if existing then existing:Destroy() end
				frameGradient:Clone().Parent = frame
			end
		end

		for _, child in ipairs(clone:GetChildren()) do
			child.Visible = false
		end

		local expandedSize = UDim2.new(0.12, 0, 0.4, 0)
		clone.Size = UDim2.new(0, 0, 0.4, 0)
		clone.Visible = true
		clone.Parent = itemsContainer

		local tweenExpand = TweenService:Create(
			clone,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = expandedSize }
		)
		tweenExpand:Play()
		tweenExpand.Completed:Wait()

		for _, child in ipairs(clone:GetChildren()) do
			child.Visible = true
		end

		if subtitleLabel and (not subtitleText or subtitleText == "") then
			subtitleLabel.Visible = false
		end

		local popSize = UDim2.new(expandedSize.X.Scale * 1.1, 0, expandedSize.Y.Scale * 1.1, 0)
		local tweenGrow = TweenService:Create(
			clone,
			TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = popSize }
		)
		tweenGrow:Play()
		tweenGrow.Completed:Wait()
		TweenService:Create(
			clone,
			TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Size = expandedSize }
		):Play()

		task.delay(2, function()
			if not clone or not clone.Parent then return end
			local fadeInfo   = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local shrinkInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			for _, desc in ipairs(clone:GetDescendants()) do
				if desc:IsA('TextLabel') then
					TweenService:Create(desc, fadeInfo, { TextTransparency = 1 }):Play()
				elseif desc:IsA('ImageLabel') then
					TweenService:Create(desc, fadeInfo, { ImageTransparency = 1 }):Play()
				elseif desc:IsA('Frame') then
					TweenService:Create(desc, fadeInfo, { BackgroundTransparency = 1 }):Play()
				end
			end
			TweenService:Create(clone, fadeInfo, { BackgroundTransparency = 1 }):Play()
			task.delay(0.1, function()
				if not clone or not clone.Parent then return end
				local s = clone.Size
				TweenService:Create(clone, shrinkInfo, {
					Size = UDim2.new(0, 0, s.Y.Scale, s.Y.Offset)
				}):Play()
				task.delay(0.15, function()
					if clone and clone.Parent then clone:Destroy() end
				end)
			end)
		end)
	elseif AlertType == 'Heal' then
		local soundsfx = game.SoundService.Sounds.SFX["water_bubble_spell_heal_01"]:Clone()
		soundsfx.Volume = 0.3
		soundsfx.Parent = player.Character
		soundsfx:Play()
		Debris:AddItem(soundsfx,3)
	elseif AlertType == 'Revive' then
		local soundsfx = game.SoundService.Sounds.SFX["water_bubble_spell_heal_05"]:Clone()
		soundsfx.Volume = 0.3
		soundsfx.Parent = player.Character
		soundsfx:Play()
		Debris:AddItem(soundsfx,3)
	else
		local finalFrame = player:WaitForChild('PlayerGui'):WaitForChild('Left'):WaitForChild('All'):WaitForChild('Main'):WaitForChild('Currencies'):WaitForChild('Coins'):WaitForChild('Quantity')
		local finalPosition = UDim2.fromOffset(finalFrame.AbsolutePosition.X, finalFrame.AbsolutePosition.Y)
		for i=1,QuantityDivided or 1,1 do
			local dropTemplate = game.ReplicatedStorage:WaitForChild('Models'):WaitForChild('UI'):WaitForChild('Drop'):Clone()
			dropTemplate.Image = dropImages[AlertType] or Image
			dropTemplate.Size = UDim2.new(0,0,0,0)
			dropTemplate.Parent = player.PlayerGui.Temporal
			
			local topItemBar = player:WaitForChild('PlayerGui'):WaitForChild('Left'):WaitForChild('All'):WaitForChild('Main'):WaitForChild('Currencies'):WaitForChild('Coins'):WaitForChild('ItemsAdded')
			
			dropTemplate.Position = UDim2.new(math.random(45,55)/100,0,math.random(45,55)/100,0)
			--dropTemplate.Position = UDim2.new(0.5,0,0.5,0)
			local tween = TweenService:Create(dropTemplate,tweenInfo,{Size = UDim2.new(0.04,0,0.06,0),Position = UDim2.new(incrementePosition(dropTemplate.Position.X.Scale),0,incrementePosition(dropTemplate.Position.Y.Scale),0)})
			tween.Completed:Connect(function()
				local tween2 = TweenService:Create(dropTemplate,TweenInfo.new(math.random(10,13)/10,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Size = UDim2.new(0.03,0,0.05,0),Position = finalPosition or UDim2.new(0.5,0,0.05,0)})
				tween2.Completed:Connect(function()
					addNewItemTopBar(topItemBar,AlertType,dropImages[AlertType] or Image,Message/QuantityDivided)
					dropTemplate:Destroy()
					if AlertType == 'Coin' then
						game.SoundService.SFX["coin_bag_ring_gemstone_item_0"..math.random(1,3)]:Play() 
					elseif AlertType == 'ExpStone' then
						local randomNumber = math.random(1,2)
						if randomNumber == 1 then game.SoundService.SFX.coin_bag_ring_gemstone_item_02:Play() 
						elseif randomNumber == 2 then game.SoundService.SFX.coin_bag_ring_gemstone_item_03:Play() 
						end
					end
				end)
				tween2:Play()	
			end)
			tween:Play()
	end
end
end

function AlertsModule.ShowAlert(player,AlertType,Message,QuantityDivided,Image,Legendary)
	if RunService:IsServer() then
		Packets.Alert:FireClient(player,AlertType,Message,QuantityDivided,Image,Legendary)
	else
		AlertsModule.ShowAlertGui(AlertType,Message,QuantityDivided,Image,Legendary)
	end
end

if RunService:IsClient() then
	Packets.Alert.OnClientEvent:Connect(function(AlertType,Message,QuantityDivided,Image,Legendary)
		AlertsModule.ShowAlertGui(AlertType,Message,QuantityDivided,Image,Legendary)
	end)
end

return AlertsModule
