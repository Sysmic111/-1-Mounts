--!strict

-- Presets del panel "Admin Abuse". Config-driven a propósito: agregar un botón
-- nuevo es agregar una entrada acá, sin tocar el UI ni el server.
-- DurationSeconds == 0 => mensaje estático (sin cuenta regresiva), ej. "happening now".
-- DurationSeconds > 0  => cuenta regresiva en vivo desde ese valor hasta 0.

export type Preset = {
	Id: string,
	ButtonLabel: string,
	Message: string, -- Todos los mensajes van en inglés (ver AGENTS.md).
	DurationSeconds: number,
}

local Presets: { Preset } = {
	{
		Id = "warning_10m",
		ButtonLabel = "Warning: 10 minutes",
		Message = "Admin abuse in",
		DurationSeconds = 600,
	},
	{
		Id = "warning_5m",
		ButtonLabel = "Warning: 5 minutes",
		Message = "Admin abuse in",
		DurationSeconds = 300,
	},
	{
		Id = "happening_now",
		ButtonLabel = "Happening now!",
		Message = "Admin abuse happening now!",
		DurationSeconds = 0,
	},
}

local byId: { [string]: Preset } = {}
for _, preset in Presets do
	byId[preset.Id] = preset
end

return {
	Presets = Presets,
	byId = byId,
}
