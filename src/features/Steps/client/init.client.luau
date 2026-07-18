--!strict
local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packets      = require(ReplicatedStorage.Shared.Packets)
local DataService  = require(ReplicatedStorage.Packages.DataService).client
local FormatNumber = require(ReplicatedStorage.Packages.FormatNumber)
local AlertsModule = require(ReplicatedStorage.Packages.AlertsModule)

local player = Players.LocalPlayer

local COLOR_GREEN  = Color3.fromRGB(75, 215, 75)
local COLOR_YELLOW = Color3.fromRGB(255, 200, 0)
local COLOR_RED    = Color3.fromRGB(215, 50, 50)

type StepsEntry = {
	touchPart:      BasePart,
	stepsIncrement: number,
}

local allSteps: { StepsEntry } = {}
local dataReady  = false
local lastFireTime = 0

local function colorEntry(entry: StepsEntry): ()
	if not dataReady then
		print("[Steps] colorEntry: dataReady=false, saltando step", entry.stepsIncrement)
		return
	end
	-- El TouchPart pudo salir por streaming; saltar si ya no está cargado
	if not entry.touchPart.Parent then return end
	local equippedSteps = (DataService:get({ "StepsEquipped" }) or 1) :: number
	local flatKey = "StepUnlocked_" .. tostring(entry.stepsIncrement)
	local isUnlocked = DataService:get({ flatKey })
	print("[Steps] colorEntry step", entry.stepsIncrement,
		"| equipped:", equippedSteps,
		"| flatKey:", flatKey,
		"| isUnlocked:", isUnlocked)
	if entry.stepsIncrement == equippedSteps then
		entry.touchPart.Color = COLOR_GREEN
	elseif isUnlocked == true then
		entry.touchPart.Color = COLOR_YELLOW
	else
		entry.touchPart.Color = COLOR_RED
	end
end

local function refreshColors(): ()
	print("[Steps] refreshColors llamado, allSteps count:", #allSteps)
	for _, entry in allSteps do
		colorEntry(entry)
	end
end

-- TouchParts ya conectados (por parte). Con StreamingEnabled una parte puede
-- salir y volver a entrar (nueva instancia), así que se reconecta cada vez.
local connected: { [BasePart]: boolean } = {}

-- Intenta conectar el botón. Es idempotente: si faltan atributos o el TouchPart
-- aún no llegó (streaming), no hace nada y se reintenta al aparecer.
local function tryConnect(model: Model): ()
	local inc  = model:GetAttribute("StepsIncresement") :: number?
	local wins = model:GetAttribute("WinsQuantity")     :: number?
	local tp   = model:FindFirstChild("TouchPart")      :: BasePart?
	if not inc or not wins or not tp then return end
	if connected[tp] then return end
	connected[tp] = true

	-- Poblar labels del panel
	local sgPart = model:FindFirstChild("Smooth Block Model") :: BasePart?
	if sgPart then
		local sg = sgPart:FindFirstChildOfClass("SurfaceGui") :: SurfaceGui?
		if sg then
			local stepsLabel = sg:FindFirstChild("Steps")        :: TextLabel?
			local winsLabel  = sg:FindFirstChild("RequiredWins") :: TextLabel?
			if stepsLabel then
				stepsLabel.Text = "+" .. tostring(inc) .. "/Steps"
			end
			if winsLabel then
				winsLabel.Text = FormatNumber:formatNumberCoins(wins) .. " Wins Required"
			end
		end
	end

	local entry: StepsEntry = { touchPart = tp, stepsIncrement = inc }
	table.insert(allSteps, entry)
	colorEntry(entry)

	tp.Touched:Connect(function(hit: BasePart)
		local character = player.Character
		if not character then return end
		if not hit:IsDescendantOf(character) then return end
		local now = os.clock()
		if now - lastFireTime < 0.5 then return end
		lastFireTime = now
		Packets.ActivateStep:Fire(inc)
	end)
end

-- Observa un botón: conecta ahora y reintenta cuando el streaming reponga el
-- TouchPart o lleguen los atributos (en vez de rendirse tras un timeout).
local function watchButton(instance: Instance): ()
	local model = instance :: Model
	tryConnect(model)
	model.ChildAdded:Connect(function(child)
		if child.Name == "TouchPart" then
			tryConnect(model)
		end
	end)
	model:GetAttributeChangedSignal("StepsIncresement"):Connect(function()
		tryConnect(model)
	end)
	model:GetAttributeChangedSignal("WinsQuantity"):Connect(function()
		tryConnect(model)
	end)
end

-- Inicializar botones ya presentes y los que aparezcan (streaming)
print("[Steps] Tagged StepButton count:", #CollectionService:GetTagged("StepButton"))
for _, instance in CollectionService:GetTagged("StepButton") do
	watchButton(instance)
end
CollectionService:GetInstanceAddedSignal("StepButton"):Connect(watchButton)

-- Esperar data y colorear; re-colorear en cada cambio relevante
task.spawn(function()
	print("[Steps] waitForData: esperando...")
	DataService:waitForData()
	print("[Steps] waitForData: resuelto | StepsEquipped:", DataService:get({ "StepsEquipped" }), "| StepUnlocked_1:", DataService:get({ "StepUnlocked_1" }))
	dataReady = true
	refreshColors()
	DataService:getChangedSignal({ "StepsEquipped" }):Connect(function()
		print("[Steps] DataService StepsEquipped cambió:", DataService:get({ "StepsEquipped" }))
		refreshColors()
	end)
	DataService:getChangedSignal({ "StepUnlocked_1" }):Connect(function()
		print("[Steps] DataService StepUnlocked_1 cambió:", DataService:get({ "StepUnlocked_1" }))
		refreshColors()
	end)
end)

-- Garantía: el servidor siempre setea este atributo tras cargar data
player:GetAttributeChangedSignal("EquippedSteps"):Connect(function()
	local val = player:GetAttribute("EquippedSteps")
	print("[Steps] GetAttributeChangedSignal EquippedSteps:", val)
	dataReady = true
	refreshColors()
end)

Packets.StepActivated.OnClientEvent:Connect(function(stepsIncrement: number)
	print("[Steps] StepActivated recibido:", stepsIncrement)
	refreshColors()
end)

-- Intentar comprar un step saltándose los anteriores. Anti-spam: los botones se
-- pisan por contacto y el server puede reenviar el fallo varias veces seguidas.
local lastErrorTime = 0
Packets.StepActivateFailed.OnClientEvent:Connect(function(message: string)
	local now = os.clock()
	if now - lastErrorTime < 2 then return end
	lastErrorTime = now
	AlertsModule.ShowAlertGui("Error", message)
end)
