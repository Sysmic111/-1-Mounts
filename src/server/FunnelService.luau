--!strict

local AnalyticsService  = game:GetService("AnalyticsService")
local HttpService        = game:GetService("HttpService")
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local AnalyticsConfig = require(ReplicatedStorage.Shared.AnalyticsConfig)
local EconomyConfig   = require(ReplicatedStorage.Shared.EconomyConfig)
local MountsConfig    = require(ReplicatedStorage.Shared.MountsConfig)
local Packets         = require(ReplicatedStorage.Shared.Packets)
local RebirthConfig   = require(ReplicatedStorage.Shared.RebirthConfig)
local WorldsConfig    = require(ReplicatedStorage.Shared.WorldsConfig)

type DataServiceServer = {
	waitForData: (self: DataServiceServer, player: Player) -> any,
	hasProfile: (self: DataServiceServer, player: Player) -> boolean,
	getProfile: (self: DataServiceServer, player: Player) -> any,
	get: (self: DataServiceServer, player: Player, path: any?) -> any,
	set: (self: DataServiceServer, player: Player, path: any, value: any, dontReplicate: boolean?) -> (),
}

type CheckoutState = {
	ProductId: number,
	SessionId: string,
	OfferId: string,
	Step: number,
	ReceiptPending: boolean,
}

type ClientRateState = {
	Tokens: number,
	LastUpdate: number,
}

local checkoutSteps: { [string]: number } = {
	OfferShown = 1,
	OfferSelected = 2,
	PromptOpened = 3,
	PurchaseConfirmed = 4,
}

-- La cadena de steps de TODOS los mundos, en orden de progresión: el índice del
-- funnel es monótono entre places (el índice 13 es el primer step de World 2).
local stepIncrements: { number } = EconomyConfig.getStepChain()

local FunnelService = {
	_dataService = nil :: DataServiceServer?,
	_sent = {} :: { [Player]: { [string]: boolean } },
	_checkouts = {} :: { [Player]: { [number]: CheckoutState } },
	_clientRates = {} :: { [Player]: ClientRateState },
	-- De sesión a propósito: el cliente re-entra al paso 3 del tutorial al reconectar
	-- y vuelve a reportarlo. Lo que persiste es AnalyticsTutorialStep.
	_tutorialMenuOpened = {} :: { [Player]: boolean },
}

local CLIENT_BURST_TOKENS = 12
local CLIENT_TOKENS_PER_SECOND = 0.2

local function fields(cohort: string, category: string, variant: string): { [string]: string }
	return {
		[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = cohort,
		[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = category,
		[Enum.AnalyticsCustomFieldKeys.CustomField03.Name] = variant,
	}
end

local function stableSession(player: Player, suffix: string): string
	return tostring(player.UserId) .. ":" .. suffix
end

function FunnelService:_markOnce(player: Player, key: string): boolean
	local sent = self._sent[player]
	if not sent then
		sent = {}
		self._sent[player] = sent
	end
	if sent[key] then return false end
	sent[key] = true
	return true
end

function FunnelService:_consumeClientToken(player: Player): boolean
	local now = os.clock()
	local state = self._clientRates[player]
	if not state then
		state = { Tokens = CLIENT_BURST_TOKENS, LastUpdate = now }
		self._clientRates[player] = state
	end

	local elapsed = math.max(0, now - state.LastUpdate)
	state.Tokens = math.min(CLIENT_BURST_TOKENS, state.Tokens + elapsed * CLIENT_TOKENS_PER_SECOND)
	state.LastUpdate = now
	if state.Tokens < 1 then return false end
	state.Tokens -= 1
	return true
end

function FunnelService:_log(
	player: Player,
	funnelName: string,
	sessionId: string,
	step: number,
	stepName: string,
	customFields: { [string]: string }?
): boolean
	local key = funnelName .. ":" .. sessionId .. ":" .. tostring(step)
	if not self:_markOnce(player, key) then return true end

	local ok, err = pcall(function()
		AnalyticsService:LogFunnelStepEvent(player, funnelName, sessionId, step, stepName, customFields)
	end)
	if not ok then
		local sent = self._sent[player]
		if sent then sent[key] = nil end
		warn("[Analytics] Funnel event failed:", funnelName, stepName, err)
	end
	return ok
end

function FunnelService:_logOnboarding(player: Player, step: number, stepName: string, customFields: { [string]: string }?): boolean
	local key = AnalyticsConfig.Funnels.Onboarding .. ":" .. tostring(step)
	if not self:_markOnce(player, key) then return true end

	local ok, err = pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName, customFields)
	end)
	if not ok then
		local sent = self._sent[player]
		if sent then sent[key] = nil end
		warn("[Analytics] Onboarding event failed:", stepName, err)
	end
	return ok
end

function FunnelService:_cohort(player: Player): string
	local ds = self._dataService
	if not ds or not ds:hasProfile(player) then return "Unknown" end
	local cohort = (ds:get(player, { "AnalyticsCohort" }) or "") :: string
	if cohort == "" then
		local profile = ds:getProfile(player)
		cohort = if profile.SessionLoadCount == 1 then "Fresh" else "Backfill"
		ds:set(player, { "AnalyticsCohort" }, cohort)
	end
	return cohort
end

function FunnelService:_logInitialProgress(player: Player, compactBackfill: boolean): ()
	local ds = self._dataService
	if not ds then return end
	local cohort = self:_cohort(player)

	local world = WorldsConfig.current()
	local stagesSession = stableSession(player, world.Key)
	self:_log(player, world.StagesFunnel, stagesSession, 1, world.Name .. " Entered", fields(cohort, "Progression", world.Key))

	local mountsSession = stableSession(player, "Mounts")
	self:_log(player, AnalyticsConfig.Funnels.Mounts, mountsSession, 1, "Chonk Owned", fields(cohort, "Progression", "World1Mounts"))
	local ownedMounts = (ds:get(player, { "Mounts" }) or {}) :: { [string]: boolean }
	local highestMount = 1
	for index = #MountsConfig.World1, 1, -1 do
		if ownedMounts[MountsConfig.World1[index].Name] then
			highestMount = index
			break
		end
	end
	if compactBackfill and highestMount > 1 then
		self:_log(player, AnalyticsConfig.Funnels.Mounts, mountsSession, highestMount, MountsConfig.World1[highestMount].Name .. " Owned", nil)
	end

	local rebirthSession = stableSession(player, "RebirthProgression")
	self:_log(player, AnalyticsConfig.Funnels.RebirthProgression, rebirthSession, 1, "Rebirth 0", fields(cohort, "Progression", "Rebirths"))
	local rebirth = math.clamp((ds:get(player, { "Rebirth" }) or 0) :: number, 0, #RebirthConfig)
	if compactBackfill and rebirth > 0 then
		self:_log(player, AnalyticsConfig.Funnels.RebirthProgression, rebirthSession, rebirth + 1, "Rebirth " .. tostring(rebirth), nil)
	end

	local stepsSession = stableSession(player, "Steps")
	self:_log(player, AnalyticsConfig.Funnels.Steps, stepsSession, 1, "Steps x1", fields(cohort, "Progression", "Steps"))
	local highestStepIndex = 1
	for index = #stepIncrements, 1, -1 do
		if ds:get(player, { "StepUnlocked_" .. tostring(stepIncrements[index]) }) == true then
			highestStepIndex = index
			break
		end
	end
	if compactBackfill and highestStepIndex > 1 then
		self:_log(player, AnalyticsConfig.Funnels.Steps, stepsSession, highestStepIndex, "Steps x" .. tostring(stepIncrements[highestStepIndex]), nil)
	end

	local dailySession = stableSession(player, "Daily")
	self:_log(player, AnalyticsConfig.Funnels.Daily, dailySession, 1, "Daily Available", fields(cohort, "Retention", "DailyLogin"))
	local claimedDay = math.clamp((ds:get(player, { "DailyClaimedDay" }) or 0) :: number, 0, 22)
	if compactBackfill and claimedDay > 0 then
		local name = if claimedDay == 22 then "Repeat Day 22" else "Day " .. tostring(claimedDay) .. " Claimed"
		self:_log(player, AnalyticsConfig.Funnels.Daily, dailySession, claimedDay + 1, name, nil)
		ds:set(player, { "AnalyticsDailyLoggedDay" }, claimedDay)
	end
end

function FunnelService:_advanceOnboarding(player: Player): ()
	local ds = self._dataService
	if not ds or not ds:hasProfile(player) or self:_cohort(player) ~= "Fresh" then return end

	local current = (ds:get(player, { "AnalyticsOnboardingStep" }) or 0) :: number
	local level = (ds:get(player, { "Level" }) or 1) :: number
	local rebirth = (ds:get(player, { "Rebirth" }) or 0) :: number
	local totalSpeed = (ds:get(player, { "TotalSpeedEarned" }) or 0) :: number
	local totalWins = (ds:get(player, { "TotalWinsEarned" }) or 0) :: number
	local ownedMounts = (ds:get(player, { "Mounts" }) or {}) :: { [string]: boolean }
	local evolved = false
	for index = 2, #MountsConfig.World1 do
		if ownedMounts[MountsConfig.World1[index].Name] then
			evolved = true
			break
		end
	end

	local requirements = {
		true,
		totalSpeed > 0,
		level >= 2 or rebirth > 0,
		totalWins > 0,
		level >= 5 or rebirth > 0 or evolved,
		evolved,
	}
	local names = { "Profile Loaded", "First Speed Earned", "Level 2 Reached", "First Win Earned", "Level 5 Reached", "First Evolve" }

	while current < #requirements and requirements[current + 1] do
		local nextStep = current + 1
		local customFields = if nextStep == 1 then fields("Fresh", "Onboarding", "World1") else nil
		if not self:_logOnboarding(player, nextStep, names[nextStep], customFields) then break end
		current = nextStep
		ds:set(player, { "AnalyticsOnboardingStep" }, current)
	end
end

-- Funnel del tutorial guiado (src/features/Tutorial/client): mide en qué paso se
-- abandona la secuencia que el jugador VE, no hitos sueltos de progresión (eso es
-- Onboarding). Los pasos son los mismos y en el mismo orden.
--
-- Solo cohorte "Fresh", igual que _advanceOnboarding: un veterano cumple las siete
-- condiciones el primer tick y meterlo aquí sería inventarse un tutorial completado
-- que nunca se le mostró.
local TUTORIAL_STEP_NAMES = {
	"Tutorial Started",
	"Level 5 Reached",
	"First Win Collected",
	"Evolve Menu Opened",
	"First Evolve",
	"Wins Collected",
	"Step Upgrade Bought",
}

-- Pasos que puede reportar el cliente. Hoy solo el 4: es el único que no sale de los
-- datos del perfil. Cualquier otro número que llegue por el packet se descarta.
local TUTORIAL_CLIENT_STEPS: { [number]: boolean } = { [4] = true }

-- Espejo de las constantes del cliente. El paso 2 lo gana el primer botón del
-- Stage 2 (1 win) y el 6 el del Stage 3 (3 más).
local TUTORIAL_MOUNT = "Moru"
local TUTORIAL_STEP_INCREMENT = 2
local TUTORIAL_WINS_FIRST = 1
local TUTORIAL_WINS_TOTAL = 4

function FunnelService:_advanceTutorial(player: Player): ()
	local ds = self._dataService
	if not ds or not ds:hasProfile(player) or self:_cohort(player) ~= "Fresh" then return end

	local current = (ds:get(player, { "AnalyticsTutorialStep" }) or 0) :: number
	if current >= #TUTORIAL_STEP_NAMES then return end

	local level = (ds:get(player, { "Level" }) or 1) :: number
	local totalWins = (ds:get(player, { "TotalWinsEarned" }) or 0) :: number
	local ownedMounts = (ds:get(player, { "Mounts" }) or {}) :: { [string]: boolean }
	local evolved = ownedMounts[TUTORIAL_MOUNT] == true
	local stepBought = ds:get(player, { "StepUnlocked_" .. tostring(TUTORIAL_STEP_INCREMENT) }) == true
	local menuOpened = (self._tutorialMenuOpened[player] == true) or evolved

	-- Los backstops (`or evolved`, `or stepBought`) no son decoración: el bucle es
	-- secuencial, así que un paso que se quede en false congela el funnel entero. El
	-- rebirth resetea Level, y el paso 4 depende de un packet que puede perderse —
	-- haber evolucionado demuestra las dos cosas de sobra.
	local requirements = {
		true,
		level >= 5 or evolved or stepBought,
		totalWins >= TUTORIAL_WINS_FIRST,
		menuOpened,
		evolved,
		totalWins >= TUTORIAL_WINS_TOTAL or stepBought,
		stepBought,
	}

	local session = stableSession(player, "Tutorial")
	while current < #requirements and requirements[current + 1] do
		local nextStep = current + 1
		local customFields = if nextStep == 1
			then fields("Fresh", "Tutorial", WorldsConfig.current().Key)
			else nil
		if not self:_log(player, AnalyticsConfig.Funnels.Tutorial, session, nextStep, TUTORIAL_STEP_NAMES[nextStep], customFields) then break end
		current = nextStep
		ds:set(player, { "AnalyticsTutorialStep" }, current)
	end
end

function FunnelService:_handleTutorialStep(player: Player, step: number): ()
	if type(step) ~= "number" or not TUTORIAL_CLIENT_STEPS[step] then return end
	if not self:_consumeClientToken(player) then return end
	self._tutorialMenuOpened[player] = true
	self:_advanceTutorial(player)
end

function FunnelService:_syncRebirthCycle(player: Player, compact: boolean): ()
	local ds = self._dataService
	if not ds or not ds:hasProfile(player) then return end
	local rebirth = (ds:get(player, { "Rebirth" }) or 0) :: number
	local nextData = RebirthConfig.getNextData(rebirth)
	if not nextData then return end

	local cycle = rebirth + 1
	local trackedCycle = (ds:get(player, { "AnalyticsRebirthCycle" }) or 0) :: number
	local trackedStep = (ds:get(player, { "AnalyticsRebirthCycleStep" }) or 0) :: number
	if trackedCycle ~= cycle then
		trackedCycle = cycle
		trackedStep = 0
		ds:set(player, { "AnalyticsRebirthCycle" }, cycle)
		ds:set(player, { "AnalyticsRebirthCycleStep" }, 0)
	end

	local session = stableSession(player, "RebirthCycle" .. tostring(cycle))
	if trackedStep == 0 then
		self:_log(player, AnalyticsConfig.Funnels.RebirthCycle, session, 1, "Cycle Started", fields(self:_cohort(player), "RebirthCycle", "R" .. tostring(cycle)))
		trackedStep = 1
		ds:set(player, { "AnalyticsRebirthCycleStep" }, trackedStep)
	end

	local level = (ds:get(player, { "Level" }) or 1) :: number
	local target = nextData.LevelRequired
	local thresholds = { math.ceil(target * 0.25), math.ceil(target * 0.5), math.ceil(target * 0.75), target }
	local highest = 1
	for index, threshold in thresholds do
		if level >= threshold then highest = index + 1 end
	end
	if highest <= trackedStep then return end

	local names = { "Cycle Started", "25% Level Reached", "50% Level Reached", "75% Level Reached", "Required Level Reached" }
	if compact then
		self:_log(player, AnalyticsConfig.Funnels.RebirthCycle, session, highest, names[highest], nil)
		trackedStep = highest
		ds:set(player, { "AnalyticsRebirthCycleStep" }, trackedStep)
		return
	end

	for step = trackedStep + 1, highest do
		if self:_log(player, AnalyticsConfig.Funnels.RebirthCycle, session, step, names[step], nil) then
			ds:set(player, { "AnalyticsRebirthCycleStep" }, step)
		else
			break
		end
	end
end

function FunnelService:_setupPlayer(player: Player): ()
	local ds = self._dataService
	if not ds then return end
	ds:waitForData(player)
	if not player:IsDescendantOf(Players) or not ds:hasProfile(player) then return end

	local cohort = (ds:get(player, { "AnalyticsCohort" }) or "") :: string
	if cohort == "" then
		local profile = ds:getProfile(player)
		cohort = if profile.SessionLoadCount == 1 then "Fresh" else "Backfill"
		ds:set(player, { "AnalyticsCohort" }, cohort)
	end

	local schemaVersion = (ds:get(player, { "AnalyticsSchemaVersion" }) or 0) :: number
	if schemaVersion < AnalyticsConfig.SchemaVersion then
		local backfillVersion = (ds:get(player, { "AnalyticsBackfillVersion" }) or 0) :: number
		local compact = cohort == "Backfill" and backfillVersion < AnalyticsConfig.SchemaVersion
		self:_logInitialProgress(player, compact)
		self:_syncRebirthCycle(player, compact)
		ds:set(player, { "AnalyticsSchemaVersion" }, AnalyticsConfig.SchemaVersion)
		if compact then
			ds:set(player, { "AnalyticsBackfillVersion" }, AnalyticsConfig.SchemaVersion)
		end
	else
		self:_syncRebirthCycle(player, false)
	end

	self:_advanceOnboarding(player)
	self:_advanceTutorial(player)
end

function FunnelService:init(dataService: DataServiceServer): ()
	self._dataService = dataService

	Players.PlayerAdded:Connect(function(player)
		task.spawn(function() self:_setupPlayer(player) end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self._sent[player] = nil
		self._checkouts[player] = nil
		self._clientRates[player] = nil
		self._tutorialMenuOpened[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(function() self:_setupPlayer(player) end)
	end

	Packets.AnalyticsCheckoutAction.OnServerEvent:Connect(function(player: Player, action: string, productId: number, sessionId: string, offerId: string)
		self:_handleCheckoutAction(player, action, productId, sessionId, offerId)
	end)

	Packets.TutorialFunnelStep.OnServerEvent:Connect(function(player: Player, step: number)
		self:_handleTutorialStep(player, step)
	end)
end

function FunnelService:onProgressChanged(player: Player): ()
	self:_advanceOnboarding(player)
	self:_advanceTutorial(player)
	self:_syncRebirthCycle(player, false)
end

-- Clave del progreso de stages EN ESTE MUNDO. World 1 conserva la clave histórica
-- para no invalidar los datos ya guardados ni los dashboards; los demás mundos
-- usan una clave con sufijo, creada on-demand igual que los StepUnlocked_<N>.
local function highestStageKey(world: WorldsConfig.WorldData): string
	if world.Key == "World1" then
		return "HighestStageReached"
	end
	return "HighestStageReached_" .. world.Key
end

function FunnelService:onStageReached(player: Player, stage: number): ()
	local ds = self._dataService
	if not ds or not ds:hasProfile(player) then return end

	-- El rango de stages sale del balance del mundo, no de un 2..14 literal: el
	-- literal seguiría "funcionando" hoy porque los dos mundos van del 2 al 14, y
	-- se volvería silenciosamente falso en cuanto un mundo tenga otro número.
	local world = WorldsConfig.current()
	if EconomyConfig.current().StageWins[stage] == nil then return end

	local key = highestStageKey(world)
	local highest = (ds:get(player, { key }) or 1) :: number
	if stage <= highest then return end
	ds:set(player, { key }, stage)

	-- El funnel es por mundo, y no es solo cosmético: _markOnce indexa por
	-- `funnel .. ":" .. step`, así que compartiendo nombre el "Stage 5 Reached" de
	-- World 2 se deduplicaría contra el de World 1 durante toda la sesión.
	self:_log(player, world.StagesFunnel, stableSession(player, world.Key), stage, "Stage " .. tostring(stage) .. " Reached", nil)
end

function FunnelService:onMountUnlocked(player: Player, mountName: string): ()
	for index, mount in MountsConfig.World1 do
		if mount.Name == mountName then
			self:_log(player, AnalyticsConfig.Funnels.Mounts, stableSession(player, "Mounts"), index, mountName .. " Owned", nil)
			self:_advanceOnboarding(player)
			self:_advanceTutorial(player)
			return
		end
	end
end

function FunnelService:onRebirthCompleted(player: Player, completedRebirth: number): ()
	local ds = self._dataService
	if not ds then return end
	self:_syncRebirthCycle(player, false)
	local cycleSession = stableSession(player, "RebirthCycle" .. tostring(completedRebirth))
	self:_log(player, AnalyticsConfig.Funnels.RebirthCycle, cycleSession, 6, "Rebirth Completed", nil)
	ds:set(player, { "AnalyticsRebirthCycleStep" }, 6)
	self:_log(player, AnalyticsConfig.Funnels.RebirthProgression, stableSession(player, "RebirthProgression"), completedRebirth + 1, "Rebirth " .. tostring(completedRebirth), nil)
end

function FunnelService:onRebirthStateChanged(player: Player): ()
	self:_advanceOnboarding(player)
	self:_syncRebirthCycle(player, false)
end

function FunnelService:onStepUnlocked(player: Player, increment: number): ()
	local index = table.find(stepIncrements, increment)
	if not index then return end
	self:_log(player, AnalyticsConfig.Funnels.Steps, stableSession(player, "Steps"), index, "Steps x" .. tostring(increment), nil)
	-- El x2 es el último paso del tutorial: cierra el funnel en el mismo acto.
	self:_advanceTutorial(player)
end

function FunnelService:onDailyClaimed(player: Player, day: number): ()
	if day < 1 or day > 22 then return end
	local ds = self._dataService
	if not ds or not ds:hasProfile(player) then return end
	local loggedDay = (ds:get(player, { "AnalyticsDailyLoggedDay" }) or 0) :: number
	if day <= loggedDay then return end
	local name = if day == 22 then "Repeat Day 22" else "Day " .. tostring(day) .. " Claimed"
	if self:_log(player, AnalyticsConfig.Funnels.Daily, stableSession(player, "Daily"), day + 1, name, nil) then
		ds:set(player, { "AnalyticsDailyLoggedDay" }, day)
	end
end

function FunnelService:_checkoutTable(player: Player): { [number]: CheckoutState }
	local checkouts = self._checkouts[player]
	if not checkouts then
		checkouts = {}
		self._checkouts[player] = checkouts
	end
	return checkouts
end

function FunnelService:_logCheckout(player: Player, state: CheckoutState, step: number, name: string): ()
	local product = AnalyticsConfig.getProduct(state.ProductId)
	if not product then return end
	local customFields = if step == 1 then fields(self:_cohort(player), product.Category, state.OfferId) else nil
	self:_log(player, AnalyticsConfig.Funnels.Checkout, state.SessionId, step, name, customFields)
end

function FunnelService:_handleCheckoutAction(player: Player, action: string, productId: number, sessionId: string, offerId: string): ()
	local ds = self._dataService
	if not ds or not ds:hasProfile(player) then return end
	if not self:_consumeClientToken(player) then return end
	if type(action) ~= "string" or type(productId) ~= "number" or type(sessionId) ~= "string" or type(offerId) ~= "string" then return end
	if #sessionId < 8 or #sessionId > 64 or #offerId < 1 or #offerId > 64 then return end
	if not AnalyticsConfig.isValidOffer(productId, offerId) then return end
	local step = checkoutSteps[action]
	if not step then return end

	local checkouts = self:_checkoutTable(player)
	local state = checkouts[productId]
	if step == 1 then
		state = { ProductId = productId, SessionId = sessionId, OfferId = offerId, Step = 0, ReceiptPending = false }
		checkouts[productId] = state
	elseif not state or state.SessionId ~= sessionId or state.OfferId ~= offerId then
		return
	end
	if not state or step ~= state.Step + 1 then return end

	local names = { "Offer Shown", "Offer Selected", "Prompt Opened", "Purchase Confirmed" }
	self:_logCheckout(player, state, step, names[step])
	state.Step = step
	if step == 4 and state.ReceiptPending then
		self:_logCheckout(player, state, 5, "Receipt Granted")
		checkouts[productId] = nil
	end
end

function FunnelService:beginServerCheckout(player: Player, productId: number, offerId: string): ()
	if not AnalyticsConfig.isValidOffer(productId, offerId) then return end
	local state: CheckoutState = {
		ProductId = productId,
		SessionId = HttpService:GenerateGUID(false),
		OfferId = offerId,
		Step = 0,
		ReceiptPending = false,
	}
	self:_checkoutTable(player)[productId] = state
	for step, name in { "Offer Shown", "Offer Selected", "Prompt Opened" } do
		self:_logCheckout(player, state, step, name)
		state.Step = step
	end
	Packets.AnalyticsCheckoutSession:FireClient(player, productId, state.SessionId, offerId)
end

function FunnelService:onReceiptGranted(player: Player, productId: number): ()
	local checkouts = self:_checkoutTable(player)
	local state = checkouts[productId]
	if not state then return end
	if state.Step >= 4 then
		self:_logCheckout(player, state, 5, "Receipt Granted")
		checkouts[productId] = nil
	else
		state.ReceiptPending = true
	end
end

return FunnelService
