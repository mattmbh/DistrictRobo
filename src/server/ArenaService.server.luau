local ArenaEventService = require(script.Parent:WaitForChild("ArenaEventService"))

task.spawn(function()
	ArenaEventService.Run()
end)
