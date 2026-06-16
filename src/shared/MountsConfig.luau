--!strict

export type MountData = {
	Name: string,
	Multiplier: number,
}

local MountsConfig = {

	World1 = {
		{ Name = "Chonk",      Multiplier = 1.00  },
		{ Name = "Moru",       Multiplier = 1.25  },
		{ Name = "Lirael",     Multiplier = 1.56  },
		{ Name = "Zahmir",     Multiplier = 1.95  },
		{ Name = "HippoHop",   Multiplier = 2.44  },
		{ Name = "Sahari",     Multiplier = 3.05  },
		{ Name = "Raiketsu",   Multiplier = 3.81  },
		{ Name = "Khar",       Multiplier = 4.77  },
		{ Name = "Lutra",      Multiplier = 5.96  },
		{ Name = "Canter",     Multiplier = 7.45  },
		{ Name = "Takaari",    Multiplier = 9.31  },
		{ Name = "Boglo",      Multiplier = 11.64 },
		{ Name = "Rook",       Multiplier = 14.55 },
		{ Name = "Prowly",     Multiplier = 18.19 },
		{ Name = "Nyx",        Multiplier = 22.74 },
		{ Name = "Apex",       Multiplier = 28.42 },
		{ Name = "Regal",      Multiplier = 35.53 },
		{ Name = "Skornclaw",  Multiplier = 44.41 },
		{ Name = "Kharvox",    Multiplier = 55.51 },
		{ Name = "Nyxion",     Multiplier = 69.39 },
	} :: { MountData },

	Premium = {
		{ Name = "Vespofuzz",       Multiplier = 100 },
		{ Name = "Phantom Chopper", Multiplier = 150 },
	} :: { MountData },

}

function MountsConfig.getMountData(name: string): MountData?
	for _, mount in MountsConfig.World1 do
		if mount.Name == name then
			return mount
		end
	end
	for _, mount in MountsConfig.Premium do
		if mount.Name == name then
			return mount
		end
	end
	return nil
end

return MountsConfig
