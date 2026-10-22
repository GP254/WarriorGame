extends Node
var sheets: Dictionary = {}
var regions: Dictionary = {}
var weapon_regions: Dictionary = {}
var civilian_frames: Dictionary = {}
var character_regions: Dictionary = {}
const WARRIORS := ["ironward-v2", "ravager-v2", "pikewarden-v2", "duskranger-v2"]
const PALETTE_SHADER = preload("res://assets/cloth_palette.gdshader")

func texture(key: String) -> Texture2D:
	if not sheets.has(key): sheets[key] = load("res://assets/art/" + key + ".png")
	return sheets[key]

func cell(key: String, column: int, row: int, columns: int = 8, rows: int = 8) -> AtlasTexture:
	var cache := "%s:%d:%d:%d:%d" % [key,column,row,columns,rows]
	if not regions.has(cache):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture(key)
		var size := atlas.atlas.get_size() / Vector2(columns,rows)
		atlas.region = Rect2(Vector2(column,row) * size,size)
		atlas.filter_clip = true
		regions[cache] = atlas
	return regions[cache]

func warrior(kind: int, row: int, frame: int) -> AtlasTexture:
	return cell(WARRIORS[clampi(kind,0,3)],clampi(frame,0,7),clampi(row,0,7))

func civilian(body: int) -> SpriteFrames:
	if civilian_frames.has(body): return civilian_frames[body]
	var frames := SpriteFrames.new()
	for facing in [0,1]:
		var name := "up" if facing == 0 else "down"
		frames.add_animation(name)
		frames.set_animation_speed(name,8)
		for i in 8: frames.add_frame(name,cell("villagers-a-v2" if body < 4 else "villagers-b",i,(body % 4) * 2 + facing))
	civilian_frames[body] = frames
	return frames

func palette(index: int) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = PALETTE_SHADER
	result.set_shader_parameter("cloth_color",Color.from_hsv(float(index % 16) / 16.0,0.34 + (index / 16) * 0.22,0.5 + (index / 16) * 0.16))
	return result

func weapon_icon(item: Dictionary) -> AtlasTexture:
	if weapon_regions.is_empty(): weapon_regions = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapon-regions.json"))
	var key := "weapon:"+str(item.id)
	if not regions.has(key):
		var coordinates: Array = weapon_regions[str(item.family)][int(item.index)]
		var icon := AtlasTexture.new()
		icon.atlas = texture(str(item.family))
		icon.region = Rect2(coordinates[0],coordinates[1],coordinates[2],coordinates[3])
		icon.filter_clip = true
		regions[key] = icon
	return regions[key]

const WALKERS := ["ironward-walk8","ravager-walk8","pikewarden-walk8","duskranger-walk8"]
const VILLAGERS := ["farmer","weaver","trader","herbalist","blacksmith","baker","elder","courier"]
const ICONS := ["strike","heavy","guard","dodge","rally","talk","map","clan","settlement","pause","gold","wood","iron","bread","grain","tools","rest","health","social","bag"]

func direction(axis: Vector2) -> int:
	return posmod(roundi(axis.angle() / (PI / 4.0)) + 2,8)

func walk(kind: int, facing: int, frame: int) -> AtlasTexture:
	return character_frame(WALKERS[clampi(kind,0,3)],facing,frame)

func citizen_walk(body: int, facing: int, frame: int) -> AtlasTexture:
	return character_frame("villager-" + VILLAGERS[clampi(body,0,7)] + "-walk8",facing,frame)

func work(body: int, frame: int) -> AtlasTexture:
	return character_frame("villager-work",body,frame)

func character_frame(sheet: String, row: int, frame: int) -> AtlasTexture:
	if character_regions.is_empty(): character_regions = JSON.parse_string(FileAccess.get_file_as_string("res://data/character-regions.json"))
	var key := "%s:aligned:%d:%d" % [sheet,row,frame]
	if not regions.has(key):
		var record: Dictionary = character_regions[sheet]
		var bounds: Array = record.rows[posmod(row,8)][posmod(frame,4)]
		var atlas := AtlasTexture.new()
		atlas.atlas = texture(sheet)
		atlas.region = Rect2(bounds[0],bounds[1],bounds[2],bounds[3])
		var canvas := Vector2.ONE*float(record.canvas)
		atlas.margin = Rect2(Vector2((canvas.x-bounds[2])/2,canvas.y-bounds[3]-2),canvas-atlas.region.size)
		atlas.filter_clip = true
		regions[key] = atlas
	return regions[key]

func icon(key: String) -> AtlasTexture:
	var index := maxi(0,ICONS.find(key))
	return cell("hud-icons",index % 5,index / 5,5,4)
