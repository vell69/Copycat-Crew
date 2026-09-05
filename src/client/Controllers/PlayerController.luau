local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local statusGui = playerGui:WaitForChild("StatusGui")

local client = script.Parent.Parent

local Zap = require(client.network)

local PlayerController = {}

function PlayerController:Init()
	Zap.UpdateStatus.On(function(data: { [string]: string })
		self:UpdateStatus(data)
	end)
end

function PlayerController:UpdateStatus(data: { [string]: string })
	local main = statusGui:WaitForChild("Main")

	main.Primary.Text = data.primary
	main.Primary.Shadow.Text = data.primary

	main.Secondary.Text = data.secondary
	main.Secondary.Shadow.Text = data.secondary
end

return PlayerController
