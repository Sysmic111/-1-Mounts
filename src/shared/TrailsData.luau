--!strict

-- Los trails dan un Multiplier que se integra al TotalMultiplier (× como hats/mounts).
-- Se compran con WinCurrency. La primera compra equipa automáticamente.
-- Al equiparse se coloca un Trail vertical (arriba→abajo) en la parte trasera de la montura.
-- Texture y Color son de PRUEBA: cambiar Texture por los assets reales cuando estén.
-- (Un Trail sin textura válida igual renderiza como cinta del Color indicado.)

export type TrailData = {
	Name: string,       -- identificador único del trail
	Multiplier: number, -- factor multiplicativo que aporta al TotalMultiplier
	Price: number,      -- costo en WinCurrency
	Texture: string,    -- rbxassetid de la textura del trail (placeholder)
	Color: Color3,      -- color de la cinta (para diferenciarlos ya, aunque la textura sea placeholder)
	-- Degradado del icono en el menú. Si es nil, el cliente deriva uno claro→color→
	-- oscuro desde Color. Solo el Rainbow lo define explícito (necesita el espectro).
	Gradient: ColorSequence?,
}

local Placeholder = "rbxassetid://0"

local RainbowGradient = ColorSequence.new({
	ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
	ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 150, 0)),
	ColorSequenceKeypoint.new(0.34, Color3.fromRGB(255, 240, 0)),
	ColorSequenceKeypoint.new(0.51, Color3.fromRGB(0, 210, 0)),
	ColorSequenceKeypoint.new(0.68, Color3.fromRGB(0, 160, 255)),
	ColorSequenceKeypoint.new(0.85, Color3.fromRGB(120, 60, 255)),
	ColorSequenceKeypoint.new(1.00, Color3.fromRGB(220, 0, 255)),
})

local TrailsData = {

	-- Orden = orden de aparición en el menú (LayoutOrder)
	Trails = {
		{ Name = "Ember",     Multiplier = 2.00,  Price = 250,    Texture = Placeholder, Color = Color3.fromRGB(255, 94, 33)   },
		{ Name = "Aqua",      Multiplier = 3.50,  Price = 1000,   Texture = Placeholder, Color = Color3.fromRGB(38, 198, 218)  },
		{ Name = "Toxic",     Multiplier = 6.00,  Price = 3600,   Texture = Placeholder, Color = Color3.fromRGB(118, 255, 3)   },
		{ Name = "Voltage",   Multiplier = 9.00,  Price = 12000,  Texture = Placeholder, Color = Color3.fromRGB(255, 235, 59)  },
		{ Name = "Bubblegum", Multiplier = 12.00, Price = 40000,  Texture = Placeholder, Color = Color3.fromRGB(255, 105, 180) },
		{ Name = "Void",      Multiplier = 16.00, Price = 120000, Texture = Placeholder, Color = Color3.fromRGB(124, 77, 255)  },
		{ Name = "Frost",     Multiplier = 22.00, Price = 380000, Texture = Placeholder, Color = Color3.fromRGB(179, 229, 252) },
		{ Name = "Rainbow",   Multiplier = 30.00, Price = 900000, Texture = Placeholder, Color = Color3.fromRGB(255, 255, 255), Gradient = RainbowGradient },
	} :: { TrailData },

}

function TrailsData.getTrailData(name: string): TrailData?
	for _, trail in TrailsData.Trails do
		if trail.Name == name then return trail end
	end
	return nil
end

return TrailsData
