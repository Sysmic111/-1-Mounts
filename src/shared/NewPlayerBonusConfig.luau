--!strict

-- Oferta de retención para jugadores nuevos: quedarse DurationSeconds seguidos en
-- una misma sesión regala una montura Premium.
--
-- El reloj es de SESIÓN y no se guarda (misma idea que el playtime de tiers en
-- PlayTimeService): irse a los 12 minutos significa volver a empezar de 0. Eso es
-- lo que hace real la amenaza del aviso al salir — si el progreso se guardara, el
-- mensaje sería mentira.
--
-- La ventana de oportunidad son las MaxSessions primeras sesiones: tres intentos
-- de 15 minutos. Después el botón no vuelve a aparecer nunca y la montura solo se
-- consigue con Robux.

return {
	-- Debe existir en MountsConfig.Premium. Vespofuzz es además un Developer Product
	-- (3606128170): regalarla aquí canibaliza esa venta a propósito, es el gancho.
	--
	-- Su valor escala (PremiumFactor 2x sobre la mejor World1 poseída), así que
	-- regalarla en la sesión 1 no rompe el early game: quien solo tenga Chonk se
	-- lleva un x2, y la montura crece con él.
	MountName = "Vespofuzz",

	-- Segundos seguidos dentro de una misma sesión.
	DurationSeconds = 15 * 60,

	-- Sesiones (de por vida) en las que se ofrece. Al agotarlas la oferta caduca.
	MaxSessions = 3,
}
