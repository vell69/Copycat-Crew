opt server_output = "src/server/network.luau"
opt client_output = "src/client/network.luau"

-- [[EVENTS]] --

event UpdateStatus = {
	from: Server,
	type: Reliable,
	call: ManyAsync,
	data: struct {
        primary: string.utf8,
        secondary: string.utf8?,
    }
}

event ToggleBuildPhase = {
	from: Server,
	type: Reliable,
	call: ManyAsync,
	data: (boolean)
}