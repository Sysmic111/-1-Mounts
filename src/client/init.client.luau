local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(ReplicatedStorage.Packages.DataService).client

DataService:init()

print("[Client] DataService iniciado")
