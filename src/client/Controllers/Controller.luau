local Players = game:GetService("Players")
local player = Players.LocalPlayer

local PlayerController = {}

function PlayerController:Init()
	print(`{player.Name} controller initialized`)
end

return PlayerController