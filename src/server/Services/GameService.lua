local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Common.Knit)

local GameService = Knit.CreateService {
    Name = "GameService",
    Client = {},
}

function GameService:KnitStart()
    print("Game Service Started")
    
    -- Example Loop
    task.spawn(function()
        while true do
            task.wait(10)
            print("Game Loop Tick... (Simulating game logic)")
            -- Here you could handle round logic, spawning enemies, etc.
        end
    end)
end

function GameService:KnitInit()
    -- Initialize other systems if needed
end

return GameService