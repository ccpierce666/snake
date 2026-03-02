local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[Client] Runtime.client.lua 启动")

-- 等待共享库被加载到 ReplicatedStorage.Common
local Common = ReplicatedStorage:WaitForChild("Common")
local Knit = require(Common:WaitForChild("Knit"))
local Roact = require(Common:WaitForChild("Roact"))
local Roui = require(Common:WaitForChild("Roui"))

print("[Client] 已加载所有共享库")

-- 将 Knit 放在全局中，供服务/控制器使用
_G.KnitInstance = Knit

-- 添加客户端服务
Knit.AddServices(script.Parent.Services)

-- 添加客户端控制器
Knit.AddControllers(script.Parent.Controllers)

print("[Client] 服务和控制器已添加，开始初始化")

-- 启动 Knit
Knit:KnitInit()
print("[Client] KnitInit 完成")

Knit:KnitStart():catch(function(err)
    warn("[Client] Knit启动错误:", err)
end)

print("[Client] Runtime.client.lua 完成")
