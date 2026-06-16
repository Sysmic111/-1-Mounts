local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(ReplicatedStorage.Packages.DataService).server
local EnvironmentService = require(ServerScriptService.Environment.EnvironmentService)
local SpeedService = require(ServerScriptService.Speed.SpeedService)
local WinsService = require(ServerScriptService.Wins.WinsService)

DataService:init({
	--useMock = true,
	--resetData = true,
	--dontSave = false,
	--viewedUserId = 111,
	--overridenUserId = 111,
	template = {
		SpeedCurrency = 0,
		WinCurrency = 0,
		Level = 1,
		Rebirth = 0,
	},
})

SpeedService:init(DataService)
WinsService:init(DataService)
EnvironmentService:init()
