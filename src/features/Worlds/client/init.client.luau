--!strict

-- Menú Teleport: viajar entre places desde la UI.
--
-- Las tarjetas NO se construyen aquí — ya viven en el .rbxl, dentro de
-- `Menus.Teleport.ScrollingFrame`, y cada una se llama EXACTAMENTE como el Key de
-- su mundo en WorldsConfig ("World1", "World2"). Ese nombre es todo el
-- emparejamiento que hay: añadir World 3 es duplicar una tarjeta en Studio y
-- llamarla "World3", sin tocar este script.
--
-- Un mundo sin tarjeta se ignora en silencio (todavía no está en el .rbxl) y una
-- tarjeta sin mundo se avisa por consola: es un nombre mal escrito en Studio, que
-- es justo el fallo que este emparejamiento por nombre puede provocar.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MenuManager  = require(ReplicatedStorage.Shared.MenuManager)
local WorldsConfig = require(ReplicatedStorage.Shared.WorldsConfig)
local Packets      = require(ReplicatedStorage.Shared.Packets)
local DataService  = require(ReplicatedStorage.Packages.DataService).client
local AlertsModule = require(ReplicatedStorage.Packages.AlertsModule)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local left  = playerGui:WaitForChild("Left")
local menus = playerGui:WaitForChild("Menus")

local btnTeleports = left:WaitForChild("Main"):WaitForChild("Line2"):WaitForChild("Teleports") :: ImageButton

local menuTeleport = menus:WaitForChild("Teleport")                    :: Frame
local scrolling    = menuTeleport:WaitForChild("ScrollingFrame")       :: ScrollingFrame
local closeButton  = menuTeleport:WaitForChild("Right"):WaitForChild("Close") :: ImageButton

local currentKey = WorldsConfig.currentKey()

-- Texto del botón de cada tarjeta según su estado.
local LABEL_CURRENT  = "Current"
local LABEL_LOCKED   = "Locked"
local LABEL_TELEPORT = "Teleport"

-- Las tarjetas bloqueadas se apagan en vez de ocultarse: el jugador tiene que ver
-- que World 2 existe. Mismo criterio que las mounts no desbloqueadas del Index,
-- que se pintan en negro en vez de desaparecer.
local COLOR_ENABLED = Color3.fromRGB(255, 255, 255)
local COLOR_LOCKED  = Color3.fromRGB(105, 105, 105)

type Card = {
	key: string,
	button: ImageButton,
	name: TextLabel?,
	action: TextLabel?,
	images: { ImageLabel },
}

-- ── Tarjetas ─────────────────────────────────────────────────────────────────

local cards: { Card } = {}

for _, worldKey in WorldsConfig.Order do
	local button = scrolling:FindFirstChild(worldKey)
	-- Mundo declarado en el config pero todavía sin tarjeta en el .rbxl.
	if not button or not button:IsA("ImageButton") then continue end

	local card = button:FindFirstChild("CardTemplate")
	local images: { ImageLabel } = {}
	local name: TextLabel? = nil
	local action: TextLabel? = nil

	if card then
		name = card:FindFirstChild("TextName") :: TextLabel?

		local teleportFrame = card:FindFirstChild("Teleport")
		if teleportFrame then
			action = teleportFrame:FindFirstChild("Quantity") :: TextLabel?
		end

		for _, childName in { "Image1", "WorldImage" } do
			local image = card:FindFirstChild(childName)
			if image and image:IsA("ImageLabel") then
				table.insert(images, image)
			end
		end
	end

	table.insert(cards, { key = worldKey, button = button, name = name, action = action, images = images })
end

-- Al revés: tarjetas que no corresponden a ningún mundo. Solo puede pasar por un
-- nombre mal escrito en Studio, y en silencio se quedaría muerta para siempre.
for _, child in scrolling:GetChildren() do
	if not child:IsA("ImageButton") then continue end
	if WorldsConfig.get(child.Name) then continue end
	warn(`[Teleport] La tarjeta "{child.Name}" no es ningún mundo de WorldsConfig — no hace nada al pulsarla`)
end

-- ── Estado ───────────────────────────────────────────────────────────────────

-- ESPEJO de WorldsService:_denyReason. Aquí solo decide cómo se PINTA la tarjeta
-- y permite avisar sin ir al servidor; quien concede el viaje es siempre él.
--
-- A propósito solo mira el flag de desbloqueo y no la cadena de steps: el flag es
-- lo que el jugador entiende como "lo tengo o no lo tengo", y duplicar aquí el
-- recorrido de la cadena sería una segunda copia de una regla que ya está
-- espejada en dos sitios. Si la cadena falta, el servidor manda su propio mensaje.
local function isUnlocked(worldKey: string): boolean
	if not WorldsConfig.needsUnlock(worldKey) then return true end
	return DataService:get({ WorldsConfig.unlockKey(worldKey) }) == true
end

local function refreshCard(card: Card)
	local isCurrent = card.key == currentKey
	local unlocked  = isUnlocked(card.key)
	local world     = WorldsConfig.get(card.key)

	if card.name and world then
		card.name.Text = world.Name
	end

	if card.action then
		card.action.Text = if isCurrent then LABEL_CURRENT
			elseif unlocked then LABEL_TELEPORT
			else LABEL_LOCKED
	end

	-- El mundo actual no se apaga: no está bloqueado, es que ya estás en él.
	local tint = if unlocked then COLOR_ENABLED else COLOR_LOCKED
	for _, image in card.images do
		image.ImageColor3 = tint
	end
end

local function refreshAll()
	for _, card in cards do
		refreshCard(card)
	end
end

-- ── Interacción ──────────────────────────────────────────────────────────────

-- Anti-spam del alert: el mismo criterio (y el mismo margen) que el cliente de
-- Steps, porque el servidor puede reenviar el fallo varias veces seguidas.
local lastErrorTime = 0
local function showError(message: string)
	local now = os.clock()
	if now - lastErrorTime < 2 then return end
	lastErrorTime = now
	AlertsModule.ShowAlertGui("Error", message)
end

for _, card in cards do
	card.button.MouseButton1Click:Connect(function()
		-- Ya estás aquí: no pasa nada, ni viaje ni error.
		if card.key == currentKey then return end

		local world = WorldsConfig.get(card.key)
		if not world then return end

		if not isUnlocked(card.key) then
			showError(`You haven't unlocked {world.Name} yet!`)
			return
		end

		Packets.RequestWorldTeleport:Fire(card.key)
	end)
end

-- El servidor revalida y puede negar por algo que el cliente no mira (la cadena
-- de steps del mundo anterior), así que este mensaje no es redundante con el de
-- arriba: la mayoría de las veces dice otra cosa.
Packets.WorldTeleportFailed.OnClientEvent:Connect(function(message: string)
	showError(message)
	-- Un "no" del servidor donde el cliente decía "sí" significa que la vista
	-- estaba desfasada.
	refreshAll()
end)

-- ── Open / Close ─────────────────────────────────────────────────────────────

btnTeleports.MouseButton1Click:Connect(function()
	MenuManager.toggle(menuTeleport, { onOpen = refreshAll })
end)

closeButton.MouseButton1Click:Connect(function()
	MenuManager.close(menuTeleport)
end)

-- Repintado en vivo: si el mundo se desbloquea con el menú abierto, la tarjeta
-- cambia sola en vez de esperar a la siguiente apertura.
task.spawn(function()
	DataService:waitForData()
	refreshAll()

	for _, card in cards do
		if not WorldsConfig.needsUnlock(card.key) then continue end
		DataService:getChangedSignal({ WorldsConfig.unlockKey(card.key) }):Connect(function()
			refreshCard(card)
		end)
	end
end)
