local bridge = {}
  
local bridge_fragments = {} 
local base_created = false 
local last_fragment = nil 
local is_creating_bridge = false

function bridge.create_bridge(model, x, y, z, rotX, rotY, rotZ)
    REQUEST_MODEL(util.joaat(model))
    while not HAS_MODEL_LOADED(util.joaat(model)) do
        util.yield()
    end
    local bridge_obj = CREATE_OBJECT(util.joaat(model), x, y, z, true, true, false)
    FREEZE_ENTITY_POSITION(bridge_obj, true)
    entities.set_can_migrate(bridge_obj, false)
    SET_ENTITY_INVINCIBLE(bridge_obj, true)
    SET_ENTITY_HAS_GRAVITY(bridge_obj, false)
    SET_ENTITY_COLLISION(bridge_obj, true, true)
    SET_ENTITY_VISIBLE(bridge_obj, true, false)
    SET_ENTITY_ROTATION(bridge_obj, rotX, rotY, rotZ, 2, true)
    SET_ENTITY_LOD_DIST(bridge_obj, 1000)
    SET_ENTITY_LOAD_COLLISION_FLAG(bridge_obj, true, 0)
    NETWORK_REQUEST_CONTROL_OF_ENTITY(bridge_obj)
    local networkId = NETWORK_GET_NETWORK_ID_FROM_ENTITY(bridge_obj)
    SET_NETWORK_ID_EXISTS_ON_ALL_MACHINES(networkId, true)
    SET_ENTITY_AS_MISSION_ENTITY(bridge_obj, true, true)
    
    return bridge_obj
end

function bridge.attach_bridge(parent, child, offsetX, offsetY, offsetZ, rotX, rotY, rotZ)
    ATTACH_ENTITY_TO_ENTITY(child, parent, 0, offsetX, offsetY, offsetZ, rotX, rotY, rotZ, false, true, true, false, 2, true, 0)
    DETACH_ENTITY(child,false, true)
    FREEZE_ENTITY_POSITION(child, true)
    NETWORK_REQUEST_CONTROL_OF_ENTITY(child)
    while not NETWORK_HAS_CONTROL_OF_ENTITY(child) do
        util.yield()
    end
    local networkId = NETWORK_GET_NETWORK_ID_FROM_ENTITY(child)
    SET_NETWORK_ID_CAN_MIGRATE(networkId, false)
    local all_players = players.list(false, true, true)
    for _, player in ipairs(all_players) do
        SET_NETWORK_ID_ALWAYS_EXISTS_FOR_PLAYER(networkId, player, true)
    end
    SET_NETWORK_ID_EXISTS_ON_ALL_MACHINES(networkId, true)
    SET_ENTITY_COLLISION(child, true, true)
    SET_ENTITY_VISIBLE(child, true, false)
    FREEZE_ENTITY_POSITION(child, true)
    SET_ENTITY_LOD_DIST(child, 1000)
    SET_ENTITY_LOAD_COLLISION_FLAG(child, true, 0)
end



function bridge.create_initial_fragment(bridge_model, bridge_points, fragment_length, distance_between_points)
    if base_created or is_creating_bridge then
        return
    end

    is_creating_bridge = true
    local total_distance = 0
    if #bridge_points > 1 then
        local point = bridge_points[1]
        local next_point = bridge_points[2]
        
        local x, y, z = point.x, point.y, point.z
        local deltaX = next_point.x - x
        local deltaY = next_point.y - y
        local deltaZ = next_point.z - z
        local yaw = math.deg(math.atan2(deltaY, deltaX))
        local distanceXY = math.sqrt(deltaX^2 + deltaY^2)
        total_distance = total_distance + distanceXY
        local pitch = -math.deg(math.atan2(deltaZ, distanceXY)) + 8.5

        local offsetX = (fragment_length / 2) * math.cos(math.rad(yaw))
        local offsetY = (fragment_length / 2) * math.sin(math.rad(yaw))
        local offsetZ = (fragment_length / 2) * math.sin(math.rad(pitch))

        local new_x = x + offsetX
        local new_y = y + offsetY
        local new_z = z + offsetZ

        local bridge_select = bridge.create_bridge(bridge_model, new_x, new_y, z - 15.7 , 0, pitch, yaw)
        table.insert(bridge_fragments, bridge_select)
        
        base_created = true
        last_fragment = bridge_select

        bridge.create_following_fragments(bridge_points, bridge_model, fragment_length)
    end

    local formatted_distance = string.format("%.2f", distance_between_points)
    util.toast(#bridge_fragments .. " fragments used for a distance of " .. formatted_distance .. " meters.")
    is_creating_bridge = false
end

function bridge.create_following_fragments(bridge_points, bridge_model, fragment_length)
    if #bridge_points > 3 and last_fragment ~= nil then
        local precede_point = bridge_points[1]
        local precede_next_point = bridge_points[2]
        local deltaX1 = precede_next_point.x - precede_point.x
        local deltaY1 = precede_next_point.y - precede_point.y
        local deltaZ1 = precede_next_point.z - precede_point.z
        local distanceXY1 = math.sqrt(deltaX1^2 + deltaY1^2)
        local pitch1 = -math.deg(math.atan2(deltaZ1, distanceXY1))

        for i = 2, #bridge_points - 1 do
            local point = bridge_points[i]
            local next_point = bridge_points[i + 1]

            local x, y, z = point.x, point.y, point.z
            local deltaX2 = next_point.x - point.x
            local deltaY2 = next_point.y - point.y
            local deltaZ2 = next_point.z - point.z
            local distanceXY2 = math.sqrt(deltaX2^2 + deltaY2^2)
            local pitch2 = -math.deg(math.atan2(deltaZ2, distanceXY2))

            local angle_difference = pitch2 - pitch1
            
            local bridge_select = bridge.create_bridge(bridge_model, x, y, z, 0, 0.0, 0.0)
            local prev_bridge = last_fragment 

            bridge.attach_bridge(prev_bridge, bridge_select, fragment_length, 0, 15.7 - angle_difference , 0,  + angle_difference, 0.0)
            table.insert(bridge_fragments, bridge_select)

            if DOES_ENTITY_EXIST(bridge_select) then
                table.insert(bridge_fragments, bridge_select)
                last_fragment = bridge_select
                pitch1 = pitch2
            else
                print("Error: Bridge segment attachment failed.")
            end
      
        end

        local final_point = bridge_points[#bridge_points]
        local last_point = bridge_points[#bridge_points - 1]
        local deltaX = final_point.x - last_point.x
        local deltaY = final_point.y - last_point.y
        local deltaZ = final_point.z - last_point.z
        local distance_to_final = math.sqrt(deltaX^2 + deltaY^2 + deltaZ^2)

        while distance_to_final > fragment_length do
            local new_x = last_point.x + (deltaX / distance_to_final) * fragment_length
            local new_y = last_point.y + (deltaY / distance_to_final) * fragment_length
            local new_z = last_point.z + (deltaZ / distance_to_final) * fragment_length

            local bridge_select = bridge.create_bridge(bridge_model, new_x, new_y, new_z, 0, 0.0, 0.0)
            local prev_bridge = last_fragment 

            bridge.attach_bridge(prev_bridge, bridge_select, fragment_length, 0, 15.7, 0, 0.0, 0.0)
            table.insert(bridge_fragments, bridge_select)

            if DOES_ENTITY_EXIST(bridge_select) then
                table.insert(bridge_fragments, bridge_select)
                last_fragment = bridge_select 
                last_point = { x = new_x, y = new_y, z = new_z }
            else
                print("Error: Bridge segment attachment failed.")
            end

            deltaX = final_point.x - last_point.x
            deltaY = final_point.y - last_point.y
            deltaZ = final_point.z - last_point.z
            distance_to_final = math.sqrt(deltaX^2 + deltaY^2 + deltaZ^2)
        end

        local bridge_select = bridge.create_bridge(bridge_model, final_point.x, final_point.y, final_point.z, 0, 0.0, 0.0)
        local prev_bridge = last_fragment 

        bridge.attach_bridge(prev_bridge, bridge_select, fragment_length, 0, 15.7, 0, 0.0, 0.0)
        table.insert(bridge_fragments, bridge_select)

        if DOES_ENTITY_EXIST(bridge_select) then
            table.insert(bridge_fragments, bridge_select)
            last_fragment = bridge_select 
        else
            print("Error: Bridge segment attachment failed.")
        end
    end
end


function bridge.delete_fragments()
    for _, fragment in ipairs(bridge_fragments) do
        if DOES_ENTITY_EXIST(fragment) then
            entities.delete_by_handle(fragment)
        end
    end
    base_created = false
    bridge_fragments = {} 
    last_fragment = nil 
end

return bridge
