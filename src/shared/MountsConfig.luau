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

	World1 = {
		{ Name = "Chonk",     Multiplier = 1.00,  Image = "rbxassetid://0", EvolveRequirements = nil                         },
		{ Name = "Moru",      Multiplier = 1.25,  Image = "rbxassetid://0", EvolveRequirements = { Level = 10,    Wins = 2   } },
		{ Name = "Lirael",    Multiplier = 1.50,  Image = "rbxassetid://0", EvolveRequirements = { Level = 20,    Wins = 5   } },
		{ Name = "Zahmir",    Multiplier = 2.00,  Image = "rbxassetid://0", EvolveRequirements = { Level = 35,    Wins = 10  } },
		{ Name = "HippoHop",  Multiplier = 2.50,  Image = "rbxassetid://0", EvolveRequirements = { Level = 60,    Wins = 18  } },
		{ Name = "Sahari",    Multiplier = 3.00,  Image = "rbxassetid://0", EvolveRequirements = { Level = 100,   Wins = 30  } },
		{ Name = "Raiketsu",  Multiplier = 4.00,  Image = "rbxassetid://0", EvolveRequirements = { Level = 160,   Wins = 50  } },
		{ Name = "Khar",      Multiplier = 5.00,  Image = "rbxassetid://0", EvolveRequirements = { Level = 260,   Wins = 80  } },
		{ Name = "Lutra",     Multiplier = 7.00,  Image = "rbxassetid://0", EvolveRequirements = { Level = 420,   Wins = 130 } },
		{ Name = "Canter",    Multiplier = 9.00,  Image = "rbxassetid://0", EvolveRequirements = { Level = 680,   Wins = 210 } },
		{ Name = "Takaari",   Multiplier = 12.00, Image = "rbxassetid://0", EvolveRequirements = { Level = 1100,  Wins = 330 } },
		{ Name = "Boglo",     Multiplier = 15.00, Image = "rbxassetid://0", EvolveRequirements = { Level = 1750,  Wins = 530 } },
		{ Name = "Rook",      Multiplier = 20.00, Image = "rbxassetid://0", EvolveRequirements = { Level = 2800,  Wins = 840  } },
		{ Name = "Prowly",    Multiplier = 25.00, Image = "rbxassetid://0", EvolveRequirements = { Level = 4500,  Wins = 1350 } },
		{ Name = "Nyx",       Multiplier = 32.00, Image = "rbxassetid://0", EvolveRequirements = { Level = 7000,  Wins = 2100 } },
		{ Name = "Apex",      Multiplier = 40.00, Image = "rbxassetid://0", EvolveRequirements = { Level = 11000, Wins = 3300 } },
		{ Name = "Regal",     Multiplier = 50.00, Image = "rbxassetid://0", EvolveRequirements = { Level = 17000, Wins = 5000 } },
		{ Name = "Skornclaw", Multiplier = 62.00, Image = "rbxassetid://0", EvolveRequirements = { Level = 26000, Wins = 7500 } },
		{ Name = "Kharvox",   Multiplier = 75.00, Image = "rbxassetid://0", EvolveRequirements = { Level = 40000, Wins = 11500 } },
		{ Name = "Nyxion",    Multiplier = 90.00, Image = "rbxassetid://0", EvolveRequirements = { Level = 60000, Wins = 17500 } },
	} :: { MountData },

	Premium = {
		{ Name = "Vespofuzz",       Multiplier = 100, Image = "rbxassetid://0", EvolveRequirements = nil },
		{ Name = "Phantom Chopper", Multiplier = 150, Image = "rbxassetid://0", EvolveRequirements = nil },
	} :: { MountData },

}

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
