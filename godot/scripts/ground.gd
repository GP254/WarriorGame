extends Node2D
var biome := 0
var settlement := true
var tiles: Array[Texture2D] = []
func setup(region: int, village: bool) -> void:
	biome = region
	settlement = village
	z_index = -10
	for row in 2:
		for column in 4: tiles.append(Art.cell("ground-tiles",column,row,4,2))
	queue_redraw()
func _draw() -> void:
	if tiles.is_empty(): return
	var tint := Color(0.74,0.78,0.73)
	for x in range(-12,12):
		for y in range(-9,9):
			var tile := biome
			if settlement:
				if x in [-1,0] or y == 0: tile = 6 if biome == 1 else 4
				if x >= -2 and x < 2 and y >= -1 and y < 2: tile = 7 if biome == 3 else 5
				if (x >= -7 and x <= -4 and y in [-6,-5]) or (x >= -3 and x < 0 and y == -5): tile = 6 if biome == 1 else 4
			draw_texture_rect(tiles[tile],Rect2(Vector2(x,y)*128,Vector2(128,128)),false,tint)
