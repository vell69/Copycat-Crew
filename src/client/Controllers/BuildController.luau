local client = script.Parent.Parent

local PlayerController = require(client.Controllers.PlayerController)

local BuildController = {
	CanBuild = false,
	SelectedUnit = nil,
}

function BuildController:Init()
	PlayerController.Signals.ToggleBuild:Connect(function(triggered: boolean)
		self.CanBuild = triggered
		print(self.CanBuild)
	end)
end

return BuildController
