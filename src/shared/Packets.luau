--!strict
local Packet = require(game.ReplicatedStorage.Packages.Packet)

--[[
	S8		Minimum: -128			Maximum: 127
	S16		Minimum: -32768			Maximum: 32767
	S24		Minimum: -8388608		Maximum: 8388607
	S32		Minimum: -2147483648	Maximum: 2147483647

	U8		Minimum: 0				Maximum: 255
	U16		Minimum: 0				Maximum: 65535
	U24		Minimum: 0				Maximum: 16777215
	U32		Minimum: 0				Maximum: 4294967295

	F16		+-2048					[65520]
	F24		+-262144				[4294959104]
	F32		+-16777216				[big]
	F64		+-9007199254740992		[huge]
]]

return {
	RequestSpeedGain  = Packet("RequestSpeedGain",  Packet.NumberF16),
	EvolveMount       = Packet("EvolveMount"),
	EvolveMountResult = Packet("EvolveMountResult", Packet.Boolean8, Packet.String),
	DoRebirth         = Packet("DoRebirth"),
	RebirthResult     = Packet("RebirthResult",     Packet.Boolean8, Packet.String),
	EquipMount        = Packet("EquipMount",         Packet.String),
	BuyHat            = Packet("BuyHat",             Packet.String),
	BuyHatResult      = Packet("BuyHatResult",       Packet.Boolean8, Packet.String),
	EquipHat          = Packet("EquipHat",           Packet.String),
	EquipHatResult    = Packet("EquipHatResult",     Packet.Boolean8, Packet.String),
	BuyTrail          = Packet("BuyTrail",           Packet.String),
	BuyTrailResult    = Packet("BuyTrailResult",     Packet.Boolean8, Packet.String),
	EquipTrail        = Packet("EquipTrail",         Packet.String),
	EquipTrailResult  = Packet("EquipTrailResult",   Packet.Boolean8, Packet.String),
	SetAgility        = Packet("SetAgility",         Packet.NumberU8),
	SetAgilityResult  = Packet("SetAgilityResult",   Packet.Boolean8, Packet.NumberU8),
	ShowRevive        = Packet("ShowRevive"),
	RequestRevive     = Packet("RequestRevive"),
	-- Lo consume Packages/AlertsModule. Sus 5 argumentos cambian de tipo según el
	-- AlertType (QuantityDivided es número o rareza, Legendary booleano o subtítulo),
	-- así que van como Any.
	Alert             = Packet("Alert", Packet.Any, Packet.Any, Packet.Any, Packet.Any, Packet.Any),
	ClaimDaily        = Packet("ClaimDaily"),
	ClaimDailyResult  = Packet("ClaimDailyResult",   Packet.Boolean8, Packet.NumberU8, Packet.String),
	ActivateStep      = Packet("ActivateStep",  Packet.NumberU16),
	StepActivated     = Packet("StepActivated", Packet.NumberU16),
	StepActivateFailed = Packet("StepActivateFailed", Packet.String),
	WallHit           = Packet("WallHit"),
	AnalyticsCheckoutAction = Packet("AnalyticsCheckoutAction", Packet.String, Packet.NumberU32, Packet.String, Packet.String),
	AnalyticsCheckoutSession = Packet("AnalyticsCheckoutSession", Packet.NumberU32, Packet.String, Packet.String),
	-- Group bonus: cliente pide verificar (sin datos); servidor responde con un status
	-- ("Granted" | "NotInGroup" | "NeedLikeRejoin" | "AlreadyClaimed").
	VerifyGroupBonus  = Packet("VerifyGroupBonus"),
	GroupBonusResult  = Packet("GroupBonusResult", Packet.String),
	-- Servidor pide al cliente lanzar el prompt nativo de favoritos (sin datos).
	PromptFavorite    = Packet("PromptFavorite"),

	-- Admin panel. El cliente solo dispara estos remotes desde el panel (que solo se
	-- construye para admins); el servidor revalida player.UserId contra AdminConfig en
	-- CADA handler, así que dispararlos a mano siendo no-admin no hace nada.
	-- targetUserId va como F64 (los UserId de Roblox superan el rango U32).
	AdminGiveMount    = Packet("AdminGiveMount", Packet.NumberF64, Packet.String),
	AdminGiveWins     = Packet("AdminGiveWins",  Packet.NumberF64, Packet.NumberF64),
	AdminSlow         = Packet("AdminSlow",       Packet.NumberF64),
	-- Ban con el sistema propio de Roblox (Players:BanAsync). duration en segundos:
	-- 86400 (1 día), 604800 (1 semana) o -1 (permanente). El servidor valida que sea
	-- uno de esos tres y que el target no sea admin.
	AdminBan          = Packet("AdminBan", Packet.NumberF64, Packet.NumberF64),
	-- Unban con el sistema propio de Roblox (Players:UnbanAsync). Por UserId (el
	-- jugador no está en la sala). El servidor valida admin + UserId válido.
	AdminUnban        = Packet("AdminUnban", Packet.NumberF64),
	-- Mensaje global admin → servidor. scope: "global" (todos los servers vía
	-- MessagingService) | "server" (este server) | "player" (targetUserId). El
	-- targetUserId va 0 salvo en "player". El servidor valida admin + longitud.
	AdminBroadcast    = Packet("AdminBroadcast", Packet.String, Packet.String, Packet.NumberF64),
	-- Servidor → cliente: mostrar el banner superior. Lleva el nombre del emisor
	-- (para pintarlo dorado), el mensaje y si el emisor está verificado (para anteponer
	-- el badge de Roblox). Lo recibe el feature Broadcast (que corren TODOS los
	-- jugadores, no solo admins).
	ShowBroadcast     = Packet("ShowBroadcast", Packet.String, Packet.String, Packet.Boolean8),

	-- Admin Abuse: el cliente admin dispara un presetId (el mensaje/duración los
	-- resuelve el SERVIDOR desde AdminAbuseConfig, nunca se confía en texto libre
	-- del cliente). Cross-server vía MessagingService, igual que AdminBroadcast.
	AdminAbuseTrigger = Packet("AdminAbuseTrigger", Packet.String),
	-- Desactiva la cuenta regresiva/mensaje activo en TODOS los servers.
	AdminAbuseCancel  = Packet("AdminAbuseCancel"),
	-- Servidor → cliente: estado actual. active=false limpia el banner. endTime es
	-- un os.time() absoluto (0 si el preset es estático, sin cuenta regresiva).
	AdminAbuseState   = Packet("AdminAbuseState", Packet.Boolean8, Packet.String, Packet.NumberF64),
}
