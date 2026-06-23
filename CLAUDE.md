# CLAUDE.md

## Flujo de trabajo
- TODO el código se edita aquí en Visual Studio Code — nunca aplicar cambios por MCP
- El MCP de Roblox Studio se puede usar SOLO para consultar/inspeccionar: estructuras de UI, jerarquía del juego, propiedades de instancias, etc.
- **PROHIBIDO** usar MCP para modificar, crear o eliminar nada en Studio — solo lectura
- Las herramientas MCP de solo lectura (list_roblox_studios, search_game_tree, inspect_instance, script_read, script_search, script_grep, get_studio_state, get_console_output, screen_capture, inspect, etc.) están SIEMPRE autorizadas — usarlas sin pedir permiso. Solo las herramientas que escriben/modifican/ejecutan (multi_edit, execute_luau, insert_asset, start_stop_play, user_*input, etc.) están prohibidas.

## Packet library (leifstout)
- SIEMPRE incluir tipos en Packet() si se envían datos: `Packet("Name", Packet.Boolean8, Packet.String)`
- Sin tipos = cero bytes transmitidos, args llegan nil — el error más común del proyecto
- `Fire(...)` = cliente→servidor o broadcast; `FireClient(player, ...)` = servidor→cliente específico
- Declarar todos los packets en `src/shared/Packets.luau`

## DataService (leifstout)
- Cliente: `DataService:get({ "Key" })`, `DataService:getChangedSignal({ "Key" }):Connect(fn)`, `DataService:waitForData()`
- Servidor: `DataService:get(player, { "Key" })`, `DataService:set(player, { "Key" }, value)`, `DataService:waitForData(player)`, `DataService:hasProfile(player)`
- Template de datos del jugador (definido en `src/server/init.server.luau`):
  `SpeedCurrency`, `WinCurrency`, `Level`, `Rebirth`, `EquippedMount`, `Mounts = { Chonk = true }`

## Arquitectura de features
- `src/features/<Feature>/server/` → ServerScriptService.<Feature> (via Rojo)
- `src/features/<Feature>/client/` → StarterPlayerScripts.<Feature>
- `src/shared/` → ReplicatedStorage.Shared
- Registrar cada feature nuevo en `default.project.json`

## Sistema de mounts
- MorphService.MorphPlayer(player, mountName) aplica el morph — pone `player.Character = mountModel` con atributo `IsMountCharacter = true`
- MountsConfig.luau está en Shared (no en server) — tanto cliente como servidor lo usan
- `MountsConfig.World1` = mounts normales, `MountsConfig.Premium` = Secret Mounts del Index
- Cada mount tiene `Image: string` (rbxassetid) — cambiar los placeholders `"rbxassetid://0"` cuando haya assets

## TotalMultiplier
- Atributo en el Player (replicado al cliente automáticamente)
- = `mountMultiplier × rebirthWinsMultiplier`
- Se recalcula en: carga de personaje, evolve exitoso, rebirth exitoso, equip manual
- El cliente lo lee con `player:GetAttribute("TotalMultiplier")`
- Speed ganado por paso = `math.ceil(TotalMultiplier)`

## Menú Index
- Las imágenes de mounts son placeholders en MountsConfig — asignarles IDs reales
- Mounts no desbloqueadas: imagen negra (`ImageColor3 = black`), nombre `"??????"`

## Animaciones de menú
- `src/shared/MenuAnimations.luau`: `open(frame)`, `close(frame, cb?)`, `blurIn()`, `blurOut()`
- Size 90%→100% Back.Out 0.25s al abrir; 100%→90% Quad.In 0.2s al cerrar
- BlurEffect "DialogueBlur" en Lighting, Size 0↔30 — NO usar TransparencyFade

## CollectionService tags en Workspace
- `"Treadmill"` → modelos de cinta; detección por posición (no Touched) en Heartbeat
- `"WinButton"` → modelos con atributo `WinsQuantity`; contienen `BasePart > SurfaceGui > TextLabel`
