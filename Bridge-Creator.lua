util.require_natives("3095a", "g")
local root = menu.my_root()
 
-- Load modules
local status, loadJson = pcall(require, "resources.bridge-builder-resources.loadJson")
if not status then
    util.toast("Failed to load resources.bridge-builder-resources.loadJson ")
    return
end

local status, bridge = pcall(require, "resources.bridge-builder-resources.bridge")
if not status then
    util.toast("Failed to load resources.bridge-builder-resources.bridge ")
    return
end

local status, bridge_utils = pcall(require, "resources.bridge-builder-resources.bridge_utils")
if not status then
    util.toast("Failed to load resources.bridge-builder-resources.bridge_utils ")
    return
end
local bridge = require("resources.bridge-builder-resources.bridge")
local bridge_utils = require("resources.bridge-builder-resources.bridge_utils")


-- Global Variables
local fragemnt_center = 62.161010742188 / 2
local fragment_length = 108

local bridge_model = "xs_combined_dystopian_14_brdg01"
local default_bridge_height = 100.0
local default_max_flat_distance = 100.0
local default_fluctuation_tolerance = 0.0
local default_bell_curve_scale = 1.0
local default_peak_distance_scale = 0.15
local num_segments = 10
local num_step = 0
local bridge_type = "Topographic"
local show_draw_line = false

local bridge_height = default_bridge_height
local max_flat_distance = default_max_flat_distance
local fluctuation_tolerance = default_fluctuation_tolerance
local bell_curve_scale = default_bell_curve_scale
local peak_distance_scale = default_peak_distance_scale

local bridge_points = {}
local start_coords = {}
local end_coords = {}
local coords_defined = false
local distance_between_points = 0.0

-- Load the json which contains the topography of the map
loadJson.loadJSON()

function createPathRespectingTopography(x1, y1, x2, y2, z1, z2)
    bridge_points = {}
    local total_distance = math.sqrt((x2 - x1)^2 + (y2 - y1)^2 + (z2 - z1)^2)
    local num_segments = math.ceil(total_distance / fragment_length)
    local dx = (x2 - x1) / num_segments
    local dy = (y2 - y1) / num_segments
    local dz = (z2 - z1) / num_segments
    num_step = num_segments
    for i = 0, num_segments do
        local x = x1 + (dx * i)
        local y = y1 + (dy * i)
        local z = z1 + (dz * i)
        local distance = math.sqrt((x - x1)^2 + (y - y1)^2 + (z - z1)^2)

        -- Check distances to see if settings are applied correctly
        if distance < total_distance * peak_distance_scale then
            z = loadJson.getHeightFromJson(x, y) + (distance / (total_distance * peak_distance_scale)) * (bridge_height * bell_curve_scale)
        elseif distance < total_distance * (peak_distance_scale + max_flat_distance / total_distance) then
            z = loadJson.getHeightFromJson(x, y) + (bridge_height * bell_curve_scale)
        else
            local descend_distance = total_distance - (total_distance * peak_distance_scale + max_flat_distance)
            z = loadJson.getHeightFromJson(x, y) + (bridge_height * bell_curve_scale) * (1 - (distance - (total_distance * peak_distance_scale + max_flat_distance)) / descend_distance)
        end

        table.insert(bridge_points, {x = x, y = y, z = z})
    end

    bridge_points = bridge_utils.smoothData(bridge_points, fluctuation_tolerance)
end

function createFlatPath(x1, y1, x2, y2, z1, z2)
    bridge_points = {}
    local total_distance = math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
    local num_segments = math.ceil(total_distance / fragment_length)
    local dx = (x2 - x1) / num_segments
    local dy = (y2 - y1) / num_segments
    num_step = num_segments

    -- Calculate distances for each section
    local ascend_segments = math.ceil(num_segments * peak_distance_scale)
    local descend_segments = math.ceil(num_segments * peak_distance_scale)
    local middle_segments = num_segments - (ascend_segments + descend_segments)

    -- Find the highest terrain point on the path
    local highest_terrain_z = math.max(z1, z2)
    for i = 0, num_segments do
        local x = x1 + dx * i
        local y = y1 + dy * i
        local terrain_height = loadJson.getHeightFromJson(x, y)
        if terrain_height > highest_terrain_z then
            highest_terrain_z = terrain_height
        end
    end

    -- Calculate highest point of the curve
    local highest_point_z = highest_terrain_z + bridge_height
    if highest_point_z < bridge_height then
        highest_point_z = bridge_height
    end

    -- Ascending part of the curve
    for i = 0, ascend_segments do
        local x = x1 + dx * i
        local y = y1 + dy * i
        local t = i / ascend_segments
        local z = z1 + (highest_point_z - z1) * t
        table.insert(bridge_points, {x = x, y = y, z = z})
    end

    -- Middle part of the curve
    for i = 1, middle_segments do
        local x = x1 + dx * (ascend_segments + i)
        local y = y1 + dy * (ascend_segments + i)
        local t = i / middle_segments
        local z = highest_point_z
        table.insert(bridge_points, {x = x, y = y, z = z})
    end

    -- Descending part of the curve
    for i = 1, descend_segments do
        local x = x1 + dx * (ascend_segments + middle_segments + i)
        local y = y1 + dy * (ascend_segments + middle_segments + i)
        local t = i / descend_segments
        local z = highest_point_z - (highest_point_z - z2) * t
        table.insert(bridge_points, {x = x, y = y, z = z})
    end

    bridge_points = bridge_utils.smoothData(bridge_points, fluctuation_tolerance)
end

function createCurvePath(x1, y1, x2, y2, z1, z2)
    bridge_points = {}
    local total_distance = math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
    local num_segments = math.ceil(total_distance / fragment_length)
    local dx = (x2 - x1) / num_segments
    local dy = (y2 - y1) / num_segments
    num_step = num_segments

    -- Find the maximum height on the path
    local highest_terrain_z = math.max(z1, z2)
    local peak_segment = math.floor(num_segments / 2)  -- Initial assumption for peak segment
    for i = 0, num_segments do
        local x = x1 + dx * i
        local y = y1 + dy * i
        local terrain_height = loadJson.getHeightFromJson(x, y)
        if terrain_height > highest_terrain_z then
            highest_terrain_z = terrain_height
            peak_segment = i  -- Adjust peak segment to avoid mountain
        end
    end

    -- Calculate the height of the highest point of the bridge
    local highest_point_z = math.max(highest_terrain_z + bridge_height, bridge_height)
    local middle_index = peak_segment

    -- Recalculate the number of segments
    local ascend_segments = middle_index
    local descend_segments = num_segments - middle_index
    local middle_segments = 1  

    -- Ascending part of the curve
    for i = 0, ascend_segments do
        local x = x1 + dx * i
        local y = y1 + dy * i
        local t = i / ascend_segments
        local z = z1 + (highest_point_z - z1) * t
        table.insert(bridge_points, {x = x, y = y, z = z})
    end

    -- Flat part in the middle of the curve
    local flat_x = x1 + dx * (ascend_segments + 1)
    local flat_y = y1 + dy * (ascend_segments + 1)
    local flat_z = highest_point_z
    table.insert(bridge_points, {x = flat_x, y = flat_y, z = flat_z})

    -- Descending part of the curve
    for i = 1, descend_segments do
        local x = flat_x + dx * i
        local y = flat_y + dy * i
        local t = i / descend_segments
        local z = highest_point_z - (highest_point_z - z2) * t
        table.insert(bridge_points, {x = x, y = y, z = z})
    end

    bridge_points = bridge_utils.smoothData(bridge_points, fluctuation_tolerance)
end

function drawBridgePath()
    local segment_index = 0  -- Global variable to keep track of current segment
    for i = 1, #bridge_points - 1 do
        local p1 = bridge_points[i]
        local p2 = bridge_points[i + 1]
        local segment_length = math.sqrt((p2.x - p1.x)^2 + (p2.y - p1.y)^2 + (p2.z - p1.z)^2)
        local num_segments = math.ceil(segment_length / fragment_length)

        for j = 0, num_segments - 1 do
            local t1 = j / num_segments
            local t2 = (j + 1) / num_segments
            local x1 = bridge_utils.lerp(p1.x, p2.x, t1)
            local y1 = bridge_utils.lerp(p1.y, p2.y, t1)
            local z1 = bridge_utils.lerp(p1.z, p2.z, t1)
            local x2 = bridge_utils.lerp(p1.x, p2.x, t2)
            local y2 = bridge_utils.lerp(p1.y, p2.y, t2)
            local z2 = bridge_utils.lerp(p1.z, p2.z, t2)

            
            -- Alternating colors: red (255, 0, 0, 255) and orange (255, 165, 0, 255)
            if show_draw_line then 
                if segment_index % 2 == 0 then
                    bridge_utils.drawLine(x1, y1, z1, x2, y2, z2, 255, 0, 0, 255)
                else
                    bridge_utils.drawLine(x1, y1, z1, x2, y2, z2, 255, 165, 0, 255)
                end
            end
            segment_index = segment_index + 1
        end
    end
end

function createPath(x1, y1, x2, y2, z1, z2)
    if not start_coords.x or not start_coords.y or not start_coords.z then
        util.toast("Start coordinates are not defined")
        return
    end

    if not end_coords.x or not end_coords.y or not end_coords.z then
        util.toast("End coordinates are not defined")
        return
    end

    if bridge_type == "Topographic" then
        createPathRespectingTopography(x1, y1, x2, y2, z1, z2)
    elseif bridge_type == "Flat" then
        createFlatPath(x1, y1, x2, y2, z1, z2)
    else
        createCurvePath(x1, y1, x2, y2, z1, z2)
    end
end

function redrawBridgePath()
    if start_coords.x and start_coords.y and start_coords.z and end_coords.x and end_coords.y and end_coords.z then
        
        distance_between_points = math.sqrt((end_coords.x - start_coords.x)^2 + (end_coords.y - start_coords.y)^2) * 0.85

        createPath(start_coords.x, start_coords.y, end_coords.x, end_coords.y, start_coords.z, end_coords.z)
        drawBridgePath()
        set_valueMenu()
        if coords_defined then
            bridge.delete_fragments()
            bridge.create_initial_fragment(bridge_model, bridge_points, fragment_length)
        end
    end
end

menu.my_root():divider("Bridge Creator")

local submenu_active = false

local construction_settings = menu.list(root, lang.find("Settings", "en"), {}, "Set the default parameters before starting construction.")

local height_setting_base = menu.slider(construction_settings, lang.find("Height", "en"), {}, "Adjust the height of the bridge above the ground.", 0, 1000, default_bridge_height, 10, function(value)
    bridge_height = value
    default_bridge_height = bridge_height
    set_valueBridgeSettings()
end)

local cuveScale_setting_base = menu.slider(construction_settings, "Multiple", {}, "Adjust the bell curve factor for the line.", 1, 5, default_bell_curve_scale, 1, function(value)
    bell_curve_scale = value
    default_bell_curve_scale = bell_curve_scale
    set_valueBridgeSettings()
end)

local peak_setting_base = menu.slider(construction_settings, "Climb distance scale", {}, "Adjust the scale of the ascent distance.", 0, 10000, math.floor(default_peak_distance_scale * 100), 5, function(value)
    peak_distance_scale = value / 100
    default_peak_distance_scale = peak_distance_scale
    set_valueBridgeSettings()
end)

local bridge_menu_type = menu.list_select(root, "Bridge Type", {}, "Select the type of bridge construction.", {
    {1, "Topographic"},
    {2, "Flat"},
    {3, "Curved"},
    
}, 1, function(value)
    if value == 1 then
        bridge_type = "Topographic"
    elseif value == 2 then
        bridge_type = "Flat"
    else 
        bridge_type = "Curved"
    end
    redrawBridgePath()
end)

local toggle_menu_loop = menu.toggle_loop(root, "Start building the bridge", {}, "Activate bridge construction mode", function()
    if not coords_defined then
        local player_ped = players.user_ped()
        local player_coords = GET_ENTITY_COORDS(player_ped, true)

        local waypoint_x, waypoint_y, waypoint_z = loadJson.getWaypointCoords()
        if waypoint_x and waypoint_y then
            start_coords = {x = player_coords.x, y = player_coords.y, z = player_coords.z}
            end_coords = {x = waypoint_x, y = waypoint_y, z = waypoint_z}
            coords_defined = true
            distance_between_points = math.sqrt((end_coords.x - start_coords.x)^2 + (end_coords.y - start_coords.y)^2)
            updateMaxFlatDistance()
            distance_between_points = math.sqrt((end_coords.x - start_coords.x)^2 + (end_coords.y - start_coords.y)^2) * 0.85

            util.toast(distance_between_points)
            createPathRespectingTopography(start_coords.x, start_coords.y, end_coords.x, end_coords.y, start_coords.z, end_coords.z)

            set_valueMenu()

            bridge.create_initial_fragment(bridge_model, bridge_points, fragment_length)
            update_menu_name(true)
        else
            util.toast("Please place a waypoint on the map.")

            bridge_points = {}
        end
    end

    if coords_defined then
        drawBridgePath()
        if submenu_active == false then
            show_submenu()
        end
    end
    
    util.yield()
end, function()
    default_bridge_height = 100.0
    default_max_flat_distance = 100.0
    default_fluctuation_tolerance = 0.0
    default_bell_curve_scale = 1.0
    default_peak_distance_scale = 0.15
    num_segments = 10
    num_step = 0
    coords_defined = false
    base_created = false
    bridge_points = {}
    start_coords = {}
    end_coords = {}
    bridge_height = default_bridge_height
    max_flat_distance = default_max_flat_distance
    fluctuation_tolerance = default_fluctuation_tolerance
    bell_curve_scale = default_bell_curve_scale
    peak_distance_scale = default_peak_distance_scale
    hide_submenu()
    if distance_item then
        menu.set_value(distance_item, "0.0")
    end
    if segment_item then
        menu.set_value(segment_item, tostring(num_segments))
    end
    if avg_height_item then
        menu.set_value(avg_height_item, "0.0")
    end
    if total_points_item then
        menu.set_value(total_points_item, "0")
    end
   
    bridge.delete_fragments()
    
    menu.set_value(bridge_menu_type, 1)
    bridge_type = "Topographic"
    set_valueBridgeSettings()
    set_valueBaseBridgeSettings()
    update_menu_name(false)
end)

function update_menu_name(state)
    if state then
        menu.set_menu_name(toggle_menu_loop, lang.find("Remove", "en"))
    else
        menu.set_menu_name(toggle_menu_loop, "Start building the bridge")
    end
end

local bridgeInfoMenu = menu.list(root, "Information", {}, "")
local pointA_coords_item = menu.readonly(bridgeInfoMenu, "Player Coordinates", "N/A")
local pointB_coords_item = menu.readonly(bridgeInfoMenu, "Waypoint Coordinates", "N/A")
local distance_item = menu.readonly(bridgeInfoMenu, "Distance between player and point", "0.0")
local avg_height_item = menu.readonly(bridgeInfoMenu, "Average bridge height", "0.0")
local segment_item = menu.readonly(bridgeInfoMenu, "Number of segments", "0")
local total_points_item = menu.readonly(bridgeInfoMenu, "Total number of points", "0")
local bridge_type_item = menu.readonly(bridgeInfoMenu, "Bridge type", "Topographic")

local bridgeSettings = menu.list(root, lang.find("Settings", "en"), {}, "")

local height_setting = menu.slider(bridgeSettings, lang.find("Height", "en"), {}, "Adjust the height of the bridge above the ground.", 0, 1000, default_bridge_height, 10, function(value)
    bridge_height = value
    redrawBridgePath()
end)

local cuveScale_setting = menu.slider(bridgeSettings, "Multiple", {}, "Adjust the bell curve factor for the line.", 1, 5, default_bell_curve_scale, 1, function(value)
    bell_curve_scale = value
    redrawBridgePath()
end)

local max_flat_distance_slider = menu.slider(bridgeSettings, "Flat Section Distance Scale", {}, "Adjust the maximum distance for the flat section of the bridge.", 0, 10000, default_max_flat_distance, 10, function(value)
    max_flat_distance = value
    redrawBridgePath()
end)

local peak_setting = menu.slider(bridgeSettings, "Climb distance scale", {}, "Adjust the scale of the ascent distance.", 0, 10000, math.floor(default_peak_distance_scale * 100), 5, function(value)
    peak_distance_scale = value / 100
    redrawBridgePath()
end)
local showLine_setting = menu.toggle(bridgeSettings, "Debug line", {}, "Hide/Show the debuge line", function(value)
    show_draw_line = value
    redrawBridgePath()
end, false)

function set_valueBridgeSettings()
    menu.set_value(height_setting, default_bridge_height)
    menu.set_value(cuveScale_setting, default_bell_curve_scale)
    menu.set_value(peak_setting, math.floor(default_peak_distance_scale * 100))
end
function set_valueBaseBridgeSettings()
    menu.set_value(height_setting_base, default_bridge_height)
    menu.set_value(cuveScale_setting_base, default_bell_curve_scale)
    menu.set_value(peak_setting_base, math.floor(default_peak_distance_scale * 100))
end
function updateMaxFlatDistance()
    local calculated_max_flat_distance = math.max(0, distance_between_points * 0.85)
    menu.set_value(max_flat_distance_slider, math.floor(calculated_max_flat_distance))
end

function show_submenu()
    menu.set_visible(bridgeInfoMenu, true)
    menu.set_visible(bridgeSettings, true)
    menu.set_visible(distance_item, true)
    menu.set_visible(segment_item, true)
    menu.set_visible(avg_height_item, true)
    menu.set_visible(total_points_item, true)
    menu.set_visible(bridge_menu_type, false)
    menu.set_visible(construction_settings, false)

    toggle_menu_loop:focus()
    submenu_active = true
end

function hide_submenu()
    menu.set_visible(bridgeInfoMenu, false)
    menu.set_visible(bridgeSettings, false)
    menu.set_visible(distance_item, false)
    menu.set_visible(segment_item, false)
    menu.set_visible(avg_height_item, false)
    menu.set_visible(total_points_item, false)
    menu.set_visible(bridge_menu_type, true)
    menu.set_visible(construction_settings, true)

    toggle_menu_loop:focus()
    submenu_active = false
end

function set_valueMenu()
    if distance_item then
        menu.set_value(distance_item, string.format("%.2f", distance_between_points))
    end
    if segment_item then
        menu.set_value(segment_item, tostring(num_step))
    end
    if avg_height_item then
        menu.set_value(avg_height_item, string.format("%.2f", bridge_utils.calculateAverageHeight(bridge_points)))
    end
    if total_points_item then
        menu.set_value(total_points_item, tostring(#bridge_points))
    end
    if bridge_type_item then
        menu.set_value(bridge_type_item, bridge_type)
    end
    if pointA_coords_item then
        menu.set_value(pointA_coords_item, string.format("X: %.2f, Y: %.2f, Z: %.2f", start_coords.x, start_coords.y, start_coords.z))
    end
    if pointB_coords_item then
        menu.set_value(pointB_coords_item, string.format("X: %.2f, Y: %.2f, Z: %.2f", end_coords.x, end_coords.y, end_coords.z))
    end
end

hide_submenu()
