-- Prometheus metrics library for OpenResty
local _M = {}

function _M.init(dict_name)
    local self = {}
    self.dict = ngx.shared[dict_name]
    
    function self:counter(name, help, labels)
        return {
            name = name,
            help = help,
            labels = labels or {},
            inc = function(self, value, label_values)
                local key = name
                if label_values then
                    for i, v in ipairs(label_values) do
                        key = key .. ":" .. v
                    end
                end
                local newval, err = self.dict:incr(key, value or 1, 0)
                if not newval and err == "not found" then
                    self.dict:add(key, value or 1)
                end
            end
        }
    end
    
    function self:histogram(name, help, labels)
        return {
            name = name,
            help = help,
            labels = labels or {},
            observe = function(self, value, label_values)
                local key = name .. "_sum"
                if label_values then
                    for i, v in ipairs(label_values) do
                        key = key .. ":" .. v
                    end
                end
                local newval, err = self.dict:incr(key, value, 0)
                if not newval and err == "not found" then
                    self.dict:add(key, value)
                end
                
                local count_key = name .. "_count"
                if label_values then
                    for i, v in ipairs(label_values) do
                        count_key = count_key .. ":" .. v
                    end
                end
                local newcount, err = self.dict:incr(count_key, 1, 0)
                if not newcount and err == "not found" then
                    self.dict:add(count_key, 1)
                end
            end
        }
    end
    
    function self:collect()
        local metrics = {}
        local keys = self.dict:get_keys(0)
        
        for _, key in ipairs(keys) do
            local value = self.dict:get(key)
            if value then
                table.insert(metrics, key .. " " .. value)
            end
        end
        
        ngx.header.content_type = "text/plain"
        ngx.say(table.concat(metrics, "\n"))
    end
    
    return self
end

return _M
