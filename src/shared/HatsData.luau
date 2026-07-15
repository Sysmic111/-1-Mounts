--!strict

-- Cada hat es un Model dentro de ReplicatedStorage.Hats cuyo nombre coincide
-- EXACTAMENTE con el campo Name (se usa para clonar el modelo en el ViewportFrame).
-- Los hats dan un Multiplier que se integra al TotalMultiplier (× como las mounts).
-- Se compran con WinCurrency. La primera compra equipa automáticamente.

export type HatData = {
	Name: string,       -- debe coincidir con el nombre del Model en ReplicatedStorage.Hats
	Multiplier: number, -- factor multiplicativo que aporta al TotalMultiplier
	Price: number,      -- costo en WinCurrency
	Image: string,      -- rbxassetid del ícono 2D (placeholder; el preview usa el ViewportFrame)
}

local HatsData = {

	-- Orden = orden de aparición en el menú (LayoutOrder)
	Hats = {
		{ Name = "Red Hat",       Multiplier = 1.10, Price = 250,    Image = "rbxassetid://0" },
		{ Name = "Mushroom Hat",  Multiplier = 1.25, Price = 1000,   Image = "rbxassetid://0" },
		{ Name = "Chef",          Multiplier = 1.45, Price = 4000,   Image = "rbxassetid://0" },
		{ Name = "Winter Beanie", Multiplier = 1.70, Price = 15000,  Image = "rbxassetid://0" },
		{ Name = "Floppy Sun Hat",Multiplier = 2.00, Price = 50000,  Image = "rbxassetid://0" },
		{ Name = "Art",           Multiplier = 2.50, Price = 150000, Image = "rbxassetid://0" },
		{ Name = "Dev",           Multiplier = 5.00, Price = 500000, Image = "rbxassetid://0" },
	} :: { HatData },

}

function HatsData.getHatData(name: string): HatData?
	for _, hat in HatsData.Hats do
		if hat.Name == name then return hat end
	end
	return nil
end

return HatsData
