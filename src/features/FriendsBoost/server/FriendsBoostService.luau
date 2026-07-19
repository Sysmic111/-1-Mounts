--!strict

-- Friends Boost: cada amigo de Roblox conectado en el mismo server aporta un
-- multiplicador que se SUMA al TotalMultiplier (aditivo, como mount/hat/trail).
-- Es una estadística en vivo (atributo del Player, no se guarda): depende de
-- quién esté conectado ahora mismo.
--
-- Server de máx 10 → hasta 9 amigos → boost máx x{1 + 0.25*9} = x3.25.

local Players = game:GetService("Players")

local BOOST_PER_FRIEND = 0.25

local FriendsBoostService = {
	_speedService = nil :: any,
}

-- Amistad por par (no cambia durante la sesión), cacheada para no repetir
-- IsFriendsWith (que hace red y tiene rate limit). Clave "minId_maxId".
local friendCache: { [string]: boolean } = {}

local function pairKey(a: number, b: number): string
	return if a < b then a .. "_" .. b else b .. "_" .. a
end

local function areFriends(a: Player, b: Player): boolean
	local key = pairKey(a.UserId, b.UserId)
	local cached = friendCache[key]
	if cached ~= nil then return cached end

	local ok, result = pcall(function()
		return a:IsFriendsWith(b.UserId)
	end)
	local value = (ok and result) or false
	friendCache[key] = value
	return value
end

function FriendsBoostService:setSpeedService(speedService: any): ()
	self._speedService = speedService
end

-- Recuenta amigos conectados de un jugador y actualiza su atributo + multiplicador.
function FriendsBoostService:_updatePlayer(player: Player): ()
	local count = 0
	for _, other in Players:GetPlayers() do
		if other ~= player and areFriends(player, other) then
			count += 1
		end
	end

	local boost = 1 + BOOST_PER_FRIEND * count
	if player:GetAttribute("FriendsBoost") ~= boost then
		player:SetAttribute("FriendsBoost", boost)
		if self._speedService then
			self._speedService:updateTotalMultiplier(player)
		end
	end
end

-- Un cambio en el server (entra/sale alguien) puede afectar el conteo de varios
-- jugadores, así que se recalculan todos.
function FriendsBoostService:_updateAll(): ()
	for _, player in Players:GetPlayers() do
		self:_updatePlayer(player)
	end
end

function FriendsBoostService:init(): ()
	Players.PlayerAdded:Connect(function(player)
		-- Inicializar ya para que el cliente lea x1 aunque no tenga amigos aún.
		if player:GetAttribute("FriendsBoost") == nil then
			player:SetAttribute("FriendsBoost", 1)
		end
		task.spawn(function()
			self:_updateAll()
		end)
	end)

	Players.PlayerRemoving:Connect(function(leaving)
		-- Limpiar del cache los pares del que se va.
		local leavingId = tostring(leaving.UserId)
		for key in friendCache do
			local a, b = key:match("^(%d+)_(%d+)$")
			if a == leavingId or b == leavingId then
				friendCache[key] = nil
			end
		end
		-- Recalcular tras el frame en que el jugador ya salió de GetPlayers.
		task.defer(function()
			self:_updateAll()
		end)
	end)

	for _, player in Players:GetPlayers() do
		if player:GetAttribute("FriendsBoost") == nil then
			player:SetAttribute("FriendsBoost", 1)
		end
	end
	task.spawn(function()
		self:_updateAll()
	end)
end

return FriendsBoostService
