local ReplicatedStorage = game:GetService("ReplicatedStorage")

local client = script.Parent.Parent

local Signal = require(ReplicatedStorage.Packages.Signal)
local Zap = require(client.network)

local PlayerController = {
	Signals = {
		ToggleBuild = Signal.new(),
	},
}

function PlayerController:Init()
	Zap.ToggleBuildPhase.On(function(triggered: boolean)
		self.Signals.ToggleBuild:Fire(triggered)
	end)
end

return PlayerController
