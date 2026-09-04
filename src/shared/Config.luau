local RunService = game:GetService("RunService")

return {
	Initialization = {
		SERVER = {
			LOAD_DESCENDANTS = false,
		},

		CLIENT = {
			LOAD_DESCENDANTS = false,
		},
	},

	Round = {
		REQUIRED_PLAYERS = 2,
		INITIALIZATION_TIME = 0,
		INTERMISSION_TIME = RunService:IsStudio() and 5 or 40,
		BUILD_TIME = RunService:IsStudio() and 600 or 30,
		GLIMPSE_TIME = RunService:IsStudio() and 5 or 10,
		COPYING_TIME = RunService:IsStudio() and 30 or 60,
		BASE_SPACING = 25,
	},
}
