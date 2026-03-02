local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Common.Roact)

local AdvancedDashboard = Roact.Component:extend("AdvancedDashboard")

function AdvancedDashboard:init()
    self:setState({
        selectedTab = "stats",
        gold = 5000,
        level = 25,
        health = 100,
    })
end

function AdvancedDashboard:render()
    local children = {}
    
    -- Top bar
    children.TopBar = Roact.createElement("Frame", {
        Size = UDim2.new(1, 0, 0, 60),
        BackgroundColor3 = Color3.fromRGB(10, 10, 20),
        BorderSizePixel = 0,
    }, {
        Title = Roact.createElement("TextLabel", {
            Size = UDim2.new(0.5, 0, 1, 0),
            BackgroundTransparency = 1,
            TextColor3 = Color3.fromRGB(0, 255, 200),
            Text = "🎮 GAME DASHBOARD",
            TextSize = 20,
            Font = Enum.Font.GothamBold,
        }),
        
        Level = Roact.createElement("TextLabel", {
            Position = UDim2.new(0.5, 0, 0, 0),
            Size = UDim2.new(0.5, 0, 1, 0),
            BackgroundTransparency = 1,
            TextColor3 = Color3.fromRGB(255, 200, 0),
            Text = "⭐ Level: " .. self.state.level .. " | 💰 Gold: " .. self.state.gold,
            TextSize = 14,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Right,
        })
    })
    
    -- Tabs
    local tabButtons = {
        stats = { label = "📊 STATS", color = Color3.fromRGB(0, 150, 255) },
        inventory = { label = "🎒 INVENTORY", color = Color3.fromRGB(100, 200, 100) },
        settings = { label = "⚙️ SETTINGS", color = Color3.fromRGB(200, 100, 100) },
    }
    
    children.TabBar = Roact.createElement("Frame", {
        Position = UDim2.new(0, 0, 0, 60),
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundColor3 = Color3.fromRGB(15, 15, 25),
        BorderSizePixel = 0,
    })
    
    local tabContainer = {}
    for tabId, tabInfo in pairs(tabButtons) do
        local isActive = self.state.selectedTab == tabId
        tabContainer[tabId] = Roact.createElement("TextButton", {
            Size = UDim2.new(0.33, -3, 1, 0),
            BackgroundColor3 = isActive and tabInfo.color or Color3.fromRGB(40, 40, 50),
            TextColor3 = Color3.fromRGB(255, 255, 255),
            Text = tabInfo.label,
            TextSize = 12,
            Font = Enum.Font.GothamBold,
            BorderSizePixel = 0,
        })
    end
    children.TabBar = Roact.createElement("Frame", {
        Position = UDim2.new(0, 0, 0, 60),
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundColor3 = Color3.fromRGB(15, 15, 25),
        BorderSizePixel = 0,
    }, {
        UIListLayout = Roact.createElement("UIListLayout", {
            Padding = UDim.new(0, 6),
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        Stats = Roact.createElement("TextButton", {
            Size = UDim2.new(0.33, -3, 1, 0),
            BackgroundColor3 = self.state.selectedTab == "stats" 
                and Color3.fromRGB(0, 150, 255) 
                or Color3.fromRGB(40, 40, 50),
            TextColor3 = Color3.fromRGB(255, 255, 255),
            Text = "📊 STATS",
            TextSize = 12,
            Font = Enum.Font.GothamBold,
            BorderSizePixel = 0,
            LayoutOrder = 1,
        }),
        Inventory = Roact.createElement("TextButton", {
            Size = UDim2.new(0.33, -3, 1, 0),
            BackgroundColor3 = self.state.selectedTab == "inventory" 
                and Color3.fromRGB(100, 200, 100) 
                or Color3.fromRGB(40, 40, 50),
            TextColor3 = Color3.fromRGB(255, 255, 255),
            Text = "🎒 INVENTORY",
            TextSize = 12,
            Font = Enum.Font.GothamBold,
            BorderSizePixel = 0,
            LayoutOrder = 2,
        }),
        Settings = Roact.createElement("TextButton", {
            Size = UDim2.new(0.33, -3, 1, 0),
            BackgroundColor3 = self.state.selectedTab == "settings" 
                and Color3.fromRGB(200, 100, 100) 
                or Color3.fromRGB(40, 40, 50),
            TextColor3 = Color3.fromRGB(255, 255, 255),
            Text = "⚙️ SETTINGS",
            TextSize = 12,
            Font = Enum.Font.GothamBold,
            BorderSizePixel = 0,
            LayoutOrder = 3,
        })
    })
    
    -- Content area
    children.Content = Roact.createElement("Frame", {
        Position = UDim2.new(0, 0, 0, 110),
        Size = UDim2.new(1, 0, 1, -110),
        BackgroundColor3 = Color3.fromRGB(20, 25, 35),
        BorderSizePixel = 0,
    }, {
        Padding = Roact.createElement("UIPadding", {
            PaddingLeft = UDim.new(0, 10),
            PaddingRight = UDim.new(0, 10),
            PaddingTop = UDim.new(0, 10),
        }),
        
        -- Stats tab content
        StatsContent = Roact.createElement("Frame", {
            Visible = self.state.selectedTab == "stats",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
        }, {
            UIListLayout = Roact.createElement("UIListLayout", {
                Padding = UDim.new(0, 15),
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            
            Health = Roact.createElement("Frame", {
                Size = UDim2.new(1, 0, 0, 50),
                BackgroundColor3 = Color3.fromRGB(200, 50, 50),
                BorderSizePixel = 0,
                LayoutOrder = 1,
            }, {
                UICorner = Roact.createElement("UICorner", {
                    CornerRadius = UDim.new(0, 6),
                }),
                Text = Roact.createElement("TextLabel", {
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    Text = "❤️ Health: " .. self.state.health .. "%",
                    TextSize = 16,
                    Font = Enum.Font.GothamBold,
                })
            }),
            
            Gold = Roact.createElement("Frame", {
                Size = UDim2.new(1, 0, 0, 50),
                BackgroundColor3 = Color3.fromRGB(255, 200, 0),
                BorderSizePixel = 0,
                LayoutOrder = 2,
            }, {
                UICorner = Roact.createElement("UICorner", {
                    CornerRadius = UDim.new(0, 6),
                }),
                Text = Roact.createElement("TextLabel", {
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    TextColor3 = Color3.fromRGB(40, 40, 40),
                    Text = "💰 Gold: " .. self.state.gold,
                    TextSize = 16,
                    Font = Enum.Font.GothamBold,
                })
            }),
            
            Level = Roact.createElement("Frame", {
                Size = UDim2.new(1, 0, 0, 50),
                BackgroundColor3 = Color3.fromRGB(100, 150, 255),
                BorderSizePixel = 0,
                LayoutOrder = 3,
            }, {
                UICorner = Roact.createElement("UICorner", {
                    CornerRadius = UDim.new(0, 6),
                }),
                Text = Roact.createElement("TextLabel", {
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    Text = "⭐ Level: " .. self.state.level,
                    TextSize = 16,
                    Font = Enum.Font.GothamBold,
                })
            }),
        }),
        
        -- Inventory content
        InventoryContent = Roact.createElement("Frame", {
            Visible = self.state.selectedTab == "inventory",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
        }, {
            Title = Roact.createElement("TextLabel", {
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundTransparency = 1,
                TextColor3 = Color3.fromRGB(100, 200, 100),
                Text = "Your Items:",
                TextSize = 14,
                Font = Enum.Font.GothamBold,
            }),
            
            Items = Roact.createElement("Frame", {
                Position = UDim2.new(0, 0, 0, 40),
                Size = UDim2.new(1, 0, 1, -40),
                BackgroundTransparency = 1,
            }, {
                UIListLayout = Roact.createElement("UIListLayout", {
                    Padding = UDim.new(0, 5),
                    FillDirection = Enum.FillDirection.Vertical,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                }),
                Item1 = Roact.createElement("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 25),
                    BackgroundColor3 = Color3.fromRGB(50, 100, 50),
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    Text = "⚔️ Iron Sword x1",
                    TextSize = 12,
                    Font = Enum.Font.Gotham,
                }),
                Item2 = Roact.createElement("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 25),
                    BackgroundColor3 = Color3.fromRGB(100, 100, 50),
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    Text = "🛡️ Shield x2",
                    TextSize = 12,
                    Font = Enum.Font.Gotham,
                }),
            })
        }),
    })
    
    return Roact.createElement("ScreenGui", {
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Name = "AdvancedDashboard",
    }, {
        MainWindow = Roact.createElement("Frame", {
            Position = UDim2.new(0, 50, 0, 50),
            Size = UDim2.new(0, 500, 0, 500),
            BackgroundColor3 = Color3.fromRGB(20, 25, 35),
            BorderSizePixel = 2,
            BorderColor3 = Color3.fromRGB(0, 255, 200),
        }, children)
    })
end

return AdvancedDashboard
