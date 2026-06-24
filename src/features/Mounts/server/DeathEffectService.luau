--!strict

-- Efecto de muerte: cuando un personaje muere (Humanoid.Died), congela su pose,
-- lo ancla donde murió y, a lo largo de 1 segundo, desvanece cada parte (tanto del
-- mount como del personaje montado encima) mientras lanza partículas de chispas.
--
-- Estructura de un personaje montado (ver MorphService):
--   player.Character (modelo del mount, IsMountCharacter = true)
--     ├─ Humanoid + HumanoidRootPart   ← el que muere
--     ├─ partes del mount
--     └─ OriginalCharacter (avatar del jugador, sentado)
--          ├─ Humanoid (sentado, sin Animate)
--          └─ partes del avatar
-- GetDescendants() del personaje cubre AMBOS conjuntos de partes y AMBOS Humanoids.
--
-- Se ejecuta en el servidor para que todos los jugadores vean el efecto: anchor,
-- transparencia, partículas y el stop de animaciones replican automáticamente.

local Players       = game:GetService("Players")
local TweenService  = game:GetService("TweenService")
local Debris        = game:GetService("Debris")

local DeathEffectService = {}

-- ── Tunables ──────────────────────────────────────────────────────────────────
local FADE_TIME       = 1                              -- segundos del desvanecimiento
local PARTICLE_COLOR  = Color3.fromRGB(170, 215, 255)  -- chispas azuladas
local PARTICLES_PER_PART = 8                            -- burst por parte
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

-- ── Partículas ──────────────────────────────────────────────────────────────────
local function makeVanishEmitter(): ParticleEmitter
	local pe = Instance.new("ParticleEmitter")
	pe.Texture          = SPARKLE_TEXTURE
	pe.Color            = ColorSequence.new(PARTICLE_COLOR)
	pe.LightEmission    = 0.6
	pe.LightInfluence   = 0
	pe.Rate             = 0                              -- solo emitimos en burst (:Emit)
	pe.Lifetime         = NumberRange.new(0.5, 1)
	pe.Speed            = NumberRange.new(2, 5)
	pe.SpreadAngle      = Vector2.new(180, 180)         -- en todas direcciones
	pe.Rotation         = NumberRange.new(0, 360)
	pe.RotSpeed         = NumberRange.new(-90, 90)
	pe.EmissionDirection = Enum.NormalId.Top
	pe.Acceleration     = Vector3.new(0, 4, 0)          -- flotan hacia arriba
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	return pe
end

-- ── Secuencia de muerte ─────────────────────────────────────────────────────────
local function playDeathFX(character: Model)
	if character:GetAttribute("DeathFXPlayed") then return end
	character:SetAttribute("DeathFXPlayed", true)

	-- 1) Detener toda animación de ambos Humanoids (mount y personaje encima) y
	--    evitar que el state machine dispare nuevas (p.ej. la animación de muerte).
	for _, h in character:GetDescendants() do
		if h:IsA("Humanoid") then
			h.EvaluateStateMachine = false
			local animator = h:FindFirstChildOfClass("Animator")
			if animator then
				for _, track in animator:GetPlayingAnimationTracks() do
					track:Stop(0)
				end
			end
		elseif h:IsA("Script") or h:IsA("LocalScript") then
			-- Desactivar scripts "Animate" para que no relancen animaciones.
			if h.Name == "Animate" then
				h.Disabled = true
			end
		end
	end

	-- 2) Anclar todas las partes donde murió (congela la pose, ya sin animación).
	local fadeInfo  = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Linear)
	for _, p in character:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
		end
	end

	-- 3) Desvanecer cada parte (y sus Decals/Textures) durante FADE_TIME y lanzar
	--    el burst de chispas desde cada parte visible.
	for _, p in character:GetDescendants() do
		if p:IsA("BasePart") then
			if p.Transparency < 1 then
				TweenService:Create(p, fadeInfo, { Transparency = 1 }):Play()

				local emitter = makeVanishEmitter()
				emitter.Parent = p
				emitter:Emit(PARTICLES_PER_PART)
				Debris:AddItem(emitter, FADE_TIME + 1)
			end
		elseif p:IsA("Decal") or p:IsA("Texture") then
			if p.Transparency < 1 then
				TweenService:Create(p, fadeInfo, { Transparency = 1 }):Play()
			end
		end
	end
end

-- ── Enganche por personaje ──────────────────────────────────────────────────────
function DeathEffectService:init(): ()
	local function onCharacterAdded(character: Model)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
			or character:WaitForChild("Humanoid", 5) :: Humanoid?
		if not humanoid then return end
		(humanoid :: Humanoid).Died:Once(function()
			playDeathFX(character)
		end)
	end

	local function setupPlayer(player: Player)
		player.CharacterAdded:Connect(onCharacterAdded)
		if player.Character then
			task.spawn(onCharacterAdded, player.Character)
		end
	end

	Players.PlayerAdded:Connect(setupPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(setupPlayer, player)
	end
end

return DeathEffectService
