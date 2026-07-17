--!strict

-- Badge rojo con "!" que se pega a la esquina de un botón del menú izquierdo para
-- avisar de que hay algo disponible (un claim del Daily, un evolve, un rebirth).
--
-- El UI de Studio no trae este badge en ningún botón, así que se construye por
-- código. Vive aquí para que Daily, Evolve y Rebirth compartan exactamente el
-- mismo aspecto en vez de tener tres copias que se desincronizan.

local NotifyBadge = {}

local BADGE_NAME = "ClaimBadge"

-- Crea el badge dentro de `button` si aún no existe, y lo devuelve. Idempotente.
function NotifyBadge.get(button: GuiObject): Frame
	local existing = button:FindFirstChild(BADGE_NAME) :: Frame?
	if existing then return existing end

	local badge = Instance.new("Frame")
	badge.Name             = BADGE_NAME
	badge.AnchorPoint      = Vector2.new(0.5, 0.5)
	badge.Position         = UDim2.fromScale(0.9, 0.1)
	badge.Size             = UDim2.fromScale(0.3, 0.3)
	badge.BackgroundColor3  = Color3.fromRGB(255, 0, 0)
	badge.BorderSizePixel  = 0
	badge.ZIndex           = 5
	badge.Visible          = false
	badge.Parent           = button

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent       = badge

	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.Parent      = badge

	local stroke = Instance.new("UIStroke")
	stroke.Color        = Color3.fromRGB(0, 0, 0)
	stroke.Thickness    = 2
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent       = badge

	local label = Instance.new("TextLabel")
	label.Size                   = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text                   = "!"
	label.TextScaled             = true
	label.TextColor3             = Color3.fromRGB(255, 255, 255)
	label.FontFace               = Font.fromName("ComicNeueAngular", Enum.FontWeight.Bold)
	label.ZIndex                 = 6
	label.Parent                 = badge

	local labelStroke = Instance.new("UIStroke")
	labelStroke.Color        = Color3.fromRGB(0, 0, 0)
	labelStroke.Thickness    = 2
	labelStroke.LineJoinMode = Enum.LineJoinMode.Round
	labelStroke.Parent       = label

	return badge
end

function NotifyBadge.setVisible(button: GuiObject, visible: boolean)
	NotifyBadge.get(button).Visible = visible
end

return NotifyBadge
