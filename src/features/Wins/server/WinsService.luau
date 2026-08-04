--!strict

local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local WinsConfig    = require(script.Parent.WinsConfig)
local RebirthConfig = require(game.ReplicatedStorage.Shared.RebirthConfig)
local FormatNumber  = require(game.ReplicatedStorage.Packages.FormatNumber)
local FunnelService = require(game.ServerScriptService.Server.FunnelService)
local Packets       = require(game.ReplicatedStorage.Shared.Packets)

type DataServiceServer = {
	hasProfile: (self: DataServiceServer, player: Player) -> boolean,
	get: (self: DataServiceServer, player: Player, path: any?) -> any,
	set: (self: DataServiceServer, player: Player, path: any, value: any, dontReplicate: boolean?) -> (),
}

type RobuxServiceLike = {
	registerProduct: (self: any, productId: number, handler: (player: Player, receiptInfo: any) -> Enum.ProductPurchaseDecision) -> (),
}

type WinZoneState = {
	connections: { RBXScriptConnection },
	debounceByPlayer: { [Player]: boolean },
}

local WinsService = {
	_dataService = nil :: DataServiceServer?,
	_robuxService = nil :: RobuxServiceLike?,
	_winZoneStates = {} :: { [Instance]: WinZoneState },
	_premiumPromptByPlayer = {} :: { [Player]: number },
}

local function debugPrint(message: string)
	if WinsConfig.Debug then
		print("[Wins] " .. message)
	end
end

local function getPlayerFromTouchedPart(part: BasePart): Player?
	local character = part:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

local function getTouchPart(winZone: Instance): BasePart?
	local touchPart = winZone:FindFirstChild(WinsConfig.TouchPartName, true)
	if touchPart and touchPart:IsA("BasePart") then
		return touchPart
	end

	return nil
end

local function getSpawnLocation(): SpawnLocation?
	return Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
end

function WinsService:init(dataService: DataServiceServer, robuxService: RobuxServiceLike): ()
	self._dataService = dataService
	self._robuxService = robuxService
	debugPrint("WinsService iniciado")

	-- Registrar el Developer Product de los botones premium en el router de recibos
	-- (RobuxService es dueño único de ProcessReceipt).
	robuxService:registerProduct(WinsConfig.PremiumProductId, function(player, _receiptInfo)
		return self:_handlePremiumReceipt(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self._premiumPromptByPlayer[player] = nil
	end)

	for _, winZone in ipairs(CollectionService:GetTagged(WinsConfig.TagName)) do
		self:_setupWinZone(winZone)
	end

	CollectionService:GetInstanceAddedSignal(WinsConfig.TagName):Connect(function(winZone)
		debugPrint(`Tag agregado: {winZone:GetFullName()}`)
		self:_setupWinZone(winZone)
	end)

	CollectionService:GetInstanceRemovedSignal(WinsConfig.TagName):Connect(function(winZone)
		debugPrint(`Tag removido: {winZone:GetFullName()}`)
		self:_cleanupWinZone(winZone)
	end)
end

function WinsService:_setupWinZone(winZone: Instance): ()
	if self._winZoneStates[winZone] then
		return
	end

	local touchPart = getTouchPart(winZone)
	if not touchPart then
		debugPrint(`Zona ignorada sin TouchPart: {winZone:GetFullName()}`)
		return
	end

	local winsQuantity = winZone:GetAttribute(WinsConfig.WinsQuantityAttribute)
	if typeof(winsQuantity) ~= "number" then
		debugPrint(`Zona ignorada sin atributo WinsQuantity numerico: {winZone:GetFullName()}`)
		return
	end

	local surfaceGui = touchPart:FindFirstChild("SurfaceGui")
	local label = surfaceGui and surfaceGui:FindFirstChild("TextLabel") :: TextLabel?
	if label then
		label.Text = "+ " .. FormatNumber:formatNumberCoins(winsQuantity)
	end

	local state: WinZoneState = {
		connections = {},
		debounceByPlayer = {},
	}

	self._winZoneStates[winZone] = state

	table.insert(state.connections, touchPart.Touched:Connect(function(touchedPart)
		self:_onTouchPartTouched(winZone, touchedPart)
	end))

	debugPrint(`Zona Wins configurada: {winZone:GetFullName()}, wins={winsQuantity}`)
end

function WinsService:_onTouchPartTouched(winZone: Instance, touchedPart: BasePart): ()
	local state = self._winZoneStates[winZone]
	if not state then
		return
	end

	local player = getPlayerFromTouchedPart(touchedPart)
	if not player or state.debounceByPlayer[player] then
		return
	end

	state.debounceByPlayer[player] = true
	task.delay(WinsConfig.TouchDebounceSeconds, function()
		state.debounceByPlayer[player] = nil
	end)

	-- Botón premium: en vez de dar Wins gratis, se cobra el Developer Product.
	-- El crédito + teleport ocurren al confirmarse la compra (ProcessReceipt).
	if winZone:GetAttribute(WinsConfig.PremiumAttribute) == true then
		self:_promptPremiumPurchase(player, winZone)
		return
	end

	self:_giveWins(player, winZone)
	self:_teleportToSpawn(player)
end

-- Acredita Wins (con multiplicador de rebirth) en la moneda del jugador.
-- Devuelve lo REALMENTE acreditado, que no es el `winsQuantity` de entrada: quien
-- quiera enseñar el premio por pantalla tiene que usar el valor devuelto o estaría
-- mintiendo por el factor del rebirth (hasta x26) y el del weather.
function WinsService:_creditWins(player: Player, winsQuantity: number): number
	local dataService = self._dataService
	if not dataService or not dataService:hasProfile(player) then
		debugPrint(`No se pudo dar Wins a {player.Name}: profile no disponible`)
		return 0
	end

	local rebirthCount = (dataService:get(player, { "Rebirth" }) or 0) :: number
	local multiplier   = RebirthConfig.getWinsMultiplier(rebirthCount)

	-- Weather Event global (atributo en vivo, lo gestiona WeatherService). Acá SÍ
	-- multiplica, a diferencia de en TotalMultiplier donde suma: los Wins no tienen
	-- base aditiva, su único multiplicador (el rebirth) también es multiplicativo.
	-- Por eso WeatherConfig lleva un WinsMultiplier aparte, mucho más contenido que
	-- el de Speed: los Wins son el sink más grande del juego.
	local weatherWins = (player:GetAttribute("WeatherWinsBoost") or 1) :: number

	local earned = math.round(winsQuantity * multiplier * weatherWins)

	local currentWins = dataService:get(player, { "WinCurrency" }) or 0
	local newWins = currentWins + earned
	dataService:set(player, { "WinCurrency" }, newWins)

	-- Estadística de por vida: acumula todo lo ganado, no baja al gastar ni rebirthear.
	local totalEarned = (dataService:get(player, { "TotalWinsEarned" }) or 0) :: number
	dataService:set(player, { "TotalWinsEarned" }, totalEarned + earned)
	FunnelService:onProgressChanged(player)

	-- En el 2º claim de por vida se lanza el prompt nativo de favoritos (una sola vez).
	-- El == 2 solo se cumple una vez en la vida del jugador, así que no se repite.
	local claimCount = ((dataService:get(player, { "WinsClaimCount" }) or 0) :: number) + 1
	dataService:set(player, { "WinsClaimCount" }, claimCount)
	if claimCount == 2 then
		Packets.PromptFavorite:FireClient(player)
	end

	debugPrint(`Wins entregados: {player.Name}, +{earned} (x{multiplier}), total={newWins}`)

	return earned
end

-- API pública para otros features que conceden Wins fuera de un botón (hoy: las
-- carreras contra NPC). Pasa por _creditWins a propósito, para heredar el
-- multiplicador de rebirth, el WeatherWinsBoost, TotalWinsEarned y el funnel: si cada
-- feature replicase esa fórmula, cualquier cambio de balance habría que tocarlo en
-- varios sitios.
-- Devuelve lo acreditado de verdad (con rebirth y weather aplicados), para que quien
-- lo llame pueda enseñar el número correcto en pantalla.
function WinsService:awardWins(player: Player, amount: number): number
	if typeof(amount) ~= "number" or amount <= 0 then
		return 0
	end
	return self:_creditWins(player, amount)
end

-- Mismo teleport al spawn que tras reclamar un botón de Wins.
function WinsService:teleportToSpawn(player: Player): ()
	self:_teleportToSpawn(player)
end

function WinsService:_giveWins(player: Player, winZone: Instance): ()
	local winsQuantity = winZone:GetAttribute(WinsConfig.WinsQuantityAttribute)
	if typeof(winsQuantity) ~= "number" then
		debugPrint(`No se pudo dar Wins a {player.Name}: WinsQuantity invalido`)
		return
	end
	self:_creditWins(player, winsQuantity)
end

-- Pisar un botón premium: guarda la intención (qué WinsQuantity reclamar) en la data
-- del jugador y lanza el prompt de compra del Developer Product.
function WinsService:_promptPremiumPurchase(player: Player, winZone: Instance): ()
	local dataService = self._dataService
	if not dataService or not dataService:hasProfile(player) then
		return
	end

	local winsQuantity = winZone:GetAttribute(WinsConfig.WinsQuantityAttribute)
	if typeof(winsQuantity) ~= "number" then
		debugPrint(`Botón premium sin WinsQuantity numérico: {winZone:GetFullName()}`)
		return
	end

	-- Anti-spam: no relanzar el prompt mientras el jugador sigue parado encima
	local now = os.clock()
	if (now - (self._premiumPromptByPlayer[player] or 0)) < WinsConfig.PremiumPromptCooldownSeconds then
		return
	end
	self._premiumPromptByPlayer[player] = now

	-- Persistente: el recibo solo conoce el productId (compartido por todos los
	-- botones premium), así que aquí registramos cuántas Wins corresponden a ESTE
	-- botón. En data para sobrevivir si el jugador reentra a mitad de compra.
	dataService:set(player, { "PendingPremiumWins" }, winsQuantity)

	FunnelService:beginServerCheckout(
		player,
		WinsConfig.PremiumProductId,
		"StageWins:" .. tostring(math.floor(winsQuantity))
	)
	MarketplaceService:PromptProductPurchase(player, WinsConfig.PremiumProductId)
	debugPrint(`Premium prompt: {player.Name}, wins={winsQuantity}`)
end

-- Llamado por el router de RobuxService cuando se confirma la compra del producto.
function WinsService:_handlePremiumReceipt(player: Player): Enum.ProductPurchaseDecision
	local dataService = self._dataService
	if not dataService or not dataService:hasProfile(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local pending = (dataService:get(player, { "PendingPremiumWins" }) or 0) :: number
	if pending <= 0 then
		-- Recibo duplicado o sin intención: ya procesado, no recobrar.
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- Consumir la intención ANTES de acreditar (evita doble cobro ante duplicados)
	dataService:set(player, { "PendingPremiumWins" }, 0)
	self:_creditWins(player, pending)
	self:_teleportToSpawn(player)

	debugPrint(`Premium concedido: {player.Name}, +{pending} wins (base)`)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function WinsService:_teleportToSpawn(player: Player): ()
	local character = player.Character
	if not character then
		debugPrint(`No se pudo teleportar a {player.Name}: character no disponible`)
		return
	end

	local spawnLocation = getSpawnLocation()
	if not spawnLocation then
		debugPrint(`No se pudo teleportar a {player.Name}: no hay SpawnLocation en Workspace`)
		return
	end

	character:PivotTo(spawnLocation.CFrame + WinsConfig.SpawnTeleportOffset)
	debugPrint(`Jugador teleportado al spawn: {player.Name}`)
end

function WinsService:_cleanupWinZone(winZone: Instance): ()
	local state = self._winZoneStates[winZone]
	if not state then
		return
	end

	for _, connection in ipairs(state.connections) do
		connection:Disconnect()
	end

	self._winZoneStates[winZone] = nil
	debugPrint(`Zona Wins limpiada: {winZone:GetFullName()}`)
end

return WinsService
