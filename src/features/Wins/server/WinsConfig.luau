--!strict

local WinsConfig = {
	Debug = true,

	TagName = "WinButton",
	TouchPartName = "TouchPart",
	WinsQuantityAttribute = "WinsQuantity",

	-- Botones premium: atributo Premium=true → se cobra un Developer Product
	-- (consumible) cada vez que se quiere reclamar el botón.
	PremiumAttribute = "Premium",
	PremiumProductId = 3606256299,
	PremiumPromptCooldownSeconds = 2, -- evita spam del prompt al estar parado encima

	TouchDebounceSeconds = 1,
	SpawnTeleportOffset = Vector3.new(0, 5, 0),
}

return WinsConfig
