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

## Multi-place / Worlds
- El juego son VARIOS places con el MISMO codebase: World 1 = `74139556114101`,
  World 2 = `88347344061446`. Un solo `default.project.json`, un solo Rojo: los dos places
  sincronizan exactamente lo mismo
- `src/shared/WorldsConfig.luau` es el **único sitio del repo que conoce PlaceIds**. Resuelve
  `game.PlaceId` UNA vez al require y cachea. Fallback a World1 con warn — en un `.rbxl` local
  sin publicar `game.PlaceId` es `0`, así que Studio cae ahí a propósito
- `WorldsConfig.Override` fuerza otro mundo para probar sin publicar. **Commitear siempre a `nil`**
- **Los dos places tienen los MISMOS nombres de Workspace** (`Stage 2`..`Stage 14`, Models
  `Steps`): "stage 5" significa cosas distintas según el place. Todo lo que dependa del stage
  va por mundo — `EconomyConfig.Worlds`, `RaceConfig.Worlds`, `ObstaclesConfig.Worlds`
- **Nunca cachear `EconomyConfig.current()` en un local de fichero.** Se llama dentro de la
  función; un alias resuelto en el require es lo que acabaría pagando tarifas de World 1 en World 2
- **World 3 = una fila en `WorldsConfig.Worlds`, una en `.Order`, y un bloque en cada config
  de balance.** Ningún servicio se toca
- **`MountsConfig.MountTiers` NO son places** — es la pestaña de tiers de monturas del Index.
  Comparte el nombre "World1" por accidente histórico y no tiene nada que ver
- El perfil es **compartido entre places** (mismo universe, ProfileStore bloquea por sesión):
  un solo `Level`, `WinCurrency`, `Rebirth`, `Mounts`, `StepsEquipped`. Es deliberado, World 2
  es continuidad. La excepción es `HighestStageReached`, que colisionaba: World 1 conserva la
  clave sin sufijo (para no invalidar datos ni dashboards) y los demás usan
  `HighestStageReached_<Key>`
- **`MessagingService` es global al universe**: Weather y los comandos cross-server de Admin
  llegan también a los servers de World 2, sin filtro de place

## Assets compartidos entre places (RojoShared)
- **Rojo es de UNA SOLA DIRECCIÓN: filesystem → Studio.** Lo que edites a mano en Studio (mover
  algo a `ServerStorage`, crear un modelo) NO vuelve a los archivos, así que el otro place no lo
  ve nunca. No existe forma de sincronizar Studio → Rojo
- El rodeo para modelos/assets es la carpeta `RojoShared/` del repo → `ReplicatedStorage.RojoShared`.
  Guardas ahí el `.rbxm` (en Studio: clic derecho → Save to File) y Rojo lo sirve en **los dos
  places** desde el mismo `default.project.json`
- Hoy contiene `Mounts.rbxm` → `ReplicatedStorage.RojoShared.Mounts`, que es de donde
  `MorphService.BuildMountRig` saca los rigs. Añadir una montura = meterla en ese `.rbxm`, no
  tocar `ServerStorage` de un place
- **TRAMPA: no puede haber a la vez `X.rbxm` y una carpeta `X/`** dentro de `RojoShared/`. Las dos
  quieren ser la misma instancia `ReplicatedStorage.RojoShared.X`, Rojo no resuelve la colisión y
  **`rojo serve` se cae con exit code 1** (pasó de verdad al crear `Mounts/` teniendo ya
  `Mounts.rbxm`). Un solo `.rbxm` ya contiene toda la jerarquía dentro: no hace falta la carpeta
- `rojo serve` **no relee `default.project.json` en caliente**, solo vigila los archivos. Si
  cambias el árbol del proyecto (feature nueva, entrada nueva), hay que reiniciar el servidor y
  reconectar el plugin, o en Studio no aparece nada
- Sigue vivo en el `.rbxl` el `ReplicatedStorage.Mounts` viejo, que ya no lee nadie: conviene
  borrarlo para no tener dos copias de 2 MB divergiendo

## Economía multi-mundo
- Los `StepsIncresement` los siembra `EconomyService` desde el config, repartidos por posición
  (ver "Atributos de Workspace"). En el `.rbxl` de un place nuevo no hay que ponerlos a mano
- **INVARIANTE: los `StepsIncresement` tienen que ser ÚNICOS entre TODOS los mundos.** La clave
  de datos es plana (`StepUnlocked_<N>`), así que un increment repetido se regalaría solo. Hay
  una aserción que revienta al cargar `EconomyConfig` si se incumple
- La **cadena de steps es GLOBAL**: `EconomyConfig.getStepChain()` une todos los mundos en orden
  de `WorldsConfig.Order`, y `StepsService` la usa para el check anti-salto. Para comprar el
  x4.000 de World 2 hacen falta los doce de World 1. **No volver a derivarla del escaneo de
  Workspace**: así es como se podía saltar World 1 entero
- `Steps` es un ARRAY ORDENADO, no un mapa: el orden ES la cadena y no se infiere de un
  `table.sort` (que solo funciona mientras los increments sean globalmente ascendentes)
- La **frontera es de ×341** (stage 14 de World 1 = 2.200 Wins → stage 2 de World 2 = 750.000)
  sobre un `WinCurrency` compartido. Por eso existe `WorldsService`
- El tramo de World 2 (niveles 131..175) **no es arbitrario**: su cadena de steps multiplica el
  ingreso ×4000 y `ln(4000)/ln(1.204) = 44.7` niveles. Si se alarga el mundo hay que pagarlo
  con más cadena de steps
- **Los 13 botones premium siguen compartiendo un único ProductId.** Ese mismo precio compra
  2 Wins en el stage 2 de World 1 y 400.000.000 en el stage 14 de World 2: todo comprador
  racional compra en el último stage del último mundo. Sin resolver

## Puerta de entrada a un mundo (WorldsService)
- Cada mundo declara `RequiresWorld`; la condición es tener **completa la cadena de steps** de
  ese mundo. Si falta alguno, `TeleportService` devuelve al jugador al mundo anterior
- **La condición son los STEPS, no el nivel**: un rebirth hecho estando en World 2 resetea
  `Level` a 1, así que un gate por nivel expulsaría al jugador legítimo. Los steps son compra
  única y sobreviven al rebirth
- En Studio **no teleporta** (no funciona entre places): avisa por consola y deja pasar
- World 1 no tiene `RequiresWorld` → ni se conecta la señal de entrada. **Pero el handler del
  menú Teleport se conecta ANTES de ese return**: World 1 es justo el mundo desde el que más se
  viaja, y dejarlo dentro del `if` lo dejaría muerto donde más falta hace

## Menú Teleport (Worlds/client)
- **Son DOS puertas y no se sustituyen.** `WorldUnlocked_<Key>` (`WorldsConfig.unlockKey`) decide
  si puede PEDIR el viaje desde el menú; `RequiresWorld` + la cadena de steps decide si puede
  ESTAR en el mundo, y se aplica AL LLEGAR, venga de donde venga (deep-link incluido)
- Por eso `_denyReason` comprueba **las dos**: un flag a true con la cadena incompleta solo
  conseguiría un viaje de ida y vuelta terminado en `Kick`
- El flag va en el **template** de datos, no on-demand como los `StepUnlocked_<N>`: el cliente
  necesita leerlo para pintar la tarjeta bloqueada sin preguntarle nada al servidor
- **Se gana pisando `Workspace.Teleport.Teleport`** con la cadena de steps de ESTE mundo completa
  (`WorldsService:_handleTeleportTouch`). Es la única forma. Desbloquea y teleporta en el mismo
  acto, reusando el camino del menú (cooldown, aviso de Studio, reintento)
- La condición es la cadena de **este** mundo, que es exactamente lo que `_enforce` va a exigir al
  llegar al otro lado: quien pasa por la parte nunca puede rebotar
- El destino **no está escrito a pelo**: `nextWorldKey()` busca el mundo cuyo `RequiresWorld` es el
  actual. La misma parte copiada al `.rbxl` de World 2 llevaría a World 3 el día que exista
- El `Touched` se conecta UNA vez al arrancar y filtra dentro (debounce de 2 s por jugador), igual
  que el HitBox del reward de Admin Abuse: dispara decenas de veces mientras estás encima
- Las tarjetas ya existen en el `.rbxl` (`Menus.Teleport.ScrollingFrame`) y se llaman EXACTAMENTE
  como el Key del mundo. Ese nombre es todo el emparejamiento: World 3 = duplicar la tarjeta en
  Studio y llamarla "World3", sin tocar el script. Una tarjeta que no case avisa por consola
- El cliente manda el **Key**, nunca un PlaceId: los PlaceIds solo los conoce `WorldsConfig`
- Solo hay packet de FALLO (`WorldTeleportFailed`). Si sale bien el jugador se va del server y no
  hay a quién contestarle
- El botón `Left.Main.Line2.Teleports` lo posee este feature. **No volver a conectarlo también en
  `Left/client`** o el menú se abriría y se cerraría en el mismo clic

## Sistema de mounts
- MorphService.MorphPlayer(player, mountName) aplica el morph — pone `player.Character = mountModel` con atributo `IsMountCharacter = true`
- Los rigs salen de `ReplicatedStorage.RojoShared.Mounts` (ver "Assets compartidos entre places")
- **`BuildMountRig` coloca la montura con `PivotTo` sobre el modelo entero, NO con
  `newHRP.CFrame = ...`.** Mover solo el HumanoidRootPart funcionaba de casualidad: los meshes van
  por Bones/Motor6D y se recolocan solos al entrar al DataModel, pero el `HitBox` se une con un
  **`WeldConstraint`**, que no guarda offset explícito — se quedaba en las coordenadas de la
  plantilla y al parentear congelaba esa separación, dejando el collider de la montura a cientos
  de studs del jugador. No revertirlo a mover una sola part
- MountsConfig.luau está en Shared (no en server) — tanto cliente como servidor lo usan
- `MountsConfig.World1` = mounts normales, `MountsConfig.Premium` = Secret Mounts del Index
- Cada mount tiene `Image: string` (rbxassetid) — cambiar los placeholders `"rbxassetid://0"` cuando haya assets
- **Dos formas de definir el multiplicador, nunca las dos a la vez**: las World1 llevan
  `Multiplier` (valor fijo); las Premium llevan `PremiumFactor`, un factor RELATIVO sobre la
  mejor World1 que el jugador **posee** (no la equipada — con una Premium puesta no hay ninguna
  World1 equipada de la que tirar). Por eso ambos campos son opcionales en `MountData`
- **Nunca leer `.Multiplier` ni `.PremiumFactor` a pelo**: usar
  `MountsConfig.getEffectiveMultiplier(name, ownedMounts)`, único sitio que resuelve cuál de los
  dos aplica. Leer el campo directo da un número equivocado para la mitad de las monturas
- Como el valor de una Premium depende de la cadena de evolves, `updateTotalMultiplier` tiene que
  correr también al evolucionar con una Premium equipada (`MountsService:_handleEvolve` ya lo hace
  en sus dos ramas)
- Los factores actuales: Vespofuzz 2x, Phantom Chopper 5x, Velune 2x, Droth 3x, Pyrax 5x,
  Vezkitt 3x. **Las dos de pago NO superan a las gratuitas** (Vespofuzz empata con Velune y pierde
  contra Droth; Phantom Chopper empata con Pyrax) — es deliberado, no un descuido
- Los carteles `Workspace.PremiumMounts.Detail<i>.SurfaceGui.Steps` ("2x Best Mount Speed") viven
  en el `.rbxl` y están a mano: si cambia un `PremiumFactor`, hay que editarlos en Studio

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

### El WalkSpeed es POR MUNDO; el coste del nivel es GLOBAL
- Son dos curvas distintas y no hay que confundirlas: `RequiredSpeedGrowth` (lo que CUESTA un
  nivel) es única para todo el juego — el perfil es compartido y `Level` es uno solo.
  `SpeedConfig.WalkSpeedCurves` (lo rápido que CORRES con ese nivel) tiene una entrada por mundo
  y se resuelve por PLACE vía `WorldsConfig.currentKey()`, igual que `EconomyConfig.current()`
- World 2 añade un **tramo de cola**: sqrt más empinado a partir del nivel 131, re-anclado al
  valor que la curva ya tenía ahí (106.0 exacto), así que la velocidad es CONTINUA en la
  frontera. Lleva de 106 a 130 en el nivel 175, donde la curva de World 1 solo daba 115.6
- La pendiente de la cola **no se escribe a mano**: se declara `TailTargetLevel` /
  `TailTargetWalkSpeed` y se deriva al cargar el módulo. Alargar el mundo = cambiar el objetivo
- **Por debajo del 131 las dos curvas coinciden a propósito.** El rebirth resetea `Level` a 1 y
  el gate del mundo es por STEPS, así que hay jugadores de nivel bajo dentro de World 2: si las
  curvas divergieran abajo, un nivel 5 correría distinto según el place
- Lo que se calibra **en runtime** contra `getWalkSpeedForLevel` (los LocalScripts de obstáculos
  de los stages) se reajusta solo al cambiar la curva. Lo que está **horneado** en un config
  (`RaceConfig.NpcSpeed`, los holds en segundos de `ObstaclesConfig`) NO — hay que rehacerlo a mano

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
- Los `StepsIncresement` **también se siembran** desde `EconomyConfig` (antes iban a mano). El
  reparto va **por POSICIÓN**, no por orden de `GetChildren()` (que es el de inserción en el
  `.rbxl` y no dice nada): de abajo arriba en Y, y dentro de cada fila de izquierda a derecha en X.
  En World 1 reproduce exactamente el reparto que ya había. **Si en un place los botones no están
  dispuestos así, el reparto sale mal** — es la única suposición de layout de todo el seeding
- Los carteles de los steps no hay que tocarlos: el cliente los escribe desde los dos atributos
  (`"+N/Steps"` y `"<n> Wins Required"`), así que sembrar el atributo actualiza el texto solo
- Fuera de este sistema (sigue a mano en Studio): los multiplicadores de treadmill
- La siembra usa el bloque del **mundo de este place**. Sembrar el mundo equivocado no da error
  en ningún sitio (los nombres de stage son idénticos), solo pagaría tarifas del otro mundo: de
  ahí los dos warnings de cobertura de `_seedStages`. **Tratar cualquiera de los dos como
  bloqueante** — significa que config y geometría discrepan sobre qué place es este

### Cómo revalidar un cambio de balance
- Hay un modelo en JS que parsea los `.luau` reales y simula un jugador (ingreso/s, compras greedy,
  playtime por sesión, 60% obby / 40% treadmill). Las mounts PERSISTEN en el rebirth: el índice de
  mount NO se resetea en la simulación. Reproducir con los hitos de arriba
- Parsear SIEMPRE solo el bloque `World1` de MountsConfig: las 5 Premium tienen
  `EvolveRequirements = nil` y un regex ingenuo las cuela como evolves gratis

## Menú Index
- Las imágenes de mounts son placeholders en MountsConfig — asignarles IDs reales
- Mounts no desbloqueadas: imagen negra (`ImageColor3 = black`), nombre `"??????"`

## Tutorial (7 pasos)
- `src/features/Tutorial/client` es **solo cliente y sin estado propio**: no hay clave de
  datos, ni packet, ni servicio. El paso se DERIVA de `Level`, `TotalWinsEarned`,
  `Mounts.Moru` y `StepUnlocked_2`. Un veterano ya los cumple todos → no ve nada, y el
  progreso sobrevive al rejoin sin persistir un baseline
- Los contadores son **absolutos** (`TotalWinsEarned >= 4`), no "3 más desde que empezó el
  paso": un baseline por paso habría que guardarlo en el perfil
- **`MountsConfig.World1[2]` (Moru) tiene `Wins = 1` POR EL TUTORIAL**, no por balance: el
  paso 2 recoge exactamente 1 win en el Stage 2 y el paso 4 lo consume. Luego el paso 5
  recoge los 3 wins del Stage 3 y el paso 6 los gasta en el step x2 (`Price = 3`). Subirlo
  rompe la cadena entera del tutorial
- El **rebirth no lo revive**: resetea `Level` a 1, pero para entonces `StepUnlocked_2` ya
  es true y ese es el corte
- La compra del step se detecta con `Packets.StepActivated`, **no** con
  `getChangedSignal({"StepUnlocked_2"})`: esa clave es plana y se crea on-demand, no está
  en el template
- El paso 3 ("abre el menú Evolve") es el único que no sale de los datos — es estado de UI
  (`MenuManager.isOpen`, señal `menuEvolve.Visible`). Cerrar el menú retrocede al paso 3
- **La textura de un `Beam` no se puede rotar**: se orienta sola a lo largo del haz y lo
  único posible es invertir el sentido intercambiando `Attachment0`/`Attachment1`. La
  flecha 2D de los pasos 3-4 sí tiene `Rotation` (`ARROW_ROTATION`)
- **`rbxassetid://133172207697852` tiene las flechas por el eje Y de la imagen** (apuntan
  hacia abajo, medido en Studio) y un Beam mapea el eje X a lo largo del haz: **salen
  perpendiculares**. El único arreglo es re-subir el asset girado 90°; al hacerlo,
  `ARROW_ROTATION` pasa de 0 a 90 para que la flecha 2D siga apuntando hacia abajo
- Los objetivos del mundo se re-resuelven en bucle cada 0.5 s en vez de una sola vez:
  con StreamingEnabled salen y entran, y `MorphService` sustituye el Character entero
  (con él, el attachment de origen del beam)

### Funnel del tutorial (`AnalyticsConfig.Funnels.Tutorial`)
- `FunnelService:_advanceTutorial` — contador monótono en `AnalyticsTutorialStep`, mismo
  patrón que `_advanceOnboarding`. **Son dos funnels distintos**: Onboarding mide hitos
  de progresión de cualquier jugador nuevo; este mide en qué paso se abandona el tutorial
  guiado, y sus 7 pasos son los 7 que el jugador ve
- **Solo cohorte "Fresh"**, igual que Onboarding: un veterano cumple las siete
  condiciones en el primer tick y se registraría un tutorial completado que nunca se le
  mostró
- El paso 4 ("Evolve Menu Opened") es el ÚNICO que el servidor no puede derivar del
  perfil — abrir un menú es estado de UI. Llega por `Packets.TutorialFunnelStep`
  (`NumberU8`), validado contra `TUTORIAL_CLIENT_STEPS` y con el mismo rate limit por
  tokens que `AnalyticsCheckoutAction`. El flag es de SESIÓN; lo que persiste es
  `AnalyticsTutorialStep`
- **Los backstops del array `requirements` (`or evolved`, `or stepBought`) no son
  decoración**: el bucle es secuencial, así que un paso que se quede en false congela el
  funnel entero. El rebirth resetea `Level` y el paso 4 depende de un packet que se puede
  perder; haber evolucionado demuestra los dos
- Se avanza desde `_setupPlayer`, `onProgressChanged`, `onMountUnlocked` y
  `onStepUnlocked` — ningún feature necesita llamarlo

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
- `"Ring"` → área con un Model `Enemy` dentro que persigue al jugador más cercano (`RingEnemyService`,
  servidor). Su velocidad es **por mundo** (`ObstaclesConfig.Ring.Speed`): World 1 = 40 fijos;
  World 2 **sin `Speed`**, o sea derivada del `Level` como Tronco y Laser (155 → 123.7)
- **Son dos diseños distintos, no dos números**: en World 1 el enemy va al 0.41 de la velocidad del
  jugador y es un estorbo de posicionamiento; en World 2 va al 1.00 de la del nivel 155 y es un
  **gate de nivel** — por debajo del 155 te alcanza, a partir de ahí le sacas ventaja. Mismo
  criterio que el Totem. Si se toca la curva de WalkSpeed de World 2, esta velocidad se mueve sola
- `"Ice"` → superficie resbaladiza (tag hardcodeado en `IceService`). Vale en una BasePart o en
  un Model (entonces resbalan todas sus partes), igual que Lava. NO usa Touched ni ningún bucle:
  baja el rozamiento con `CustomPhysicalProperties`, y las propiedades replican solas al cliente
  — por eso no hay nada en el cliente. Conserva densidad y elasticidad de la parte: solo toca
  el rozamiento. Al quitar el tag restaura lo que hubiera antes (incluido "ninguno")
- `"IceCube"` / `"IceCube2"` → **emisores**, no cubos: una BasePart que cada `Interval` s suelta
  un clon que recorre `Distance` studs y se destruye. Las dos comparten script
  (`Stages/client/IceCube.client.luau`) y se distinguen en la tabla `VARIANTS`:
  IceCube va en **−Z del mundo** a la velocidad de un jugador del `Level` (World 2 = 150 →
  121.8 studs/s); IceCube2 sube en **+Y del mundo** a `Speed = 10` fijos
- Las direcciones son ejes del **MUNDO**, no del emisor: girar la part en Studio cambia cómo se
  ve el cubo, nunca hacia dónde va
- `Speed` en `ObstaclesConfig` **manda sobre `Level`**: es para obstáculos cuyo ritmo NO debe
  seguir al jugador. Ahí el `Level` se queda solo como documentación de dónde encaja
- Los clones se taggean `"Lava"`, **pero ese tag no es lo que mata**: `LavaService` es de servidor
  y conecta `Touched` sobre instancias del servidor, así que un clon de cliente no existe para él.
  La muerte va por el patrón de Walls/Laser/Totem/Axes — detección por POSICIÓN en el cliente +
  `Packets.WallHit`, que es quien tiene la autoridad. El tag se mantiene porque describe lo que la
  part es y lo encontraría cualquier barrido de "Lava" en el cliente
- `PLAYER_RADIUS` es 2.5 en TODOS los obstáculos de cliente. Si uno se desvía, el mismo roce mata
  en un sitio y no en otro
- **`Clone()` copia los tags**: el clon del IceCube lleva `RemoveTag` obligatorio o cada cubo se
  registra como emisor nuevo y el crecimiento exponencial tumba el cliente en segundos
- Sobre el hielo, **la palanca real es `ICE_FRICTION_WEIGHT`, no `ICE_FRICTION`**: Roblox mezcla
  el rozamiento de las dos superficies ponderado por sus pesos, así que con peso 1 el 0.3 del
  personaje domina la media y no se nota nada. El peso alto (100) es lo que hace que mande el hielo

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
