local bridge_utils = {}
 
function bridge_utils.drawLine(x1, y1, z1, x2, y2, z2, r, g, b, a)
    DRAW_LINE(x1, y1, z1, x2, y2, z2, r, g, b, a)
end

function bridge_utils.lerp(a, b, t)
    return a + (b - a) * t
end

function bridge_utils.smoothData(points, tolerance)
    local smoothed_points = {}
    for i = 2, #points - 1 do
        local p1 = points[i - 1]
        local p2 = points[i]
        local p3 = points[i + 1]
        
        local avg_z = (p1.z + p2.z + p3.z) / 3
        if math.abs(p2.z - avg_z) > tolerance then
            table.insert(smoothed_points, {x = p2.x, y = p2.y, z = avg_z})
        else
            table.insert(smoothed_points, {x = p2.x, y = p2.y, z = p2.z})
        end
    end
    
    table.insert(smoothed_points, 1, points[1])
    table.insert(smoothed_points, points[#points])
    
    return smoothed_points
end

return bridge_utils
