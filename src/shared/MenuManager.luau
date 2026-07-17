--!strict

-- Dueño único del menú abierto en el cliente.
--
-- Antes cada feature llevaba su propio `isOpen` local (Left tenía `openMenu` para
-- Evolve/Rebirth/Index, y Hats, Trails y Daily uno cada uno), así que ninguno
-- sabía de los otros y los menús se apilaban unos encima de otros.
--
-- Esto funciona porque los ModuleScripts se cachean por VM: todos los
-- LocalScripts del cliente comparten esta misma tabla al requerirla.
--
-- Solo para menús centrales excluyentes. NO usar para el tooltip de PlayTime
-- (panel lateral sin blur) ni para Notification (alerta que va deliberadamente
-- por encima del menú abierto).

local MenuAnimations = require(script.Parent.MenuAnimations)

export type MenuOptions = {
	onOpen: (() -> ())?,
	-- Se llama al cerrar, venga el cierre de donde venga (botón de cerrar, o que
	-- el jugador abriera otro menú). Aquí va la limpieza de tweens/conexiones.
	onClose: (() -> ())?,
}

local MenuManager = {}

local current: Frame? = nil
local currentOnClose: (() -> ())? = nil
local blurred = false

local function setBlur(on: boolean)
	if on == blurred then return end
	blurred = on
	if on then
		MenuAnimations.blurIn()
	else
		MenuAnimations.blurOut()
	end
end

-- Cierra el actual sin tocar el blur (quien llama decide qué hacer con él, para
-- que al cambiar de menú no parpadee).
local function closeCurrent()
	local frame = current
	if not frame then return end

	local onClose = currentOnClose
	current = nil
	currentOnClose = nil

	MenuAnimations.close(frame)
	if onClose then onClose() end
end

function MenuManager.isOpen(frame: Frame): boolean
	return current == frame
end

function MenuManager.isAnyOpen(): boolean
	return current ~= nil
end

function MenuManager.open(frame: Frame, options: MenuOptions?)
	if current == frame then return end

	-- Cerrar el que hubiera: el blur se queda puesto entre uno y otro.
	closeCurrent()

	current = frame
	currentOnClose = options and options.onClose or nil

	setBlur(true)
	MenuAnimations.open(frame)

	if options and options.onOpen then
		options.onOpen()
	end
end

function MenuManager.close(frame: Frame)
	if current ~= frame then return end
	closeCurrent()
	setBlur(false)
end

function MenuManager.closeAll()
	closeCurrent()
	setBlur(false)
end

function MenuManager.toggle(frame: Frame, options: MenuOptions?)
	if current == frame then
		MenuManager.close(frame)
	else
		MenuManager.open(frame, options)
	end
end

-- Para overlays que no gestiona el manager (Notification): al cerrarse deben
-- quitar el blur solo si no queda ningún menú detrás.
function MenuManager.refreshBlur()
	setBlur(current ~= nil)
end

return MenuManager
