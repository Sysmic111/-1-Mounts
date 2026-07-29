# AGENTS.md

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
- Template de datos del jugador: definido en `src/server/init.server.luau` (fuente de verdad).
  Progresión: `SpeedCurrency`, `WinCurrency`, `Level`, `Rebirth`, `EquippedMount`,
  `Mounts = { Chonk = true }`. Compras: `Treadmill<Tier>`, `Hats`/`EquippedHat`,
  `Trails`/`EquippedTrail`, `StepsEquipped`, `StarterPackBought`. Daily: `DailyClaimedDay`,
  `DailyLastClaimDate`
- El rebirth SOLO resetea `Level` y `SpeedCurrency`. Todo lo demás se conserva: `WinCurrency`,
  las mounts (todas, incluidas Premium y las del Daily), la montura equipada, hats, trails y steps
- Los `StepUnlocked_<N>` son claves planas creadas on-demand al comprar; solo `StepUnlocked_1`
  está en el template

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
- Los multiplicadores se **SUMAN** entre sí; SOLO el rebirth multiplica el total:
  `total = (1 + (mount-1) + (playtime-1) + (hat-1) + (trail-1) + (speedBoost-1) + (friends-1) + (group-1) + (weather-1)) × rebirthMultiplier`
- Cada fuente aporta su "+X" sobre una base de 1; el rebirth es la mecánica de prestigio que
  multiplica todo lo acumulado. **NO volver a multiplicar los factores entre sí** (rompe el balance)
- Se calcula en UN solo sitio: `SpeedService:_updateTotalMultiplier`. Los clientes solo LEEN el
  atributo (`player:GetAttribute("TotalMultiplier")`), nunca recalculan
- Se recalcula en: carga de personaje, evolve, rebirth, equip de mount/hat/trail, tiers de playtime,
  compra de Speed Tier, entrada/salida de amigos, claim del group bonus, y activar/quitar un
  weather event
- Speed ganado por paquete = `math.ceil(TotalMultiplier × EquippedSteps × treadmillMultiplier)`
- Los steps y el treadmill NO están dentro de TotalMultiplier: multiplican aparte en `SpeedService`

## Weather Events
- Evento global que activa un admin desde el panel (`WeatherConfig.Presets`: Thunderstorm,
  Blizzard, Blood Moon, Aurora). **No caduca solo**: queda activo hasta que alguien pulse
  "Remove weather"
- El bonus viaja por **atributos de Player**, no por wiring de servicios (mismo canal que
  `FriendsBoost`): `WeatherBoost` lo SUMA `SpeedService`, `WeatherWinsBoost` lo MULTIPLICA
  `WinsService:_creditWins`. Ambos valen 1 sin evento
- Es la **única fuente que además multiplica Wins** fuera del rebirth. Por eso `WeatherConfig`
  lleva dos números distintos: un `Multiplier` de Speed vistoso (x2..x10, aditivo, se diluye en
  late-game) y un `WinsMultiplier` mucho más contenido (x1.25..x3, multiplicativo de verdad).
  **No igualarlos**: un x10 multiplicativo sobre Wins se come la cadena de evolves entera
- Tres capas de propagación, y hacen falta las tres: `Packets.WeatherState` (este server),
  `MessagingService` (los demás servers vivos) y un DataStore (`WeatherEvent`/`Current`, para
  los servers que arranquen DESPUÉS). Sin la tercera, un server nuevo levantaría sin el weather
- El cliente (`src/features/Weather/client`) toma un **snapshot de Lighting al arrancar** y lo
  restaura al quitar el evento. Tweenea las instancias que YA existen en el `.rbxl`
  (`Atmosphere`, `ColorCorrection`, `Bloom`, `Sky`) — no crea las suyas, salvo el
  `ColorCorrectionEffect` "WeatherFlash" de los rayos, que va aparte para no pelear con el tween
- **NO tocar el `BlurEffect` "DialogueBlur"**: es de `MenuManager`/`MenuAnimations`
- Las partículas son un `Part` invisible parented a la `Camera`, reposicionado en `RenderStepped`
  para seguir al jugador. Al cambiar de weather se apaga la emisión y se destruye con delay, o
  la lluvia desaparecería en un frame
- Los `Skybox` de los presets son `nil` a propósito (placeholders, como los `rbxassetid://0` de
  `MountsConfig`): sin ellos el evento se ve igual de bien solo con atmósfera + `ClockTime` + tint
- El label `Bot.Content."Current Event"` (que vive en el `.rbxl`) lo posee este feature en
  exclusiva; vacío = sin evento

## Eventos globales: el patrón de las 3 capas
- Lo comparten Admin Abuse, Weather, el Reward de Vezkitt y el Test Treadmill. Un evento global NO se
  propaga solo con `MessagingService`: ese solo llega a los servers **vivos en el momento
  del publish**. Durante un evento entra una avalancha de gente y Roblox abre servers
  nuevos justamente por eso — sin la capa de DataStore, los jugadores que vienen AL evento
  son los únicos que no lo ven
- Las tres capas: `MessagingService` (servers vivos) + DataStore (los que arranquen
  después) + un `os.time()` **absoluto** guardado como estado (que todos cierren a la vez)
- Guardar el instante de cierre y no un booleano da tres cosas gratis: un estado caducado
  se lee solo como "cerrado" (no hay que limpiar la clave), cada server programa su propio
  `task.delay` de cierre sin que nadie publique nada, y un server que arranca a mitad
  recibe el tiempo restante correcto
- Todos llevan un tope de seguridad (3h) para que un admin olvidadizo no deje contenido
  exclusivo —o una cinta x100— abierto para siempre en servers que nadie supervisa
- El emisor ignora su propio eco con `if data.j == game.JobId then return end`, y lo que
  llega por el topic o por el DataStore **se revalida contra el config** antes de aplicarse
- En Admin Abuse hay DOS instantes y no son lo mismo: `endTime` es cuándo la cuenta regresiva
  del banner llega a 0 (y el banner se queda, sin reloj: "admin abuse in" → ocurre ahora),
  y `expiresAt` es cuándo se deja de anunciar. Los presets estáticos ("happening now") tienen
  `endTime = 0` pero sí `expiresAt`, o quedarían anunciándose para siempre
- Reenviar el estado en `PlayerAdded` cubre a los **jugadores** que entran tarde a un server
  que ya lo tenía; no cubre a los **servers** que nacen tarde. Son dos agujeros distintos y
  hacen falta los dos arreglos

## Reward de Admin Abuse (Vezkitt)
- `Workspace.AdminUtils`: un obby detrás de un `Barrier`, con un `Reward` (rig con un
  Part `HitBox`) al final que concede la montura `Vezkitt`. Es la ÚNICA forma de conseguirla
- Abrir mueve el `Barrier` a `ServerStorage.AdminAbuse` y lo devuelve al cerrar: al ser el
  MISMO objeto conserva su posición exacta (igual que el treadmill de prueba)
- El `Touched` del HitBox se conecta UNA vez al arrancar y consulta el flag `_rewardActive`.
  No se conectan/desconectan señales al abrir y cerrar. Antes de conceder comprueba si el
  jugador ya la tiene: el `Touched` dispara decenas de veces mientras estás encima
- **El estado se guarda como un `os.time()` absoluto de cierre, no como un booleano**, y va
  por tres capas: `MessagingService` (servers vivos) + DataStore `AdminReward`/`OpenUntil`
  (los que arranquen después) + el instante absoluto (todos cierran a la vez). La capa del
  DataStore NO es opcional: durante un evento Roblox abre servers nuevos justamente porque
  entra una avalancha de gente, y sin ella esos jugadores —los que vienen al evento— se
  encuentran el obby cerrado
- Cada server programa su propio `task.delay` de auto-cierre contra ese mismo instante, así
  que nadie tiene que publicar el cierre. `REWARD_MAX_OPEN_SECONDS` (3h) es el tope de
  seguridad para que un admin olvidadizo no deje contenido exclusivo abierto para siempre

## Economía / balance

### Forma del juego
- El recorrido es el rango de niveles **1..130** (nivel 130 = se pasa el stage 14), con **8 rebirths**
- Duración objetivo ~9h. Hitos simulados: R1 a los ~18 min, R8 a las 6.7h, nivel 130 a las 8.65h
  con las 20 mounts de World1 y los 12 steps buttons
- Un "ciclo" = subir de nivel 1 al nivel que pide el siguiente rebirth. El rebirth SOLO resetea
  `Level` y `SpeedCurrency`: las **mounts PERSISTEN** (y con ellas su multiplicador), igual que
  `WinCurrency`, hats, trails y steps
- Reparto de niveles: rebirths 40→125, evolves de mounts 5→126, stages 2→14 mapeados a nivel 1→130
  (el mapa stage→nivel está comentado en `EconomyConfig.luau`; no se aplica por código, la dificultad
  es geometría)

### La curva de niveles es EXPONENCIAL a propósito
- `req(L) = floor(8 × 1.200^(L-1))` en `SpeedConfig.getRequiredSpeedForLevel`
- **No volver a una curva polinómica.** El ingreso dentro de un ciclo sigue creciendo mucho aunque
  los multiplicadores sumen (steps 1→2000 multiplican aparte, base aditiva 1→~100, rebirth 1→26). La
  curva vieja (`5 × L^1.45`) solo crecía ×10 entre el nivel 50 y el 130 y quedaba pulverizada
- `SpeedConfig.RequiredSpeedGrowth` es la palanca de duración total (modelo ADITIVO, mounts
  persistentes): 1.19 → ~5.6h, 1.20 → ~8.65h, 1.205 → ~11.2h. Es lo único que hay que tocar para
  reajustar el ritmo global. OJO: este valor es para el modelo aditivo; con el multiplicativo viejo
  era 1.230. Subir los Wins de los evolves NO es la palanca: las mounts son el motor del
  ingreso y encarecerlas frena todo el juego (medido: 15-21h y sin completar la cadena)
- Números grandes (~3.2e12 en el nivel 130) son normales: la UI ya formatea con K/M/B

### Cosas que no son obvias y rompen el balance si se olvidan
- El `WinsMultiplier` del rebirth se aplica **dos veces**: a los Wins en `WinsService:_creditWins`
  y al Speed dentro del `TotalMultiplier`. Por eso el techo es x26 y no x248
- La tasa de paquetes se satura a **10/s cuando WalkSpeed ≥ 50, o sea nivel 34**. A partir de ahí
  subir de nivel NO acelera el farmeo; solo lo hacen los multiplicadores
- El evolve **consume Wins** pero solo **requiere** Level. Como las mounts persisten, la cadena es
  una **compra única** (1.138.230 Wins en total): el mayor sink del juego, pero no recurrente. Tras
  completarla, los únicos sinks de Wins que quedan son los cosméticos top (hat Dev, Frost/Rainbow) —
  contenido nuevo de Wins debería tenerlo en cuenta
- Evolucionar hacia una montura **ya poseída** re-equipa gratis (fast-path en
  `MountsService:_handleEvolve`, espejado en el `canEvolve` del cliente). Sin él, se cobraría dos
  veces la misma montura
- Los gates de Level reparten la cadena entre ciclos sin re-espaciarla: cada ciclo llega más alto
  (40, 55, 68… 130), así que Raiketsu cae en el ciclo 1 y Nyxion solo en el final
- Regalar Speed crudo (Daily, StarterPack) escribe `SpeedCurrency` sin pasar por `_addSpeed`: el
  level-up se resuelve en el siguiente paquete de movimiento. Una cantidad fija de Speed caduca
  rápido en una curva exponencial — para premios permanentes usar Wins

### Atributos de Workspace: sembrar, no editar a mano
- Los `WinsQuantity` de stages y steps buttons son atributos de Workspace: **NO editarlos en Studio**.
  Se siembran desde `EconomyConfig.luau` vía `EconomyService:seedWorkspace()` para que el balance
  se versione en git y no en el `.rbxl`
- `EconomyService:seedWorkspace()` DEBE correr antes de `WinsService:init` y `StepsService:init` —
  ambos leen esos atributos una sola vez y los cachean (`buildStepsMap` nunca re-escanea)
- Fuera de este sistema (siguen a mano en Studio): multiplicadores de treadmill y `StepsIncresement`

### Cómo revalidar un cambio de balance
- Hay un modelo en JS que parsea los `.luau` reales y simula un jugador (ingreso/s, compras greedy,
  playtime por sesión, 60% obby / 40% treadmill). Las mounts PERSISTEN en el rebirth: el índice de
  mount NO se resetea en la simulación. Reproducir con los hitos de arriba
- Parsear SIEMPRE solo el bloque `World1` de MountsConfig: las 5 Premium tienen
  `EvolveRequirements = nil` y un regex ingenuo las cuela como evolves gratis

## Menú Index
- Las imágenes de mounts son placeholders en MountsConfig — asignarles IDs reales
- Mounts no desbloqueadas: imagen negra (`ImageColor3 = black`), nombre `"??????"`

## Animaciones de menú
- `src/shared/MenuAnimations.luau`: `open(frame)`, `close(frame, cb?)`, `blurIn()`, `blurOut()`
- Size 90%→100% Back.Out 0.25s al abrir; 100%→90% Quad.In 0.2s al cerrar
- BlurEffect "DialogueBlur" en Lighting, Size 0↔30 — NO usar TransparencyFade

## Menús excluyentes (MenuManager)
- `src/shared/MenuManager.luau` es el dueño ÚNICO del menú abierto: `toggle(frame, opts?)`,
  `open`, `close`, `closeAll`, `isOpen(frame)`, `isAnyOpen()`, `refreshBlur()`
- Todo menú central NUEVO debe abrirse con MenuManager. NO declarar un `isOpen` local ni llamar
  a `MenuAnimations.blurIn/blurOut` a mano: así es como los menús acababan apilándose
- `opts.onOpen` para poblar el menú; `opts.onClose` para limpiar tweens/conexiones (lo llama
  también cuando el cierre lo provoca que el jugador abra otro menú — ver el Revive de Stages)
- Funciona porque los ModuleScripts se cachean por VM: todos los LocalScripts comparten la tabla
- Excepciones deliberadas: `Notification` (alerta que va por encima del menú; al cerrarla llamar
  a `MenuManager.refreshBlur()`) y el tooltip de PlayTime (panel lateral sin blur)

## Indicador "!" (NotifyBadge)
- `src/shared/NotifyBadge.luau`: `get(button)` / `setVisible(button, visible)` — badge rojo por código
- Lo usan los botones Daily (claim disponible), Evolve y Rebirth (acción disponible)
- Las condiciones del badge en el cliente son ESPEJO de las del servidor
  (`MountsService:_handleEvolve`, `RebirthService:_handleRebirth`) — si cambian allí, cambiarlas aquí

## Robux / Developer Products
- `ProcessReceipt` es único en el juego y lo posee `RobuxService`, que actúa de **router**.
  Un feature nuevo con producto NO toca ProcessReceipt: llama a
  `robuxService:registerProduct(productId, handler)` en su `init`
- El handler corre con el perfil ya cargado y debe ser **idempotente**: Roblox reintenta los recibos.
  Patrón: comprobar el flag de propiedad, marcarlo ANTES de acreditar, devolver `PurchaseGranted`
- El cliente solo lanza `MarketplaceService:PromptProductPurchase`. Nunca concede nada
- No hay gamepasses en el proyecto, solo Developer Products
- ProductIds: treadmills Gold/Diamond/Emerald/Ruby (`RobuxConfig`), mounts Premium Vespofuzz y
  Phantom Chopper (`MountsConfig.Premium`), botón premium de Wins (`WinsConfig.PremiumProductId`,
  uno solo compartido por los 13 → su valor debe escalar con el stage), StarterPack
  (`StarterPackConfig`)
- Los precios en Robux viven en la web de Roblox; los `Price.Title` de la UI son cosméticos y pueden
  desincronizarse

## Daily Login
- El día se decide por **fecha UTC absoluta** (`floor(os.time() / 86400)`), NO por "24h desde el claim":
  reclamar a las 23:50 UTC permite volver a reclamar a las 00:10 UTC
- Saltarse días no reinicia la racha, solo la retrasa. Día 22 = repetible indefinidamente
- El servidor es la única fuente de verdad del calendario: el cliente solo pide "claim"
- Las mounts de los días 7/14/21 (Velune, Droth, Pyrax) están en `MountsConfig.Premium` sin ProductId
  → no son comprables, solo salen del Daily. Como las mounts persisten tras el rebirth, son permanentes

## StarterPack
- Oferta única (`StarterPackBought`). Al comprarse se oculta el botón `Right.Main.Line1.Starter`
- Sus dos cards están hechas a mano en Studio, comparten nombre y `LayoutOrder`: se distinguen por
  su icono (`StarterPackConfig.WinsIcon` / `SpeedIcon`) y el config manda sobre el `RewardText`

## CollectionService tags en Workspace
- `"Treadmill"` → modelos de cinta; detección por posición (no Touched) en Heartbeat
- `"WinButton"` → modelos con atributo `WinsQuantity`; contienen `BasePart > SurfaceGui > TextLabel`
- `"StepButton"` → lo usa el cliente de Steps. OJO: el servidor NO usa el tag, filtra por
  `Name == "Steps"` dentro de `Workspace.StepsButtons`. Un botón tageado pero fuera de esa carpeta
  se ve y se puede pisar, pero el servidor lo rechaza
- `"Lava"` → kill brick (tag hardcodeado en `LavaService`)

## Trampas conocidas (sin arreglar)
- **Treadmill validado por máximo global**: `getMaxTreadmillMultiplier` comprueba si el jugador
  *puede* usar un multiplicador, no si está encima de esa cinta. Con Ruby comprado se puede reclamar
  x100 estando en una x1. Distorsiona cualquier medición de tiempos.
  **Ojo ahora que el treadmill de admin es cross-server**: soltar una cinta x100 sube el techo de
  TODO el juego, y como no hace falta pisarla, basta con que exista. De ahí el tope de 3h
- **`RequestSpeedGain` sin validación de posición**: el servidor solo aplica rate limit (10/s) y el
  clamp de treadmill. Un cliente puede spamear el paquete quieto
- **`WallHit`**: remote sin validación; el cliente puede pedir su propia muerte
- **El treadmill de `Rebirth=1` da x1**, igual que el gratuito (mejora muerta), y la rama de rebirth
  se corta en x4 (Rebirth=3)
- **Posible desincronía repo/place**: se han visto números en el juego que no cuadran con las
  fórmulas del repo. Ante resultados raros en un playtest, verificar que Rojo esté sincronizado antes
  de tocar el balance
