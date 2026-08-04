--!strict

-- Plataforma que se desvanece de los Stages.
--
-- Cada parte taggeada "Transparent" hace un ciclo continuo:
--   1. Fade: la transparencia sube 0 → 1 mientras mantiene la colisión.
--   2. Al volverse totalmente transparente: se quita la colisión y queda
--      invisible durante INVISIBLE_HOLD segundos.
--   3. Reinicia: vuelve a opaca y sólida.
--
-- La duración del fade se calibra al WalkSpeed de nivel 130: un jugador de ese
-- nivel alcanza a cruzar el largo de la plataforma justo antes de que desaparezca;
-- uno más lento se cae. El largo se mide del propio tamaño de la parte, así que
-- funciona aunque la redimensiones.
--
-- La fase se deriva de GetServerTimeNow() para que todos los clientes estén
-- sincronizados sin replicar nada (igual que LavaRise / Axes / Tronco).

local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpeedConfig     = require(ReplicatedStorage.Shared.SpeedConfig)
local ObstaclesConfig = require(ReplicatedStorage.Shared.ObstaclesConfig)

-- ── Tunables ──────────────────────────────────────────────────────────────────
local TAG             = "Transparent"
-- Calibración por mundo (ver ObstaclesConfig). INVISIBLE_HOLD está en segundos
-- ABSOLUTOS, así que también va por mundo.
local CONFIG = ObstaclesConfig.get("Transparent")

local REFERENCE_LEVEL = CONFIG.Level                   -- nivel que alcanza a cruzarla antes de que desaparezca
local INVISIBLE_HOLD  = CONFIG.InvisibleHold or 3      -- s que permanece invisible y sin colisión
local REF_SPEED       = SpeedConfig.getWalkSpeedForLevel(REFERENCE_LEVEL)  -- studs/s

-- ── Estado ────────────────────────────────────────────────────────────────────
type Fader = {
	part:         BasePart,
	baseTransp:   number,   -- transparencia original (fade parte de aquí hasta 1)
	baseCollide:  boolean,  -- CanCollide original (a restaurar al reiniciar)
	fadeDuration: number,   -- s en pasar de opaca a transparente
	period:       number,   -- s del ciclo completo (fade + hold)
}

local faders: { [BasePart]: Fader } = {}

-- ── Registro ──────────────────────────────────────────────────────────────────
local function registerFader(inst: Instance)
	if not inst:IsA("BasePart") then return end
	local part = inst :: BasePart

	-- El largo horizontal recorrible = la mayor de las dimensiones X/Z.
	local length = math.max(part.Size.X, part.Size.Z)
	local fadeDuration = length / REF_SPEED

	faders[part] = {
		part         = part,
		baseTransp   = part.Transparency,
		baseCollide  = part.CanCollide,
		fadeDuration = fadeDuration,
		period       = fadeDuration + INVISIBLE_HOLD,
	}
end

for _, inst in CollectionService:GetTagged(TAG) do
	registerFader(inst)
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(registerFader)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(inst)
	if inst:IsA("BasePart") then
		local f = faders[inst :: BasePart]
		if f then
			-- Restaurar el estado original al desetiquetar.
			f.part.Transparency = f.baseTransp
			f.part.CanCollide   = f.baseCollide
		end
		faders[inst :: BasePart] = nil
	end
end)

-- ── Loop principal ────────────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
	-- % 3600 reduce la magnitud del timestamp para evitar pérdida de precisión.
	local now = Workspace:GetServerTimeNow() % 3600

	for _, f in faders do
		local t = now % f.period

		if t < f.fadeDuration then
			-- Fase de fade: sube la transparencia, mantiene la colisión.
			local prog = t / f.fadeDuration
			f.part.Transparency = f.baseTransp + (1 - f.baseTransp) * prog
			f.part.CanCollide   = true
		else
			-- Fase invisible: totalmente transparente y sin colisión.
			f.part.Transparency = 1
			f.part.CanCollide   = false
		end
	end
end)
