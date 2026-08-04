--!strict
local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Packets = require(game.ReplicatedStorage.Shared.Packets)
local EconomyConfig = require(game.ReplicatedStorage.Shared.EconomyConfig)
local WorldsConfig  = require(game.ReplicatedStorage.Shared.WorldsConfig)
local FunnelService = require(game.ServerScriptService.Server.FunnelService)

type DataServiceServer = {
	waitForData: (self: DataServiceServer, player: Player) -> any,
	hasProfile:  (self: DataServiceServer, player: Player) -> boolean,
	get:         (self: DataServiceServer, player: Player, path: { string }) -> any,
	set:         (self: DataServiceServer, player: Player, path: { string }, value: any, dontReplicate: boolean?) -> (),
}

local StepsService = {
	_dataService       = nil :: DataServiceServer?,
	-- Los botones que existen FÍSICAMENTE en este place. Responde a "¿es este un
	-- botón real de aquí?" y es lo que impide que un cliente dispare el increment
	-- de otro mundo.
	_stepsMap          = {} :: { [number]: number }, -- stepsIncrement -> winsQuantity
	-- La cadena de compra COMPLETA, de todos los mundos. Sale del config, no del
	-- escaneo de Workspace (ver init).
	_sortedIncrements  = {} :: { number },
	_lastActivateTime  = {} :: { [Player]: number },
}

local stepsButtonsFolder: Folder

local function buildStepsMap(stepsMap: { [number]: number }): ()
	for _, child in stepsButtonsFolder:GetChildren() do
		if child.ClassName ~= "Model" or child.Name ~= "Steps" then continue end
		local model = child :: Model
		local inc   = model:GetAttribute("StepsIncresement") :: number?
		local wins  = model:GetAttribute("WinsQuantity")     :: number?
		if inc and wins then
			stepsMap[inc] = wins
		end
	end
end

function StepsService:init(dataService: DataServiceServer): ()
	self._dataService = dataService
	stepsButtonsFolder = Workspace:WaitForChild("StepsButtons") :: Folder
	buildStepsMap(self._stepsMap)

	-- La cadena anti-salto sale del CONFIG, no de los botones de este place.
	--
	-- Cuando se derivaba del escaneo de Workspace, en World 2 el increment más bajo
	-- era su propio primer botón: se podía comprar sin haber tocado World 1. Con la
	-- cadena global, el primer step de World 2 exige los doce de World 1.
	self._sortedIncrements = EconomyConfig.getStepChain()

	local function setupPlayer(player: Player)
		task.spawn(function()
			dataService:waitForData(player)
			if not player:IsDescendantOf(Players) then return end

			-- Garantizar que el primer step siempre esté desbloqueado. El 1 literal es
			-- getStepChain()[1] y está también en el template de datos: si alguna vez
			-- cambia el primer eslabón de la cadena, hay que cambiarlo en los tres sitios.
			if dataService:get(player, { "StepUnlocked_1" }) ~= true then
				dataService:set(player, { "StepUnlocked_1" }, true)
			end

			local equipped = (dataService:get(player, { "StepsEquipped" }) or 0) :: number
			if equipped == 0 then
				equipped = 1
				dataService:set(player, { "StepsEquipped" }, 1)
			end

			player:SetAttribute("EquippedSteps", equipped)
		end)
	end

	Players.PlayerAdded:Connect(setupPlayer)
	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		self._lastActivateTime[player] = nil
	end)

	Packets.ActivateStep.OnServerEvent:Connect(function(player: Player, stepsIncrement: number)
		self:_handleActivate(player, stepsIncrement)
	end)
end

function StepsService:_handleActivate(player: Player, stepsIncrement: number): ()
	local now = os.clock()
	local last = self._lastActivateTime[player] or 0
	if now - last < 0.5 then return end
	self._lastActivateTime[player] = now

	local ds = self._dataService
	if not ds or not ds:hasProfile(player) then return end

	-- Validate stepsIncrement is a real button in the game
	local winsQuantity = self._stepsMap[stepsIncrement]
	if winsQuantity == nil then return end

	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local flatKey = "StepUnlocked_" .. tostring(stepsIncrement)

	local newlyUnlocked = ds:get(player, { flatKey }) ~= true
	if newlyUnlocked then
		-- No permitir saltarse niveles: todos los steps ANTERIORES EN LA CADENA deben
		-- estar comprados antes de comprar este. La cadena abarca todos los mundos,
		-- así que aquí es donde se exige haber terminado World 1 para empezar World 2.
		--
		-- Se corta al llegar a la POSICIÓN de este increment, no comparando números:
		-- el orden del array es el orden de diseño, y no tiene por qué coincidir con
		-- el orden numérico si algún mundo futuro no encaja al final.
		for _, inc in self._sortedIncrements do
			if inc == stepsIncrement then break end
			if ds:get(player, { "StepUnlocked_" .. tostring(inc) }) ~= true then
				-- Decir QUÉ mundo falta: "compra los anteriores" no sirve de nada si
				-- los que faltan están en otro place.
				local pendingKey = EconomyConfig.getWorldForIncrement(inc)
				local pending = pendingKey and WorldsConfig.get(pendingKey)
				local message = if pending and pendingKey ~= WorldsConfig.currentKey()
					then `Finish {pending.Name}'s steps first!`
					else "Buy the previous steps first!"
				Packets.StepActivateFailed:FireClient(player, message)
				return
			end
		end

		local winCurrency = (ds:get(player, { "WinCurrency" }) or 0) :: number
		if winCurrency < winsQuantity then return end
		ds:set(player, { "WinCurrency" }, winCurrency - winsQuantity)
		ds:set(player, { flatKey }, true)
		FunnelService:onStepUnlocked(player, stepsIncrement)
	end

	ds:set(player, { "StepsEquipped" }, stepsIncrement)
	player:SetAttribute("EquippedSteps", stepsIncrement)
	Packets.StepActivated:FireClient(player, stepsIncrement)
end

return StepsService
