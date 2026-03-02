-- Knit - 简单的服务/控制器框架
local Knit = {}

local services = {}
local controllers = {}
local signals = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local isServer = game:GetService("RunService"):IsServer()

-- Signal class
local Signal = {}
Signal.__index = Signal

function Signal.new()
    local self = setmetatable({}, Signal)
    self._bindable = Instance.new("BindableEvent")
    self._remoteEvent = nil  -- 用于跨环境通信
    return self
end

function Signal:Fire(...)
    -- 本地触发
    self._bindable:Fire(...)
    
    -- 如果是服务器端信号且有客户端监听，通过 RemoteEvent 发送
    if isServer and self._remoteEvent then
        pcall(function(...)
            self._remoteEvent:FireAllClients(...)
        end, ...)
    end
end

function Signal:FireTo(player, ...)
    if isServer and self._remoteEvent and player then
        pcall(function(...)
            self._remoteEvent:FireClient(player, ...)
        end, ...)
    end
end

function Signal:Connect(callback)
    return self._bindable.Event:Connect(callback)
end

function Signal:Wait()
    return self._bindable.Event:Wait()
end

function Signal:Destroy()
    self._bindable:Destroy()
    if self._remoteEvent then
        self._remoteEvent:Destroy()
    end
end

-- Knit functions
function Knit.CreateSignal()
    return Signal.new()
end

function Knit.CreateService(definition)
    local service = definition
    service._isService = true
    return service
end

function Knit.CreateController(definition)
    local controller = definition
    controller._isController = true
    return controller
end

function Knit.GetService(name)
    local service = services[name]
    
    -- 如果是客户端且服务有方法，创建代理以调用服务器
    if not isServer and service then
        -- 为服务的所有方法创建调用代理
        local proxy = {}
        for key, value in pairs(service) do
            if type(value) == "function" then
                proxy[key] = function(self, ...)
                    -- 通过 RemoteFunction 调用服务器
                    local remoteFunctionName = "Call_" .. name .. "_" .. key
                    local remoteFunction = ReplicatedStorage:FindFirstChild(remoteFunctionName)
                    if remoteFunction then
                        return remoteFunction:InvokeServer(...)
                    else
                        warn("[Knit] 找不到 RemoteFunction: " .. remoteFunctionName)
                    end
                end
            else
                proxy[key] = value
            end
        end
        return proxy
    end
    
    return service
end

function Knit.GetController(name)
    return controllers[name]
end

function Knit.AddServices(folder)
    if not folder then return end
    for _, module in ipairs(folder:GetChildren()) do
        if module:IsA("ModuleScript") then
            local service = require(module)
            if service and service.Name then
                services[service.Name] = service
                print("[Knit] 注册服务: " .. service.Name)
            end
        end
    end
end

function Knit.AddControllers(folder)
    if not folder then return end
    for _, module in ipairs(folder:GetChildren()) do
        if module:IsA("ModuleScript") then
            local controller = require(module)
            if controller and controller.Name then
                controllers[controller.Name] = controller
                print("[Knit] 注册控制器: " .. controller.Name)
            end
        end
    end
end

function Knit:KnitInit()
    -- 调用所有服务的KnitInit
    for name, service in pairs(services) do
        if service.KnitInit then
            print("[Knit] 初始化服务: " .. name)
            local success, err = pcall(function()
                service:KnitInit()
            end)
            if not success then
                warn("[Knit] 服务初始化失败 " .. name .. ": " .. tostring(err))
            end
        end
    end
end

function Knit:KnitStart()
    -- 返回一个带有catch方法的promise-like对象
    local promise = {}
    
    function promise:catch(callback)
        -- 如果是服务器，创建跨环境通信的 RemoteEvents 和 RemoteFunctions
        if isServer then
            for name, service in pairs(services) do
                if service.Client and type(service.Client) == "table" then
                    for signalName, signal in pairs(service.Client) do
                        -- 只处理 Signal 对象，不是函数
                        if signal and type(signal) == "table" and signal._bindable then
                            -- 为每个客户端信号创建 RemoteEvent
                            local remoteEvent = Instance.new("RemoteEvent")
                            remoteEvent.Name = "Signal_" .. name .. "_" .. signalName
                            remoteEvent.Parent = ReplicatedStorage
                            signal._remoteEvent = remoteEvent
                            print("[Knit] 为 " .. name .. "." .. signalName .. " 创建了 RemoteEvent")
                        end
                    end
                end
                
                -- 为服务的公共方法创建 RemoteFunctions
                for methodName, method in pairs(service) do
                    if type(method) == "function" and methodName:sub(1, 1) ~= "_" and methodName ~= "KnitInit" and methodName ~= "KnitStart" then
                        local remoteFunction = Instance.new("RemoteFunction")
                        remoteFunction.Name = "Call_" .. name .. "_" .. methodName
                        remoteFunction.Parent = ReplicatedStorage
                        
                        remoteFunction.OnServerInvoke = function(player, ...)
                            return method(service, player, ...)
                        end
                        
                        print("[Knit] 为 " .. name .. ":" .. methodName .. " 创建了 RemoteFunction")
                    end
                end
            end
        else
            -- 如果是客户端，连接服务器的 RemoteEvents
            local Common = ReplicatedStorage:WaitForChild("Common")
            for name, service in pairs(services) do
                if service.Client and type(service.Client) == "table" then
                    for signalName, signal in pairs(service.Client) do
                        -- 只处理 Signal 对象
                        if signal and type(signal) == "table" and signal._bindable then
                            local remoteEventName = "Signal_" .. name .. "_" .. signalName
                            local remoteEvent = ReplicatedStorage:WaitForChild(remoteEventName, 5)
                            if remoteEvent then
                                remoteEvent.OnClientEvent:Connect(function(...)
                                    signal:Fire(...)
                                end)
                                print("[Knit] 客户端已连接到 " .. remoteEventName)
                            end
                        end
                    end
                end
            end
        end
        
        -- 调用所有服务的KnitStart
        for name, service in pairs(services) do
            if service.KnitStart then
                print("[Knit] 启动服务: " .. name)
                local success, err = pcall(function()
                    service:KnitStart()
                end)
                if not success then
                    warn("[Knit] 服务启动失败 " .. name .. ": " .. tostring(err))
                    callback(err)
                end
            end
        end
        
        -- 调用所有控制器的KnitStart
        for name, controller in pairs(controllers) do
            if controller.KnitStart then
                print("[Knit] 启动控制器: " .. name)
                local success, err = pcall(function()
                    controller:KnitStart()
                end)
                if not success then
                    warn("[Knit] 控制器启动失败 " .. name .. ": " .. tostring(err))
                    callback(err)
                end
            end
        end
        
        return promise
    end
    
    return promise
end

return Knit
