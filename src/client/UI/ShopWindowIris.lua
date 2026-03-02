local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Iris = require(ReplicatedStorage.Common.Iris)

local ShopWindowIris = {}

function ShopWindowIris.Start()
    local selectedItem = Iris.State("sword")
    local goldAmount = Iris.State(1000)
    
    -- Shop items data
    local shopItems = {
        { id = "sword", name = "Iron Sword", price = 100, icon = "⚔️" },
        { id = "shield", name = "Wooden Shield", price = 150, icon = "🛡️" },
        { id = "bow", name = "Wooden Bow", price = 200, icon = "🏹" },
        { id = "potion", name = "Health Potion", price = 50, icon = "🧪" },
        { id = "armor", name = "Leather Armor", price = 300, icon = "🎽" },
    }
    
    -- Start Iris loop
    Iris:Connect(function()
        Iris.Window({"Shop"})
            Iris.Text({"Gold: " .. goldAmount:get()})
            
            Iris.Text({"=== Available Items ==="})
            
            for _, item in ipairs(shopItems) do
                Iris.Text({item.icon .. " " .. item.name .. " - " .. item.price .. " Gold"})
                
                if Iris.Button({item.name}).clicked() then
                    selectedItem:set(item.id)
                    print("Selected: " .. item.name)
                end
            end
            
            Iris.Text({"=== Selected: " .. selectedItem:get() .. " ==="})
            
            if Iris.Button({"Buy Item"}).clicked() then
                print("Buying item: " .. selectedItem:get())
                if goldAmount:get() >= 100 then
                    goldAmount:set(goldAmount:get() - 100)
                    print("Purchase successful! Gold remaining: " .. goldAmount:get())
                else
                    print("Not enough gold!")
                end
            end
            
            if Iris.Button({"Reset Gold"}).clicked() then
                goldAmount:set(1000)
            end
        Iris.End()
    end)
end

return ShopWindowIris
