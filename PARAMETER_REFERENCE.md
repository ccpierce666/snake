# 游戏参数对照表

## 增长系统参数

### 增长倍数计算公式
```lua
倍数 = 1.0 + (currentLength / maxLength)^exponent
最终增长 = floor(基础增长 × 倍数 + 0.5)
```

| 参数 | 当前值 | 说明 | 位置 |
|------|-------|------|------|
| **maxLength** | 500000 | 达到2.0倍的身体长度 | SnakeGameService.lua L56, SnakeGameController.lua L32 |
| **exponent** | 0.25 | 四次方根，控制加速曲线 | SnakeGameService.lua L59, SnakeGameController.lua L35 |
| **min倍数** | 1.0 | 长度为0时的倍数 | 公式计算 |
| **max倍数** | 2.0 | 长度≥500000时的倍数 | 公式结果 |

## 食物价值系统

### 食物生成概率与基础增长值

| 食物等级 | value值 | 概率 | 基础增长段数 | 分布 |
|--------|--------|------|-----------|------|
| 常见 | 1 | 57% | 3 | 最多，初级 |
| 较常见 | 2 | 25% | 6 | 常见 |
| 不常见 | 3 | 10% | 12 | 较少 |
| 罕见 | 4 | 5% | 24 | 稀有 |
| 极罕见 | 5 | 2% | 56 | 很少见 |
| 传奇 | 6 | 0.7% | 224 | 极少 |
| 史诗 | 7 | 0.2% | 512 | 非常罕见 |
| 传说 | 8 | 0.1% | 1024 | 最珍稀 |

来源：`SnakeGameService.lua` L117-126

## 身体分级系统

### 身体大小等级

| Tier | 身体长度范围 | 身体大小 | 蛇头大小 | 阶段 |
|------|-----------|--------|--------|------|
| 1 | 0-99 | 1.0 | 1.6 | 初始小蛇 |
| 2 | 100-999 | 1.3 | 1.9 | 中等蛇 |
| 3 | 1000-9999 | 1.6 | 2.2 | 大蛇 |
| 4 | 10000-99999 | 1.9 | 2.5 | 巨大蛇 |
| 5 | 100000+ | 2.2 | 2.8 | 超大蛇（固定大小） |

来源：`SnakeGame3DView.lua` L29-35 (`BODY_SIZE_TIERS`)

## 虚线圈系统

### 吸取范围指示圈参数

| 参数 | 值 | 说明 | 位置 |
|------|-----|------|------|
| **RING_RADIUS** | 5.5 | 虚线圈半径 | SnakeGame3DView.lua L24 |
| **DASH_COUNT** | 20 | 虚线段数量 | SnakeGame3DView.lua L25 |
| **PICKUP_RADIUS** | 5.5 | 服务器碰撞检测半径 | SnakeGameService.lua L273 |
| **圆位置** | Y=0.45 | 贴在地面上 | SnakeGame3DView.lua L275 |
| **旋转方向** | 顺时针 | 负方向旋转 | SnakeGame3DView.lua L270 |

## 钱币系统

### 钱币参数

| 参数 | 值 | 说明 | 位置 |
|------|-----|------|------|
| **MONEY_PER_FOOD** | 10 | 每点食物价值获得的钞票 | SnakeGameService.lua L15 |
| **初始钞票** | loadMoney() | 从DataStore读取 | SnakeGameService.lua L390 |
| **保存位置** | DataStore | SnakeGameMoney_v1 | SnakeGameService.lua L17 |

## 游戏区域参数

### 地图与蛇参数

| 参数 | 值 | 说明 | 位置 |
|------|-----|------|------|
| **GAME_AREA_SIZE** | 120 | 游戏区域大小（每边120 studs） | SnakeGameService.lua L9, SnakeGame3DView.lua L6 |
| **INITIAL_LENGTH** | 5 | 初始蛇长（段数） | SnakeGameService.lua L10 |
| **SNAKE_SPEED** | 15 | 蛇移动速度（studs/秒） | SnakeGameService.lua L11, SnakeGame3DView.lua L209 |
| **SNAKE_RADIUS** | 0.8 | 蛇头碰撞半径 | SnakeGameService.lua L12 |
| **FOOD_RADIUS** | 0.6 | 食物碰撞半径 | SnakeGameService.lua L13 |
| **GAME_TICK** | 1/60 | 游戏刻度（60 FPS） | SnakeGameService.lua L14, SnakeGame3DView.lua L210 |

## 食物生成参数

### 食物系统

| 参数 | 值 | 说明 | 位置 |
|------|-----|------|------|
| **最大食物数** | 300 | 地图上维持的食物数量 | SnakeGameService.lua L326 |
| **初始食物数** | 300 | 游戏开始时生成 | SnakeGameService.lua L384 |
| **生成范围** | ±96 studs | 安全生成区域 | SnakeGameService.lua L66-67 |

## 关键函数映射

| 函数名 | 作用 | 文件位置 | 调用位置 |
|--------|------|--------|---------|
| **calculateGrowthMultiplier** | 计算增长倍数 | SS L52, SC L31 | SS L314, SC L136 |
| **getBodySizeForLength** | 计算身体分级 | SG3D L93 | SG3D L346 |
| **spawnFood** | 生成食物 | SS L113 | SS L328 |
| **getLeaderboard** | 获取排行榜 | SS L137 | SS L149, 311 |
| **calculateGrowthMultiplier** | 增长倍数 | SS L52 | SS L314 |

## 常用文件缩写

| 缩写 | 完整路径 |
|------|---------|
| **SS** | `src/server/Services/SnakeGameService.lua` |
| **SC** | `src/client/Controllers/SnakeGameController.lua` |
| **SG3D** | `src/client/UI/SnakeGame3DView.lua` |
| **SUI** | `src/client/UI/SnakeGameUI.lua` |

## 调整指南

### 如果要让增长更快
```lua
改变参数：
- maxLength 改为 250000（提前达到2.0倍）
- exponent 改为 0.3（平缓加速）
```

### 如果要让增长更慢
```lua
改变参数：
- maxLength 改为 1000000（延迟达到2.0倍）
- exponent 改为 0.2（极端陡峭）
```

### 如果要改变食物分布
```lua
修改位置：SnakeGameService.lua L117-126
改变条件语句的概率阈值
```

### 如果要改变身体大小分级
```lua
修改位置：SnakeGame3DView.lua L29-35
改变 BODY_SIZE_TIERS 表的值
```

## 日志格式

### 食物吸取日志
```
[SnakeGameService] 玩家 {userId} 吸取 {count} 个食物 | 价值+{totalVal} 长度+{totalGrowth}(倍数×{multiplier}) | 总长={newLength} 钞票={money}
```

### 身体升级日志
```
[SnakeGame3D] 📈 蛇身体升级: {tierInfo} (当前长度: {currentLength})
```

### 分数更新日志
```
[SnakeGameController] 分数增加: {diff} | 倍数×{multiplier} | 增长: {estimatedGrowth}
```

## 性能相关

### 游戏循环
- **服务器**：RunService.Heartbeat（每帧调用 moveSnakes）
- **客户端**：RunService.Heartbeat（每帧更新渲染）
- **UI更新**：实时监听信号变化

### 数据同步
- **FoodChanged**：食物更新信号
- **LeaderboardChanged**：排行榜更新信号
- **MoneyChanged**：钱币更新信号（单个玩家）
- **DirectionChanged**：方向变化信号（其他玩家）

---

所有参数均已在代码注释中标记，如需修改请搜索对应的参数名称。
