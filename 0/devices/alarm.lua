local api, device = ...

device.activate = function (state)
	device:remoteExecute(function (state)
		rs.setOutput("top", state)
	end, state)
end

api.onReady(function ()
	device.activate(false)
end)

return true
