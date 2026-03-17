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
        if not self.Connected then return end
        self.Connected = false
        local signal = self._signal
        if not signal or not signal._connections then return end
        for i = #signal._connections, 1, -1 do
            if signal._connections[i] == self then
                table.remove(signal._connections, i)
                break
            end
        end
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
