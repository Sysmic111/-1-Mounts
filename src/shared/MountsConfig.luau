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

export type WorldData = {
	Name: string,
	Key: string,
	Image: string,
}

local MountsConfig = {

	Worlds = {
		{ Name = "World 1", Key = "World1", Image = "rbxassetid://0" },
	} :: { WorldData },

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
		{ Name = "Moru",      Multiplier = 1.25,  Image = "rbxassetid://97674690910640",  EvolveRequirements = { Level = 5,   Wins = 5      } },
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
	-- OJO — decisión deliberada, no un descuido: las dos de pago NO están por encima
	-- de las gratuitas. Vespofuzz (x2) empata con Velune y pierde contra Droth (x3);
	-- Phantom Chopper (x5) empata con Pyrax. Si algún día se revisan las ventas de
	-- 3606128170 / 3606128200, es aquí donde hay que mirar.
	Premium = {
		{ Name = "Vespofuzz",       PremiumFactor = 2, Image = "rbxassetid://124781012483071", EvolveRequirements = nil, ProductId = 3606128170 },
		{ Name = "Phantom Chopper", PremiumFactor = 5, Image = "rbxassetid://119825390796383", EvolveRequirements = nil, ProductId = 3606128200 },
		{ Name = "Velune",          PremiumFactor = 2, Image = "rbxassetid://136869744377145", EvolveRequirements = nil },
		{ Name = "Droth",           PremiumFactor = 3, Image = "rbxassetid://138492432017701", EvolveRequirements = nil },
		{ Name = "Pyrax",           PremiumFactor = 5, Image = "rbxassetid://104693225494550", EvolveRequirements = nil },
		{ Name = "Vezkitt",         PremiumFactor = 3, Image = "rbxassetid://123190378184732", EvolveRequirements = nil },
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
