-- Signal - Minimal stub
local Signal = {}
Signal.__index = Signal

function Signal.new()
    local self = setmetatable({}, Signal)
    self._connections = {}
    return self
end

function Signal:Connect(callback)
    local connection = {
        Connected = true,
        _callback = callback,
        _signal = self,
    }
    
    function connection:Disconnect()
        self.Connected = false
    end
    
    table.insert(self._connections, connection)
    return connection
end

function Signal:Fire(...)
    for _, connection in ipairs(self._connections) do
        if connection.Connected then
            connection._callback(...)
        end
    end
end

return Signal
