--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local EconomyConfig = require(ReplicatedStorage.Shared.EconomyConfig)
local WorldsConfig  = require(ReplicatedStorage.Shared.WorldsConfig)
local WinsConfig    = require(game.ServerScriptService.Wins.WinsConfig)

-- Siembra en Workspace los valores económicos definidos en EconomyConfig.
--
-- IMPORTANTE: seedWorkspace() debe correr ANTES de WinsService:init y de
-- StepsService:init. Los dos leen estos atributos una sola vez al arrancar y no
-- vuelven a escanear:
--   · StepsService.buildStepsMap cachea los precios en _stepsMap → sembrar
--     después dejaría los precios viejos y cobraría mal las compras.
--   · WinsService:_setupWinZone escribe el cartel del botón con el valor que lee
--     al arrancar → sembrar después dejaría los carteles desactualizados.
--
-- MULTI-PLACE: los valores salen del bloque del MUNDO DE ESTE PLACE. Los dos
-- places tienen los mismos nombres de stage, así que sembrar el mundo equivocado
-- no da error en ningún sitio: simplemente pagaría tarifas de World 1 en World 2
-- (×341 de diferencia en la frontera). De ahí los warnings de cobertura.
-- El contrato de orden no cambia: WorldsConfig resuelve en el require, sin esperas.
local EconomyService = {}

local WINS_BUTTON_NAME    = "Wins"
local PREMIUM_BUTTON_NAME = "WinsPremium"
local STEPS_BUTTON_NAME   = "Steps"

local function getStageNumber(stageName: string): number
	return tonumber(stageName:match("%d+")) or 0
end

function EconomyService:_seedStages(): ()
	local stagesFolder = Workspace:FindFirstChild("Stages")
	if not stagesFolder then
		warn("[Economy] No se encontró Workspace.Stages")
		return
	end

	local stageWins = EconomyConfig.current().StageWins

	local seeded = 0
	local found: { [number]: boolean } = {}

	for _, stage in stagesFolder:GetChildren() do
		local stageNum = getStageNumber(stage.Name)
		-- El Stage 1 es el spawn y no tiene botones: no está en la tabla.
		if stageNum < 2 then continue end

		local baseWins = stageWins[stageNum]
		if not baseWins then
			-- Antes esto era un `continue` mudo, y el stage se quedaba con lo que
			-- hubiera puesto a mano en el .rbxl. Con dos mundos eso es justo el
			-- síntoma de estar sembrando el mundo equivocado, así que hace ruido.
			warn(`[Economy] {stage.Name} existe en Workspace pero no está en el balance de este mundo`)
			continue
		end
		found[stageNum] = true

		local normal = stage:FindFirstChild(WINS_BUTTON_NAME)
		if normal then
			normal:SetAttribute(WinsConfig.WinsQuantityAttribute, baseWins)
			seeded += 1
		end

		local premium = stage:FindFirstChild(PREMIUM_BUTTON_NAME)
		if premium then
			premium:SetAttribute(
				WinsConfig.WinsQuantityAttribute,
				baseWins * EconomyConfig.PremiumWinsFactor
			)
			seeded += 1
		end
	end

	-- La otra mitad de la comprobación: balance sin geometría que lo reciba.
	for stageNum in stageWins do
		if not found[stageNum] then
			warn(`[Economy] El balance define el stage {stageNum} pero no existe en Workspace.Stages`)
		end
	end

	print(`[Economy] Botones de Wins sembrados: {seeded}`)
end

-- Los steps buttons son doce Models con el MISMO nombre en una sola carpeta, así
-- que para sembrarlos hay que ordenarlos por su sitio en el mundo: el orden de
-- GetChildren() es el de inserción en el .rbxl y no tiene nada que ver con cómo
-- están colocados.
--
-- El criterio es el de la disposición real: DE ABAJO ARRIBA (Y), y dentro de cada
-- fila DE IZQUIERDA A DERECHA (X); Z desempata por si una fila se parte en dos.
-- En World 1 eso reproduce exactamente la asignación que ya había a mano
-- (1,2,4,8,16,32 en la fila baja y 64..2000 en la alta).
--
-- Se comparan con tolerancia porque dos botones de la misma fila no tienen la Y
-- bit a bit idéntica y el orden dentro de la fila quedaría al azar.
local POSITION_EPSILON = 0.5

local function comparePosition(a: Model, b: Model): boolean
	local pa = a:GetPivot().Position
	local pb = b:GetPivot().Position

	if math.abs(pa.Y - pb.Y) > POSITION_EPSILON then return pa.Y < pb.Y end
	if math.abs(pa.Z - pb.Z) > POSITION_EPSILON then return pa.Z < pb.Z end
	return pa.X < pb.X
end

function EconomyService:_seedSteps(): ()
	local stepsFolder = Workspace:FindFirstChild("StepsButtons")
	if not stepsFolder then
		warn("[Economy] No se encontró Workspace.StepsButtons")
		return
	end

	local steps = EconomyConfig.current().Steps

	local buttons: { Model } = {}
	for _, child in stepsFolder:GetChildren() do
		if child.ClassName ~= "Model" or child.Name ~= STEPS_BUTTON_NAME then continue end
		table.insert(buttons, child :: Model)
	end

	table.sort(buttons, comparePosition)

	-- Un desajuste de cuenta significa que el .rbxl y el balance no hablan del
	-- mismo mundo, o que falta/sobra un botón. Se siembra lo que se pueda, en orden.
	if #buttons ~= #steps then
		warn(`[Economy] Hay {#buttons} steps buttons en Workspace y {#steps} en el balance de este mundo`)
	end

	local seeded = 0
	for index, entry in steps do
		local button = buttons[index]
		if not button then break end

		-- Se siembra TAMBIÉN el StepsIncresement, no solo el precio: así el balance
		-- entero de los steps se versiona en git y un place nuevo no necesita que
		-- nadie toque atributos a mano. Los carteles no hay que tocarlos — el cliente
		-- los escribe desde estos dos atributos ("+N/Steps" y "<n> Wins Required").
		button:SetAttribute("StepsIncresement", entry.Increment)
		button:SetAttribute(WinsConfig.WinsQuantityAttribute, entry.Price)
		seeded += 1
	end

	print(`[Economy] Steps buttons sembrados: {seeded}`)
end

function EconomyService:seedWorkspace(): ()
	-- El mundo PRIMERO: un place mal sincronizado o sin fila en WorldsConfig se
	-- diagnostica con una sola línea de consola.
	local world = WorldsConfig.current()
	print(`[Economy] Mundo: {world.Name} (PlaceId {game.PlaceId})`)

	self:_seedStages()
	self:_seedSteps()
end

return EconomyService
