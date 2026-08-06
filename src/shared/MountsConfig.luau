--!strict

export type EvolveRequirements = {
	Level: number,
	Wins: number,
}

-- Una montura define su multiplicador de UNA de estas dos formas, nunca las dos:
--
--   Multiplier    -> valor fijo. Es lo que usan las World1.
--   PremiumFactor -> factor RELATIVO sobre la mejor World1 que el jugador posee.
--                    Es lo que usan las Premium.
--
-- Por eso los dos campos son opcionales en el tipo: el valor efectivo no se lee
-- nunca a pelo, se pide a MountsConfig.getEffectiveMultiplier.
export type MountData = {
	Name: string,
	Multiplier: number?,
	PremiumFactor: number?,
	Image: string,
	EvolveRequirements: EvolveRequirements?,
	ProductId: number?, -- Developer Product (solo monturas Premium)
}

-- Pestaña del menú Index. OJO: aquí "World1" es un TIER DE MONTURAS, no un place.
-- Los places (World 1 = 74139556114101, World 2 = 88347344061446) los resuelve
-- WorldsConfig, que es el único sitio del repo que conoce PlaceIds. Los dos
-- conceptos comparten nombre por accidente histórico y no están relacionados.
export type MountTierData = {
	Name: string,
	Key: string,
	Image: string,
}

local MountsConfig = {

	MountTiers = {
		{ Name = "World 1", Key = "World1", Image = "rbxassetid://0" },
	} :: { MountTierData },

	-- La cadena de evolución completa cabe dentro del rango 1..130, que es el
	-- recorrido del juego. Las mounts PERSISTEN tras el rebirth: la cadena es una
	-- compra única (1.138.230 Wins en total), el mayor sink del juego. Los gates
	-- de Level la reparten solos entre los ciclos, porque cada ciclo llega más
	-- alto (40, 55, 68... 130): Raiketsu cae en el ciclo 1 y Nyxion solo en el
	-- final. OJO: subir estos Wins NO es la palanca de duración (las mounts son el
	-- motor del ingreso y encarecerlas frena todo el juego) — la palanca es
	-- SpeedConfig.RequiredSpeedGrowth.
	World1 = {
		{ Name = "Chonk",     Multiplier = 1.00,  Image = "rbxassetid://100326118934119", EvolveRequirements = nil                          },
		-- Wins = 1 (no 5) porque este evolve es el paso 4 del tutorial: el paso 2
		-- recoge exactamente 1 win en el Stage 2 y este lo consume. Ver
		-- src/features/Tutorial/client.
		{ Name = "Moru",      Multiplier = 1.25,  Image = "rbxassetid://97674690910640",  EvolveRequirements = { Level = 5,   Wins = 1      } },
		{ Name = "Lirael",    Multiplier = 1.50,  Image = "rbxassetid://95707865724771",  EvolveRequirements = { Level = 11,  Wins = 15     } },
		{ Name = "Zahmir",    Multiplier = 2.00,  Image = "rbxassetid://132074107395602", EvolveRequirements = { Level = 17,  Wins = 40     } },
		{ Name = "HippoHop",  Multiplier = 2.50,  Image = "rbxassetid://85336803052578",  EvolveRequirements = { Level = 23,  Wins = 90     } },
		{ Name = "Sahari",    Multiplier = 3.00,  Image = "rbxassetid://75167575854655",  EvolveRequirements = { Level = 30,  Wins = 180    } },
		{ Name = "Raiketsu",  Multiplier = 4.00,  Image = "rbxassetid://113400202018284", EvolveRequirements = { Level = 37,  Wins = 350    } },
		{ Name = "Khar",      Multiplier = 5.00,  Image = "rbxassetid://73383101139015",  EvolveRequirements = { Level = 44,  Wins = 650    } },
		{ Name = "Lutra",     Multiplier = 7.00,  Image = "rbxassetid://97442893124570",  EvolveRequirements = { Level = 51,  Wins = 1100   } },
		{ Name = "Canter",    Multiplier = 9.00,  Image = "rbxassetid://74039606584745",  EvolveRequirements = { Level = 58,  Wins = 1900   } },
		{ Name = "Takaari",   Multiplier = 12.00, Image = "rbxassetid://122489530999812", EvolveRequirements = { Level = 65,  Wins = 3200   } },
		{ Name = "Boglo",     Multiplier = 15.00, Image = "rbxassetid://138323140722642", EvolveRequirements = { Level = 72,  Wins = 5200   } },
		{ Name = "Rook",      Multiplier = 20.00, Image = "rbxassetid://138284593408680", EvolveRequirements = { Level = 79,  Wins = 8500   } },
		{ Name = "Prowly",    Multiplier = 25.00, Image = "rbxassetid://117894410844746", EvolveRequirements = { Level = 86,  Wins = 13000  } },
		{ Name = "Nyx",       Multiplier = 32.00, Image = "rbxassetid://82695908784510",  EvolveRequirements = { Level = 93,  Wins = 21000  } },
		{ Name = "Apex",      Multiplier = 40.00, Image = "rbxassetid://103363620861213", EvolveRequirements = { Level = 100, Wins = 33000  } },
		{ Name = "Regal",     Multiplier = 50.00, Image = "rbxassetid://96629437634159",  EvolveRequirements = { Level = 107, Wins = 90000  } },
		{ Name = "Skornclaw", Multiplier = 62.00, Image = "rbxassetid://98717951577991",  EvolveRequirements = { Level = 114, Wins = 160000 } },
		{ Name = "Kharvox",   Multiplier = 75.00, Image = "rbxassetid://107557322180491", EvolveRequirements = { Level = 120, Wins = 300000 } },
		{ Name = "Nyxion",    Multiplier = 90.00, Image = "rbxassetid://96015267241327",  EvolveRequirements = { Level = 126, Wins = 500000 } },

		-- ── Tramo de World 2 (el place, niveles 131..175) ─────────────────────────
		--
		-- Van en ESTE array y no en una tabla `World2` propia a propósito: la cadena
		-- de evolves es este array y nada más (MountsService:_handleEvolve y el
		-- espejo del cliente avanzan por índice sobre él, igual que FunnelService).
		-- Una tabla aparte se vería en el Index pero no habría forma de conseguirlas.
		--
		-- Los gates de Level caen justo antes de un stage de EconomyConfig.World2
		-- (133, 137, 140...): se evoluciona y con eso se entra al stage siguiente.
		--
		-- Los Wins están en la escala de World 2 (vuelta completa = 536M, cadena de
		-- steps ≈ 79.9B), no en la de World 1. Suben ×10 por montura contra un
		-- crecimiento de la curva de 1.204^10 = ×6.4 en esos mismos 10 niveles: la
		-- montura marginal empeora, igual que los steps, y por eso la cadena no
		-- cortocircuita el mundo. Total ≈ 45.5B ≈ 0.57× la cadena de steps.
		--
		-- Los multiplicadores son ADITIVOS dentro del TotalMultiplier (90 → 250 es
		-- ×2.8 sobre la base), así que el motor de ingreso de World 2 sigue siendo su
		-- cadena de steps (×4000) y estas monturas la acompañan sin sustituirla.
		{ Name = "Frostmane",  Multiplier = 110.00, Image = "rbxassetid://95196819681688", EvolveRequirements = { Level = 133, Wins = 5000000     } },
		{ Name = "Kryo",       Multiplier = 135.00, Image = "rbxassetid://101080335855594", EvolveRequirements = { Level = 143, Wins = 60000000    } },
		{ Name = "Drumgo",     Multiplier = 165.00, Image = "rbxassetid://111154755475379", EvolveRequirements = { Level = 153, Wins = 500000000   } },
		{ Name = "Iskryon",    Multiplier = 205.00, Image = "rbxassetid://105694988436139", EvolveRequirements = { Level = 163, Wins = 5000000000  } },
		{ Name = "Drogmarth",  Multiplier = 250.00, Image = "rbxassetid://134469275872562", EvolveRequirements = { Level = 173, Wins = 40000000000 } },
	} :: { MountData },

	-- Secret Mounts del Index. Sin ProductId no se pueden comprar: Velune, Droth y
	-- Pyrax solo salen del Daily Login (días 7, 14 y 21) y Vezkitt del obby de
	-- Admin Abuse.
	--
	-- No llevan multiplicador fijo: escalan con PremiumFactor sobre la mejor World1
	-- que el jugador POSEA. Una Premium siempre vale más que la mejor base (el
	-- factor mínimo es 2), y su valor crece solo según avanza la cadena de evolves
	-- en vez de quedar obsoleta a mitad de partida o romper el early game.
	--
	-- Las de pago son las que llevan ProductId: hoy Vespofuzz (3606128170) y Frostak
	-- (3606128200). Phantom Chopper se quedó SIN ProductId al pasárselo a Frostak,
	-- así que ahora mismo no hay forma de conseguirla.
	--
	-- OJO: Frostak (x6) SÍ está por encima de todas las gratuitas (la mejor es
	-- Pyrax, x5). Es un cambio de criterio respecto a como estaba: antes ninguna de
	-- pago superaba a las del Daily —Vespofuzz (x2) empata con Velune y pierde
	-- contra Droth (x3), y Phantom Chopper (x5) empataba con Pyrax— para que pagar
	-- adelantase, no desbloquease poder que no se puede conseguir jugando. Si algún
	-- día se revisan las ventas, es aquí donde hay que mirar.
	--
	-- El número del pedestal en Workspace.PremiumMounts (Buy<n>/Detail<n>) NO es el
	-- índice de esta lista: es la posición entre las que tienen ProductId. Lo
	-- resuelve PremiumMounts/client con su propio contador.
	Premium = {
		{ Name = "Vespofuzz",       PremiumFactor = 2, Image = "rbxassetid://124781012483071", EvolveRequirements = nil, ProductId = 3606128170 },
		{ Name = "Phantom Chopper", PremiumFactor = 5, Image = "rbxassetid://119825390796383", EvolveRequirements = nil },
		{ Name = "Velune",          PremiumFactor = 2, Image = "rbxassetid://136869744377145", EvolveRequirements = nil },
		{ Name = "Droth",           PremiumFactor = 3, Image = "rbxassetid://138492432017701", EvolveRequirements = nil },
		{ Name = "Pyrax",           PremiumFactor = 5, Image = "rbxassetid://104693225494550", EvolveRequirements = nil },
		{ Name = "Vezkitt",         PremiumFactor = 3, Image = "rbxassetid://123190378184732", EvolveRequirements = nil },
		{ Name = "Frostak",         PremiumFactor = 6, Image = "rbxassetid://133718337714509", EvolveRequirements = nil, ProductId = 3606128200 },

		
	} :: { MountData },

}

-- Devuelve la montura Premium asociada a un Developer Product (o nil)
function MountsConfig.getPremiumByProductId(productId: number): MountData?
	for _, mount in MountsConfig.Premium do
		if mount.ProductId == productId then return mount end
	end
	return nil
end

function MountsConfig.getMountData(name: string): MountData?
	for _, mount in MountsConfig.World1 do
		if mount.Name == name then return mount end
	end
	for _, mount in MountsConfig.Premium do
		if mount.Name == name then return mount end
	end
	return nil
end

-- Multiplicador de la mejor World1 que el jugador POSEE (no la equipada): es la
-- referencia sobre la que escalan las Premium. Se mira la propiedad y no el equipo
-- porque con una Premium puesta no hay ninguna World1 equipada de la que tirar.
--
-- Nunca baja: el rebirth resetea Level y SpeedCurrency, jamás las mounts.
--
-- Devuelve 1 si no posee ninguna (imposible en la práctica: MountsService siembra
-- Chonk, que ya vale 1).
function MountsConfig.getBestOwnedMultiplier(ownedMounts: { [string]: boolean }): number
	local best = 1
	for _, mount in MountsConfig.World1 do
		if ownedMounts[mount.Name] and (mount.Multiplier or 1) > best then
			best = mount.Multiplier or 1
		end
	end
	return best
end

-- Multiplicador efectivo de una montura para un jugador concreto. ÚNICO sitio que
-- resuelve Multiplier vs PremiumFactor: leer cualquiera de los dos campos a pelo
-- fuera de aquí da un número equivocado para la mitad de las monturas.
function MountsConfig.getEffectiveMultiplier(mountName: string, ownedMounts: { [string]: boolean }): number
	local mount = MountsConfig.getMountData(mountName)
	if not mount then return 1 end

	if mount.PremiumFactor then
		return mount.PremiumFactor * MountsConfig.getBestOwnedMultiplier(ownedMounts)
	end

	return mount.Multiplier or 1
end

return MountsConfig
