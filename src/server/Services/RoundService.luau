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

function RoundService:Init(): nil
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
			print(`Waiting {Config.Round.INITIALIZATION_TIME} seconds before starting to ensure proper initialization.`)
			task.wait(Config.Round.INITIALIZATION_TIME)
		end

		local trove = Trove.new()

		for i = Config.Round.INTERMISSION_TIME, 1, -1 do
			print(`Intermission: {i}`)
			task.wait(1)
		end

		print(`Choosing random player...`)

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

		print(`Chosen player: {builder.Name}`)

		Zap.UpdateStatus.FireExcept(builder, {
			primary = "WaitingForBuilder",
			secondary = "",
		})

		local randomIndex = math.random(1, #workspace.Base.Spawns:GetChildren())
		local randomSpawn = workspace.Base.Spawns:GetChildren()[randomIndex]
		builderCharacter:PivotTo(randomSpawn.CFrame)

		Zap.ToggleBuildPhase.Fire(builder, true)

		for i = Config.Round.BUILD_TIME, 1, -1 do
			print(`Build time: {i}`)
			task.wait(1)
		end

		Zap.ToggleBuildPhase.Fire(builder, false)

		print(`Builder {builder.Name} has finished building, now teleporting players to take a glimpse.`)
		task.wait(3)

		for _, player: Player in ipairs(copiers) do
			local character = player.Character
			if not character then
				continue
			end

			character:PivotTo(
				workspace.Base.Spawns:GetChildren()[math.random(1, #workspace.Base.Spawns:GetChildren())].CFrame
			)
		end

		for i = Config.Round.GLIMPSE_TIME, 1, -1 do
			print(`Glimpse time: {i}`)
			task.wait(1)
		end

		print("Glimpse time is over, now teleporting players to copy the build.")
		task.wait(3)

		trove:Destroy()
	end
end

return RoundService
