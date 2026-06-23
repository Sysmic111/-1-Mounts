--!strict
local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packets      = require(ReplicatedStorage.Shared.Packets)
local DataService  = require(ReplicatedStorage.Packages.DataService).client
local FormatNumber = require(ReplicatedStorage.Packages.FormatNumber)

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

local function initButton(instance: Instance): ()
	local model = instance :: Model
	local inc   = model:GetAttribute("StepsIncresement") :: number?
	local wins  = model:GetAttribute("WinsQuantity")     :: number?
	local tp = model:WaitForChild("TouchPart", 10) :: BasePart?
	print("[Steps] initButton:", model.Name, "| inc:", inc, "| wins:", wins, "| tp:", tp ~= nil)
	if not inc or not wins or not tp then
		print("[Steps] initButton: atributo faltante, abortando")
		return
	end

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

-- Inicializar botones ya presentes y los que aparezcan (streaming)
print("[Steps] Tagged StepButton count:", #CollectionService:GetTagged("StepButton"))
for _, instance in CollectionService:GetTagged("StepButton") do
	task.spawn(initButton, instance)
end
CollectionService:GetInstanceAddedSignal("StepButton"):Connect(function(instance)
	print("[Steps] GetInstanceAddedSignal:", instance.Name)
	task.spawn(initButton, instance)
end)

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
