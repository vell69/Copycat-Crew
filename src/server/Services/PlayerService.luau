local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Shared.Data).server

local PlayerService = {}

local function getWorkspacePlayersFolder()
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
end

function PlayerService:_playerAdded(player: Player)
	local playerData = Data.Service:waitForData(player)
	assert(playerData, `[Roll]: failed to fetch {player.Name}'s data`)

	print(playerData.Money())

	local function characterAdded(character: Model)
		local playersFolder = getWorkspacePlayersFolder()
		character.Parent = playersFolder
	end

	if player.Character then
		characterAdded(player.Character)
	end

	player.CharacterAdded:Connect(characterAdded)
end

function PlayerService:_playerRemoving(_player: Player)

end

return PlayerService