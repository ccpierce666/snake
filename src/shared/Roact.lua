-- Roact - Minimal stub with real rendering
local Roact = {}
Roact.Component = {}
Roact.Component.__index = Roact.Component

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

-- Real mounting with actual UI rendering
function Roact.mount(element, parent, key)
    print("[Roact] Mounting element to " .. parent:GetFullName())
    
    if type(element._type) == "string" then
        -- Built-in Roblox class (e.g., "Frame", "ScreenGui")
        local instance = Instance.new(element._type)
        
        -- Set properties
        for prop, value in pairs(element._props) do
            if prop:sub(1, 1) ~= "_" then
                pcall(function()
                    local target = instance[prop]
                    if typeof(value) == "function" and target and typeof(target) == "RBXScriptSignal" then
                        target:Connect(value)
                    else
                        instance[prop] = value
                    end
                end)
            end
        end
        
        -- Add children
        if element._children then
            for key, child in pairs(element._children) do
                if child then
                    local childInstance = Roact.mount(child, instance, key)
                    if childInstance then
                        childInstance.Parent = instance
                    end
                end
            end
        end
        
        instance.Parent = parent
        print("[Roact] Created " .. element._type .. " with key: " .. (key or "nil"))
        return instance
    else
        -- Component (user-defined class)
        local component = element._type:new()
        component.props = element._props
        component.children = element._children
        
        -- Call didMount
        if component.didMount then
            component:didMount()
        end
        
        -- Get render result
        local renderResult = component:render()
        
        if renderResult then
            return Roact.mount(renderResult, parent, key)
        end
        
        return component
    end
end

function Roact.unmount(handle)
    if handle and handle:IsA("Instance") then
        handle:Destroy()
    end
end

function Roact.update(handle, element)
    if handle and handle:IsA("Instance") then
        local parent = handle.Parent
        if parent then
            handle:Destroy()
            return Roact.mount(element, parent)
        end
    end
    return nil
end

return Roact
