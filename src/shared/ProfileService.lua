-- ProfileService - Minimal stub for testing
local ProfileService = {}

function ProfileService.GetProfileStore(name, template)
    local store = {}
    
    function store:LoadProfileAsync(key)
        local profile = {
            Data = {},
            UserId = 0,
        }
        
        -- Copy template
        for k, v in pairs(template) do
            profile.Data[k] = v
        end
        
        function profile:AddUserId(userId)
            self.UserId = userId
        end
        
        function profile:Reconcile()
        end
        
        function profile:ListenToRelease(callback)
            self._releaseCallback = callback
        end
        
        function profile:Release()
            if self._releaseCallback then
                self._releaseCallback()
            end
        end
        
        return profile
    end
    
    return store
end

return ProfileService
