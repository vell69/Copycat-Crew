local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local initializedModules = {}

local function initializeModule(module)
	local modulePath = module:GetFullName()
	if initializedModules[modulePath] then
		return
	end

	initializedModules[modulePath] = true

	local success, controller = pcall(require, module)
	local name = module.Name

	if not success then
		warn(`[CLIENT INITIALIZATION]: Failed to require controller {name}: {controller}`)
		return
	end

	if type(controller) == "table" and type(controller.Init) == "function" then
		local ok, err = pcall(function()
			controller:Init()
		end)

		if not ok then
			warn(`[CLIENT INITIALIZATION]: Failed to initialize controller {name}: {err}`)
		end
	end
end

local controllerFolder = script:FindFirstChild("Controllers")
local controllers = controllerFolder
		and (Config.Initialization.CLIENT.LOAD_DESCENDANTS and controllerFolder:GetDescendants() or controllerFolder:GetChildren())
	or {}

for _, module in ipairs(controllers) do
	if module:IsA("ModuleScript") then
		initializeModule(module)
	end
end