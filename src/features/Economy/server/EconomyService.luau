--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local EconomyConfig = require(ReplicatedStorage.Shared.EconomyConfig)
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

	local seeded = 0
	for _, stage in stagesFolder:GetChildren() do
		local stageNum = getStageNumber(stage.Name)
		local baseWins = EconomyConfig.StageWins[stageNum]
		-- El Stage 1 es el spawn y no tiene botones: no está en la tabla.
		if not baseWins then continue end

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

	print(`[Economy] Botones de Wins sembrados: {seeded}`)
end

function EconomyService:_seedSteps(): ()
	local stepsFolder = Workspace:FindFirstChild("StepsButtons")
	if not stepsFolder then
		warn("[Economy] No se encontró Workspace.StepsButtons")
		return
	end

	local seeded = 0
	for _, child in stepsFolder:GetChildren() do
		if child.ClassName ~= "Model" or child.Name ~= STEPS_BUTTON_NAME then continue end

		local inc = child:GetAttribute("StepsIncresement") :: number?
		if not inc then continue end

		local price = EconomyConfig.StepPrices[inc]
		if not price then
			warn(`[Economy] Step button x{inc} sin precio en EconomyConfig.StepPrices`)
			continue
		end

		child:SetAttribute(WinsConfig.WinsQuantityAttribute, price)
		seeded += 1
	end

	print(`[Economy] Steps buttons sembrados: {seeded}`)
end

function EconomyService:seedWorkspace(): ()
	self:_seedStages()
	self:_seedSteps()
end

return EconomyService
