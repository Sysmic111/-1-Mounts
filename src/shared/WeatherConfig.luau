--!strict

-- Presets de los Weather Events (eventos globales que dispara un admin desde el panel).
-- Config-driven como AdminAbuseConfig: agregar un weather nuevo es agregar una entrada
-- acá, sin tocar el UI ni el server.
--
-- El cliente admin manda SOLO el Id; el servidor resuelve multiplicadores y visuales
-- desde este módulo, así que un cliente modificado no puede inventarse un x9999.
--
-- Multiplicadores: OJO, son dos números distintos a propósito.
--   Multiplier     -> Speed. Entra ADITIVO en TotalMultiplier (+(m-1) sobre la base),
--                     como todas las demás fuentes (ver AGENTS.md). Un x10 aditivo se
--                     nota muchísimo al principio y poco en late-game, que es justo el
--                     comportamiento que queremos de un evento: emocionante para todos
--                     sin romper la curva del que ya va lejos.
--   WinsMultiplier -> Wins. Ahí sí MULTIPLICA de verdad (es como funciona el rebirth en
--                     WinsService:_creditWins). Por eso va mucho más contenido: los Wins
--                     son el sink más grande del juego (la cadena de evolves) y un x10
--                     multiplicativo se lo comería entero.
--
-- Skybox: nil = no se cambia el skybox, solo se tiñe el cielo actual con
-- Atmosphere/ColorCorrection/ClockTime (que ya da un cambiazo enorme). Cuando haya
-- assets propios, poner acá las 6 caras y el cliente hace el swap solo, a mitad de
-- la transición (cuando el fog ya tapa el cielo) — misma convención de placeholders
-- que MountsConfig.

export type ParticleSpec = {
	Texture: string,
	Color: ColorSequence,
	Size: NumberSequence,
	Transparency: NumberSequence,
	Rate: number,
	Lifetime: NumberRange,
	Speed: NumberRange,
	SpreadAngle: Vector2,
	Acceleration: Vector3,
	Rotation: NumberRange,
	RotSpeed: NumberRange,
	LightEmission: number,
	LightInfluence: number,
	Drag: number,
	ZOffset: number,
	Squash: NumberSequence?,
	-- Caja de emisión (el Part invisible que sigue a la cámara) y su desplazamiento
	-- respecto de ella: la lluvia/nieve se emite desde un plano MUY por encima, la
	-- ceniza y las motas desde un cubo que envuelve al jugador.
	EmitBoxSize: Vector3,
	EmitOffset: Vector3,
	EmissionDirection: Enum.NormalId,
}

export type SkyboxSpec = {
	Up: string, Dn: string, Lf: string, Rt: string, Ft: string, Bk: string,
}

export type AtmosphereSpec = {
	Density: number,
	Offset: number,
	Color: Color3,
	Decay: Color3,
	Glare: number,
	Haze: number,
}

export type ColorCorrectionSpec = {
	Brightness: number,
	Contrast: number,
	Saturation: number,
	TintColor: Color3,
}

export type BloomSpec = {
	Intensity: number,
	Size: number,
	Threshold: number,
}

export type LightingSpec = {
	Ambient: Color3,
	OutdoorAmbient: Color3,
	Brightness: number,
	ClockTime: number,
	FogColor: Color3,
	FogStart: number,
	FogEnd: number,
	Atmosphere: AtmosphereSpec,
	ColorCorrection: ColorCorrectionSpec,
	Bloom: BloomSpec,
}

export type Preset = {
	Id: string,
	ButtonLabel: string,  -- texto del botón en el admin panel
	DisplayName: string,  -- lo que se ve en Bot.Content."Current Event" (en inglés)
	Multiplier: number,       -- Speed (aditivo)
	WinsMultiplier: number,   -- Wins (multiplicativo)
	UIColor: Color3,          -- color del botón del panel + TextColor3 del label
	Gradient: ColorSequence,  -- para el UIGradient del label Current Event
	Skybox: SkyboxSpec?,
	Lightning: boolean,       -- flashes de rayo (solo la tormenta)
	Lighting: LightingSpec,
	Particle: ParticleSpec,
}

-- Texturas built-in de Roblox (rbxasset://, empaquetadas con el cliente): existen
-- siempre y no hay que subir nada. Cambiables por assets propios cuando los haya.
local TEX_SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

-- Orden de la tabla = orden de los botones en el admin panel.
local Presets: { Preset } = {
	-- ── ⛈️ THUNDERSTORM ──────────────────────────────────────────────────────
	-- Gris plomo, cielo apagado, niebla cerrada y lluvia en streaks verticales.
	-- Es el único con flashes de rayo (Lightning = true).
	{
		Id = "thunderstorm",
		ButtonLabel = "⛈️ Thunderstorm x2",
		DisplayName = "⛈️ THUNDERSTORM",
		Multiplier = 2,
		WinsMultiplier = 1.25,
		UIColor = Color3.fromRGB(90, 120, 165),
		Gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 190, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 110, 160)),
		}),
		Skybox = nil,
		Lightning = true,
		Lighting = {
			Ambient = Color3.fromRGB(60, 66, 80),
			OutdoorAmbient = Color3.fromRGB(78, 86, 104),
			Brightness = 1,
			ClockTime = 15.5,
			FogColor = Color3.fromRGB(96, 104, 122),
			FogStart = 0,
			FogEnd = 480,
			Atmosphere = {
				Density = 0.42,
				Offset = 0.1,
				Color = Color3.fromRGB(150, 158, 172),
				Decay = Color3.fromRGB(70, 78, 96),
				Glare = 0,
				Haze = 2.4,
			},
			ColorCorrection = {
				Brightness = -0.04,
				Contrast = 0.14,
				Saturation = -0.28,
				TintColor = Color3.fromRGB(206, 220, 245),
			},
			Bloom = { Intensity = 0.35, Size = 24, Threshold = 1.1 },
		},
		Particle = {
			Texture = TEX_SPARKLE,
			Color = ColorSequence.new(Color3.fromRGB(175, 205, 245)),
			Size = NumberSequence.new(0.35),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.35),
				NumberSequenceKeypoint.new(1, 0.35),
			}),
			Rate = 900,
			Lifetime = NumberRange.new(1.1, 1.5),
			Speed = NumberRange.new(85, 105),
			SpreadAngle = Vector2.new(4, 4),
			Acceleration = Vector3.new(-6, -40, 0),
			Rotation = NumberRange.new(0, 0),
			RotSpeed = NumberRange.new(0, 0),
			LightEmission = 0.35,
			LightInfluence = 0,
			Drag = 0,
			ZOffset = 0,
			-- Estirado vertical: convierte el sprite en un hilo de lluvia.
			Squash = NumberSequence.new(3.6),
			EmitBoxSize = Vector3.new(120, 2, 120),
			EmitOffset = Vector3.new(0, 60, 0),
			EmissionDirection = Enum.NormalId.Bottom,
		},
	},

	-- ── ❄️ BLIZZARD ──────────────────────────────────────────────────────────
	-- Blanco lavado, saturación por el suelo, niebla cortísima (se ve poco a lo
	-- lejos) y nieve girando lento.
	{
		Id = "blizzard",
		ButtonLabel = "❄️ Blizzard x3",
		DisplayName = "❄️ BLIZZARD",
		Multiplier = 3,
		WinsMultiplier = 1.5,
		UIColor = Color3.fromRGB(120, 190, 230),
		Gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(235, 250, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 190, 235)),
		}),
		Skybox = nil,
		Lightning = false,
		Lighting = {
			Ambient = Color3.fromRGB(130, 145, 160),
			OutdoorAmbient = Color3.fromRGB(160, 178, 195),
			Brightness = 2.4,
			ClockTime = 13,
			FogColor = Color3.fromRGB(222, 236, 246),
			FogStart = 0,
			FogEnd = 300,
			Atmosphere = {
				Density = 0.55,
				Offset = 0.85,
				Color = Color3.fromRGB(232, 244, 252),
				Decay = Color3.fromRGB(168, 196, 218),
				Glare = 0.6,
				Haze = 4.2,
			},
			ColorCorrection = {
				Brightness = 0.09,
				Contrast = -0.06,
				Saturation = -0.45,
				TintColor = Color3.fromRGB(224, 242, 255),
			},
			Bloom = { Intensity = 0.9, Size = 30, Threshold = 0.85 },
		},
		Particle = {
			Texture = TEX_SPARKLE,
			Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.45),
				NumberSequenceKeypoint.new(1, 0.7),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.15, 0.15),
				NumberSequenceKeypoint.new(0.8, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Rate = 500,
			Lifetime = NumberRange.new(3, 4.5),
			Speed = NumberRange.new(14, 24),
			SpreadAngle = Vector2.new(35, 35),
			-- Viento lateral fuerte: es ventisca, no nevada tranquila.
			Acceleration = Vector3.new(-22, -8, 6),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-90, 90),
			LightEmission = 0.5,
			LightInfluence = 0,
			Drag = 1.2,
			ZOffset = 0,
			Squash = nil,
			EmitBoxSize = Vector3.new(110, 6, 110),
			EmitOffset = Vector3.new(0, 45, 0),
			EmissionDirection = Enum.NormalId.Bottom,
		},
	},

	-- ── 🩸 BLOOD MOON ────────────────────────────────────────────────────────
	-- Noche cerrada teñida de rojo, atmósfera densa y ceniza SUBIENDO
	-- (Acceleration.Y positivo) en vez de cayendo.
	{
		Id = "blood_moon",
		ButtonLabel = "🩸 Blood Moon x5",
		DisplayName = "🩸 BLOOD MOON",
		Multiplier = 5,
		WinsMultiplier = 2,
		UIColor = Color3.fromRGB(190, 45, 55),
		Gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 130, 110)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 20, 30)),
		}),
		Skybox = nil,
		Lightning = false,
		Lighting = {
			-- El rojo va sobre todo en el TINTE (ColorCorrection) y en la atmósfera,
			-- NO en el Ambient: un Ambient rojo oscuro deja las sombras sin detalle y
			-- el mapa se vuelve injugable. El Ambient se mantiene claro y solo
			-- ligeramente cálido para que la geometría siga leyéndose.
			Ambient = Color3.fromRGB(96, 68, 70),
			OutdoorAmbient = Color3.fromRGB(126, 86, 88),
			Brightness = 2,
			ClockTime = 0,
			FogColor = Color3.fromRGB(98, 48, 50),
			FogStart = 0,
			FogEnd = 850,
			Atmosphere = {
				-- Density y Haze bajos a propósito: son los que tapaban el mapa.
				Density = 0.3,
				Offset = 0.4,
				Color = Color3.fromRGB(205, 135, 125),
				Decay = Color3.fromRGB(115, 52, 54),
				Glare = 0.8,
				Haze = 1.6,
			},
			ColorCorrection = {
				-- Brightness positivo para levantar las zonas oscuras. La saturación
				-- se queda baja: el color rojo lo pone el TintColor, subirla además
				-- satura el rojo hasta que se pierden los bordes de las cosas.
				Brightness = 0.1,
				Contrast = 0.16,
				Saturation = 0.12,
				TintColor = Color3.fromRGB(255, 206, 200),
			},
			-- Threshold alto: que brillen la luna y las partículas, no el mapa entero.
			Bloom = { Intensity = 1, Size = 32, Threshold = 0.95 },
		},
		Particle = {
			Texture = TEX_SPARKLE,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 170, 90)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(230, 60, 40)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 15, 15)),
			}),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.5),
				NumberSequenceKeypoint.new(1, 0.05),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Rate = 260,
			Lifetime = NumberRange.new(3.5, 6),
			Speed = NumberRange.new(3, 9),
			SpreadAngle = Vector2.new(180, 180),
			-- Positivo: la ceniza flota hacia arriba.
			Acceleration = Vector3.new(3, 7, -2),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-45, 45),
			LightEmission = 1,
			LightInfluence = 0,
			Drag = 0.6,
			ZOffset = 0,
			Squash = nil,
			EmitBoxSize = Vector3.new(90, 50, 90),
			EmitOffset = Vector3.new(0, -10, 0),
			EmissionDirection = Enum.NormalId.Top,
		},
	},

	-- ── 🌌 AURORA BOREALIS ───────────────────────────────────────────────────
	-- El más raro: noche estrellada limpia, tintes verde/violeta, bloom alto y
	-- motas doradas flotando sin dirección clara.
	{
		Id = "aurora",
		ButtonLabel = "🌌 Aurora x10",
		DisplayName = "🌌 AURORA BOREALIS",
		Multiplier = 10,
		WinsMultiplier = 3,
		UIColor = Color3.fromRGB(80, 210, 170),
		Gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 255, 200)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 210, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 130, 255)),
		}),
		Skybox = nil,
		Lightning = false,
		Lighting = {
			Ambient = Color3.fromRGB(28, 52, 62),
			OutdoorAmbient = Color3.fromRGB(46, 82, 96),
			Brightness = 1.4,
			ClockTime = 0.4,
			FogColor = Color3.fromRGB(24, 52, 60),
			FogStart = 0,
			FogEnd = 700,
			Atmosphere = {
				Density = 0.34,
				Offset = 0.55,
				Color = Color3.fromRGB(110, 220, 190),
				Decay = Color3.fromRGB(70, 40, 130),
				Glare = 2.6,
				Haze = 2,
			},
			ColorCorrection = {
				Brightness = 0.06,
				Contrast = 0.2,
				Saturation = 0.55,
				TintColor = Color3.fromRGB(190, 240, 255),
			},
			Bloom = { Intensity = 2.2, Size = 56, Threshold = 0.55 },
		},
		Particle = {
			Texture = TEX_SPARKLE,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 170)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(130, 255, 210)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 140, 255)),
			}),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.3, 0.55),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.25, 0.05),
				NumberSequenceKeypoint.new(0.75, 0.05),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Rate = 200,
			Lifetime = NumberRange.new(4, 7),
			Speed = NumberRange.new(2, 6),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(1.5, 2.5, 1.5),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-30, 30),
			LightEmission = 1,
			LightInfluence = 0,
			Drag = 0.9,
			ZOffset = 0,
			Squash = nil,
			EmitBoxSize = Vector3.new(95, 55, 95),
			EmitOffset = Vector3.new(0, 0, 0),
			EmissionDirection = Enum.NormalId.Top,
		},
	},
}

local byId: { [string]: Preset } = {}
for _, preset in Presets do
	byId[preset.Id] = preset
end

-- Segundos de la transición entre estados (entrar, salir y cambiar de un weather a
-- otro). El cliente tweenea todo Lighting con esta duración.
local TransitionSeconds = 2.5

-- Ventana aleatoria entre flashes de rayo, para los presets con Lightning = true.
local LightningInterval = NumberRange.new(4, 11)

return {
	Presets = Presets,
	byId = byId,
	TransitionSeconds = TransitionSeconds,
	LightningInterval = LightningInterval,
}
