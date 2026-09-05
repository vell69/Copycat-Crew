local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Zap = require(script.Parent.Parent.network)

local FIRST_ROUND = true

local PityWeights = {}
local RoundService = {}

local function chooseRandomBuilder(): Player?
	local totalWeight = 0
	local weights = {}

	for _, player: Player in ipairs(Players:GetPlayers()) do
		local weight = PityWeights[player] or 1
		weights[player] = weight
		totalWeight += weight
	end

	if totalWeight <= 0 then
		return nil
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	local chosen = nil

	for _, player: Player in ipairs(Players:GetPlayers()) do
		cumulative += weights[player]
		if roll <= cumulative then
			chosen = player
			break
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player == chosen then
			PityWeights[player] = 1
		else
			PityWeights[player] = math.min((PityWeights[player] or 1) + 1, 20)
		end
	end

	return chosen
end

local function formatTime(seconds: number): string
	seconds = math.floor(seconds)
	local minutes = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%02d:%02d", minutes, secs)
end

function RoundService:Init()
	task.spawn(function()
		while true do
			if not RunService:IsStudio() then
				if #Players:GetPlayers() < Config.Round.REQUIRED_PLAYERS then
					print(`Waiting for more players.`)
					task.wait(1)
					continue
				end
			end

			if FIRST_ROUND then
				FIRST_ROUND = false
				for i = Config.Round.INITIALIZATION_TIME, 1, -1 do
					Zap.UpdateStatus.FireAll({
						primary = `Waiting {formatTime(i)}`,
						secondary = `for proper server initialization.`,
					})
					task.wait(1)
				end
			end

			local trove = Trove.new()

			for i = Config.Round.INTERMISSION_TIME, 1, -1 do
				Zap.UpdateStatus.FireAll({
					primary = `{formatTime(i)}`,
					secondary = `Intermission`,
				})
				task.wait(1)
			end

			Zap.UpdateStatus.FireAll({
				primary = `Choosing a random builder...`,
				secondary = ``,
			})

			local builder = chooseRandomBuilder()
			if not builder then
				print("No players available to choose from.")
				trove:Destroy()
				continue
			end

			local copiers = Players:GetPlayers()
			if table.find(copiers, builder) then
				table.remove(copiers, table.find(copiers, builder))
			else
				print(`Chosen player {builder.Name} is no longer in the game.`)
				trove:Destroy()
				continue
			end

			local builderCharacter = builder.Character
			if not builderCharacter then
				print(`Failed to define chosen player's character.`)
				trove:Destroy()
				continue
			end

			Zap.UpdateStatus.Fire(builder, {
				primary = `You have been chosen as a builder.`,
				secondary = ``,
			})

			local randomIndex = math.random(1, #workspace.Bases.Base.Spawns:GetChildren())
			local randomSpawn = workspace.Bases.Base.Spawns:GetChildren()[randomIndex]
			builderCharacter:PivotTo(randomSpawn.CFrame)

			workspace.Bases.Base.Name = `Base_{builder.UserId}`
			Zap.EnableBuildMode.Fire(builder)

			for i = Config.Round.BUILD_TIME, 1, -1 do
				Zap.UpdateStatus.FireAll({
					primary = `Waiting for the builder to finish`,
					secondary = `{formatTime(i)}`,
				})
				task.wait(1)
			end

			Zap.DisableBuildMode.Fire(builder)
			Zap.UpdateStatus.FireAll({
				primary = `The builder time is up.`,
				secondary = `Now teleporting other players to take a glimpse!`,
			})

			task.wait(3)

			for _, player: Player in copiers do
				local character = player.Character
				if not character then
					continue
				end

				local base = workspace.Bases:FindFirstChildOfClass("Model")
				character:PivotTo(base.Spawns:GetChildren()[math.random(1, #base.Spawns:GetChildren())].CFrame)
			end

			for i = Config.Round.GLIMPSE_TIME, 1, -1 do
				Zap.UpdateStatus.FireAll({
					primary = `{formatTime(i)}`,
					secondary = ``,
				})
				task.wait(1)
			end

			Zap.UpdateStatus.FireAll({
				primary = `Glimpse time is over`,
				secondary = `now teleporting players to copy the build!`,
			})

			task.wait(3)

			for _, player: Player in copiers do
				local character = player.Character
				if not character then
					continue
				end

				local base = workspace.Bases:FindFirstChildOfClass("Model")
				local index = #workspace.Bases:GetChildren() + 1
				local _, size = base:GetBoundingBox()
				local x = (index - 1) * (size.X + Config.Round.BASE_SPACING)

				base = base:Clone()
				base.Units:ClearAllChildren()
				base.Parent = workspace.Bases
				base.Name = `Base_{player.UserId}`
				base:PivotTo(base:GetPivot() * CFrame.new(x, 0, 0))
				character:PivotTo(base.Spawns:GetChildren()[math.random(1, #base.Spawns:GetChildren())].CFrame)
			end

			Zap.EnableBuildMode.FireList(copiers)

			for i = Config.Round.COPYING_TIME, 1, -1 do
				Zap.UpdateStatus.FireAll({
					primary = `{formatTime(i)}`,
					secondary = ``,
				})
				task.wait(1)
			end

			Zap.DisableBuildMode.FireList(copiers)

			Zap.UpdateStatus.FireAll({
				primary = `Copying time is over`,
				secondary = `now restarting the round!`,
			})

			task.wait(3)

			Zap.UpdateStatus.FireAll({ primary = ``, secondary = `` })

			for _, player: Player in Players:GetPlayers() do
				player:LoadCharacterAsync()
			end

			workspace.Bases:ClearAllChildren()
			trove:Destroy()
		end
	end)
end

return RoundService
