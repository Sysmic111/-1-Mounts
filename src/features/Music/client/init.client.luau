--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService      = game:GetService("SoundService")

local Icon = require(ReplicatedStorage.Packages.TopbarPlus)

-- Iconos del botón. TopbarPlus no trae iconos de música: se pasan como asset id.
local ICON_SOUND_ON  = "rbxassetid://121345016428169"
local ICON_SOUND_OFF = "rbxassetid://89613622501307"

-- Se mutea el SoundGroup entero: silencia todo lo enrutado a SoundService.Music
-- de una sola vez, sin tocar los SFX.
local musicGroup = SoundService:WaitForChild("Music") :: SoundGroup

-- Volumen "encendido" capturado una vez. El fallback evita quedar atascado en 0
-- si por lo que sea el grupo arranca muteado.
local onVolume = musicGroup.Volume > 0 and musicGroup.Volume or 0.5

-- Estado por defecto (deselected) = música sonando; toggled (selected) = muteado.
local icon = Icon.new()
icon:setName("MusicToggle")
icon:setImage(ICON_SOUND_ON, "deselected")
icon:setImage(ICON_SOUND_OFF, "selected")

icon.selected:Connect(function()
	musicGroup.Volume = 0
end)

icon.deselected:Connect(function()
	musicGroup.Volume = onVolume
end)
