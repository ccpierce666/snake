local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[Server] Runtime.server.lua 启动")

-- 等待 Common 文件夹和 Knit 模块（由 Init.server.lua 创建）
local commonFolder = ReplicatedStorage:WaitForChild("Common", 5)
if not commonFolder then
    error("[Server] 超时等待 ReplicatedStorage.Common")
end

local Knit = require(commonFolder:WaitForChild("Knit", 5))

print("[Server] 已加载 Knit")

-- 将 Knit 放在全局中，供服务使用
_G.KnitInstance = Knit

-- 添加服务器端服务
Knit.AddServices(script.Parent.Services)

print("[Server] 服务已添加，开始初始化")

-- 启动 Knit
Knit:KnitInit()
print("[Server] KnitInit 完成")

Knit:KnitStart():catch(function(err)
    warn("[Server] Knit启动错误:", err)
end)

print("[Server] Runtime.server.lua 完成")
