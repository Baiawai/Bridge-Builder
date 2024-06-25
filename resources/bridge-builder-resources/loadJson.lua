local json = require("json")
local json_file_path = "Lua Scripts\\resources\\bridge-builder-resources\\map_data.json"
local file_path = filesystem.stand_dir() .. json_file_path

local map_datas = {}
local loadJson = {}

-- Function to load JSON file with attempts
function loadJson.loadJSON(max_attempts)
    max_attempts = max_attempts or 3
    local attempts = 0
    local success = false

    while attempts < max_attempts and not success do
        local file_content = io.contents(file_path)
        if file_content then
            local decoded_content = json.decode(file_content)
            if decoded_content and decoded_content.map_data then
                map_datas = decoded_content.map_data
                success = true
            else
                map_datas = {}
            end
        else
            map_datas = {}
        end
        attempts = attempts + 1

        if not success then
            util.toast("Failed to load JSON data. Retrying... (" .. attempts .. "/" .. max_attempts .. ")")
        end
    end

    if not success then
        util.toast("Failed to load JSON data after " .. max_attempts .. " attempts.")
    end
end

-- Function to get height from JSON
function loadJson.getHeightFromJson(x, y)
    local key = tostring(math.floor(x / 50) * 50) .. "," .. tostring(math.floor(y / 50) * 50)
    return map_datas[key] or 0.0
end

-- Function to get waypoint coordinates
function loadJson.getWaypointCoords()
    local blip = GET_FIRST_BLIP_INFO_ID(8)
    if DOES_BLIP_EXIST(blip) then
        local coord = GET_BLIP_INFO_ID_COORD(blip)
        return coord.x, coord.y, coord.z
    end
    return nil
end

return loadJson
