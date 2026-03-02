-- Init.server.lua - 初始化脚本，将共享库复制到 ReplicatedStorage
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[Init] 开始初始化共享库")

-- 创建或获取 Common 文件夹
local commonFolder = ReplicatedStorage:FindFirstChild("Common")
if not commonFolder then
    commonFolder = Instance.new("Folder")
    commonFolder.Name = "Common"
    commonFolder.Parent = ReplicatedStorage
    print("[Init] 创建了 ReplicatedStorage.Common")
else
    print("[Init] 使用现有的 ReplicatedStorage.Common")
end

-- 复制共享库文件
local sharedFiles = {
    "Knit",
    "Roact",
    "Roui",
    "Signal",
    "Promise",
    "Iris",
    "ProfileService",
}

local sharedFolder = script.Parent.Parent:FindFirstChild("Knit")
if not sharedFolder then
    -- 共享文件直接在脚本父目录的上级
    sharedFolder = script.Parent.Parent
end

for _, fileName in ipairs(sharedFiles) do
    local sourceModule = sharedFolder:FindFirstChild(fileName)
    if sourceModule and sourceModule:IsA("ModuleScript") then
        -- 检查目标是否已存在
        if not commonFolder:FindFirstChild(fileName) then
            local clone = sourceModule:Clone()
            clone.Parent = commonFolder
            print("[Init] 复制了 " .. fileName .. " 到 ReplicatedStorage.Common")
        else
            print("[Init] " .. fileName .. " 已存在于 ReplicatedStorage.Common")
        end
    end
end

print("[Init] 共享库初始化完成")
