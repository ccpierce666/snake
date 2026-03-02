# 蛇身体大小增长系统 (简化版)

## 设计规则

### 身体大小阶段

```
初生蛇 (长度 < 10)     → 身体大小 = 0.33  (1/3格子)
成长蛇 (长度 >= 10)    → 身体大小 = 0.66  (2/3格子) - 直接增长一倍
```

### 采样间距 (关键)

**采样间距 = 身体大小 × 0.9**

这确保了：
- 相邻球体之间有 10% 的重叠
- 球体看起来紧密贴合，没有缝隙
- 无论身体多大或多小，比例关系始终一致

## 工作原理

### 初生阶段 (长度 < 10)

```
bodySize = 0.33
samplingDistance = 0.33 × 0.9 = 0.297

服务器body数组中的相邻位置距离 ≈ 0.25
→ 0.25 < 0.297: 需要多个位置才能达到采样距离
→ 频繁采样，球体密集排列
→ 0.33大小的球，0.297的采样间距
→ 相邻球体重叠，看起来非常紧密

可视化：
●●●●●●●●●●●●●●●
(球心距离0.297，球半径0.165)
```

### 成长阶段 (长度 >= 10)

```
bodySize = 0.66 (直接增长一倍！)
samplingDistance = 0.66 × 0.9 = 0.594

服务器body数组中的相邻位置距离 ≈ 0.25
→ 需要约2-3个位置才能达到采样距离
→ 稀疏采样，但球体更大
→ 0.66大小的球，0.594的采样间距
→ 相邻球体仍然重叠，保持一致的视觉效果

可视化：
  ●    ●    ●    ●
(球心距离0.594，球半径0.33，有重叠)
```

## 关键参数

### 头部大小

```lua
头部大小 = bodySize × 1.2

初生期：0.33 × 1.2 = 0.396  (清晰可见的头部)
成长期：0.66 × 1.2 = 0.792  (更明显的头部)
```

## 代码实现

### 1. 身体大小计算

```lua
local function calculateBodySize(currentLength)
    if currentLength < 10 then
        return 0.33  -- 1/3格子
    else
        return 0.66  -- 2/3格子 (直接增长一倍)
    end
end
```

### 2. 采样逻辑

```lua
local samplingDistance = bodySize * 0.9

for i = 2, #body do
    local dist = (body[i] - lastPos).Magnitude
    if dist >= samplingDistance then
        -- 采样这个位置
        lastPos = body[i]
    end
end
```

### 3. 球体大小设置

```lua
local sz = isHead and (bodySize * 1.2) or bodySize
snakeParts[i].Size = Vector3.new(sz, sz, sz)
```

## 数值对比

### 初生蛇 vs 成长蛇

| 属性 | 初生蛇 | 成长蛇 |
|-----|-------|-------|
| 身体大小 | 0.33 | 0.66 |
| 增长倍数 | - | 2.0× |
| 头部大小 | 0.396 | 0.792 |
| 采样间距 | 0.297 | 0.594 |
| 采样密度 | 密集 | 稀疏 (但球更大) |

### 视觉紧密度

```
初生蛇：
  球大小 / 采样间距 = 0.33 / 0.297 ≈ 1.11
  → 球体有明显重叠，非常紧密

成长蛇：
  球大小 / 采样间距 = 0.66 / 0.594 ≈ 1.11
  → 球体同样有重叠，视觉一致

比例完全一致！✓
```

## 为什么采样间距是 bodySize × 0.9？

### 理论分析

在3D空间中，两个球体之间的距离定义为它们球心之间的距离。

如果球的半径是 r（直径 d = 2r）：
- **完全相接**：球心距离 = d
- **10%重叠**：球心距离 = 0.9d
- **20%重叠**：球心距离 = 0.8d

在Roblox中：
- Part.Size = (diameter, diameter, diameter)
- Part 的半径 = diameter / 2

所以：
```
bodySize = diameter
球心距离应该 = bodySize × 0.9
```

这给出 10% 的重叠，是视觉上"紧密贴合"的理想值。

## 后续扩展

如果需要更多阶段，可以这样添加：

```lua
local function calculateBodySize(currentLength)
    if currentLength < 10 then
        return 0.33
    elseif currentLength < 100 then
        return 0.66
    elseif currentLength < 1000 then
        return 1.0
    elseif currentLength < 10000 then
        return 1.33
    else
        return 1.66
    end
end
```

关键是保持 **samplingDistance = bodySize × 0.9** 的公式，这样所有阶段都会保持一致的视觉效果。

## 验证清单

- ✅ 初生蛇（长度<10）：身体大小0.33，紧密贴合
- ✅ 成长蛇（长度≥10）：身体大小0.66，直接增长一倍，仍然紧密贴合
- ✅ 头部：始终比身体大20%，清晰可见
- ✅ 采样间距：动态匹配身体大小，保证一致的视觉效果
- ✅ 无缝隙：相邻球体有10%重叠，看起来像一条连贯的蛇
