-- Iris - Minimal stub
local Iris = {}

local isConnected = false

function Iris.Init()
    print("[Iris] Initialized")
end

function Iris.Connect(callback)
    print("[Iris] Connect called, but Iris is a stub - skipping callback")
    -- Don't actually run the callback since we don't have a real Iris implementation
end

function Iris.State(initialValue)
    local state = {
        value = initialValue,
    }
    
    function state:get()
        return self.value
    end
    
    function state:set(newValue)
        self.value = newValue
    end
    
    return state
end

function Iris.Window(config)
    return {
        Name = config[1] or "Window",
    }
end

function Iris.End()
end

function Iris.Text(config)
    return {
        Text = config[1] or "",
    }
end

function Iris.Button(config)
    return {
        Label = config[1] or "Button",
        clicked = function() return false end,
    }
end

function Iris.Separator()
end

function Iris.Checkbox(config)
    return {
        checked = function() return false end,
    }
end

return Iris
