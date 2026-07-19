--!strict

-- Leaderboards globales (Workspace.LeaderBoards). Cada board es un Part con un
-- SurfaceGui; el valor de cada jugador se persiste en un OrderedDataStore y el
-- top 20 se lee y se renderiza server-side (el SurfaceGui está en Workspace, así
-- que replica a todos los clientes).
--
-- Filas: se clonan los templates de SurfaceGui.Templates → 1/2/3 (top 3, con
-- medalla) y 4 (puestos 4-20). Cada fila: PlayerName, PlayerScore, Icon (el icono
-- de la estadística de ese board).

local DataStoreService = game:GetService("DataStoreService")
local Players          = game:GetService("Players")
local Workspace        = game:GetService("Workspace")

local FormatNumber = require(game.ReplicatedStorage.Packages.FormatNumber)

type DataServiceServer = {
	hasProfile: (self: DataServiceServer, player: Player) -> boolean,
	get: (self: DataServiceServer, player: Player, path: { string }) -> any,
}

type BoardConfig = {
	boardName: string,   -- nombre del Part dentro de Workspace.LeaderBoards
	dataKey: string,     -- clave de la data del jugador que alimenta este board
	storeName: string,   -- nombre del OrderedDataStore
	title: string,
	sub: string,
	icon: string,        -- icono de la estadística (se pone en cada fila)
	abbreviate: boolean, -- true → formatear con K/M/B; false → entero plano
}

local BOARDS: { BoardConfig } = {
	{
		boardName = "Rebirths", dataKey = "Rebirth", storeName = "Leaderboard_Rebirths_v1",
		title = "TOP REBIRTHS", sub = "Most rebirths",
		icon = "rbxassetid://92722693463368", abbreviate = false,
	},
	{
		boardName = "TotalSpeed", dataKey = "TotalSpeedEarned", storeName = "Leaderboard_TotalSpeed_v1",
		title = "TOP SPEED", sub = "Most speed earned",
		icon = "rbxassetid://121327750241374", abbreviate = true,
	},
	{
		boardName = "TotalWins", dataKey = "TotalWinsEarned", storeName = "Leaderboard_TotalWins_v1",
		title = "TOP WINS", sub = "Most wins earned",
		icon = "rbxassetid://73013260592473", abbreviate = true,
	},
}

local TOP_COUNT        = 20
local SAVE_INTERVAL    = 120 -- s (guardar valores de los jugadores presentes)
local REFRESH_INTERVAL = 120 -- s (releer el OrderedDataStore y re-renderizar)

local LeaderboardService = {
	_dataService = nil :: DataServiceServer?,
}

local stores: { [string]: OrderedDataStore } = {}
-- userId → nombre. GetNameFromUserIdAsync tiene rate limit, así que se cachea.
local nameCache: { [number]: string } = {}
-- userId → { dataKey → último valor leído con el perfil vivo }. Se usa como
-- fallback al guardar en PlayerRemoving, cuando el perfil ya se está liberando.
local lastValues: { [number]: { [string]: number } } = {}

-- ── Utilidades ────────────────────────────────────────────────────────────────

local function resolveName(userId: number): string
	local cached = nameCache[userId]
	if cached then return cached end

	local connected = Players:GetPlayerByUserId(userId)
	if connected then
		nameCache[userId] = connected.Name
		return connected.Name
	end

	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local resolved = (ok and name) or ("User " .. tostring(userId))
	nameCache[userId] = resolved
	return resolved
end

local function getBoardSurface(boardName: string): SurfaceGui?
	local folder = Workspace:FindFirstChild("LeaderBoards")
	local part = folder and folder:FindFirstChild(boardName)
	return part and part:FindFirstChildOfClass("SurfaceGui") or nil
end

-- ── Guardado ──────────────────────────────────────────────────────────────────

function LeaderboardService:_savePlayer(player: Player): ()
	local ds = self._dataService
	if not ds then return end

	local userId = player.UserId
	for _, board in BOARDS do
		-- En PlayerRemoving el perfil puede estar liberándose: hasProfile puede
		-- seguir en true un instante pero get falla internamente. Se protege con
		-- pcall y se cae al último valor cacheado (leído con el perfil vivo).
		local ok, raw = pcall(function()
			if ds:hasProfile(player) then
				return ds:get(player, { board.dataKey })
			end
			return nil
		end)

		local value: number?
		if ok and typeof(raw) == "number" then
			value = math.floor(raw)
			lastValues[userId] = lastValues[userId] or {}
			lastValues[userId][board.dataKey] = value :: number
		else
			local cached = lastValues[userId]
			value = cached and cached[board.dataKey]
		end

		-- OrderedDataStore solo admite enteros positivos; 0 no aporta al ranking.
		if not value or value <= 0 then continue end

		local store = stores[board.storeName]
		local v = value
		pcall(function()
			store:SetAsync(tostring(userId), v)
		end)
	end
end

function LeaderboardService:_saveAll(): ()
	for _, player in Players:GetPlayers() do
		self:_savePlayer(player)
	end
end

-- ── Render ────────────────────────────────────────────────────────────────────

function LeaderboardService:_refreshBoard(board: BoardConfig): ()
	local sg = getBoardSurface(board.boardName)
	if not sg then return end

	-- Título y subtítulo
	local header = sg:FindFirstChild("Header")
	if header then
		local title = header:FindFirstChild("Title") :: TextLabel?
		local sub   = header:FindFirstChild("sub")   :: TextLabel?
		if title then title.Text = board.title end
		if sub   then sub.Text   = board.sub   end
	end

	local templates = sg:FindFirstChild("Templates")
	local scrolling = sg:FindFirstChild("ScrollingFrame") :: ScrollingFrame?
	if not templates or not scrolling then return end

	-- Leer el top del OrderedDataStore (false = descendente, mayor primero)
	local store = stores[board.storeName]
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, TOP_COUNT)
	end)
	if not ok or not pages then return end

	local ok2, page = pcall(function()
		return (pages :: DataStorePages):GetCurrentPage()
	end)
	if not ok2 or not page then return end

	-- Limpiar filas anteriores (conservar el UIListLayout)
	for _, child in scrolling:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	for rank, entry in ipairs(page) do
		local userId = tonumber(entry.key)
		if not userId then continue end
		local value = entry.value :: number

		local templateName = if rank <= 3 then tostring(rank) else "4"
		local template = templates:FindFirstChild(templateName) :: GuiObject?
		if not template then continue end

		local row = template:Clone()
		row.Name        = "Row"
		row.Visible     = true
		row.LayoutOrder = rank

		local nameLabel  = row:FindFirstChild("PlayerName")  :: TextLabel?
		local scoreLabel = row:FindFirstChild("PlayerScore") :: TextLabel?
		local iconLabel  = row:FindFirstChild("Icon")        :: ImageLabel?

		local displayName = resolveName(userId)
		if nameLabel then
			-- Top 3 lleva medalla; del 4 en adelante se antepone el puesto.
			nameLabel.Text = if rank <= 3 then displayName else (tostring(rank) .. ". " .. displayName)
		end
		if scoreLabel then
			scoreLabel.Text = if board.abbreviate then FormatNumber:formatNumberCoins(value) else tostring(value)
		end
		if iconLabel then
			iconLabel.Image = board.icon
		end

		row.Parent = scrolling
	end
end

function LeaderboardService:_refreshAll(): ()
	for _, board in BOARDS do
		self:_refreshBoard(board)
		task.wait() -- espaciar las llamadas a DataStore entre boards
	end
end

-- ── Init ──────────────────────────────────────────────────────────────────────

function LeaderboardService:init(dataService: DataServiceServer): ()
	self._dataService = dataService

	for _, board in BOARDS do
		stores[board.storeName] = DataStoreService:GetOrderedDataStore(board.storeName)
	end

	-- Guardar el valor final del jugador cuando se va, y limpiar sus caches.
	Players.PlayerRemoving:Connect(function(player)
		self:_savePlayer(player)
		lastValues[player.UserId] = nil
	end)

	-- Render inicial con lo que ya haya en los stores (sesiones anteriores).
	task.spawn(function()
		self:_refreshAll()
	end)

	-- Loop: guardar los presentes y volver a renderizar cada 2 min.
	task.spawn(function()
		while true do
			task.wait(math.min(SAVE_INTERVAL, REFRESH_INTERVAL))
			self:_saveAll()
			self:_refreshAll()
		end
	end)
end

return LeaderboardService
