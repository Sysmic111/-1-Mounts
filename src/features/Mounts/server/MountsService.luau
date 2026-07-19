--!strict

local Players = game:GetService("Players")

local MountsConfig = require(game.ReplicatedStorage.Shared.MountsConfig)
local MorphService = require(script.Parent.MorphService)
local Packets     = require(game.ReplicatedStorage.Shared.Packets)
local FormatNumber = require(game.ReplicatedStorage.Packages.FormatNumber)
local FunnelService = require(game.ServerScriptService.Analytics.FunnelService)

type DataServiceServer = {
	waitForData: (self: DataServiceServer, player: Player) -> any,
	hasProfile: (self: DataServiceServer, player: Player) -> boolean,
	get: (self: DataServiceServer, player: Player, path: any?) -> any,
	set: (self: DataServiceServer, player: Player, path: any, value: any, dontReplicate: boolean?) -> (),
}

local MountsService = {
	_dataService  = nil :: DataServiceServer?,
	_speedService = nil :: any,
}

local function getLatestOwnedWorld1Index(dataService: DataServiceServer, player: Player): number?
	local ownedMounts = (dataService:get(player, { "Mounts" }) or {}) :: { [string]: boolean }
	for i = #MountsConfig.World1, 1, -1 do
		if ownedMounts[MountsConfig.World1[i].Name] then
			return i
		end
	end
	return nil
end

function MountsService:setSpeedService(speedService: any): ()
	self._speedService = speedService
end

function MountsService:init(dataService: DataServiceServer): ()
	self._dataService = dataService

	Players.PlayerAdded:Connect(function(player)
		self:_setupPlayer(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:_setupPlayer(player)
		end)
	end

	Packets.EvolveMount.OnServerEvent:Connect(function(player: Player)
		self:_handleEvolve(player)
	end)

	Packets.EquipMount.OnServerEvent:Connect(function(player: Player, mountName: string)
		if type(mountName) ~= "string" then return end
		self:EquipMount(player, mountName)
		if self._speedService then
			self._speedService:updateTotalMultiplier(player)
		end
	end)
end

function MountsService:_setupPlayer(player: Player): ()
	local dataService = self._dataService
	if not dataService then return end

	dataService:waitForData(player)
	if not player:IsDescendantOf(Players) then return end

	-- Dar Chonk si el jugador no lo tiene (jugadores que entran antes del template update)
	local hasChonk = dataService:get(player, { "Mounts", "Chonk" })
	if not hasChonk then
		dataService:set(player, { "Mounts", "Chonk" }, true)
	end

	-- Si no tiene mount equipado, equipar Chonk
	local equipped = dataService:get(player, { "EquippedMount" }) :: string?
	if not equipped or equipped == "" then
		dataService:set(player, { "EquippedMount" }, "Chonk")
		equipped = "Chonk"
	end

	-- Esperar a que el personaje esté disponible y luego equipar
	if player.Character then
		self:_equipOnCharacter(player, equipped)
	end

	player.CharacterAdded:Connect(function(character)
		-- Si el character ya es un mount, no re-equipar
		if character:GetAttribute("IsMountCharacter") then return end

		local currentMount = dataService:get(player, { "EquippedMount" }) :: string?
		if currentMount and currentMount ~= "" then
			self:_equipOnCharacter(player, currentMount)
		end
	end)
end

function MountsService:_equipOnCharacter(player: Player, mountName: string): ()
	-- Esperar un frame para que el personaje esté completamente cargado
	task.defer(function()
		if not player:IsDescendantOf(Players) then return end
		MorphService.MorphPlayer(player, mountName)
	end)
end

function MountsService:EquipMount(player: Player, mountName: string): boolean
	local dataService = self._dataService
	if not dataService or not dataService:hasProfile(player) then return false end

	local ownsMount = dataService:get(player, { "Mounts", mountName })
	if not ownsMount then return false end

	dataService:set(player, { "EquippedMount" }, mountName)
	MorphService.MorphPlayer(player, mountName)
	return true
end

function MountsService:_handleEvolve(player: Player): ()
	local dataService = self._dataService
	if not dataService or not dataService:hasProfile(player) then return end

	-- La progresión no depende de EquippedMount: una montura Premium, Daily o una
	-- base anterior equipada no debe cambiar cuál es el siguiente evolve.
	local currentIndex = getLatestOwnedWorld1Index(dataService, player)
	if not currentIndex then
		Packets.EvolveMountResult:FireClient(player, false, "No base mount unlocked.")
		return
	end

	local nextMount = MountsConfig.World1[currentIndex + 1]
	if not nextMount then
		Packets.EvolveMountResult:FireClient(player, false, "You already have the max mount.")
		return
	end

	-- Las mounts persisten tras el rebirth: si la siguiente ya es del jugador
	-- (p. ej. equipó una inferior y vuelve a subir), re-equipar gratis. Sin este
	-- fast-path se le cobrarían Wins por una montura que ya posee.
	if dataService:get(player, { "Mounts", nextMount.Name }) == true then
		dataService:set(player, { "EquippedMount" }, nextMount.Name)
		MorphService.MorphPlayer(player, nextMount.Name)
		if self._speedService then
			self._speedService:updateTotalMultiplier(player)
		end
		Packets.EvolveMountResult:FireClient(player, true, "")
		FunnelService:onMountUnlocked(player, nextMount.Name)
		return
	end

	local reqs = nextMount.EvolveRequirements
	if not reqs then
		Packets.EvolveMountResult:FireClient(player, false, "Next mount has no requirements defined.")
		return
	end

	local playerLevel = (dataService:get(player, { "Level" }) or 1) :: number
	local playerWins  = (dataService:get(player, { "WinCurrency" }) or 0) :: number

	local missing: { string } = {}
	if playerLevel < reqs.Level then
		table.insert(missing, "Level " .. reqs.Level .. " (you have " .. playerLevel .. ")")
	end
	if playerWins < reqs.Wins then
		table.insert(missing, FormatNumber:formatNumberCoins(reqs.Wins)
			.. " Wins (you have " .. FormatNumber:formatNumberCoins(playerWins) .. ")")
	end

	if #missing > 0 then
		Packets.EvolveMountResult:FireClient(player, false, "You need: " .. table.concat(missing, " and "))
		return
	end

	dataService:set(player, { "Mounts", nextMount.Name }, true)
	dataService:set(player, { "EquippedMount" }, nextMount.Name)
	dataService:set(player, { "WinCurrency" }, playerWins - reqs.Wins)
	FunnelService:onMountUnlocked(player, nextMount.Name)
	MorphService.MorphPlayer(player, nextMount.Name)
	if self._speedService then
		self._speedService:updateTotalMultiplier(player)
	end
	Packets.EvolveMountResult:FireClient(player, true, "")
end

function MountsService:GetMultiplier(player: Player): number
	local dataService = self._dataService
	if not dataService or not dataService:hasProfile(player) then return 1 end

	local mountName = dataService:get(player, { "EquippedMount" }) :: string?
	if not mountName or mountName == "" then return 1 end

	local mountData = MountsConfig.getMountData(mountName)
	if not mountData then return 1 end

	return mountData.Multiplier
end

return MountsService
