--!strict

-- Oferta única: se compra una sola vez por jugador y no vuelve a ofrecerse.
--
-- Calibrado contra la curva de SpeedConfig (8 × 1.225^(L-1)):
--   · 25.000 Speed dejan al jugador en el nivel 33, justo donde la tasa de
--     paquetes se satura a 10/s (WalkSpeed 50 → nivel 34). En absoluto son el
--     26% del camino al primer rebirth (nivel 40).
--   · 200 Wins compran exactamente el step x16, al que un jugador free no llega
--     hasta pasados ~30 min. Esta es la mitad que de verdad vale: los Wins y los
--     steps son permanentes y sobreviven al rebirth, mientras que el Speed se
--     consume y a la hora de juego ya no paga ni un nivel.
-- En conjunto adelanta ~25-35 min de un recorrido de ~9h.

local StarterPackConfig = {
	ProductId = 3606125733,
	Wins  = 200,
	Speed = 25_000,

	-- Las dos cards del menú están hechas a mano en Studio, se llaman igual
	-- (DayCardTemplate) y ambas tienen LayoutOrder 0, así que su icono es lo único
	-- que permite distinguirlas. El cliente las usa para escribir el RewardText
	-- desde este config y que los textos no puedan desincronizarse de los números.
	WinsIcon  = "rbxassetid://73013260592473",
	SpeedIcon = "rbxassetid://131658902182565",
}

return StarterPackConfig
