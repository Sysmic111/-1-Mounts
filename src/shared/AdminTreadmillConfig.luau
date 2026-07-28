--!strict

-- Multiplicadores permitidos para el treadmill de prueba (ServerStorage.AdminAbuse.
-- Treadmill). Un solo lugar: el cliente genera los botones desde Multipliers y el
-- servidor valida contra la misma lista, así nunca se desincronizan.

local Multipliers: { number } = { 5, 10, 20, 50, 100, 200 }

local allowed: { [number]: boolean } = {}
for _, multiplier in Multipliers do
	allowed[multiplier] = true
end

return {
	Multipliers = Multipliers,
	isAllowed = function(multiplier: number): boolean
		return allowed[multiplier] == true
	end,
}
