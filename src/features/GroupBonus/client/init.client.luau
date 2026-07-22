--!strict

-- Abre el menú GroupRewards por proximidad al cofre Workspace.GroupChest y gestiona
-- el botón Verify. El cofre y el frame viven en el .rbxl (no en Rojo): se referencian
-- por nombre en runtime.
--
-- Cierre: por proximidad (el frame no tiene botón Close). Se abre al acercarse y se
-- cierra al alejarse, usando MenuManager para no apilarse con otros menús.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local GroupService      = game:GetService("GroupService")

local MenuManager      = require(ReplicatedStorage.Shared.MenuManager)
local Packets          = require(ReplicatedStorage.Shared.Packets)
local GroupBonusConfig = require(ReplicatedStorage.Shared.GroupBonusConfig)
local AlertsModule     = require(ReplicatedStorage.Packages.AlertsModule)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local menus     = playerGui:WaitForChild("Menus")
local menu      = menus:WaitForChild("GroupRewards") :: Frame
local verifyBtn = menu:WaitForChild("Verify")        :: ImageButton

-- Margen extra sobre el radio del cofre para el "topar".
local TOUCH_MARGIN = 6

local function populate()
	local speedBoost = menu:FindFirstChild("SpeedBoost") :: TextLabel?
	if speedBoost then
		speedBoost.Text = "Speed Boost: x" .. tostring(GroupBonusConfig.Multiplier)
	end
end

-- ── Botón Verify ──────────────────────────────────────────────────────────────

verifyBtn.MouseButton1Click:Connect(function()
	Packets.VerifyGroupBonus:Fire()
end)

Packets.GroupBonusResult.OnClientEvent:Connect(function(status: string)
	if status == "NotInGroup" then
		-- Prompt nativo para unirse al grupo (yields → en su propio hilo, con pcall).
		task.spawn(function()
			pcall(function()
				GroupService:PromptJoinAsync(GroupBonusConfig.GroupId)
			end)
		end)
	elseif status == "NeedLikeRejoin" then
		AlertsModule.ShowAlertGui("Error", "Like the game and rejoin to claim")
	end
	-- "Granted" y "AlreadyClaimed" no muestran notificación: el bonus ya se aplica
	-- (TotalMultiplier se replica) y el cierre del menú es por proximidad.
end)

-- ── Apertura/cierre por proximidad ──────────────────────────────────────────────

-- Resuelve el cofre y su PrimaryPart tolerando streaming (pueden no existir aún o
-- descargarse). Cachea mientras sigan válidos.
local chest: Model? = nil
local chestPart: BasePart? = nil

local function resolveChest(): BasePart?
	if chestPart and chestPart:IsDescendantOf(Workspace) then
		return chestPart
	end
	chestPart = nil
	if not (chest and chest:IsDescendantOf(Workspace)) then
		chest = Workspace:FindFirstChild("GroupChest") :: Model?
	end
	if chest then
		chestPart = chest.PrimaryPart
	end
	return chestPart
end

local wasInRange = false

RunService.Heartbeat:Connect(function()
	local part = resolveChest()
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not part or not rootPart then
		wasInRange = false
		return
	end

	local radius = part.Size.Magnitude / 2 + TOUCH_MARGIN
	local inRange = (rootPart.Position - part.Position).Magnitude <= radius

	if inRange and not wasInRange then
		-- Entra al radio: abrir solo si no hay otro menú abierto (no arrancar al jugador
		-- de otro menú que haya abierto a mano).
		if not MenuManager.isAnyOpen() then
			MenuManager.open(menu, { onOpen = populate })
		end
	elseif not inRange and wasInRange then
		-- Sale del radio: cerrar solo si el que está abierto es el nuestro.
		if MenuManager.isOpen(menu) then
			MenuManager.close(menu)
		end
	end

	wasInRange = inRange
end)
