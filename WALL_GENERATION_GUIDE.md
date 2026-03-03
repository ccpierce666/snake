# 围墙生成指南

## 问题说明

workspace下的hill模型替换围墙没有成功。本文档提供多种解决方案。

## 当前改进

`SnakeGame3DView.lua` 已经优化，现在支持两套方案：

### 方案A: 使用Hill模型（推荐）
- **优点**: 视觉效果好，卡通风格
- **前提**: Workspace中必须存在名为 "hill" 的Model或Part
- **如果成功**: 会在输出中看到 "[SnakeGame3D] Hill模型围墙生成成功!"

### 方案B: 默认围墙（备选）
- **优点**: 简单可靠，无依赖
- **特点**: 四条绿色边界墙
- **如果启用**: 会在输出中看到 "[SnakeGame3D] 使用默认围墙方案"

## 如何确保Hill模型存在

### 选项1: 手动在Roblox Studio中创建
1. 打开你的Roblox项目
2. 在Workspace中创建一个Model或Part
3. 命名为 "hill"
4. 按照卡通风格装饰（可参考游戏设计标准）
5. 保存项目

### 选项2: 使用Roblox Studio脚本生成Hill模型
在Server脚本中运行以下代码：

```lua
-- 在Roblox Studio的Command Bar或Server脚本中运行
local hill = Instance.new("Model")
hill.Name = "hill"
hill.Parent = workspace

-- 创建简单的山丘形状
local part = Instance.new("Part")
part.Name = "HillBody"
part.Shape = Enum.PartType.Ball
part.Size = Vector3.new(40, 25, 40)
part.Color = Color3.fromRGB(120, 200, 100)
part.Material = Enum.Material.SmoothPlastic
part.CanCollide = true
part.Anchored = true
part.Parent = hill

-- 设置模型的Pivot
hill:PivotTo(CFrame.new(0, 12.5, 0))

print("Hill模型已创建: " .. hill.Name)
```

### 选项3: 从存储库导入
如果项目中已有预制的hill模型，检查以下位置：
- ReplicatedStorage/Assets/hill
- ServerStorage/hill
- 其他资源文件夹

然后复制到Workspace。

## 调试步骤

1. **检查输出窗口** - 查看是否有"Hill模型..."的消息
2. **手动测试** - 在Roblox Studio中：
   - 打开命令行
   - 输入 `print(workspace:FindFirstChild("hill"))` 
   - 应该输出模型信息而不是nil

3. **如果仍然不工作**：
   - 确认Hill模型名字大小写正确（必须是小写"hill"）
   - 确认Hill模型在Workspace的根目录下
   - 确认Hill模型是Model或Part类型

## 自定义围墙外观

如需修改默认围墙的外观，编辑 `SnakeGame3DView.lua` 中的这些参数：

```lua
local wH = 8 -- 改变高度
local wT = 3 -- 改变厚度
local wallColor = Color3.fromRGB(120, 200, 100) -- 改变颜色
```

## 相关文件

- `src/client/UI/SnakeGame3DView.lua` - 围墙生成逻辑
- `.cursor/rules/game-standards.mdc` - 游戏设计标准

## 测试方法

1. 在Roblox Studio中启动游戏
2. 打开Output窗口（View > Output）
3. 查找 "[SnakeGame3D]" 开头的消息
4. 确认围墙是否正确显示
