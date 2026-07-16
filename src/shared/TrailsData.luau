--!strict

-- Los trails dan un Multiplier que se integra al TotalMultiplier (× como hats/mounts).
-- Se compran con WinCurrency. La primera compra equipa automáticamente.
-- Al equiparse se coloca un Trail horizontal (lado→lado) en la parte trasera de la montura.
-- Texture y Color son de PRUEBA: cambiar Texture por los assets reales cuando estén.
-- (Un Trail sin textura válida igual renderiza como cinta del Color indicado.)

export type TrailData = {
	Name: string,       -- identificador único del trail
	Multiplier: number, -- factor multiplicativo que aporta al TotalMultiplier
	Price: number,      -- costo en WinCurrency
	Texture: string,    -- rbxassetid de la textura del trail (placeholder)
	Color: Color3,      -- color de la cinta (para diferenciarlos ya, aunque la textura sea placeholder)
}

local Placeholder = "rbxassetid://0"

local TrailsData = {

	-- Orden = orden de aparición en el menú (LayoutOrder)
	Trails = {
		{ Name = "Ember",     Multiplier = 1.10, Price = 300,    Texture = Placeholder, Color = Color3.fromRGB(255, 94, 33)   },
		{ Name = "Aqua",      Multiplier = 1.25, Price = 1200,   Texture = Placeholder, Color = Color3.fromRGB(38, 198, 218)  },
		{ Name = "Toxic",     Multiplier = 1.45, Price = 4500,   Texture = Placeholder, Color = Color3.fromRGB(118, 255, 3)   },
		{ Name = "Voltage",   Multiplier = 1.70, Price = 16000,  Texture = Placeholder, Color = Color3.fromRGB(255, 235, 59)  },
		{ Name = "Bubblegum", Multiplier = 2.00, Price = 55000,  Texture = Placeholder, Color = Color3.fromRGB(255, 105, 180) },
		{ Name = "Void",      Multiplier = 2.50, Price = 160000, Texture = Placeholder, Color = Color3.fromRGB(124, 77, 255)  },
		{ Name = "Frost",     Multiplier = 3.20, Price = 500000, Texture = Placeholder, Color = Color3.fromRGB(179, 229, 252) },
		{ Name = "Rainbow",   Multiplier = 4.00, Price = 1500000,Texture = Placeholder, Color = Color3.fromRGB(255, 255, 255) },
	} :: { TrailData },

}

function TrailsData.getTrailData(name: string): TrailData?
	for _, trail in TrailsData.Trails do
		if trail.Name == name then return trail end
	end
	return nil
end

return TrailsData
