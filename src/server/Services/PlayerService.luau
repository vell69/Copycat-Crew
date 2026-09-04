local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

	Zap.PlaceUnit.On(function(_player: Player, name: string, cframe: CFrame, _plot: Instance)
		local unit = Instance.new("Part")
		unit.Color = Blocks[name].color
		unit.Size = Vector3.new(4, 4, 4)
		unit.CFrame = cframe
		unit.Anchored = true
		unit.CanCollide = true
		unit.Parent = workspace
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
