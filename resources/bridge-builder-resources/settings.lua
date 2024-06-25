local root = menu.my_root() -- Racine du menu
 
local settings = {
    bridge_height = 100.0,
    max_flat_distance = 100.0,
    fluctuation_tolerance = 0.0,
    num_segments = 10,
    bell_curve_scale = 1.0,
    peak_distance_scale = 0.15
}



local ligneSettings = menu.list(root, "Paramètres de ligne", {}, "")

menu.slider(ligneSettings, "Hauteur du pont", {}, "Ajustez la hauteur du pont au-dessus du sol.", 0, 1000, settings.bridge_height, 10, function(value)
    settings.bridge_height = value
    bridge.redrawBridgePath()
end)

local max_flat_distance_slider = menu.slider(ligneSettings, "Distance max pour le plat", {}, "Ajustez la distance maximale pour la section plate du pont.", 0, 10000, settings.max_flat_distance, 10, function(value)
    settings.max_flat_distance = value
    bridge.redrawBridgePath()
end)

menu.slider(ligneSettings, "Multiple de cloche", {}, "Ajustez le facteur de cloche pour la ligne.", 1, 5, settings.bell_curve_scale, 1, function(value)
    settings.bell_curve_scale = value
    bridge.redrawBridgePath()
end)

menu.slider(ligneSettings, "Échelle de la distance de montée", {}, "Ajustez l'échelle de la distance de montée.", 1, 100, math.floor(settings.peak_distance_scale * 100), 1, function(value)
    settings.peak_distance_scale = value / 100
    bridge.redrawBridgePath()
end)

menu.toggle(ligneSettings, "Reconstruire après modifications", {}, "Reconstruire le pont après modifications de la ligne", function(value)
    settings.rebuild_on_modifications = value
end, true)

return {
    settings = settings,
    updateMaxFlatDistance = updateMaxFlatDistance
}
