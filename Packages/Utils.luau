local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UtilsModule = {}

local rarityColors = {
	['Common'] = Color3.new(0.666667, 0.666667, 0.666667),
	['Rare'] = Color3.new(0.219608, 0.454902, 1),
	['Epic'] = Color3.new(0.670588, 0.435294, 1),
	['Legendary'] = Color3.new(1, 0.756863, 0.137255),
	['Unique'] = Color3.new(1, 0.364706, 0.94902),
	['Promo'] = Color3.new(1, 0.00392157, 0.00392157),
	['Copper'] = Color3.new(0.737255, 0.384314, 0.027451),
	['Metal'] = Color3.new(0.6, 0.6, 0.6),
	['Gold'] = Color3.new(0.945098, 0.815686, 0.0156863),
	['Luck'] = Color3.new(1, 1, 1),
}

local rarityImages = {
	['Common'] = 'rbxassetid://127590596446189',
	['Uncommon'] = 'rbxassetid://111889725362828',
	['Rare'] = 'rbxassetid://111889725362828',
	['Epic'] = 'rbxassetid://73401027452691',
	['Legendary'] = 'rbxassetid://73740047300148',
	['Unique'] = 'rbxassetid://76397814858780',
	['Promo'] = 'rbxassetid://98660390438469',
	['Bronze'] = 'rbxassetid://116379518571710',
	['Steel'] = 'rbxassetid://100931416805069',
	['Gold'] = 'rbxassetid://117575285573428',
	['Holidays'] = 'rbxassetid://95037879900217',
	['Shiny'] = 'rbxassetid://98660390438469',
	['Illustration'] = 'rbxassetid://94898913412221',
	['Dark'] = 'rbxassetid://80255198488018',
	['Concert'] = 'rbxassetid://136931170413522',
}

local rarityRates = {
	['Common'] = 1,
	['Rare'] = 5,
	['Epic'] = 12,
	['Legendary'] = 100,
	['Unique'] = 250,
	['Exclusive'] = 1000
}

local elementColors = {
	['Normal'] = Color3.new(0.87451, 0.87451, 0.87451),
	['Fire'] = Color3.new(0.890196, 0, 0),
	['Water'] = Color3.new(0.027451, 0.529412, 1),
	['Grass'] = Color3.new(0.298039, 0.729412, 0.25098),
	['Lightning'] = Color3.new(1, 1, 0.101961),
	['Ice'] = Color3.new(0, 1, 1),
	['Fighting'] = Color3.new(1, 0.666667, 0),
	['Poison'] = Color3.new(0.666667, 0.333333, 1),
	['Ground'] = Color3.new(0.666667, 0.490196, 0.247059),
	['Flying'] = Color3.new(0.666667, 1, 1),
	['Psychic'] = Color3.new(1, 0.235294, 0.603922),
	['Bug'] = Color3.new(0.333333, 1, 0.498039),
	['Rock'] = Color3.new(0.666667, 0.666667, 0.498039),
	['Ghost'] = Color3.new(0.666667, 0.666667, 1),
	['Dragon'] = Color3.new(0.188235, 0.447059, 1),
	['Darkness'] = Color3.new(0.294118, 0.294118, 0.439216),
	['Steel'] = Color3.new(0.509804, 0.509804, 0.509804),
	['Fairy'] = Color3.new(1, 0.666667, 1),
	['Metal'] = Color3.new(0.6, 0.6, 0.6)
}

local upgradeImages = {
	['Storage'] = 'rbxassetid://93356189660333',
	['Magnet'] = 'rbxassetid://126934903597897',
	['Open Booster Pack'] = 'rbxassetid://79324082105617',
}

local currencyImages = {
	['Coins'] = 'rbxassetid://92147024576083',
	['Gems'] = 'rbxassetid://16717837834',
	['Robux'] = 'rbxassetid://11149722970',
}

local rewardsImages = {
	['Coins'] = 'rbxassetid://92147024576083',
	['Gems'] = 'rbxassetid://16717837834',
	['Robux'] = 'rbxassetid://11149722970',
}

local luckImages = {
	['x2'] = 'rbxassetid://84033702924625',
	['x4'] = 'rbxassetid://80532822145964',
	['x8'] = 'rbxassetid://123586098506709',
}

local luckImagesOrdered = {
	'rbxassetid://84033702924625',
	'rbxassetid://123586098506709',
	'rbxassetid://80532822145964',
}

local Images = {
	['Empty Dice'] = 'rbxassetid://80038198647815',
	['Rarity Border'] = 'rbxassetid://90121710376202'
}

-- Feed level system (mounts only)
local FEED_LEVEL_EXP = { 0, 100, 250, 500, 900, 1400, 2200, 3300, 4800, 7000 }
local FEED_LEVEL_MULT = { 1.00, 1.10, 1.25, 1.45, 1.70, 2.00, 2.40, 2.90, 3.50, 4.20 }

local advanceQuantity = {
	['Common'] = {[1] = 15,[2] = 30,[3] = 60,[4] = 150,[5] = 375,[6] = 750,[7] = 1125,[8] = 1688,[9] = 2533,[10] = 3802,},
	['Rare'] = {[1] = 5,[2] = 10,[3] = 20,[4] = 50,[5] = 120,[6] = 240,[7] = 360,[8] = 540,[9] = 810,[10] = 1215,},
	['Epic'] = {[1] = 3,[2] = 5,[3] = 10,[4] = 25,[5] = 40,[6] = 70,[7] = 225,[8] = 360,[9] = 576,[10] = 922,},
	['Legendary'] = {[1] = 3,[2] = 7,[3] = 10,[4] = 20,[5] = 32,[6] = 64,[7] = 96,[8] = 150,[9] = 200,[10] = 300,},
	['Unique'] = {[1] = 3,[2] = 4,[3] = 5,[4] = 6,[5] = 7,[6] = 8,[7] = 9,[8] = 10,[9] = 12,[10] = 15,},
}


UtilsModule.GetLuckImage = function(index)
	return luckImagesOrdered[index] or ''
end

UtilsModule.GetImage = function(name)
	return Images[name] or ''
end

UtilsModule.GetImageUpgrade = function(upgrade)
	return upgradeImages[upgrade] or ''
end

UtilsModule.GetImageCurrency = function(currency)
	return currencyImages[currency] or "rbxassetid://106216031501874"
end

UtilsModule.GetColorRarity = function(rarity)
	return rarityColors[rarity] or Color3.new(1, 1, 1)
end

UtilsModule.GetRateRarity = function(rarity)
	return rarityRates[rarity] or '?'
end


UtilsModule.GetColorElement = function(element)
	return elementColors[element] 
end

UtilsModule.GetImageRarity = function(rarity)
	return rarityImages[rarity] 
end

-- Returns the current feed level (1–10) given total accumulated EXP.
UtilsModule.GetFeedLevel = function(exp: number): number
	local level = 1
	for i = #FEED_LEVEL_EXP, 1, -1 do
		if exp >= FEED_LEVEL_EXP[i] then
			level = i
			break
		end
	end
	return level
end

-- Returns the total EXP threshold needed to reach the NEXT level, or nil if already max.
UtilsModule.GetFeedLevelExpNeeded = function(level: number): number?
	return FEED_LEVEL_EXP[level + 1]
end

-- Returns the ATK/HP multiplier for a given feed level.
UtilsModule.GetFeedLevelMultiplier = function(level: number): number
	return FEED_LEVEL_MULT[level] or 1.0
end

UtilsModule.GetAdvanceQuantity = function(rarity, advance)
	local t = advanceQuantity[rarity]
	if not t then return nil end
	return t[advance + 1]
end

-- Total quantity consumed by all advances up to (but not including) `advance`.
UtilsModule.GetQuantityUsed = function(rarity: string, advance: number): number
	local used = 0
	for i = 0, advance - 1 do
		used += UtilsModule.GetAdvanceQuantity(rarity, i) or 0
	end
	return used
end

local MAX_MULTIPLIERS = {
	Common    = 2.0,
	Rare      = 2.5,
	Epic      = 3.0,
	Legendary = 3.5,
	Unique    = 4.0,
}

-- Quadratic curve: slow gains early, bigger gains at higher levels.
-- At advance=0 returns 1.0, at advance=10 returns the rarity max multiplier.
UtilsModule.GetAdvanceMultiplier = function(rarity: string, advance: number): number
	local maxMult = MAX_MULTIPLIERS[rarity]
	if not maxMult then return 1.0 end
	if advance <= 0 then return 1.0 end
	if advance >= 10 then return maxMult end
	local t = advance / 10
	return 1 + (maxMult - 1) * (t * t)
end

UtilsModule.GetImageReward = function(rewardType,reward)
	if rewardType == 'Coins' then
		return 'rbxassetid://92147024576083'
	elseif rewardType == 'ExpStones' then
		return 'rbxassetid://118882738318553'
	elseif rewardType == 'Gems' then
		return 'rbxassetid://16717837834'
	elseif rewardType == 'Summoning Crystals' then
		return 'rbxassetid://103490512397582'
	elseif rewardType == 'Booster' or rewardType == 'Heavy Booster' or rewardType == 'God Booster'   then
		local boosterPack = game.ReplicatedStorage.Remotes.CardsManager:InvokeServer('GetBoosterByName',reward)
		return boosterPack.ImageItem
	elseif rewardType == 'BoosterBox' then
		local boosterProduct = game.ReplicatedStorage.Remotes.CardsManager:InvokeServer('GetProductByName',reward)
		return boosterProduct.ImageItem
	else
		return 'rbxassetid://106216031501874'
	end
end


UtilsModule.GetCurrentTime = function()
	return os.time()
end

UtilsModule.GetDateTableFromTime = function(timeComing)
	return os.date("!*t", timeComing)
end

UtilsModule.IsNewDay = function(lastLoginTime)
	local currentTime = UtilsModule.GetCurrentTime()
	local lastLoginDate = UtilsModule.GetDateTableFromTime(lastLoginTime)
	local currentDate = UtilsModule.GetDateTableFromTime(currentTime)
	return lastLoginDate.year ~= currentDate.year or lastLoginDate.yday ~= currentDate.yday
end

UtilsModule.DeepCopy = function(original)
	local copy = {}
	for key, value in pairs(original) do
		if type(value) == "table" then
			copy[key] = UtilsModule.DeepCopy(value)
		else
			copy[key] = value
		end
	end
	return copy
end

UtilsModule.ContainsValue = function(tbl, value)
	for _, v in pairs(tbl) do
		if v == value then
			return true
		end
	end
	return false
end

UtilsModule.CalculateCost = function(base,level,newRate)
	local rate = 1.3
	if newRate then
		return math.floor(base * (newRate ^ (level - 1)))
	else
		return math.floor(base * (rate ^ (level - 1)))
	end
end

UtilsModule.CalculatePet = function(base,level,stars)
	local rate = 1.25
	local newBase = base
	if not stars then stars = 0 end
	if stars > 0 then
		stars += 1
		newBase = math.floor(base * (1.3 ^ (stars - 1)))
		
	end
	return math.floor(newBase * (rate ^ (level - 1)))
end



UtilsModule.GetUsernameFromUserId = function(userId)
	for i,v in pairs(game.Players:GetPlayers()) do
		if v.UserId == userId then
			return v.Name
		end
	end
	return false
end

local function getCurrentTime()
	return os.time()
end

local function getDateTableFromTime(time)
	return os.date("!*t", time)
end


UtilsModule.IsNewDay = function(lastLoginTime)
	local currentTime = getCurrentTime()
	local lastLoginDate = getDateTableFromTime(lastLoginTime)
	local currentDate = getDateTableFromTime(currentTime)
	return lastLoginDate.year ~= currentDate.year or lastLoginDate.yday ~= currentDate.yday
end

UtilsModule.IsNewWeek = function(lastLoginTime)
	local currentTime = getCurrentTime()
	local lastLoginDate = getDateTableFromTime(lastLoginTime)
	local currentDate = getDateTableFromTime(currentTime)
	local currentWeek = math.ceil(currentDate.yday / 7)
	local lastWeek = math.ceil(lastLoginDate.yday / 7)
	return lastLoginDate.year ~= currentDate.year or currentWeek ~= lastWeek
end

UtilsModule.setupObject = function(objectCategory,item,isDescription)
	if isDescription then
		if objectCategory == 'Booster Packs' then
			local object = game.ReplicatedStorage.Modules.Products["Booster Pack"]
			object.Main.TextureID = item.Image
			return object
		elseif objectCategory == 'Heavy Packs' then
			local object = game.ReplicatedStorage.Modules.Products["Booster Pack"]
			object.Main.TextureID = item.Image
			object.Border.Color = Color3.new(0.529412, 0.529412, 0.529412)
			return object
		elseif objectCategory == 'Sleeves' then
			local object = game.ReplicatedStorage.Modules.Products["Sleeves Item"]
			object.Main.Front.Texture = item.Image
			object.Main.Back.Texture = item.Image
			return object
		elseif objectCategory == 'Deck Boxes' then
			local object = game.ReplicatedStorage.Modules.Products["Deck Box Item"]
			object.Main.TextureID = item.Image
			object.Top.TextureID = item.Image
			return object
		elseif objectCategory == 'Playmats' then
			local object = game.ReplicatedStorage.Modules.Products["Playmat Item"]
			object.Main.Texture.Texture = item.Image
			return object
		elseif objectCategory == 'Passes' then
			local object = game.ReplicatedStorage.Modules.Products["Passes"]
			object.Main.Texture.Texture = item.Image
			return object
		elseif objectCategory == 'Gems' then
			local object = game.ReplicatedStorage.Modules.Products[item.Name]
			return object
		elseif objectCategory == 'Items' then
			local object = game.ReplicatedStorage.Modules.Items[item.Name]
			return object
		elseif objectCategory == 'Products' then
			local object
			if item.ProductType then
				object = game.ReplicatedStorage.Modules.Products[item.ProductType]
			else
				object = game.ReplicatedStorage.Modules.Products[item.Product]
			end
			if item.Product then
				if item.Product == 'Sleeves Display Item' then
					object.Main.TextureID = item.ImageContainer
					object.Sleeve.Back.Texture = item.Image
				elseif item.Product == 'Deck Box Display Item' then
					object.Main.TextureID = item.ImageContainer
					object.DeckBox.TextureID = item.Image
					object.DeckBoxTop.TextureID = item.Image
				elseif item.Product == 'Playmat Display Item' or  item.Product == 'Booster Pack' then
					object.Main.TextureID = item.Image
				end
			else
				if object.Main.ClassName == 'MeshPart' then
					object.Main.TextureID = item.Image
				else
					for i,v in pairs(object:GetChildren()) do
						if v.Name == 'TexturePart' then v.TextureID = item.Image end
					end
				end
			end
			if item.Content then
				for i,v in pairs(item.Content) do
					if v.ItemType == 'Booster Packs' then
						for ii,vv in pairs(object:GetChildren()) do
							if vv.Name == 'Booster Pack Item' then
								vv.Main.TextureID = v.Item.Image
							end
						end
					elseif v.ItemType == 'Card1' then
						object.Card1.Front.Texture = v.Item.Image
					elseif v.ItemType == 'Card2' then
						object.Card2.Front.Texture = v.Item.Image
					elseif v.ItemType == 'Card3' then
						object.Card3.Front.Texture = v.Item.Image
					end
				end
			end

			return object
		elseif objectCategory == 'Card1' or objectCategory == 'Card2' or objectCategory == 'Card3' then
			local object = game.ReplicatedStorage.Modules.CardTemplates['CardWorldTemplate']
			object.Main.Front.Texture = item.Image
			return object
		end
	else
		if objectCategory == 'Booster Packs' then
			local object = game.ReplicatedStorage.Modules.Products["Booster Pack Item"]
			object.Main.TextureID = item.Image
			return object
		elseif objectCategory == 'Sleeves' then
			local object = game.ReplicatedStorage.Modules.Products["Sleeves Display Item"]
			object.Main.TextureID = item.ImageContainer
			object.Sleeve.Front.Texture = item.Image
			object.Sleeve.Back.Texture = item.Image
			return object
		elseif objectCategory == 'Deck Boxes' then
			local object = game.ReplicatedStorage.Modules.Products["Deck Box Display Item"]
			object.Main.TextureID = item.ImageContainer
			object.DeckBox.TextureID = item.Image
			object.DeckBoxTop.TextureID = item.Image
			return object
		elseif objectCategory == 'Playmats' then
			local object = game.ReplicatedStorage.Modules.Products["Playmat Display Item"]
			object.Main.TextureID = item.Image
			return object
		elseif objectCategory == 'Passes' then
			local object = game.ReplicatedStorage.Modules.Products["Passes"]
			object.Main.Texture.Texture = item.Image
			return object
		elseif objectCategory == 'Gems' then
			local object = game.ReplicatedStorage.Modules.Products[item.Name]
			return object
		elseif objectCategory == 'Items' then
			local object = game.ReplicatedStorage.Modules.Items[item.Name]
			return object
		elseif objectCategory == 'Products' then
			local object
			if item.ProductType then
				object = game.ReplicatedStorage.Modules.Products[item.ProductType]
			else
				object = game.ReplicatedStorage.Modules.Products[item.Product]
			end
			if item.Product then
				if item.Product == 'Sleeves Display Item' then
					object.Main.TextureID = item.ImageContainer
					object.Sleeve.Back.Texture = item.Image
				elseif item.Product == 'Deck Box Display Item' then
					object.Main.TextureID = item.ImageContainer
					object.DeckBox.TextureID = item.Image
					object.DeckBoxTop.TextureID = item.Image
				elseif item.Product == 'Playmat Display Item' or item.Product == 'Booster Pack' then
					object.Main.TextureID = item.Image
				end
			else
				if object.Main.ClassName == 'MeshPart' then
					object.Main.TextureID = item.Image
				else
					for i,v in pairs(object:GetChildren()) do
						if v.Name == 'TexturePart' then v.TextureID = item.Image end
						if v.Name == 'Booster Box Item' then 
							v.Main.TextureID = item.Image 
							v.Top.TextureID = item.Image 
							v.Bot.TextureID = item.Image
						end
					end
				end
			end

			if item.Content then
				for i,v in pairs(item.Content) do
					if v.ItemType == 'Booster Packs' then
						for ii,vv in pairs(object:GetChildren()) do
							if vv.Name == 'Booster Pack Item' then
								vv.Main.TextureID = v.Item.Image
							end
						end
					elseif v.ItemType == 'Card1' then
						object.Card1.Front.Texture = v.Item.Image
					elseif v.ItemType == 'Card2' then
						object.Card2.Front.Texture = v.Item.Image
					elseif v.ItemType == 'Card3' then
						object.Card3.Front.Texture = v.Item.Image
					end
				end
			end

			return object
		end
	end
end

UtilsModule.IsArray = function(tbl)
	if type(tbl) ~= "table" then
		return false
	end

	local n = #tbl            -- longitud del segmento secuencial
	for i = 1, n do
		if tbl[i] == nil then -- hay un hueco
			return false
		end
	end

	-- Verifica que no existan claves extra no numéricas o fuera de rango
	for k, _ in pairs(tbl) do
		if type(k) ~= "number" or k < 1 or k > n or k % 1 ~= 0 then
			return false
		end
	end

	return true
end

UtilsModule.SetupViewport = function(viewportFrame, model)
	model:PivotTo(CFrame.new()) 
	-- 1. Cámara
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40        -- FOV algo menor que el 70 ° por defecto
	viewportFrame.CurrentCamera = cam
	cam.Parent = viewportFrame

	-- 2. Datos de la caja
	local modelCF, size = model:GetBoundingBox()
	local center = modelCF.Position
	local maxDim = math.max(size.X, size.Y, size.Z)

	-- 3. Distancia necesaria para que todo quepa:
	--    d = (maxDim/2) / tan(FOV/2)
	local distance = (maxDim / 2) / math.tan(math.rad(cam.FieldOfView / 2))
	distance = distance * 1.2   -- pequeño margen extra

	-- 4. Posición de la cámara (elevada y girada 30 ° frente al modelo que mira -Z)
	local angle = math.rad(30)
	local offset = CFrame.Angles(0, angle, 0):VectorToWorldSpace(Vector3.new(0, size.Y * 0.3, -distance))
	cam.CFrame = CFrame.new(center + offset, center)
end

UtilsModule.GetEmptyPos = function(player)
	local taken = {}      -- set de posiciones ocupadas (ej.: taken[3] = true)

	-- Función auxiliar que marca los slots ya usados en un contenedor
	local function markSlots(container)
		for _, inst in ipairs(container:GetChildren()) do
			-- Nos aseguramos de que sea una Tool (u objeto con NumberValue "pos")
			if inst:IsA("Tool") then
				local posVal = inst:GetAttribute('SlotIn')
				if posVal then
					if posVal >= 1 and posVal <= 10 then
						taken[posVal] = true
					end
				end
			end
		end
	end

	-- ① Backpack
	markSlots(player.Backpack)

	-- ② Character (por si tiene una Tool equipada)
	if player.Character then
		markSlots(player.Character)
	end

	local maxSlots = 10
	if player:GetAttribute('Platform') and player:GetAttribute('Platform') == 'Mobile' then
		maxSlots = 6
	end
	-- ③ Busca el menor slot disponible
	for i = 1, maxSlots do
		if not taken[i] then
			return i              -- libre
		end
	end

	return 0 
end

UtilsModule.HasWord = function(text,word)
	word = string.lower(word)
	return string.find(string.lower(tostring(text)), word) ~= nil
end

UtilsModule.DaysUntil = function(year, month, day)
	-- Build a time-stamp for midnight of the target date
	local target = os.time{year = year, month = month, day = day,
		hour = 0,   min   = 0,    sec = 0}
	local now    = os.time()

	local seconds = target - now
	if seconds <= 0 then
		return 0                            -- date passed
	end

	return math.ceil(seconds / 86400)       -- 86 400 s = 1 day

end

UtilsModule.GetSecondsUntilEndOfDay = function()
	local now = os.time()
	local currentDate = os.date("!*t", now)

	-- Crear una tabla para hoy a las 23:59:59
	local endOfDay = {
		year  = currentDate.year,
		month = currentDate.month,
		day   = currentDate.day,
		hour  = 23,
		min   = 59,
		sec   = 59
	}

	local endTime = os.time(endOfDay)
	return endTime - now
end

UtilsModule.GetPlayerFromAny = function(idOrName)
	if typeof(idOrName) == "number" then
		return Players:GetPlayerByUserId(idOrName)
	elseif typeof(idOrName) == "string" then
		return Players:FindFirstChild(idOrName)
	elseif typeof(idOrName) == "Instance" and idOrName:IsA("Player") then
		return idOrName
	end
	return nil
end

UtilsModule.ConvertNumericKeysToStrings = function(tbl)
	local fixedTable = {}
	for key, value in pairs(tbl) do
		if type(key) == "number" then
			fixedTable[tostring(key)] = value
		else
			fixedTable[key] = value
		end
	end
	return fixedTable
end


UtilsModule.ApplyRichTextTags = function(text)
	text = text:gsub("<pink>", '<stroke color="#000000" joins="miter" thickness="2" transparency="0.25"><font color="#FF4073">')
	text = text:gsub("<yellow>", '<stroke color="#000000" joins="miter" thickness="1.5" transparency="0.25"><font color="#f1d004">')
	text = text:gsub("<red>", '<stroke color="#000000" joins="miter" thickness="1.5" transparency="0.25"><font color="#ff0000">')
	text = text:gsub("<gray>", '<stroke color="#000000" joins="miter" thickness="1.5" transparency="0.25"><font color="##646464">')
	text = text:gsub("<lgray>", '<stroke color="#000000" joins="miter" thickness="1.5" transparency="0.25"><font color="#ababab">')
	text = text:gsub("<blue>", '<stroke color="#000000" joins="miter" thickness="1.5" transparency="0.25"><font color="#009ae7">')
	text = text:gsub("<white>", '<stroke color="#000000" joins="miter" thickness="1.5" transparency="0.25"><font color="#ffffff">')
	text = text:gsub("<green>", '<stroke color="#000000" joins="miter" thickness="1.5" transparency="0.25"><font color="#00ff00">')
	text = text:gsub("<gold>", '<stroke color="#000000" joins="miter" thickness="1.5" transparency="0.25"><font color="#f1d004">')
	text = text:gsub("<holo>", '<stroke color="#000000" joins="miter" thickness="1.5" transparency="0.25"><font color="#affff2">')
	
	text = text:gsub("<Fire>", '<stroke color="#000000" joins="miter" thickness="1.5" transparency="0.25"><font color="#ff0000">')
	text = text:gsub("<Water>", '<stroke color="#000000" joins="miter" thickness="1.5" transparency="0.25"><font color="#0055ff">')
	text = text:gsub("<Grass>", '<stroke color="#000000" joins="miter" thickness="1.5" transparency="0.25"><font color="#55ff00">')
	text = text:gsub("<Lightning>", '<stroke color="#000000" joins="miter" thickness="1.5" transparency="0.25"><font color="#ffff1a">')
	text = text:gsub("<Fighting>", '<stroke color="#000000" joins="miter" thickness="1.5" transparency="0.25"><font color="#ffaa00">')
	text = text:gsub("<Psychic>", '<stroke color="#000000" joins="miter" thickness="1.5" transparency="0.25"><font color="#ff3c9a">')
	text = text:gsub("<Darkness>", '<stroke color="#000000" joins="miter" thickness="1.5" transparency="0.25"><font color="#4b4b70">')
	text = text:gsub("<Metal>", '<stroke color="#000000" joins="miter" thickness="1.5" transparency="0.25"><font color="#999999">')
	text = text:gsub("<Dragon>", '<stroke color="#000000" joins="miter" thickness="1.5" transparency="0.25"><font color="#3072ff">')
	text = text:gsub("<Normal>", '<stroke color="#000000" joins="miter" thickness="1.5" transparency="0.25"><font color="#ffffff">')

	text = text:gsub("<end>", '</font></stroke>')
	return text
end

local STABLE_FRAMES = 8
UtilsModule.WaitForNearbyStream = function(player,radius)
	-- esperar a que el personaje exista
	if not radius then radius = 200 end
	repeat task.wait() until player.Character and player.Character.PrimaryPart
	local root = player.Character.PrimaryPart

	-- pedir stream del área
	if workspace.StreamingEnabled then
		player:RequestStreamAroundAsync(root.Position)
	end

	-- esperar a que el número de partes en el radio deje de cambiar
	local lastCount = -1
	local stable = 0
	while stable < STABLE_FRAMES do
		if workspace.StreamingEnabled then
			player:RequestStreamAroundAsync(root.Position)
		end
		local parts = workspace:GetPartBoundsInRadius(root.Position, radius)
		local count = #parts
		if count == lastCount then
			stable += 1
		else
			stable = 0
			lastCount = count
		end
		task.wait()
	end

	-- precargar assets de lo que ya está en memoria
	local toPreload = {}
	for _, part in ipairs(workspace:GetPartBoundsInRadius(root.Position, radius)) do
		table.insert(toPreload, part)
		for _, d in ipairs(part:GetDescendants()) do
			table.insert(toPreload, d)
		end
	end
	pcall(function() ContentProvider:PreloadAsync(toPreload) end)
end

UtilsModule.RandomCFrameXZ = function(cf,distance)
	
	local rng = Random.new()
	local a = rng:NextNumber(0, math.pi*2)
	local off = Vector3.new(math.cos(a)*distance, 0, math.sin(a)*distance)
	return CFrame.new(cf.Position + off) * (cf - cf.Position)
end


local bindName = "ImpactShake"
UtilsModule.ImpactShake = function(duration, amplitude, frequency)
	duration = math.min(duration or 0.8, 1)   -- máx 1s
	amplitude = amplitude or 1.5              -- traslación en studs
	frequency = frequency or 20               -- Hz del ruido
	local cam = workspace.CurrentCamera
	if not cam then return end

	local t0 = tick()
	local seed = math.random(-1000,1000)
	RunService:UnbindFromRenderStep(bindName)
	RunService:BindToRenderStep(bindName, Enum.RenderPriority.Camera.Value + 1, function(dt)
		local t = tick() - t0
		if t >= duration or not cam then
			RunService:UnbindFromRenderStep(bindName)
			return
		end
		local k = 1 - t/duration
		k = k*k  -- decaimiento cuadrático
		local n1 = math.noise(seed, t*frequency, 0)
		local n2 = math.noise(seed, 0, t*frequency)
		local n3 = math.noise(seed, t*frequency, t*0.5)

		local posOff = Vector3.new(n1, n3*0.5, n2) * amplitude * k
		local rotOff = CFrame.Angles(math.rad(n2*2*amplitude)*k, math.rad(n1*2*amplitude)*k, 0)

		cam.CFrame = cam.CFrame * CFrame.new(posOff) * rotOff
	end)
end

UtilsModule.InsertDataPlayer = function(instance, name, value, parent, loaded)
	local data = Instance.new(instance)
	data.Name = name
	if value then data.Value = value end
	if loaded then data.Value = loaded end
	data.Parent = parent
	return data
end


return UtilsModule
