--!strict

-- Receptor de los Weather Events. Lo corren TODOS los jugadores (no solo admins):
-- escucha Packets.WeatherState y aplica/quita el ambiente. El disparo vive en el
-- panel Admin; acá solo se recibe y se pinta.
--
-- Qué toca:
--   · Lighting (Ambient, Brightness, ClockTime, Fog...) y sus hijos ya existentes en
--     el .rbxl: Atmosphere, ColorCorrection, Bloom, Sky. Se tweenean ESAS instancias
--     y se restauran desde un snapshot tomado al arrancar, antes de tocar nada.
--   · Un Part invisible parented a la Camera con el ParticleEmitter, reposicionado
--     cada frame para que la precipitación siga al jugador por todo el mapa.
--   · El TextLabel Bot.Content."Current Event", que existe en el .rbxl y sin evento
--     va vacío.
--
-- NO toca el BlurEffect "DialogueBlur": ese es de MenuManager/MenuAnimations. Si el
-- weather lo tocara, abrir un menú durante un evento pelearía por la misma propiedad.
--
-- El contador `generation` invalida la transición/loops anteriores cuando llega un
-- estado nuevo a mitad de tween (mismo patrón que AdminAbuse/client).

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")
local Workspace         = game:GetService("Workspace")

local WeatherConfig = require(ReplicatedStorage.Shared.WeatherConfig)
local Packets       = require(ReplicatedStorage.Shared.Packets)

local player = Players.LocalPlayer

local TWEEN_INFO = TweenInfo.new(
	WeatherConfig.TransitionSeconds,
	Enum.EasingStyle.Sine,
	Enum.EasingDirection.Out
)

-- Flash del rayo: subida casi instantánea y bajada un poco más lenta, para que
-- parezca un relámpago y no un parpadeo de monitor.
local FLASH_IN  = TweenInfo.new(0.04, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FLASH_OUT = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FLASH_BRIGHTNESS = 0.85

-- ── Instancias de Lighting ───────────────────────────────────────────────────
-- Todas existen en el .rbxl (con los nombres Atmosphere / ColorCorrection / Bloom /
-- Sky). Se buscan por CLASE, no por nombre, para no romperse si alguien las renombra
-- en Studio. OJO con los nombres de clase: el efecto llamado "ColorCorrection" es de
-- clase `ColorCorrectionEffect`.
--
-- Este bloque tiene que ir ANTES de crear el flashEffect de más abajo: si no,
-- FindFirstChildOfClass("ColorCorrectionEffect") podría devolver el nuestro en vez
-- del de la escena.

local atmosphere      = Lighting:FindFirstChildOfClass("Atmosphere")
local colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
local bloom           = Lighting:FindFirstChildOfClass("BloomEffect")
local sky             = Lighting:FindFirstChildOfClass("Sky")

-- ColorCorrection propio SOLO para los flashes de rayo. Va aparte del de la escena
-- para que el flash no pelee con el tween del weather sobre la misma propiedad.
local flashEffect = Instance.new("ColorCorrectionEffect")
flashEffect.Name = "WeatherFlash"
flashEffect.Brightness = 0
flashEffect.Contrast = 0
flashEffect.Saturation = 0
flashEffect.TintColor = Color3.fromRGB(255, 255, 255)
flashEffect.Enabled = false
flashEffect.Parent = Lighting

-- ── Snapshot del estado original ─────────────────────────────────────────────
-- Se toma UNA vez, al arrancar y antes de aplicar nada. Es lo que se restaura al
-- quitar el evento, así el mapa vuelve exactamente a como lo dejó el diseñador.

local function snapshot(instance: Instance?, props: { string }): { [string]: any }?
	if not instance then return nil end
	local saved = {}
	for _, prop in props do
		saved[prop] = (instance :: any)[prop]
	end
	return saved
end

local LIGHTING_PROPS   = { "Ambient", "OutdoorAmbient", "Brightness", "ClockTime", "FogColor", "FogStart", "FogEnd" }
local ATMOSPHERE_PROPS = { "Density", "Offset", "Color", "Decay", "Glare", "Haze" }
local CC_PROPS         = { "Brightness", "Contrast", "Saturation", "TintColor" }
local BLOOM_PROPS      = { "Intensity", "Size", "Threshold" }
local SKY_PROPS        = { "SkyboxUp", "SkyboxDn", "SkyboxLf", "SkyboxRt", "SkyboxFt", "SkyboxBk" }

local baseLighting   = snapshot(Lighting, LIGHTING_PROPS)
local baseAtmosphere = snapshot(atmosphere, ATMOSPHERE_PROPS)
local baseColorCorr  = snapshot(colorCorrection, CC_PROPS)
local baseBloom      = snapshot(bloom, BLOOM_PROPS)
local baseSky        = snapshot(sky, SKY_PROPS)

-- ── Tweens ───────────────────────────────────────────────────────────────────

local activeTweens: { Tween } = {}

local function cancelTweens()
	for _, tween in activeTweens do
		tween:Cancel()
	end
	table.clear(activeTweens)
end

local function tweenTo(instance: Instance?, goal: { [string]: any }?)
	if not instance or not goal then return end
	local tween = TweenService:Create(instance, TWEEN_INFO, goal)
	table.insert(activeTweens, tween)
	tween:Play()
end

local function applySkybox(spec: WeatherConfig.SkyboxSpec?)
	if not sky then return end

	if spec then
		sky.SkyboxUp = spec.Up
		sky.SkyboxDn = spec.Dn
		sky.SkyboxLf = spec.Lf
		sky.SkyboxRt = spec.Rt
		sky.SkyboxFt = spec.Ft
		sky.SkyboxBk = spec.Bk
	elseif baseSky then
		for prop, value in baseSky do
			(sky :: any)[prop] = value
		end
	end
end

-- ── Partículas ───────────────────────────────────────────────────────────────
-- El Part vive dentro de la Camera: así es puramente local (no se replica, no
-- estorba a nadie más) y desaparece solo si algo lo destruye.

local particlePart: Part? = nil
local particleConn: RBXScriptConnection? = nil

local function destroyParticles(fadeSeconds: number)
	if particleConn then
		particleConn:Disconnect()
		particleConn = nil
	end

	local part = particlePart
	particlePart = nil
	if not part then return end

	-- Se apaga la emisión y se destruye DESPUÉS de que muera la última partícula:
	-- destruirlo de golpe haría desaparecer la lluvia en un frame.
	local emitter = part:FindFirstChildOfClass("ParticleEmitter")
	if emitter then
		emitter.Enabled = false
	end
	task.delay(fadeSeconds, function()
		part:Destroy()
	end)
end

local function createParticles(spec: WeatherConfig.ParticleSpec)
	local camera = Workspace.CurrentCamera
	if not camera then return end

	local part = Instance.new("Part")
	part.Name = "WeatherEmitter"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Locked = true
	part.CastShadow = false
	part.Size = spec.EmitBoxSize
	part.CFrame = CFrame.new(camera.CFrame.Position + spec.EmitOffset)
	part.Parent = camera

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = spec.Texture
	emitter.Color = spec.Color
	emitter.Size = spec.Size
	emitter.Transparency = spec.Transparency
	emitter.Rate = spec.Rate
	emitter.Lifetime = spec.Lifetime
	emitter.Speed = spec.Speed
	emitter.SpreadAngle = spec.SpreadAngle
	emitter.Acceleration = spec.Acceleration
	emitter.Rotation = spec.Rotation
	emitter.RotSpeed = spec.RotSpeed
	emitter.LightEmission = spec.LightEmission
	emitter.LightInfluence = spec.LightInfluence
	emitter.Drag = spec.Drag
	emitter.ZOffset = spec.ZOffset
	emitter.EmissionDirection = spec.EmissionDirection
	if spec.Squash then
		emitter.Squash = spec.Squash
	end
	emitter.Parent = part

	particlePart = part

	-- El emisor persigue a la cámara: sin esto, la precipitación se quedaría en el
	-- punto donde estabas al activarse el evento.
	particleConn = RunService.RenderStepped:Connect(function()
		local cam = Workspace.CurrentCamera
		if not cam then return end
		-- Roblox reemplaza la Camera en algunos casos (reset, cambios de CameraType):
		-- si pasó, el Part quedó huérfano y hay que re-adoptarlo o las partículas
		-- desaparecen sin más.
		if part.Parent ~= cam then
			part.Parent = cam
		end
		-- Solo la posición: si copiáramos la rotación, la caja de emisión giraría
		-- con la cámara y la lluvia dejaría de caer recta.
		part.CFrame = CFrame.new(cam.CFrame.Position + spec.EmitOffset)
	end)
end

-- ── Label "Current Event" ────────────────────────────────────────────────────
-- Vive en el .rbxl (Bot.Content."Current Event"), con un UIGradient y un UIStroke
-- ya puestos. Se resuelve de forma defensiva: si el GUI Bot no está, el resto del
-- weather funciona igual.

local eventLabel: TextLabel? = nil
local eventGradient: UIGradient? = nil
local baseGradientColor: ColorSequence? = nil

task.spawn(function()
	local playerGui = player:WaitForChild("PlayerGui")
	local bot = playerGui:WaitForChild("Bot", 30)
	if not bot then return end
	local content = bot:WaitForChild("Content", 10)
	if not content then return end
	local label = content:WaitForChild("Current Event", 10)
	if not (label and label:IsA("TextLabel")) then return end

	eventLabel = label
	eventGradient = label:FindFirstChildOfClass("UIGradient")
	if eventGradient then
		baseGradientColor = eventGradient.Color
	end
end)

local function setEventLabel(preset: WeatherConfig.Preset?)
	local label = eventLabel
	if not label then return end

	if not preset then
		label.Text = ""
		if eventGradient and baseGradientColor then
			eventGradient.Color = baseGradientColor
		end
		return
	end

	label.Text = string.format(
		"%s  •  x%s SPEED  •  x%s WINS",
		preset.DisplayName,
		tostring(preset.Multiplier),
		tostring(preset.WinsMultiplier)
	)
	label.TextColor3 = preset.UIColor
	-- El UIGradient tiñe también al UIStroke hermano (misma trampa documentada en
	-- AdminAbuse/client). Acá es deseable: refuerza el color del weather.
	if eventGradient then
		eventGradient.Color = preset.Gradient
	end
end

-- ── Rayos ────────────────────────────────────────────────────────────────────

local function startLightning(isCurrent: () -> boolean)
	task.spawn(function()
		local interval = WeatherConfig.LightningInterval
		while isCurrent() do
			task.wait(interval.Min + math.random() * (interval.Max - interval.Min))
			if not isCurrent() then break end

			flashEffect.Enabled = true
			-- Doble destello: el segundo, más flojo, es lo que lo hace parecer un
			-- relámpago de verdad y no un simple fundido a blanco.
			for i = 1, 2 do
				local strength = if i == 1 then FLASH_BRIGHTNESS else FLASH_BRIGHTNESS * 0.55
				TweenService:Create(flashEffect, FLASH_IN, { Brightness = strength }):Play()
				task.wait(0.06)
				TweenService:Create(flashEffect, FLASH_OUT, { Brightness = 0 }):Play()
				task.wait(0.12)
			end
			task.wait(0.4)
			-- Se apaga SIEMPRE, aunque el weather ya haya cambiado a mitad del
			-- destello: si saliéramos del loop antes de esto, el efecto quedaría
			-- encendido pisando al weather nuevo. La salida la decide el `while`.
			flashEffect.Brightness = 0
			flashEffect.Enabled = false
		end
	end)
end

-- ── Aplicar / quitar ─────────────────────────────────────────────────────────

local generation = 0

-- Aplica un weather, o lo quita si preset == nil.
local function apply(preset: WeatherConfig.Preset?)
	generation += 1
	local myGen = generation
	local function isCurrent(): boolean
		return myGen == generation
	end

	cancelTweens()

	-- Las partículas viejas se desvanecen mientras entran las nuevas: sin esto, al
	-- encadenar dos weathers se vería un salto seco.
	destroyParticles(2)

	flashEffect.Enabled = false
	flashEffect.Brightness = 0

	setEventLabel(preset)

	if preset then
		local spec = preset.Lighting
		tweenTo(Lighting, {
			Ambient = spec.Ambient,
			OutdoorAmbient = spec.OutdoorAmbient,
			Brightness = spec.Brightness,
			ClockTime = spec.ClockTime,
			FogColor = spec.FogColor,
			FogStart = spec.FogStart,
			FogEnd = spec.FogEnd,
		})
		tweenTo(atmosphere, spec.Atmosphere)
		tweenTo(colorCorrection, spec.ColorCorrection)
		tweenTo(bloom, spec.Bloom)

		createParticles(preset.Particle)

		if preset.Lightning then
			startLightning(isCurrent)
		end
	else
		tweenTo(Lighting, baseLighting)
		tweenTo(atmosphere, baseAtmosphere)
		tweenTo(colorCorrection, baseColorCorr)
		tweenTo(bloom, baseBloom)
	end

	-- El skybox no se puede tweenear (son texturas): se cambia a mitad de la
	-- transición, cuando el fog y la atmósfera ya taparon el cielo y el corte no
	-- se nota.
	task.delay(WeatherConfig.TransitionSeconds / 2, function()
		if not isCurrent() then return end
		applySkybox(if preset then preset.Skybox else nil)
	end)
end

Packets.WeatherState.OnClientEvent:Connect(function(active: boolean, weatherId: string)
	if type(active) ~= "boolean" or type(weatherId) ~= "string" then return end

	if not active then
		apply(nil)
		return
	end

	local preset = WeatherConfig.byId[weatherId]
	if not preset then return end

	apply(preset)
end)
