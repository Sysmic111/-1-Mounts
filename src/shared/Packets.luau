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
	SetAgility        = Packet("SetAgility",         Packet.NumberU8),
	SetAgilityResult  = Packet("SetAgilityResult",   Packet.Boolean8, Packet.NumberU8),
	ShowRevive        = Packet("ShowRevive"),
	RequestRevive     = Packet("RequestRevive"),
	ActivateStep      = Packet("ActivateStep",  Packet.NumberU16),
	StepActivated     = Packet("StepActivated", Packet.NumberU16),
	WallHit           = Packet("WallHit"),
}
