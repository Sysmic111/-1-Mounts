--!strict

export type EvolveRequirements = {
	Level: number,
	Wins: number,
}

export type MountData = {
	Name: string,
	Multiplier: number,
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
	-- recorrido del juego. El rebirth borra Mounts pero conserva WinCurrency, así
	-- que estos Wins se re-pagan en cada ciclo: es el sink principal del juego
	-- (535.230 Wins por ciclo).
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
		{ Name = "Regal",     Multiplier = 50.00, Image = "rbxassetid://96629437634159",  EvolveRequirements = { Level = 107, Wins = 52000  } },
		{ Name = "Skornclaw", Multiplier = 62.00, Image = "rbxassetid://98717951577991",  EvolveRequirements = { Level = 114, Wins = 80000  } },
		{ Name = "Kharvox",   Multiplier = 75.00, Image = "rbxassetid://107557322180491", EvolveRequirements = { Level = 120, Wins = 125000 } },
		{ Name = "Nyxion",    Multiplier = 90.00, Image = "rbxassetid://96015267241327",  EvolveRequirements = { Level = 126, Wins = 190000 } },
	} :: { MountData },

	-- Secret Mounts del Index. Sin ProductId no se pueden comprar: las tres de
	-- abajo solo se consiguen en el Daily Login (días 7, 14 y 21).
	Premium = {
		{ Name = "Vespofuzz",       Multiplier = 100, Image = "rbxassetid://124781012483071", EvolveRequirements = nil, ProductId = 3606128170 },
		{ Name = "Phantom Chopper", Multiplier = 150, Image = "rbxassetid://119825390796383", EvolveRequirements = nil, ProductId = 3606128200 },
		{ Name = "Velune",          Multiplier = 25,  Image = "rbxassetid://136869744377145", EvolveRequirements = nil },
		{ Name = "Droth",           Multiplier = 70,  Image = "rbxassetid://138492432017701", EvolveRequirements = nil },
		{ Name = "Pyrax",           Multiplier = 130, Image = "rbxassetid://104693225494550", EvolveRequirements = nil },
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

return MountsConfig
