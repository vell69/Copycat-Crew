opt server_output = "src/server/network.luau"
opt client_output = "src/client/network.luau"

-- [[EVENTS]] --

event UpdateStatus = {
	from: Server,
	type: Reliable,
	call: ManyAsync,
	data: struct {
        primary: string.utf8,
        secondary: string.utf8,
    }
}

event EnableBuildMode = {
	from: Server,
	type: Reliable,
	call: ManyAsync,
	data: (plot: Instance.Part)
}

event DisableBuildMode = {
	from: Server,
	type: Reliable,
	call: ManyAsync
}

event PlaceUnit = {
	from: Client,
	type: Reliable,
	call: ManyAsync,
	data: (unitName: string.utf8, unitCFrame: CFrame, plot: Instance.Part)
}

event RemoveUnit = {
	from: Client,
	type: Reliable,
	call: ManyAsync,
	data: (unitName: string.utf8, unitCFrame: CFrame)
}