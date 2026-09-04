local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Blocks = require(ReplicatedStorage.Shared.Blocks)
local Data = require(ReplicatedStorage.Shared.Data).server
local Zap = require(script.Parent.Parent.network)

local PlayerService = {}

local function getWorkspacePlayersFolder(): Folder
	local folder = workspace:FindFirstChild("Players")

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Players"
		folder.Parent = workspace
	end

	return folder
end

function PlayerService:Init()
	local function onPlayerAdded(player: Player)
		self:_playerAdded(player)
	end

	local function onPlayerRemoving(player: Player)
		self:_playerRemoving(player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player: Player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Zap.PlaceUnit.On(function(_player: Player, name: string, shape: string, cframe: CFrame, folder: Folder)
		local unit = Instance.new("Part")
		unit.Name = name
		unit.Color = Blocks[name].color
		unit.Size = Vector3.new(4, 4, 4)
		unit.Shape = Enum.PartType[shape]
		unit.CFrame = cframe
		unit.Anchored = true
		unit.CanCollide = true
		unit.Parent = folder
		unit:SetAttribute("id", HttpService:GenerateGUID(false))
	end)

	Zap.RemoveUnit.On(function(player: Player, unitId: string, folder: Folder)
		local unit = nil

		for _, _unit in folder:GetChildren() do
			if _unit:GetAttribute("id") == unitId then
				unit = _unit
				break
			end
		end

		if not unit then
			error(`[RemoveUnit]: {player.Name} tried to remove a non-existing block`)
			return
		end

		unit:Destroy()
	end)
end

function PlayerService:_playerAdded(player: Player)
	local playerData = Data.Service:waitForData(player)
	assert(playerData, `[Roll]: failed to fetch {player.Name}'s data`)

	local function characterAdded(character: Model)
		local playersFolder = getWorkspacePlayersFolder()
		character.Parent = playersFolder
	end

	if player.Character then
		characterAdded(player.Character)
	end

	player.CharacterAdded:Connect(characterAdded)
end

function PlayerService:_playerRemoving(_player: Player) end

return PlayerService
