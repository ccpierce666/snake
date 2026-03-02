-- Roact - Minimal stub with real rendering
local Roact = {}
Roact.Component = {}
Roact.Component.__index = Roact.Component

-- Event mapping support
Roact.Event = setmetatable({}, {
    __index = function(_, key) return key end
})

function Roact.Component:extend(name)
    local class = setmetatable({}, self)
    class.__index = class
    class.__name = name
    return class
end

function Roact.Component:new(...)
    local instance = setmetatable({}, self)
    instance.state = {}
    instance:init(...)
    return instance
end

function Roact.Component:init()
end

function Roact.Component:setState(newState)
    for k, v in pairs(newState) do
        self.state[k] = v
    end
end

function Roact.Component:didMount()
end

function Roact.Component:willUnmount()
end

function Roact.Component:render()
    return nil
end

-- Real element creation
function Roact.createElement(componentType, props, children)
    return {
        _type = componentType,
        _props = props or {},
        _children = children or {},
    }
end

-- Fragment support
local Fragment = "__ROACT_FRAGMENT__"
Roact.createFragment = function(children)
    return {
        _type = Fragment,
        _children = children or {}
    }
end

-- Real mounting with actual UI rendering
function Roact.mount(element, parent, key)
    if not element then return nil end
    
    -- Handle Fragments
    if element._type == Fragment then
        local lastInstance = nil
        for k, child in pairs(element._children) do
            lastInstance = Roact.mount(child, parent, k)
        end
        return lastInstance
    end
    
    if type(element._type) == "string" then
        -- Built-in Roblox class (e.g., "Frame", "ScreenGui")
        local success, instance = pcall(function() return Instance.new(element._type) end)
        if not success then 
            warn("[Roact] Failed to create instance of type:", element._type)
            return nil 
        end
        
        -- Set properties and events
        for prop, value in pairs(element._props) do
            if prop:sub(1, 1) ~= "_" then
                local isEvent = false
                
                -- Detect and connect events
                if type(value) == "function" then
                    local eventObj = nil
                    -- Try common event names or if it's explicitly an event key
                    pcall(function() eventObj = instance[prop] end)
                    
                    if typeof(eventObj) == "RBXScriptSignal" then
                        print("[Roact] Connecting event:", element._type .. "." .. prop)
                        eventObj:Connect(value)
                        isEvent = true
                    elseif prop == "Activated" or prop == "MouseButton1Click" then
                        -- Fallback for common events if instance[prop] failed but we know it should exist
                        pcall(function()
                            instance[prop]:Connect(value)
                            print("[Roact] Fallback Connecting event:", element._type .. "." .. prop)
                            isEvent = true
                        end)
                    end
                end

                if not isEvent then
                    pcall(function()
                        instance[prop] = value
                    end)
                end
            end
        end
        
        -- Add children
        if element._children then
            for key, child in pairs(element._children) do
                if child then
                    local childInstance = Roact.mount(child, instance, key)
                    if childInstance and typeof(childInstance) == "Instance" then
                        childInstance.Parent = instance
                    elseif childInstance and type(childInstance) == "table" and childInstance._instance then
                        -- For component results that return an instance
                        childInstance._instance.Parent = instance
                    end
                end
            end
        end
        
        if parent then
            instance.Parent = parent
        end
        return instance
    elseif type(element._type) == "function" then
        -- Functional Component
        local renderResult = element._type(element._props, element._children)
        if renderResult then
            return Roact.mount(renderResult, parent, key)
        end
        return nil
    else
        -- Component (user-defined class)
        local component = element._type:new()
        component.props = element._props
        component.children = element._children
        
        -- Call didMount
        if component.didMount then
            pcall(function() component:didMount() end)
        end
        
        -- Get render result
        local renderResult = component:render()
        
        if renderResult then
            local instance = Roact.mount(renderResult, parent, key)
            -- Store instance on component for later
            component._instance = instance
            return instance
        end
        
        return component
    end
end

function Roact.unmount(handle)
    if not handle then return end
    if typeof(handle) == "Instance" then
        handle:Destroy()
    elseif type(handle) == "table" and handle.willUnmount then
        pcall(function() handle:willUnmount() end)
        if handle._instance then
            handle._instance:Destroy()
        end
    end
end

function Roact.update(handle, element)
    -- Simplistic update: just remount
    local parent = nil
    if typeof(handle) == "Instance" then
        parent = handle.Parent
        handle:Destroy()
    elseif type(handle) == "table" and handle._instance then
        parent = handle._instance.Parent
        handle._instance:Destroy()
    end
    
    if parent then
        return Roact.mount(element, parent)
    end
    return nil
end

return Roact