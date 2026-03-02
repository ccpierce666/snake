# 蛇身体间距动态调整

## 问题说明

用户反馈：球变小了，身体之间的缝隙也要调整，否则看起来不像一条蛇。

## 解决方案

身体间距从**固定的0.6**改为**动态计算：`bodySize * 0.95`**

这样保证无论蛇的大小如何变化，球之间的相对间距都能保持一致，始终看起来像一条连贯的蛇。

## 工作原理

### 旧系统（固定间距）
```
身体大小: 0.33    间距: 0.6    （间距太大，球之间有大缝隙）
身体大小: 1.0     间距: 0.6    （间距比例合适）
身体大小: 1.8     间距: 0.6    （间距相对较小）

问题：早期蛇（0.33大小）的球之间有大缝隙，看不出像一条蛇
```

### 新系统（动态间距）
```
身体大小: 0.33    间距: 0.33*0.95=0.31   （球紧密相连）
身体大小: 1.0     间距: 1.0*0.95=0.95    （球紧密相连）
身体大小: 1.8     间距: 1.8*0.95=1.71    （球紧密相连）

优势：无论身体大小如何，球之间的间距比例始终相同，看起来像一条蛇
```

## 数值说明

### 为什么是0.95而不是1.0？

```
如果spacing = bodySize * 1.0：
  - 球刚好相接触，没有任何重叠
  - 看起来像分离的珠子

如果spacing = bodySize * 0.95：
  - 球之间有微小重叠（重叠量5%）
  - 看起来像一条连贯的蛇身

如果spacing = bodySize * 0.5：
  - 球有大量重叠
  - 看起来拥挤，不美观
```

### 间距与身体大小的关系

| 身体大小 | 间距 | 重叠情况 |
|---------|------|--------|
| 0.33 | 0.314 | 微小重叠 |
| 0.60 | 0.57 | 微小重叠 |
| 0.95 | 0.903 | 微小重叠 |
| 1.0 | 0.95 | 微小重叠 |
| 1.8 | 1.71 | 微小重叠 |

**关键点**：间距始终 = 身体大小 × 0.95，保证一致的视觉效果

## 代码改动

### 改动1：动态计算函数的参数

**旧代码：**
```lua
local function addSnakeRenderPoints(body, isLocal)
    if not body or #body == 0 then return end
    
    local spacing = 0.6 -- 固定间距
```

**新代码：**
```lua
local function addSnakeRenderPoints(body, isLocal, bodySize)
    if not body or #body == 0 then return end
    
    -- 根据身体大小动态调整间距，保证球紧密相连
    -- bodySize * 0.95 确保球之间有微小重叠，看起来像一条连贯的蛇
    local spacing = bodySize * 0.95
```

### 改动2：函数调用传入参数

**旧代码：**
```lua
if localPlayerSnakeState then
    addSnakeRenderPoints(localPlayerSnakeState.body, true)
end

for _, s in pairs(otherSnakes) do
    addSnakeRenderPoints(s.body, false)
end

local bodySize = calculateBodySize(currentLength)
```

**新代码：**
```lua
-- 计算当前身体大小（根据蛇的总长度，动态计算）
local currentLength = localPlayerSnakeState and #localPlayerSnakeState.body or 0
local bodySize = calculateBodySize(currentLength)

if localPlayerSnakeState then
    addSnakeRenderPoints(localPlayerSnakeState.body, true, bodySize)
end

for _, s in pairs(otherSnakes) do
    addSnakeRenderPoints(s.body, false, bodySize)
end
```

## 效果对比

### 早期蛇（大小0.33）

**旧系统：**
```
o   o   o   o   o   o   o
（球之间有明显缝隙，看起来像分离的珠子）
```

**新系统：**
```
ooo ooo ooo ooo ooo ooo
（球紧密相连，看起来像一条蛇）
```

### 中期蛇（大小1.0）

**旧系统：**
```
●●●●●●●●●●
（球基本相接，但不完美）
```

**新系统：**
```
●●●●●●●●●●
（球紧密相连，完美相接）
```

## 调整空间

如果觉得间距还需要调整，可以改变倍数：

### 更紧密的连接（增加重叠）
```lua
local spacing = bodySize * 0.8  -- 球有更多重叠
```

### 稍微松散一点（减少重叠）
```lua
local spacing = bodySize * 0.98  -- 球几乎不重叠
```

### 完全相接（无重叠）
```lua
local spacing = bodySize * 1.0  -- 球刚好相接触
```

## 技术细节

### 为什么这样做有效？

当我们改变身体大小时，间距也自动调整，保证了**尺度不变性**（Scale Invariance）：

```
蛇的视觉一致性 ∝ （间距 / 球大小） 保持常数

旧系统：间距 / 球大小 = 0.6 / 0.33 = 1.82（早期）
                          = 0.6 / 1.8 = 0.33（后期）
                          （比例不一致！）

新系统：间距 / 球大小 = (0.33*0.95) / 0.33 = 0.95（早期）
                         = (1.8*0.95) / 1.8 = 0.95（后期）
                         （比例一致！）
```

## 总结

新的动态间距系统：

✅ **自动匹配身体大小**：间距与身体大小成正比
✅ **保持视觉一致性**：无论蛇多大，都看起来像一条连贯的蛇
✅ **微小重叠**：0.95倍数确保球之间微小重叠，美观自然
✅ **易于调整**：只需改变倍数即可调整紧密度

现在蛇无论多大或多小，都能看起来像一条真正连贯的蛇！
