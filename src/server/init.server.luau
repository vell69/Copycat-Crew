local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local serviceFolder = script:FindFirstChild("Services")
local Services = serviceFolder
		and (Config.Initialization.SERVER.LOAD_DESCENDANTS and serviceFolder:GetDescendants() or serviceFolder:GetChildren())
	or {}

for _, module in ipairs(Services) do
	if module:IsA("ModuleScript") then
		local service = require(module)
		local name = module.Name

		if service.Init then
			local success, err = pcall(function()
				service:Init()
			end)

			if not success then
				warn(`[SERVER INITIALIZATION]: Failed to initialize service {name}: {err}`)
			end
		end
	end
end