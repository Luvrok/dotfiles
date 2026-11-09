-- save where the pip stopped: mpv's watch_later does not keep every
-- network stream, and the host starts the next open from this file
local name = mp.get_opt("mpv-pip.name")
local dir = mp.get_opt("mpv-pip.dir")
local last = 0
local total = 0
local ended = false

mp.observe_property("time-pos", "number", function(_, value)
    if value then
        last = value
    end
end)

mp.observe_property("duration", "number", function(_, value)
    if value and value > 0 then
        total = value
    end
end)

mp.observe_property("eof-reached", "bool", function(_, value)
    if value ~= nil then
        ended = value
    end
end)

local function save()
    if not name or not dir then
        return
    end
    local file = dir .. "/" .. name
    local pos = mp.get_property_number("time-pos") or last
    local duration = mp.get_property_number("duration") or total
    -- finished (or all but the last seconds): the next open starts over
    if ended or not pos or pos <= 0 or (duration and duration > 0 and pos >= duration - 2) then
        os.remove(file)
        return
    end
    local temp = file .. ".tmp"
    local out = io.open(temp, "w")
    if not out then
        return
    end
    out:write(string.format("%.3f\n", pos))
    out:close()
    os.rename(temp, file)
end

mp.register_event("shutdown", save)
mp.register_event("end-file", save)
