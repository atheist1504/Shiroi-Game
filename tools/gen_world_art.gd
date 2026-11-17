extends SceneTree

# Sinh hình bản đồ bằng code (không cần họa sĩ), chạy từ thư mục dự án:
#   1) Godot --headless --path . -s tools/gen_world_art.gd -- images
#      Vẽ bộ tile pixel 16x16 (assets/tiles/terrain_tiles.png) và ảnh lục địa
#      (assets/maps/continent.png, 2 điểm ảnh mỗi ô).
#   2) Godot --headless --path . --import       (để Godot nhập ảnh mới)
#   3) Godot --headless --path . -s tools/gen_world_art.gd -- paint
#      Dựng lại tileset (assets/tiles/terrain_tileset.tres) và tô lại
#      scenes/world_map.tscn từ loại nền đang có: giữ nguyên ô nào là cỏ, đất,
#      nước, vách đá... (nên va chạm và các khu không đổi), chỉ thay hình, thêm
#      đường mòn, viền cỏ, bờ nước, hoa đá, cây.
# Muốn đổi bố cục thì sửa loại nền trong editor rồi chạy lại bước 3.
# Bố cục ảnh tile (16 cột):
#   hàng 0-10  nền theo enum Ground, cột 0-7 là biến thể
#   hàng 11    nước, cột = mặt nạ cạnh giáp đất (B=1, Đ=2, N=4, T=8)
#   hàng 12    vách đá, cột = mặt nạ cạnh hở
#   hàng 13    viền cỏ phủ lên nền khác, cột = mặt nạ cạnh giáp cỏ
#   hàng 14    đường mòn, cột = mặt nạ cạnh nối đường mòn
#   hàng 15    vật trang trí nhỏ
#   hàng 16-17 cây 2x2 ô: cột 0 sồi, 2 thông, 4 cây trăng, 6 cây khô
#   hàng 18-20 mảng cỏ cao / đất trống / đồng hoa, cột = mặt nạ nối mảng
#   hàng 21-23 cây to 3x3 ô: cột 0 sồi, 3 sồi sẫm, 6 cây thu, 9 cây hoa hồng, 12 cây trăng
#   hàng 24-25 vật thể: 0 tảng đá 2x2, 2 bụi hoa 2x2, 4 gốc cây, 5 khúc gỗ 2x1,
#              10 cụm đá mỏ 2x2, 12 cụm quặng sắt 2x2, 14 cụm quặng vàng 2x2,
#              7 dương xỉ, 8 đá rêu, 9 cụm nấm
#   hàng 26    gò đất cao (chặn đường), cột = mặt nạ cạnh hở
#   hàng 27    cầu gỗ: cột 0 lối đông-tây, cột 1 lối bắc-nam
# Có ảnh gốc AI ở assets/tiles/source/ thì tools/ai_art.gd đè hình AI lên cây
# (hàng 16, 21: cột 0, 3, 12 là ba biến thể cây tán xanh bạc), vật thể, quặng,
# cột đá, tinh thể, cầu; nền, nước, vách vẫn vẽ bằng code.
# Mọi hình đều là tile trong tileset: sửa ảnh terrain_tiles.png bằng tay hay
# thay ảnh khác cùng bố cục thì bản đồ tự đổi theo.

const T := 16
const COLS := 16
const ROWS := 28
const TILE_PNG := "res://assets/tiles/terrain_tiles.png"
const TILESET_PATH := "res://assets/tiles/terrain_tileset.tres"
const MAP_SCENE := "res://scenes/world_map.tscn"
const CONTINENT_PNG := "res://assets/maps/continent.png"

enum G { GRASS, FOREST, DIRT, STONE, RUST, GOLD, MUD, SAND, RUIN, WATER, CLIFF, VOID }
const ROW_WATER := 11
const ROW_CLIFF := 12
const ROW_FRINGE := 13
const ROW_TRAIL := 14
const ROW_DECO := 15
const ROW_TREE := 16
enum D { FLOWER_MOON, FLOWER_RED, FLOWER_YELLOW, FLOWER_PURPLE, PEBBLE, ROCK, MUSHROOM, REEDS, PILLAR, CRYSTAL, ORE, LILY, BUSH, TUFT, CHIP, LEAVES }
enum TREE { OAK = 0, PINE = 2, MOON = 4, DEAD = 6 }
const ROW_TALL := 18
const ROW_BARE := 19
const ROW_MEADOW := 20
const ROW_BIGTREE := 21
const ROW_PROPS := 24
const ROW_HIGHLAND := 26
const ROW_BRIDGE := 27
enum BIG { OAK = 0, DARK = 3, AUTUMN = 6, BLOSSOM = 9, MOON = 12 }
enum P { BOULDER = 0, BUSH2 = 2, STUMP = 4, LOG = 5, FERN = 7, MOSSROCK = 8, SHROOMS = 9, ORE_STONE = 10, ORE_IRON = 12, ORE_GOLD = 14 }
const BIG_SHADES := {
	BIG.OAK: [Color(0.11, 0.24, 0.12), Color(0.18, 0.38, 0.17), Color(0.27, 0.52, 0.22), Color(0.38, 0.65, 0.28), Color(0.55, 0.78, 0.38)],
	BIG.DARK: [Color(0.07, 0.20, 0.16), Color(0.12, 0.32, 0.25), Color(0.18, 0.44, 0.32), Color(0.27, 0.56, 0.40), Color(0.40, 0.68, 0.50)],
	BIG.AUTUMN: [Color(0.35, 0.15, 0.06), Color(0.58, 0.28, 0.10), Color(0.78, 0.45, 0.15), Color(0.90, 0.62, 0.22), Color(0.98, 0.80, 0.40)],
	BIG.BLOSSOM: [Color(0.45, 0.20, 0.32), Color(0.72, 0.40, 0.55), Color(0.88, 0.58, 0.72), Color(0.96, 0.75, 0.85), Color(1.0, 0.90, 0.95)],
	BIG.MOON: [Color(0.12, 0.22, 0.32), Color(0.25, 0.42, 0.52), Color(0.40, 0.62, 0.70), Color(0.62, 0.82, 0.86), Color(0.85, 0.96, 0.98)],
}

const AI_ART := preload("res://tools/ai_art.gd")
var _img: Image
# Có ảnh gốc AI thì rừng dùng nhiều biến thể cây tán xanh bạc.
var _ai_art: bool = AI_ART.new().has_sources()
# Gốc khung bản đồ (ô) khi tô: MAP_ORIGIN của world_terrain.gd (âm, vì bản đồ nối ra lục địa).
var _o := Vector2i.ZERO
const OLD_FOREST_CELLS := Vector2i(160, 90)
const TERRAIN_SCRIPT := "res://scripts/world_terrain.gd"
const PLAY_MASK_PNG := "res://assets/maps/play_mask.png"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if "images" in args:
		_make_tiles()
		_make_continent()
		print("Đã vẽ ảnh tile và ảnh lục địa.")
	elif "layout" in args:
		await _layout()
	elif "expand" in args:
		_expand()
	elif "paint" in args:
		await _paint()
	else:
		printerr("Cần tham số: -- images hoặc -- paint")
	quit()

# ---------------------------------------------------------------- tiện ích

func _h(x: int, y: int, s: int) -> float:
	var n: int = x * 374761393 + y * 668265263 + s * 1274126177
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFF) / 65535.0

func _px(ox: int, oy: int, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= T or y >= T:
		return
	if c.a >= 1.0:
		_img.set_pixel(ox + x, oy + y, c)
	else:
		_img.set_pixel(ox + x, oy + y, _img.get_pixel(ox + x, oy + y).blend(c))

func _pick(colors: Array, r: float) -> Color:
	return colors[mini(int(r * colors.size()), colors.size() - 1)]

func _fill_noise(ox: int, oy: int, colors: Array, s: int, weights: Array = []) -> void:
	for y in T:
		for x in T:
			var r := _h(ox + x, oy + y, s)
			var c: Color = colors[0]
			if weights.is_empty():
				c = _pick(colors, r)
			else:
				var acc := 0.0
				for i in weights.size():
					acc += weights[i]
					if r <= acc:
						c = colors[i]
						break
			_img.set_pixel(ox + x, oy + y, c)

func _cell(col: int, row: int) -> Vector2i:
	return Vector2i(col * T, row * T)

# ---------------------------------------------------------------- tile nền

const GRASS_C := [Color(0.35, 0.57, 0.27), Color(0.32, 0.53, 0.25), Color(0.39, 0.62, 0.29)]
const GRASS_DARK := Color(0.26, 0.45, 0.21)
const GRASS_LIGHT := Color(0.49, 0.71, 0.34)
const FOREST_C := [Color(0.24, 0.40, 0.22), Color(0.21, 0.36, 0.20), Color(0.27, 0.44, 0.24)]
const DIRT_C := [Color(0.55, 0.41, 0.27), Color(0.51, 0.37, 0.25), Color(0.59, 0.45, 0.30)]
const STONE_C := [Color(0.50, 0.50, 0.53), Color(0.46, 0.46, 0.49), Color(0.54, 0.54, 0.57)]
const RUST_C := [Color(0.50, 0.34, 0.26), Color(0.46, 0.31, 0.24), Color(0.54, 0.37, 0.28)]
const GOLD_C := [Color(0.58, 0.51, 0.37), Color(0.54, 0.47, 0.34), Color(0.62, 0.55, 0.40)]
const MUD_C := [Color(0.34, 0.31, 0.21), Color(0.31, 0.28, 0.19), Color(0.37, 0.34, 0.23)]
const SAND_C := [Color(0.86, 0.77, 0.53), Color(0.83, 0.73, 0.50), Color(0.89, 0.80, 0.57)]
const RUIN_C := [Color(0.60, 0.58, 0.63), Color(0.56, 0.54, 0.59), Color(0.64, 0.62, 0.66)]
const WATER_C := [Color(0.20, 0.47, 0.62), Color(0.18, 0.44, 0.59), Color(0.22, 0.50, 0.65)]
const ROCK_C := [Color(0.47, 0.44, 0.41), Color(0.43, 0.40, 0.38), Color(0.51, 0.48, 0.45)]

func _make_tiles() -> void:
	_img = Image.create(COLS * T, ROWS * T, false, Image.FORMAT_RGBA8)
	_img.fill(Color(0, 0, 0, 0))
	for v in 8:
		_grass(_cell(v, G.GRASS), v)
		_forest(_cell(v, G.FOREST), v)
		_dirt(_cell(v, G.DIRT), v)
		_stone(_cell(v, G.STONE), v, STONE_C, Color(0.66, 0.66, 0.70), Color(0.34, 0.34, 0.38), Color(0, 0, 0, 0))
		_stone(_cell(v, G.RUST), v, RUST_C, Color(0.68, 0.45, 0.30), Color(0.33, 0.22, 0.17), Color(0.85, 0.48, 0.22))
		_stone(_cell(v, G.GOLD), v, GOLD_C, Color(0.75, 0.68, 0.52), Color(0.40, 0.35, 0.25), Color(1.0, 0.86, 0.32))
		_mud(_cell(v, G.MUD), v)
		_sand(_cell(v, G.SAND), v)
		_ruin(_cell(v, G.RUIN), v)
		_water(_cell(v, G.WATER), 0, v)
		_cliff(_cell(v, G.CLIFF), 0, v)
	for mask in 16:
		_water(_cell(mask, ROW_WATER), mask, mask)
		_cliff(_cell(mask, ROW_CLIFF), mask, mask)
		_fringe(_cell(mask, ROW_FRINGE), mask)
		_trail(_cell(mask, ROW_TRAIL), mask)
	_decorations()
	_tree_oak(_cell(TREE.OAK, ROW_TREE), [Color(0.17, 0.33, 0.17), Color(0.25, 0.46, 0.22), Color(0.36, 0.60, 0.28), Color(0.50, 0.73, 0.36)])
	_tree_pine(_cell(TREE.PINE, ROW_TREE))
	_tree_oak(_cell(TREE.MOON, ROW_TREE), [Color(0.20, 0.33, 0.42), Color(0.36, 0.55, 0.62), Color(0.56, 0.78, 0.82), Color(0.82, 0.95, 0.96)])
	_tree_dead(_cell(TREE.DEAD, ROW_TREE))
	for mask in 16:
		_patch(_cell(mask, ROW_TALL), mask, ROW_TALL)
		_patch(_cell(mask, ROW_BARE), mask, ROW_BARE)
		_patch(_cell(mask, ROW_MEADOW), mask, ROW_MEADOW)
		_highland(_cell(mask, ROW_HIGHLAND), mask)
	for kind in BIG_SHADES:
		_big_tree(_cell(kind, ROW_BIGTREE), BIG_SHADES[kind], 50 + kind)
	_props()
	_bridge(_cell(0, ROW_BRIDGE), true)
	_bridge(_cell(1, ROW_BRIDGE), false)
	# Hình do công cụ AI vẽ (assets/tiles/source/) đè lên cây, vật thể, quặng, cầu.
	var ai = AI_ART.new()
	if ai.has_sources():
		ai.apply_tiles(_img)
		ai.make_sprites()
	_save(_img, TILE_PNG)

func _save(image: Image, path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	image.save_png(abs_path)

func _grass(o: Vector2i, v: int) -> void:
	_fill_noise(o.x, o.y, GRASS_C, 11 + v, [0.55, 0.3, 0.15])
	var count := 7 + v
	for i in count:
		var x := int(_h(i, v, 21) * 16)
		var y := int(_h(i, v, 22) * 15)
		_px(o.x, o.y, x, y + 1, GRASS_DARK)
		_px(o.x, o.y, x, y, GRASS_LIGHT if _h(i, v, 23) > 0.5 else GRASS_DARK)
	if v >= 6:
		# Cỏ ba lá nhỏ.
		var cx := 4 + int(_h(v, 1, 24) * 8)
		var cy := 4 + int(_h(v, 2, 24) * 8)
		for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]:
			_px(o.x, o.y, cx + d.x, cy + d.y, Color(0.45, 0.68, 0.32))
		_px(o.x, o.y, cx, cy + 1, GRASS_DARK)

func _forest(o: Vector2i, v: int) -> void:
	_fill_noise(o.x, o.y, FOREST_C, 31 + v, [0.5, 0.3, 0.2])
	for i in 6 + v:
		var x := int(_h(i, v, 32) * 16)
		var y := int(_h(i, v, 33) * 16)
		var leaf := [Color(0.42, 0.32, 0.18), Color(0.50, 0.38, 0.20), Color(0.30, 0.48, 0.25), Color(0.18, 0.30, 0.17)]
		_px(o.x, o.y, x, y, _pick(leaf, _h(i, v, 34)))
		if _h(i, v, 35) > 0.6:
			_px(o.x, o.y, x + 1, y, _pick(leaf, _h(i, v, 36)))

func _dirt(o: Vector2i, v: int) -> void:
	_fill_noise(o.x, o.y, DIRT_C, 41 + v, [0.5, 0.3, 0.2])
	for i in 2 + v % 3:
		_pebble(o, int(2 + _h(i, v, 42) * 12), int(2 + _h(i, v, 43) * 12), Color(0.62, 0.55, 0.47), Color(0.40, 0.31, 0.22))
	if v >= 5:
		var x := int(3 + _h(v, 0, 44) * 9)
		var y := int(3 + _h(v, 1, 44) * 9)
		for k in 4:
			_px(o.x, o.y, x + k, y + (k % 2), Color(0.40, 0.29, 0.19))

func _pebble(o: Vector2i, x: int, y: int, light: Color, dark: Color) -> void:
	_px(o.x, o.y, x, y, light)
	_px(o.x, o.y, x + 1, y, light.darkened(0.12))
	_px(o.x, o.y, x, y + 1, dark.lightened(0.15))
	_px(o.x, o.y, x + 1, y + 1, dark)

func _stone(o: Vector2i, v: int, base: Array, light: Color, dark: Color, speck: Color) -> void:
	_fill_noise(o.x, o.y, base, 51 + v * 7 + int(light.r * 100), [0.5, 0.3, 0.2])
	# Vài tảng đá: viền sáng góc trên trái, tối góc dưới phải.
	for i in 2 + v % 2:
		var cx := 3 + int(_h(i, v, 52 + int(light.g * 50)) * 10)
		var cy := 3 + int(_h(i, v, 53 + int(light.g * 50)) * 10)
		var r := 2 + int(_h(i, v, 54) * 2)
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if x * x + y * y > r * r:
					continue
				var c: Color = base[2]
				if x + y <= -r + 1:
					c = light
				elif x + y >= r - 1:
					c = dark
				_px(o.x, o.y, cx + x, cy + y, c)
	if speck.a > 0.0:
		for i in 2 + v % 3:
			var x := int(_h(i, v, 55) * 15)
			var y := int(_h(i, v, 56) * 15)
			_px(o.x, o.y, x, y, speck)
			if v % 2 == 0:
				_px(o.x, o.y, x + 1, y, speck.lightened(0.3))

func _mud(o: Vector2i, v: int) -> void:
	_fill_noise(o.x, o.y, MUD_C, 61 + v, [0.5, 0.3, 0.2])
	if v % 2 == 0:
		var cx := 4 + int(_h(v, 0, 62) * 7)
		var cy := 4 + int(_h(v, 1, 62) * 7)
		for y in range(-2, 3):
			for x in range(-3, 4):
				if (x * x) / 9.0 + (y * y) / 4.0 <= 1.0:
					_px(o.x, o.y, cx + x, cy + y, Color(0.22, 0.25, 0.22))
		_px(o.x, o.y, cx - 1, cy - 1, Color(0.45, 0.52, 0.50))
		_px(o.x, o.y, cx, cy - 1, Color(0.38, 0.44, 0.42))
	for i in 3:
		_px(o.x, o.y, int(_h(i, v, 63) * 16), int(_h(i, v, 64) * 16), Color(0.29, 0.36, 0.20))

func _sand(o: Vector2i, v: int) -> void:
	_fill_noise(o.x, o.y, SAND_C, 71 + v, [0.5, 0.3, 0.2])
	# Gợn cát chạy ngang, nối liền giữa các ô.
	for row in [3, 8, 13]:
		for x in T:
			var y: int = row + int(round(sin((x + v * 3) * 0.55) * 1.2))
			_px(o.x, o.y, x, y, Color(0.92, 0.84, 0.62))
			_px(o.x, o.y, x, y + 1, Color(0.76, 0.66, 0.44))
	if v >= 6:
		_pebble(o, 6, 6, Color(0.75, 0.70, 0.62), Color(0.55, 0.48, 0.38))

func _ruin(o: Vector2i, v: int) -> void:
	var mortar := Color(0.47, 0.45, 0.50)
	for by in 2:
		for bx in 2:
			var shade := _h(bx + v * 2, by, 81) * 0.08 - 0.04
			for y in 8:
				for x in 8:
					var c: Color = _pick(RUIN_C, _h(o.x + bx * 8 + x, o.y + by * 8 + y, 82))
					c = c.lightened(shade) if shade > 0 else c.darkened(-shade)
					if x == 0 or y == 0:
						c = mortar
					elif x == 1 or y == 1:
						c = c.lightened(0.08)
					_px(o.x, o.y, bx * 8 + x, by * 8 + y, c)
	if v >= 4:
		# Vết nứt.
		var x := 3 + int(_h(v, 0, 83) * 9)
		var y := 2 + int(_h(v, 1, 83) * 4)
		for k in 6:
			_px(o.x, o.y, x + int(_h(k, v, 84) * 2), y + k, mortar)
	if v >= 6:
		for i in 5:
			_px(o.x, o.y, int(_h(i, v, 85) * 16), int(_h(i, v, 86) * 16), Color(0.36, 0.52, 0.30))

func _water(o: Vector2i, mask: int, v: int) -> void:
	_fill_noise(o.x, o.y, WATER_C, 91 + v % 4, [0.6, 0.25, 0.15])
	for i in 2:
		var x := int(_h(i, v, 92) * 12)
		var y := 2 + int(_h(i, v, 93) * 12)
		for k in 3:
			_px(o.x, o.y, x + k, y, Color(0.42, 0.68, 0.80))
		_px(o.x, o.y, x + 1, y + 1, Color(0.16, 0.40, 0.55))
	# Bờ: mép cát ướt rồi bọt trắng ở cạnh giáp đất.
	for y in T:
		for x in T:
			var d := 99
			if mask & 1: d = mini(d, y)
			if mask & 2: d = mini(d, T - 1 - x)
			if mask & 4: d = mini(d, T - 1 - y)
			if mask & 8: d = mini(d, x)
			var j := int(_h(o.x + x, o.y + y, 94) * 2)
			if d <= 1 + j - 1:
				_px(o.x, o.y, x, y, Color(0.72, 0.65, 0.46))
			elif d <= 2 + j:
				_px(o.x, o.y, x, y, Color(0.86, 0.93, 0.95))
			elif d <= 4 + j:
				_px(o.x, o.y, x, y, Color(0.30, 0.58, 0.70))

func _cliff(o: Vector2i, mask: int, v: int) -> void:
	_fill_noise(o.x, o.y, ROCK_C, 101 + v % 4, [0.5, 0.3, 0.2])
	for i in 3:
		var x := int(_h(i, v, 102) * 14)
		var y := int(_h(i, v, 103) * 10)
		_px(o.x, o.y, x, y, Color(0.60, 0.57, 0.53))
		_px(o.x, o.y, x + 1, y + 1, Color(0.33, 0.30, 0.28))
	if mask & 4:
		# Mặt vách dựng đứng phía nam: sọc dọc tối, chân vách đổ bóng.
		for y in range(9, T):
			for x in T:
				var c := Color(0.34, 0.31, 0.29) if (x + int(_h(x, v, 104) * 3)) % 4 != 0 else Color(0.27, 0.25, 0.23)
				if y == 9:
					c = Color(0.58, 0.55, 0.50)
				if y >= T - 2:
					c = Color(0.20, 0.19, 0.18)
				_px(o.x, o.y, x, y, c)
	if mask & 1:
		# Mép trên có cỏ phủ.
		for x in T:
			var depth := 1 + int(_h(o.x + x, o.y, 105) * 2)
			for y in depth:
				_px(o.x, o.y, x, y, GRASS_C[0] if y < depth - 1 else GRASS_DARK)
	if mask & 8:
		for y in T:
			_px(o.x, o.y, 0, y, Color(0.25, 0.23, 0.22))
	if mask & 2:
		for y in T:
			_px(o.x, o.y, T - 1, y, Color(0.25, 0.23, 0.22))

func _fringe(o: Vector2i, mask: int) -> void:
	if mask == 0:
		return
	for y in T:
		for x in T:
			var depth := 99
			if mask & 1: depth = mini(depth, y)
			if mask & 2: depth = mini(depth, T - 1 - x)
			if mask & 4: depth = mini(depth, T - 1 - y)
			if mask & 8: depth = mini(depth, x)
			var reach := 2 + int(_h(o.x + x, o.y + y, 111) * 3)
			if depth < reach:
				_px(o.x, o.y, x, y, _pick(GRASS_C, _h(x, y, 112 + mask)))
			elif depth == reach and _h(x, y, 113) > 0.5:
				_px(o.x, o.y, x, y, GRASS_DARK)

func _trail_inside(mask: int, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= T or y >= T:
		return false
	var mid_x := x >= 2 and x <= 13
	var mid_y := y >= 2 and y <= 13
	if mid_x and mid_y: return true
	if mask & 1 and mid_x and y < 2: return true
	if mask & 4 and mid_x and y > 13: return true
	if mask & 8 and mid_y and x < 2: return true
	if mask & 2 and mid_y and x > 13: return true
	return false

func _trail(o: Vector2i, mask: int) -> void:
	var path_c := [Color(0.62, 0.50, 0.34), Color(0.58, 0.46, 0.31), Color(0.66, 0.54, 0.37)]
	for y in T:
		for x in T:
			if not _trail_inside(mask, x, y):
				continue
			# Mép đường (giáp cỏ, không phải chỗ nối sang ô bên) lởm chởm nhẹ.
			var border := false
			for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var n: Vector2i = Vector2i(x, y) + d
				var leaves_tile := n.x < 0 or n.y < 0 or n.x >= T or n.y >= T
				if not leaves_tile and not _trail_inside(mask, n.x, n.y):
					border = true
			if border and _h(o.x + x, o.y + y, 121) > 0.6:
				continue
			_px(o.x, o.y, x, y, _pick(path_c, _h(o.x + x, o.y + y, 122)))
	for i in 3:
		var x := 4 + int(_h(i, mask, 123) * 8)
		var y := 4 + int(_h(i, mask, 124) * 8)
		_px(o.x, o.y, x, y, Color(0.48, 0.38, 0.27))

func _decorations() -> void:
	var r := ROW_DECO
	_flower(_cell(D.FLOWER_MOON, r), Color(0.86, 0.93, 1.0), Color(1.0, 0.95, 0.6))
	_flower(_cell(D.FLOWER_RED, r), Color(0.90, 0.30, 0.30), Color(1.0, 0.85, 0.4))
	_flower(_cell(D.FLOWER_YELLOW, r), Color(1.0, 0.85, 0.30), Color(0.85, 0.55, 0.2))
	_flower(_cell(D.FLOWER_PURPLE, r), Color(0.68, 0.48, 0.90), Color(1.0, 0.92, 0.6))
	var o := _cell(D.PEBBLE, r)
	_pebble(o, 5, 9, Color(0.70, 0.68, 0.66), Color(0.42, 0.40, 0.38))
	_pebble(o, 9, 6, Color(0.66, 0.64, 0.62), Color(0.40, 0.38, 0.36))
	o = _cell(D.ROCK, r)
	_blob(o, 8, 9, 5, 4, Color(0.55, 0.53, 0.52), Color(0.72, 0.70, 0.68), Color(0.34, 0.33, 0.33))
	o = _cell(D.MUSHROOM, r)
	for p in [Vector2i(5, 9), Vector2i(10, 11)]:
		_px(o.x, o.y, p.x, p.y + 1, Color(0.92, 0.88, 0.80))
		_px(o.x, o.y, p.x, p.y + 2, Color(0.80, 0.75, 0.68))
		for dx in range(-2, 3):
			_px(o.x, o.y, p.x + dx, p.y, Color(0.80, 0.22, 0.20))
		for dx in range(-1, 2):
			_px(o.x, o.y, p.x + dx, p.y - 1, Color(0.88, 0.30, 0.26))
		_px(o.x, o.y, p.x - 1, p.y, Color(1, 1, 1))
	o = _cell(D.REEDS, r)
	for k in 4:
		var x := 4 + k * 3
		for y in range(5 + k % 2, 15):
			_px(o.x, o.y, x, y, Color(0.42, 0.55, 0.28) if y > 8 else Color(0.50, 0.62, 0.32))
		if k % 2 == 0:
			_px(o.x, o.y, x, 4, Color(0.45, 0.30, 0.18))
			_px(o.x, o.y, x, 5, Color(0.45, 0.30, 0.18))
	o = _cell(D.PILLAR, r)
	for y in range(4, 14):
		for x in range(5, 11):
			var c := Color(0.68, 0.66, 0.70) if x < 7 else Color(0.55, 0.53, 0.58)
			if x == 10: c = Color(0.40, 0.38, 0.43)
			_px(o.x, o.y, x, y, c)
	for x in range(4, 12):
		_px(o.x, o.y, x, 14, Color(0.36, 0.34, 0.38))
	_px(o.x, o.y, 6, 4, Color(0, 0, 0, 0))
	_px(o.x, o.y, 9, 5, Color(0.40, 0.38, 0.43))
	o = _cell(D.CRYSTAL, r)
	for y in range(5, 13):
		var w := 2 if y < 8 else 1
		for x in range(8 - w, 8 + w):
			_px(o.x, o.y, x, y, Color(1.0, 0.85, 0.30) if x < 8 else Color(0.85, 0.62, 0.18))
	_px(o.x, o.y, 7, 6, Color(1, 1, 0.9))
	o = _cell(D.ORE, r)
	_blob(o, 8, 9, 4, 3, Color(0.50, 0.40, 0.36), Color(0.66, 0.56, 0.50), Color(0.32, 0.26, 0.24))
	_px(o.x, o.y, 7, 8, Color(0.88, 0.50, 0.22))
	_px(o.x, o.y, 9, 10, Color(0.88, 0.50, 0.22))
	o = _cell(D.LILY, r)
	_blob(o, 8, 8, 4, 3, Color(0.30, 0.58, 0.30), Color(0.42, 0.70, 0.36), Color(0.20, 0.42, 0.22))
	_px(o.x, o.y, 9, 8, WATER_C[0])
	_px(o.x, o.y, 10, 8, WATER_C[0])
	_px(o.x, o.y, 6, 7, Color(1.0, 0.70, 0.80))
	_px(o.x, o.y, 7, 7, Color(1.0, 0.85, 0.90))
	o = _cell(D.BUSH, r)
	_blob(o, 8, 9, 6, 5, Color(0.22, 0.42, 0.20), Color(0.36, 0.58, 0.28), Color(0.14, 0.28, 0.14))
	_px(o.x, o.y, 6, 7, Color(0.85, 0.30, 0.35))
	_px(o.x, o.y, 10, 9, Color(0.85, 0.30, 0.35))
	o = _cell(D.TUFT, r)
	for k in 5:
		var x := 5 + k * 2
		var hgt := 4 + int(_h(k, 0, 131) * 4)
		for y in range(14 - hgt, 14):
			_px(o.x, o.y, x + (1 if y < 14 - hgt + 2 and k % 2 == 0 else 0), y, GRASS_DARK if y > 11 else GRASS_LIGHT)
	o = _cell(D.CHIP, r)
	for y in range(8, 12):
		for x in range(4, 12 - (y - 8)):
			_px(o.x, o.y, x, y, Color(0.62, 0.60, 0.65) if y < 10 else Color(0.48, 0.46, 0.52))
	o = _cell(D.LEAVES, r)
	for i in 7:
		var lc := [Color(0.80, 0.48, 0.20), Color(0.70, 0.35, 0.18), Color(0.85, 0.65, 0.25)]
		_px(o.x, o.y, 3 + int(_h(i, 0, 132) * 10), 3 + int(_h(i, 1, 132) * 10), _pick(lc, _h(i, 2, 132)))

func _flower(o: Vector2i, petal: Color, center: Color) -> void:
	for p in [Vector2i(5, 6), Vector2i(10, 10), Vector2i(4, 12)]:
		_px(o.x, o.y, p.x, p.y + 1, GRASS_DARK)
		_px(o.x, o.y, p.x, p.y + 2, GRASS_DARK)
		for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
			_px(o.x, o.y, p.x + d.x, p.y + d.y, petal)
		_px(o.x, o.y, p.x, p.y, center)

func _blob(o: Vector2i, cx: int, cy: int, rx: int, ry: int, mid: Color, light: Color, dark: Color) -> void:
	for y in range(-ry, ry + 1):
		for x in range(-rx, rx + 1):
			var e := float(x * x) / float(rx * rx) + float(y * y) / float(ry * ry)
			if e > 1.0:
				continue
			var c := mid
			if e > 0.75:
				c = dark
			elif x + y < -max(rx, ry) * 0.4:
				c = light
			_px(o.x, o.y, cx + x, cy + y, c)

# ---------------------------------------------------------------- cây 32x32

func _big_px(o: Vector2i, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= 32 or y >= 32:
		return
	var dst := _img.get_pixel(o.x + x, o.y + y)
	_img.set_pixel(o.x + x, o.y + y, c if c.a >= 1.0 else dst.blend(c))

func _shadow(o: Vector2i) -> void:
	for y in range(26, 32):
		for x in range(4, 28):
			var e := pow((x - 16) / 12.0, 2) + pow((y - 29) / 3.0, 2)
			if e <= 1.0:
				_big_px(o, x, y, Color(0, 0, 0, 0.28))

func _trunk(o: Vector2i, top: int) -> void:
	for y in range(top, 30):
		for x in range(14, 18):
			var c := Color(0.42, 0.29, 0.18) if x < 16 else Color(0.32, 0.21, 0.13)
			if x == 14: c = Color(0.50, 0.36, 0.23)
			_big_px(o, x, y, c)
	_big_px(o, 13, 29, Color(0.32, 0.21, 0.13))
	_big_px(o, 18, 29, Color(0.32, 0.21, 0.13))

# shades: viền tối, tối, giữa, sáng
func _tree_oak(o: Vector2i, shades: Array) -> void:
	_shadow(o)
	_trunk(o, 18)
	var blobs := [Vector3(16, 12, 10), Vector3(10, 15, 6), Vector3(22, 15, 6), Vector3(16, 7, 6)]
	for y in 32:
		for x in 32:
			var inside := false
			var edge := false
			for b in blobs:
				var d := Vector2(x - b.x, y - b.y).length()
				if d <= b.z:
					inside = true
				elif d <= b.z + 1.0:
					edge = true
			if inside:
				# Ánh sáng từ trên trái.
				var lit := ((16 - x) + (12 - y)) / 22.0 + (_h(x, y, 141) - 0.5) * 0.35
				var c: Color = shades[1]
				if lit > 0.35:
					c = shades[3]
				elif lit > -0.1:
					c = shades[2]
				if y > 18 and lit < 0.1:
					c = shades[0].lerp(shades[1], 0.5)
				_big_px(o, x, y, c)
			elif edge:
				_big_px(o, x, y, shades[0])

func _tree_pine(o: Vector2i) -> void:
	_shadow(o)
	_trunk(o, 24)
	var dark := Color(0.12, 0.27, 0.18)
	var mid := Color(0.18, 0.38, 0.24)
	var light := Color(0.30, 0.52, 0.32)
	for layer in 3:
		var top := 1 + layer * 7
		var bottom := top + 11
		for y in range(top, bottom):
			var half := int((y - top) * 0.9) + 1 + layer
			for x in range(16 - half, 16 + half + 1):
				var c := mid
				if x == 16 - half or x == 16 + half or y == bottom - 1:
					c = dark
				elif x < 16 - half / 3:
					c = light
				_big_px(o, x, y, c)

func _tree_dead(o: Vector2i) -> void:
	_shadow(o)
	_trunk(o, 10)
	var bark := Color(0.38, 0.32, 0.27)
	var branches := [[Vector2(16, 14), Vector2(8, 6)], [Vector2(16, 12), Vector2(24, 4)], [Vector2(12, 10), Vector2(10, 3)], [Vector2(16, 18), Vector2(25, 13)], [Vector2(20, 8), Vector2(23, 2)]]
	for br in branches:
		var a: Vector2 = br[0]
		var b: Vector2 = br[1]
		for k in 12:
			var p := a.lerp(b, k / 11.0)
			_big_px(o, int(p.x), int(p.y), bark)
			if k < 6:
				_big_px(o, int(p.x) + 1, int(p.y), bark.darkened(0.2))

# ---------------------------------------------------------------- lục địa

const CONT_SIZE := Vector2i(640, 360)
# Rừng Nguyệt Ảnh trong lục địa (điểm ảnh của continent.png): ô (80, 70) x2.
const REGION_PX := Rect2i(160, 140, 320, 180)

func _moisture_noise() -> FastNoiseLite:
	var moist := FastNoiseLite.new()
	moist.seed = 77
	moist.frequency = 0.008
	moist.fractal_octaves = 3
	return moist

func _make_continent() -> void:
	var elev := _continent_elevation()
	var moist := _moisture_noise()
	var w := CONT_SIZE.x
	var hgt := CONT_SIZE.y
	var image := Image.create(w, hgt, false, Image.FORMAT_RGBA8)
	for y in hgt:
		for x in w:
			var e := elev[y * w + x]
			var m := moist.get_noise_2d(x, y) * 0.5 + 0.5
			var c := _biome(e, m, float(y) / hgt, float(x) / w)
			# Đổ bóng địa hình (ánh sáng từ tây bắc) cho cảm giác nổi.
			if e > 0.39:
				var e2 := elev[clampi(y - 1, 0, hgt - 1) * w + clampi(x - 1, 0, w - 1)]
				var shade := clampf((e2 - e) * 16.0, -0.4, 0.4)
				c = c.lightened(shade) if shade > 0 else c.darkened(-shade)
			image.set_pixel(x, y, c)
	for river in CONTINENT_RIVERS:
		_draw_river(image, river)
	_save(image, CONTINENT_PNG)

# Sông trên lục địa (điểm ảnh của continent.png): từ hồ núi phía bắc chảy vào Rừng
# Nguyệt Ảnh đúng chỗ sông trong rừng (x ≈ 1300 px); nhánh từ hồ trong rừng ra hồ lớn
# phía tây; sông phía đông.
const CONTINENT_RIVERS := [
	[Vector2(300, 52), Vector2(292, 80), Vector2(312, 96), Vector2(322, 118), Vector2(322, 146)],
	[Vector2(158, 288), Vector2(140, 272), Vector2(128, 262)],
	[Vector2(520, 40), Vector2(530, 90), Vector2(548, 140), Vector2(555, 190), Vector2(560, 215)],
]
const RIVER_COLOR := Color(0.20, 0.50, 0.62)

# Độ cao lục địa (mỗi điểm ảnh của continent.png), dùng cho cả ảnh và bước nối bản đồ.
func _continent_elevation() -> PackedFloat32Array:
	var noise := FastNoiseLite.new()
	noise.seed = 20261113
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_octaves = 5
	noise.frequency = 0.0055
	var warp := FastNoiseLite.new()
	warp.seed = 5
	warp.frequency = 0.01
	warp.fractal_octaves = 3
	var w := CONT_SIZE.x
	var hgt := CONT_SIZE.y
	var elev := PackedFloat32Array()
	elev.resize(w * hgt)
	var region_center := Vector2(REGION_PX.get_center())
	for y in hgt:
		for x in w:
			var nx := float(x) / w
			var ny := float(y) / hgt
			var e := noise.get_noise_2d(x, y) * 0.5 + 0.5
			# Biển bao quanh: hạ dần ra mép.
			var dx := absf(nx - 0.5) * 2.0
			var dy := absf(ny - 0.52) * 2.0
			var edge := maxf(dx * 0.95, dy) + (warp.get_noise_2d(x, y)) * 0.28
			e = e * 0.85 + 0.25 - pow(edge, 3.2) * 0.75
			# Dãy núi tuyết phía bắc và núi phía đông.
			var ridge := 1.0 - absf(warp.get_noise_2d(x * 2.3, y * 2.3))
			e += 0.32 * clampf((0.30 - ny) / 0.22, 0.0, 1.0) * (0.6 + ridge * 0.6)
			e += 0.22 * clampf((nx - 0.78) / 0.12, 0.0, 1.0) * clampf((0.85 - ny) / 0.4, 0.0, 1.0)
			# Rừng Nguyệt Ảnh là đất thấp, bằng phẳng.
			var rd := maxf(absf(x - region_center.x) / (REGION_PX.size.x * 0.5 + 24), absf(y - region_center.y) / (REGION_PX.size.y * 0.5 + 24))
			if rd < 1.0:
				var lowland := 0.48 + (e - 0.5) * 0.25
				e = lerpf(lowland, e, smoothstep(0.55, 1.0, rd))
			elev[y * w + x] = e
	_carve_lake(elev, w, Vector2(95, 250), Vector2(55, 40))
	_carve_lake(elev, w, Vector2(560, 225), Vector2(30, 22))
	_carve_lake(elev, w, Vector2(330, 95), Vector2(26, 14))
	return elev

func _carve_lake(elev: PackedFloat32Array, w: int, center: Vector2, radius: Vector2) -> void:
	for y in range(int(center.y - radius.y - 8), int(center.y + radius.y + 8)):
		for x in range(int(center.x - radius.x - 8), int(center.x + radius.x + 8)):
			if x < 0 or y < 0 or x >= w or y >= CONT_SIZE.y:
				continue
			var d := pow((x - center.x) / radius.x, 2) + pow((y - center.y) / radius.y, 2)
			d += (_h(x / 6, y / 6, 151) - 0.5) * 0.5
			if d < 1.0:
				elev[y * w + x] = minf(elev[y * w + x], 0.33)

func _biome(e: float, m: float, ny: float, nx: float) -> Color:
	if e < 0.30: return Color(0.12, 0.33, 0.45)
	if e < 0.355: return Color(0.18, 0.46, 0.55)
	if e < 0.385: return Color(0.82, 0.75, 0.53)
	if e > 0.62 + ny * 0.75: return Color(0.92, 0.94, 0.97)
	if e > 0.70: return Color(0.56, 0.52, 0.50)
	if e > 0.60: return Color(0.55, 0.44, 0.31)
	if m < 0.36 and nx > 0.55: return Color(0.84, 0.72, 0.46)
	if m > 0.58: return Color(0.24, 0.42, 0.22)
	return Color(0.56, 0.64, 0.38)

func _draw_river(image: Image, points: Array) -> void:
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var steps := int(a.distance_to(b))
		for k in steps:
			var p := a.lerp(b, float(k) / steps)
			p += Vector2(sin(p.y * 0.2) * 2.0, cos(p.x * 0.2) * 2.0)
			var width := 1 + int(float(i) / points.size() * 2.5)
			for dy in range(-width, width + 1):
				for dx in range(-width, width + 1):
					var q := Vector2i(p) + Vector2i(dx, dy)
					if q.x >= 0 and q.y >= 0 and q.x < CONT_SIZE.x and q.y < CONT_SIZE.y and dx * dx + dy * dy <= width * width:
						image.set_pixelv(q, Color(0.20, 0.50, 0.62))

# ---------------------------------------------------------------- tô bản đồ

func _paint() -> void:
	var packed := load(MAP_SCENE) as PackedScene
	var map_root := packed.instantiate()
	var ground := map_root.get_node("Ground") as TileMapLayer
	var obstacles := map_root.get_node("Obstacles") as TileMapLayer
	var cells: Vector2i = map_root.MAP_CELLS
	_o = map_root.MAP_ORIGIN
	# Đọc loại nền hiện có từ custom data trước khi đổi tileset.
	var types := {}
	var solid := {}
	for x in range(_o.x, _o.x + cells.x):
		for y in range(_o.y, _o.y + cells.y):
			var c := Vector2i(x, y)
			var gd := ground.get_cell_tile_data(c)
			types[c] = int(gd.get_custom_data("ground")) if gd else G.GRASS
			var od := obstacles.get_cell_tile_data(c)
			# (2026-11-17) Bỏ hết gò đất cao: chủ dự án không muốn đồi trên bản đồ.
			if od and obstacles.get_cell_atlas_coords(c).y != ROW_HIGHLAND:
				solid[c] = int(od.get_custom_data("ground"))
	var avoid: Array[Vector2i] = await _gameplay_cells()
	_drop_stray_rock_patches(types, solid)
	# Chỉ bo hồ một lần, chạy lại script không ăn mòn thêm.
	if not map_root.has_meta("water_rounded"):
		_round_water(solid, cells)
		map_root.set_meta("water_rounded", true)
	_blend_shore(types, solid, cells)
	map_root.remove_meta("highlands_added")
	var tileset := _build_tileset()
	# Chiếm đường dẫn của tileset cũ đang nạp để scene trỏ tới file .tres, không nhúng.
	tileset.take_over_path(TILESET_PATH)
	ResourceSaver.save(tileset, TILESET_PATH)

	var blend := _ensure_layer(map_root, "Blend", ground.get_index() + 1, 0)
	var deco := _ensure_layer(map_root, "Decoration", -1, 0)
	var canopy := _ensure_layer(map_root, "Canopy", -1, 3)
	for layer in [ground, blend, obstacles, deco, canopy]:
		layer.tile_set = tileset
		layer.clear()
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var material := _ground_material()
	ground.material = material
	blend.material = material
	var trail := _trails(cells, solid, types)
	var patches := _patches(cells, solid, types, trail)
	var green := [G.GRASS, G.FOREST]
	var trees := {}
	var props := {}
	var pebbles := {}
	var herbs := {}
	for x in range(_o.x, _o.x + cells.x):
		for y in range(_o.y, _o.y + cells.y):
			var c := Vector2i(x, y)
			var t: int = types[c]
			var r := _h(x, y, 201)
			var v := int(_h(x, y, 202) * 4) if r < 0.78 else 4 + int(_h(x, y, 203) * 4)
			ground.set_cell(c, 0, Vector2i(v, t))
			if solid.has(c):
				var kind: int = solid[c]
				var mask := 0
				for i in 4:
					var n: Vector2i = c + [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT][i]
					var inside := _in_map(n, cells)
					if inside and solid.get(n, -1) != kind:
						mask |= 1 << i
				var row := ROW_WATER if kind == G.WATER else ROW_CLIFF
				if kind == G.VOID:
					obstacles.set_cell(c, 0, Vector2i(2, ROW_BRIDGE))
					continue
				obstacles.set_cell(c, 0, Vector2i(mask, row))
				# Lá súng chỉ ở hồ, sông trong Rừng Nguyệt Ảnh, không rải ra biển.
				if kind == G.WATER and mask == 0 and _h(x, y, 204) < 0.04 and Rect2i(Vector2i.ZERO, OLD_FOREST_CELLS).has_point(c):
					deco.set_cell(c, 0, Vector2i(D.LILY, ROW_DECO))
				continue
			if trail.has(c):
				blend.set_cell(c, 0, Vector2i(_mask(c, func(n): return trail.has(n)), ROW_TRAIL))
				continue
			if patches.has(c):
				var prow: int = patches[c]
				blend.set_cell(c, 0, Vector2i(_mask(c, func(n): return patches.get(n, -1) == prow), prow))
			elif t == G.FOREST:
				var fm := _mask(c, func(n): return types.get(n, -1) == G.GRASS and not solid.has(n) and not trail.has(n))
				if fm > 0:
					blend.set_cell(c, 0, Vector2i(fm, ROW_FRINGE))
			elif not t in green:
				var gm := _mask(c, func(n): return types.has(n) and not solid.has(n) and types[n] in green and not trail.has(n))
				if gm > 0:
					blend.set_cell(c, 0, Vector2i(gm, ROW_FRINGE))
			var item := _pick_deco(t, x, y)
			if item >= 0:
				deco.set_cell(c, 0, Vector2i(item, ROW_DECO))
			var kind_tree := -1 if _near_any(pebbles, c, 2) or _near_any(herbs, c, 2) else _pick_tree(c, t, cells, solid, trail, avoid, trees, types)
			if kind_tree >= 0:
				trees[c] = true
				canopy.set_cell(c, 0, _tree_coords(kind_tree, x, y))
				deco.erase_cell(c)
				continue
			if _pick_pebble(c, t, solid, trail, avoid, pebbles, trees):
				pebbles[c] = true
				deco.erase_cell(c)
				continue
			var prop := _pick_prop(c, t, solid, trail, avoid, props)
			# (2026-11-17) Bụi tối (FERN) thay bằng bụi quả đỏ: thảo dược nhặt được.
			if prop.x == P.FERN:
				if _pickup_spot_ok(c, solid, trail, avoid, trees):
					props[c] = true
					herbs[c] = true
					deco.erase_cell(c)
			elif prop.x >= 0:
				props[c] = true
				deco.set_cell(c, 0, prop)

	# Cầu gỗ (ghi trong metadata khi dựng bố cục).
	for b in map_root.get_meta("bridges", []):
		var bc: Vector2i = b[0]
		blend.set_cell(bc, 0, Vector2i(0 if b[1] else 1, ROW_BRIDGE))
		deco.erase_cell(bc)
		canopy.erase_cell(bc)

	_write_pickups(map_root, "StonePickups", pebbles, "pebble", &"stone")
	_write_pickups(map_root, "HerbPickups", herbs, "herb", &"herb")

	var fog := map_root.get_node_or_null("FogBorder")
	if not fog:
		fog = Node2D.new()
		fog.name = "FogBorder"
		fog.set_script(load("res://scripts/fog_border.gd"))
		map_root.add_child(fog)
		fog.owner = map_root
	var scene := PackedScene.new()
	scene.pack(map_root)
	ResourceSaver.save(scene, MAP_SCENE)
	print("Đã tô lại bản đồ: %d cây, %d ô đường mòn, %d hòn đá, %d bụi thảo dược nhặt được." % [trees.size(), trail.size(), pebbles.size(), herbs.size()])

# (2026-11-17) Nền đá/gỉ sắt/vàng chỉ còn ở 3 bãi mỏ lớn; các bãi nhỏ lạc chỗ (dưới
# 100 ô) đổi thành cỏ/rừng theo cùng nhiễu với phần còn lại của rừng.
func _drop_stray_rock_patches(types: Dictionary, solid: Dictionary) -> void:
	var rocky := [G.STONE, G.RUST, G.GOLD]
	var forest_noise := FastNoiseLite.new()
	forest_noise.seed = 7001
	forest_noise.frequency = 0.05
	var seen := {}
	for c in types.keys():
		if seen.has(c) or solid.has(c) or not types[c] in rocky:
			continue
		var patch: Array[Vector2i] = [c]
		seen[c] = true
		var i := 0
		while i < patch.size():
			for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var n: Vector2i = patch[i] + d
				if types.has(n) and not seen.has(n) and not solid.has(n) and types[n] in rocky:
					seen[n] = true
					patch.append(n)
			i += 1
		if patch.size() >= 100:
			continue
		for p in patch:
			types[p] = G.FOREST if forest_noise.get_noise_2d(p.x, p.y) > 0.05 else G.GRASS

func _near_any(cells_set: Dictionary, c: Vector2i, r: int) -> bool:
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			if cells_set.has(c + Vector2i(dx, dy)):
				return true
	return false

# Hòn đá nhỏ nhặt được (2026-11-17): rải trên cỏ và đất trống, tránh Trại, đường mòn,
# vật cản, cây và chỗ có người/quái/tài nguyên.
const PEBBLE_CAMP_CLEAR := 24.0 # ô; Trại rộng tối đa 320 px = 20 ô
func _pick_pebble(c: Vector2i, t: int, solid: Dictionary, trail: Dictionary, avoid: Array[Vector2i], pebbles: Dictionary, trees: Dictionary) -> bool:
	if not t in [G.GRASS, G.DIRT] or _h(c.x, c.y, 361) >= 0.012:
		return false
	if _near_any(pebbles, c, 4):
		return false
	return _pickup_spot_ok(c, solid, trail, avoid, trees)

# Chỗ đặt vật nhặt được: ngoài Trại (tài nguyên trong Trại không hồi), xa mép mây,
# không sát cây, vật cản, đường mòn, và chỗ có người/quái/tài nguyên.
func _pickup_spot_ok(c: Vector2i, solid: Dictionary, trail: Dictionary, avoid: Array[Vector2i], trees: Dictionary) -> bool:
	if Vector2(c).distance_to(CAMP_CELL) < PEBBLE_CAMP_CLEAR or _edge_value(c) > 0.8:
		return false
	if _near_any(trees, c, 2) or _near_any(solid, c, 1) or _near_any(trail, c, 1):
		return false
	for p in avoid:
		if absi(p.x - c.x) <= 2 and absi(p.y - c.y) <= 2:
			return false
	return true

# Ghi vật nhặt được (hòn đá, bụi thảo dược) thành điểm tài nguyên (resource_node.tscn)
# dưới một node của world_map.tscn. node_id theo ô nên save giữ đúng cái đã nhặt.
func _write_pickups(map_root: Node, holder_name: String, cells_set: Dictionary, kind: String, resource: StringName) -> void:
	var old := map_root.get_node_or_null(holder_name)
	if old:
		map_root.remove_child(old)
		old.free()
	var holder := Node2D.new()
	holder.name = holder_name
	map_root.add_child(holder)
	holder.owner = map_root
	var res_scene := load("res://scenes/resource_node.tscn") as PackedScene
	var keys := cells_set.keys()
	keys.sort()
	for c in keys:
		var node := res_scene.instantiate()
		node.name = "%s_%d_%d" % [kind.capitalize(), c.x, c.y]
		node.position = Vector2(c) * T + Vector2(8, 10)
		node.set("node_id", StringName("%s_%d_%d" % [kind, c.x, c.y]))
		node.set("node_type", kind)
		node.set("resource_id", resource)
		node.set("yield_amount", 1)
		holder.add_child(node)
		node.owner = map_root

func _in_map(c: Vector2i, cells: Vector2i) -> bool:
	return Rect2i(_o, cells).has_point(c)

# Khoảng cách (ô) tới mép khung bản đồ.
func _border(c: Vector2i, cells: Vector2i) -> int:
	var rel := c - _o
	return mini(mini(rel.x, cells.x - 1 - rel.x), mini(rel.y, cells.y - 1 - rel.y))

# Gần mép vùng chơi thì rừng dày: bản đồ cũ dùng hình bầu dục, bản đồ mở rộng dùng mặt nạ.
func _edge_value(c: Vector2i) -> float:
	if _o == Vector2i.ZERO:
		return _shape_value(c)
	return load(TERRAIN_SCRIPT).play_shape_value(Vector2(c) * T + Vector2(8, 8))

func _mask(c: Vector2i, test: Callable) -> int:
	var mask := 0
	var dirs := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for i in 4:
		if test.call(c + dirs[i]):
			mask |= 1 << i
	return mask

func _ensure_layer(map_root: Node, layer_name: String, index: int, z: int) -> TileMapLayer:
	var layer := map_root.get_node_or_null(layer_name) as TileMapLayer
	if not layer:
		layer = TileMapLayer.new()
		layer.name = layer_name
		map_root.add_child(layer)
		layer.owner = map_root
	if index >= 0:
		map_root.move_child(layer, index)
	layer.z_index = z
	return layer

func _build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "ground")
	ts.set_custom_data_layer_type(0, TYPE_INT)
	var src := TileSetAtlasSource.new()
	src.resource_name = "Tile Shiroi (tools/gen_world_art.gd)"
	src.texture = load(TILE_PNG)
	src.texture_region_size = Vector2i(T, T)
	ts.add_source(src, 0)
	var full := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	for row in range(0, 11):
		for col in 8:
			_tile(src, Vector2i(col, row), row, row == G.WATER or row == G.CLIFF, full)
	for col in 16:
		_tile(src, Vector2i(col, ROW_WATER), G.WATER, true, full)
		_tile(src, Vector2i(col, ROW_CLIFF), G.CLIFF, true, full)
		_tile(src, Vector2i(col, ROW_FRINGE), -1, false, full)
		_tile(src, Vector2i(col, ROW_TRAIL), -1, false, full)
		_tile(src, Vector2i(col, ROW_DECO), -1, false, full)
	for col in [TREE.OAK, TREE.PINE, TREE.MOON, TREE.DEAD]:
		var coords := Vector2i(col, ROW_TREE)
		src.create_tile(coords, Vector2i(2, 2))
		var td := src.get_tile_data(coords, 0)
		td.set_custom_data("ground", -1)
		# Gốc cây nằm ở mép dưới ô được đặt.
		td.texture_origin = Vector2i(0, 8)
	for col in 16:
		_tile(src, Vector2i(col, ROW_TALL), -1, false, full)
		_tile(src, Vector2i(col, ROW_BARE), -1, false, full)
		_tile(src, Vector2i(col, ROW_MEADOW), -1, false, full)
		_tile(src, Vector2i(col, ROW_HIGHLAND), G.CLIFF, true, full)
	for kind in BIG_SHADES:
		_big_tile(src, Vector2i(kind, ROW_BIGTREE), Vector2i(3, 3), Vector2i(0, 16))
	_big_tile(src, Vector2i(P.BOULDER, ROW_PROPS), Vector2i(2, 2), Vector2i(0, 8))
	_big_tile(src, Vector2i(P.BUSH2, ROW_PROPS), Vector2i(2, 2), Vector2i(0, 8))
	_big_tile(src, Vector2i(P.LOG, ROW_PROPS), Vector2i(2, 1), Vector2i(0, 0))
	_tile(src, Vector2i(0, ROW_BRIDGE), -1, false, full)
	_tile(src, Vector2i(1, ROW_BRIDGE), -1, false, full)
	# Ô ngoài vùng chơi: trong suốt, chặn đường (mây đen che bên trên).
	_tile(src, Vector2i(2, ROW_BRIDGE), G.VOID, true, full)
	for col in [P.STUMP, P.FERN, P.MOSSROCK, P.SHROOMS]:
		_tile(src, Vector2i(col, ROW_PROPS), -1, false, full)
	return ts

func _big_tile(src: TileSetAtlasSource, coords: Vector2i, size: Vector2i, origin: Vector2i) -> void:
	src.create_tile(coords, size)
	var td := src.get_tile_data(coords, 0)
	td.set_custom_data("ground", -1)
	td.texture_origin = origin

func _tile(src: TileSetAtlasSource, coords: Vector2i, ground_type: int, blocks: bool, shape: PackedVector2Array) -> void:
	src.create_tile(coords)
	var td := src.get_tile_data(coords, 0)
	td.set_custom_data("ground", ground_type)
	if blocks:
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, shape)

# Ô có người, quái, tài nguyên, công trình... để không đặt cây che lên.
func _gameplay_cells() -> Array[Vector2i]:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var result: Array[Vector2i] = []
	var terrain := main.get_node("Environment/Terrain")
	for node in main.find_children("*", "Node2D", true, false):
		var n := node as Node2D
		if terrain.is_ancestor_of(n) or n == terrain or n.name in ["Walls", "Zones", "Environment"] or n.get_parent().name in ["Walls", "Zones"]:
			continue
		result.append(Vector2i((n.global_position / float(T)).floor()))
	main.queue_free()
	await process_frame
	return result

func _trails(cells: Vector2i, solid: Dictionary, types: Dictionary) -> Dictionary:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(_o, cells)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for c in solid:
		grid.set_point_solid(c, true)
	for x in range(_o.x, _o.x + cells.x):
		for y in range(_o.y, _o.y + cells.y):
			grid.set_point_weight_scale(Vector2i(x, y), 1.0 + _h(x / 3, y / 3, 211) * 2.5)
	# Trại nối ra các khu; sông chỉ qua được ở cầu nên đường mòn tự đi qua cầu.
	var hub := Vector2i(56, 37)
	var routes := [
		[hub, Vector2i(95, 12)],    # Khu Rừng
		[hub, Vector2i(40, 70)],    # rừng phía tây nam, qua cầu
		[hub, Vector2i(85, 80)],    # rừng phía nam, qua cầu
		[hub, Vector2i(100, 33)],   # Mỏ Sắt
		[Vector2i(100, 33), Vector2i(137, 31)],  # Mỏ Vàng
		[Vector2i(95, 12), Vector2i(135, 10)],   # Mỏ Đá
		[Vector2i(100, 33), Vector2i(133, 43)],  # Cổng Tàn Tích
		[hub, Vector2i(40, 22)],    # chỗ người chơi xuất phát
	]
	var trail := {}
	for route in routes:
		for i in route.size() - 1:
			var from: Vector2i = route[i]
			var to: Vector2i = route[i + 1]
			if grid.is_point_solid(from) or grid.is_point_solid(to):
				continue
			for p in grid.get_id_path(from, to):
				for d in [Vector2i.ZERO]:
					var q: Vector2i = p + d
					if types.has(q) and not solid.has(q) and types[q] in [G.GRASS, G.FOREST]:
						trail[q] = true
	return trail

func _pick_deco(t: int, x: int, y: int) -> int:
	var r := _h(x, y, 221)
	var k := _h(x, y, 222)
	match t:
		G.GRASS:
			if r < 0.035: return [D.FLOWER_MOON, D.FLOWER_MOON, D.FLOWER_RED, D.FLOWER_YELLOW, D.FLOWER_PURPLE][int(k * 5)]
			if r < 0.065: return D.TUFT
			# (2026-11-17) Không rải đá trang trí trên cỏ, đất: hòn đá nhỏ ở đó đều nhặt được.
			if r < 0.08: return D.BUSH
		G.FOREST:
			if r < 0.03: return D.MUSHROOM
			if r < 0.07: return D.LEAVES
			if r < 0.09: return D.BUSH
			if r < 0.10: return D.FLOWER_MOON
		G.STONE:
			if r < 0.05: return D.ROCK
			if r < 0.08: return D.PEBBLE
		G.RUST:
			if r < 0.05: return D.ORE
			if r < 0.07: return D.PEBBLE
		G.GOLD:
			if r < 0.04: return D.CRYSTAL
			if r < 0.07: return D.ROCK
		G.MUD:
			if r < 0.07: return D.REEDS
			if r < 0.09: return D.MUSHROOM
		G.SAND:
			if r < 0.025: return D.PEBBLE
			if r < 0.035: return D.ROCK
		G.RUIN:
			if r < 0.03: return D.PILLAR
			if r < 0.07: return D.CHIP
	return -1

func _pick_tree(c: Vector2i, t: int, cells: Vector2i, solid: Dictionary, trail: Dictionary, avoid: Array[Vector2i], trees: Dictionary, types_ref: Dictionary) -> int:
	var border := _border(c, cells)
	var chance := 0.0
	match t:
		G.GRASS: chance = 0.32 if _edge_value(c) > 0.62 else 0.012
		G.FOREST: chance = 0.3 if _edge_value(c) > 0.62 else 0.16
		G.MUD: chance = 0.03
		G.RUIN: chance = 0.01
	if t != G.MUD and t != G.RUIN:
		chance *= _grove(c)
	if _h(c.x, c.y, 231) >= chance:
		return -1
	# Chừa đường mòn, vật cản, cây khác, nền đất căn cứ và chỗ có người/quái/tài nguyên.
	for dx in range(-2, 3):
		for dy in range(-2, 2):
			var n := c + Vector2i(dx, dy)
			if absi(dx) <= 1 and (solid.has(n) or trail.has(n)):
				return -1
			if trees.has(n) or (types_ref.get(n, -1) == G.DIRT):
				return -1
	for p in avoid:
		if absi(p.x - c.x) <= 3 and absi(p.y - c.y) <= 3:
			return -1
	var k := _h(c.x, c.y, 232)
	match t:
		G.MUD, G.RUIN:
			return TREE.DEAD
		G.FOREST:
			return TREE.MOON if k < 0.3 else (TREE.PINE if k < 0.6 else TREE.OAK)
	return TREE.MOON if k < 0.2 else (TREE.OAK if k < 0.75 else TREE.PINE)

# Bo góc và làm lởm chởm mép hồ chữ nhật: chỉ bớt nước ở mép, không thêm vật cản.
func _round_water(solid: Dictionary, cells: Vector2i) -> void:
	var dirs := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for pass_index in 2:
		var remove: Array[Vector2i] = []
		for c in solid:
			if solid[c] != G.WATER:
				continue
			var land: Array[int] = []
			for i in 4:
				var n: Vector2i = c + dirs[i]
				var inside := _in_map(n, cells)
				if inside and solid.get(n, -1) != G.WATER:
					land.append(i)
			var corner := land.size() == 2 and (land[1] - land[0]) % 2 == 1
			if land.size() >= 3 or corner or (pass_index == 0 and land.size() == 1 and _h(c.x, c.y, 241) < 0.3):
				remove.append(c)
		for c in remove:
			solid.erase(c)

# Ô đất sát hồ còn mang loại nền cũ dưới nước (thường là cỏ) thì lấy theo đa
# số ô xung quanh, để không có viền cỏ lạc giữa đầm bùn hay bãi cát.
func _blend_shore(types: Dictionary, solid: Dictionary, cells: Vector2i) -> void:
	for _pass in 3:
		_blend_shore_once(types, solid, cells)

func _blend_shore_once(types: Dictionary, solid: Dictionary, cells: Vector2i) -> void:
	for x in range(_o.x, _o.x + cells.x):
		for y in range(_o.y, _o.y + cells.y):
			var c := Vector2i(x, y)
			if solid.has(c):
				continue
			var counts := {}
			var near_water := false
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var n := c + Vector2i(dx, dy)
					if n == c or not types.has(n):
						continue
					if solid.get(n, -1) == G.WATER:
						near_water = true
					elif not solid.has(n):
						counts[types[n]] = counts.get(types[n], 0) + 1
			if not near_water:
				continue
			for t in counts:
				if t != types[c] and counts[t] >= 3 and counts[t] > counts.get(types[c], 0):
					types[c] = t
					break

# ================================================================ bộ hình v2
# Địa hình không còn một màu: mảng cỏ cao, đất trống, đồng hoa (lớp Blend),
# gò đất cao có vách (lớp Obstacles), cây to 3x3, tảng đá, bụi, gốc, khúc gỗ.

func _put(o: Vector2i, w: int, h: int, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= w or y >= h:
		return
	var dst := _img.get_pixel(o.x + x, o.y + y)
	_img.set_pixel(o.x + x, o.y + y, c if c.a >= 1.0 else dst.blend(c))

# Hình mảng nối liền với ô bên cạnh theo mặt nạ; góc cũng lấp khi hai cạnh kề đều nối.
func _patch_shape(mask: int, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= T or y >= T:
		return false
	var lo := 2
	var hi := 13
	var in_x := x >= lo and x <= hi
	var in_y := y >= lo and y <= hi
	if in_x and in_y: return true
	var n := y < lo
	var s := y > hi
	var w := x < lo
	var e := x > hi
	if n and in_x: return mask & 1 != 0
	if s and in_x: return mask & 4 != 0
	if w and in_y: return mask & 8 != 0
	if e and in_y: return mask & 2 != 0
	if n and e: return mask & 1 != 0 and mask & 2 != 0
	if s and e: return mask & 4 != 0 and mask & 2 != 0
	if s and w: return mask & 4 != 0 and mask & 8 != 0
	if n and w: return mask & 1 != 0 and mask & 8 != 0
	return false

func _patch(o: Vector2i, mask: int, kind: int) -> void:
	for y in T:
		for x in T:
			if not _patch_shape(mask, x, y):
				continue
			var border := false
			for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var q: Vector2i = Vector2i(x, y) + d
				var leaves := q.x < 0 or q.y < 0 or q.x >= T or q.y >= T
				if not leaves and not _patch_shape(mask, q.x, q.y):
					border = true
			var r := _h(o.x + x, o.y + y, 301 + kind)
			if border and r > 0.5:
				continue
			var c := Color.WHITE
			match kind:
				ROW_TALL:
					c = [Color(0.29, 0.50, 0.23), Color(0.31, 0.53, 0.24), Color(0.27, 0.48, 0.22)][mini(int(r * 3), 2)]
					# Lá cỏ cao: sọc dọc, đầu lá sáng.
					var blade := (x + int(_h(x, 0, 302) * 3)) % 4 == 0 and _h(x, y, 304) > 0.35
					if blade:
						c = Color(0.40, 0.63, 0.29) if y % 5 == 0 else Color(0.23, 0.42, 0.19)
				ROW_BARE:
					c = [Color(0.56, 0.44, 0.30), Color(0.52, 0.40, 0.27), Color(0.60, 0.48, 0.33)][mini(int(r * 3), 2)]
					if r > 0.93:
						c = GRASS_C[0]
					elif r < 0.05:
						c = Color(0.66, 0.62, 0.56)
				ROW_MEADOW:
					c = [Color(0.40, 0.64, 0.31), Color(0.44, 0.68, 0.33), Color(0.37, 0.60, 0.29)][mini(int(r * 3), 2)]
					if r > 0.95:
						c = [Color(0.88, 0.94, 1.0), Color(0.72, 0.55, 0.92), Color(1.0, 0.88, 0.40), Color(1.0, 0.70, 0.78)][mini(int(_h(x, y, 303) * 4), 3)]
			_px(o.x, o.y, x, y, c)

# Gò đất cao: mặt trên phủ cỏ, cạnh nam là vách đá dựng, các cạnh khác có mép đá.
func _highland(o: Vector2i, mask: int) -> void:
	for y in T:
		for x in T:
			var c: Color = _pick([Color(0.40, 0.63, 0.30), Color(0.37, 0.59, 0.28), Color(0.44, 0.67, 0.33)], _h(o.x + x, o.y + y, 311))
			if _h(o.x + x, o.y + y, 312) > 0.92:
				c = GRASS_DARK
			_px(o.x, o.y, x, y, c)
	if mask & 1:
		for x in T:
			_px(o.x, o.y, x, 0, Color(0.62, 0.60, 0.55))
			if _h(x, mask, 313) > 0.4:
				_px(o.x, o.y, x, 1, Color(0.50, 0.48, 0.44))
	for side in [8, 2]:
		if mask & side:
			for y in T:
				var x := 0 if side == 8 else T - 1
				_px(o.x, o.y, x, y, Color(0.42, 0.40, 0.37))
				_px(o.x, o.y, x + (1 if side == 8 else -1), y, Color(0.55, 0.53, 0.49))
	if mask & 4:
		for y in range(7, T):
			for x in T:
				var stripe := (x + int(_h(x, 7, 314) * 3)) % 5 == 0
				var c := Color(0.45, 0.42, 0.38) if not stripe else Color(0.33, 0.31, 0.28)
				if y == 7:
					c = Color(0.66, 0.63, 0.57)
				elif y >= T - 2:
					c = Color(0.22, 0.21, 0.19)
				elif y > 11 and not stripe:
					c = Color(0.39, 0.37, 0.34)
				_px(o.x, o.y, x, y, c)
		# Cỏ rủ xuống mép vách.
		for x in T:
			if _h(x, 9, 315) > 0.55:
				_px(o.x, o.y, x, 7, GRASS_C[2])
				if _h(x, 10, 315) > 0.6:
					_px(o.x, o.y, x, 8, GRASS_DARK)

# Tán lá nhiều chùm (kiểu RPG): mỗi chùm sáng trên trái, tối dưới phải,
# ranh chùm tối, viền ngoài đậm nhất. shades: viền, tối, giữa, sáng, rất sáng.
func _crown(o: Vector2i, w: int, h: int, center: Vector2, radius: Vector2, shades: Array, count: int, s: int) -> void:
	var blobs: Array[Vector3] = []
	for i in count:
		var a := _h(i, s, 321) * TAU
		var d := sqrt(_h(i, s, 322))
		var p := center + Vector2(cos(a) * radius.x, sin(a) * radius.y) * d * 0.78
		blobs.append(Vector3(p.x, p.y, 4.0 + _h(i, s, 323) * 3.0))
	blobs.append(Vector3(center.x, center.y - radius.y * 0.35, 6.0))
	# Chùm thấp hơn vẽ đè lên chùm cao hơn.
	blobs.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
	for y in h:
		for x in w:
			var top := -1
			for i in blobs.size():
				var b := blobs[i]
				if Vector2(x - b.x, y - b.y).length() <= b.z:
					top = i
			if top < 0:
				for b in blobs:
					if Vector2(x - b.x, y - b.y).length() <= b.z + 1.0:
						_put(o, w, h, x, y, shades[0])
						break
				continue
			var bt := blobs[top]
			var rel := Vector2(x - bt.x, y - bt.y) / bt.z
			var lit := -(rel.x + rel.y) * 0.7 - (float(y) - center.y) / radius.y * 0.45 + (_h(x, y, 324 + s) - 0.5) * 0.25
			var c: Color = shades[2]
			if rel.length() > 0.86:
				c = shades[1]
			elif lit > 0.75:
				c = shades[4]
			elif lit > 0.25:
				c = shades[3]
			elif lit < -0.45:
				c = shades[1]
			_put(o, w, h, x, y, c)

func _ellipse_shadow(o: Vector2i, w: int, h: int, center: Vector2, radius: Vector2, alpha: float) -> void:
	for y in h:
		for x in w:
			if pow((x - center.x) / radius.x, 2) + pow((y - center.y) / radius.y, 2) <= 1.0:
				_put(o, w, h, x, y, Color(0, 0, 0, alpha))

func _big_tree(o: Vector2i, shades: Array, s: int) -> void:
	var w := 48
	var h := 48
	_ellipse_shadow(o, w, h, Vector2(26, 44), Vector2(17, 4), 0.3)
	# Thân và rễ.
	for y in range(28, 46):
		var half := 3 + (2 if y > 42 else 0) + (1 if y > 44 else 0)
		for x in range(24 - half, 24 + half):
			var c := Color(0.40, 0.27, 0.16)
			if x < 24 - half + 2:
				c = Color(0.50, 0.35, 0.21)
			elif x >= 24 + half - 2:
				c = Color(0.27, 0.17, 0.10)
			if (y + x) % 7 == 0:
				c = c.darkened(0.15)
			_put(o, w, h, x, y, c)
	_crown(o, w, h, Vector2(24, 19), Vector2(19, 15), shades, 30, s)

func _props() -> void:
	# Tảng đá rêu 2x2.
	var o := _cell(P.BOULDER, ROW_PROPS)
	_ellipse_shadow(o, 32, 32, Vector2(17, 27), Vector2(14, 4), 0.3)
	for y in 32:
		for x in 32:
			var e := pow((x - 16) / 13.0, 2) + pow((y - 19) / 10.0, 2)
			if e > 1.0:
				continue
			var facet := int((x + y * 0.5) / 6.0) % 3
			var c: Color = [Color(0.56, 0.55, 0.53), Color(0.50, 0.49, 0.48), Color(0.61, 0.60, 0.58)][facet]
			if e > 0.8:
				c = Color(0.30, 0.30, 0.31)
			elif x + y < 26:
				c = c.lightened(0.15)
			elif x + y > 44:
				c = c.darkened(0.2)
			if y < 15 and _h(x / 2, y / 2, 331) > 0.55:
				c = Color(0.36, 0.56, 0.28) if _h(x, y, 332) > 0.3 else Color(0.28, 0.46, 0.22)
			_put(o, 32, 32, x, y, c)
	# Bụi cây 2x2 có hoa.
	o = _cell(P.BUSH2, ROW_PROPS)
	_ellipse_shadow(o, 32, 32, Vector2(17, 27), Vector2(13, 4), 0.3)
	_crown(o, 32, 32, Vector2(16, 19), Vector2(12, 8), [Color(0.10, 0.25, 0.11), Color(0.17, 0.38, 0.17), Color(0.25, 0.50, 0.22), Color(0.35, 0.62, 0.28), Color(0.50, 0.75, 0.36)], 12, 7)
	for i in 6:
		var p := Vector2i(8 + int(_h(i, 0, 333) * 16), 13 + int(_h(i, 1, 333) * 10))
		_put(o, 32, 32, p.x, p.y, Color(1.0, 0.85, 0.9))
		_put(o, 32, 32, p.x + 1, p.y, Color(0.95, 0.6, 0.7))
	# Gốc cây.
	o = _cell(P.STUMP, ROW_PROPS)
	_ellipse_shadow(o, 16, 16, Vector2(8, 13), Vector2(7, 2), 0.3)
	for y in range(5, 14):
		for x in range(3, 13):
			var top := pow((x - 7.5) / 5.0, 2) + pow((y - 6.0) / 2.2, 2) <= 1.0
			var body := y >= 6 and x >= 3 and x <= 12
			if top:
				var ring := int(Vector2(x - 7.5, (y - 6.0) * 2.2).length()) % 2 == 0
				_put(o, 16, 16, x, y, Color(0.80, 0.64, 0.42) if ring else Color(0.70, 0.54, 0.34))
			elif body:
				_put(o, 16, 16, x, y, Color(0.42, 0.28, 0.17) if x > 4 else Color(0.52, 0.36, 0.22))
	# Khúc gỗ nằm 2x1.
	o = _cell(P.LOG, ROW_PROPS)
	for y in range(5, 14):
		for x in range(4, 30):
			var c := Color(0.45, 0.30, 0.18)
			if y == 5 or y == 13:
				c = Color(0.28, 0.18, 0.11)
			elif y < 8:
				c = Color(0.56, 0.39, 0.24)
			if (x * 3 + y) % 11 == 0:
				c = c.darkened(0.2)
			_put(o, 32, 16, x, y, c)
	for y in range(5, 14):
		for x in range(2, 8):
			if pow((x - 5) / 3.0, 2) + pow((y - 9) / 4.5, 2) <= 1.0:
				var ring := int(Vector2((x - 5) * 1.5, y - 9).length()) % 2 == 0
				_put(o, 32, 16, x, y, Color(0.80, 0.64, 0.42) if ring else Color(0.66, 0.50, 0.32))
	for x in range(10, 24, 5):
		_put(o, 32, 16, x, 6, Color(0.36, 0.56, 0.28))
		_put(o, 32, 16, x + 1, 6, Color(0.30, 0.50, 0.24))
	# Dương xỉ.
	o = _cell(P.FERN, ROW_PROPS)
	for k in 5:
		var a := -PI * 0.9 + k * PI * 0.2
		for t in 7:
			var p := Vector2(8, 13) + Vector2(cos(a), sin(a)) * t
			_put(o, 16, 16, int(p.x), int(p.y), Color(0.30, 0.56, 0.26) if t < 5 else Color(0.45, 0.70, 0.34))
	# Đá rêu nhỏ.
	o = _cell(P.MOSSROCK, ROW_PROPS)
	_blob(o, 8, 10, 5, 4, Color(0.52, 0.51, 0.50), Color(0.66, 0.65, 0.63), Color(0.32, 0.32, 0.33))
	for x in range(5, 10):
		_px(o.x, o.y, x, 7, Color(0.36, 0.58, 0.28))
	# Cụm đá mỏ 2x2: đá nhiều mặt cắt, quặng lộ thành tinh thể khối (đá xám bạc, sắt cam, vàng).
	_ore_cluster(_cell(P.ORE_STONE, ROW_PROPS), [Color(0.44, 0.47, 0.54), Color(0.52, 0.55, 0.62), Color(0.60, 0.63, 0.70)], [Color(0.62, 0.68, 0.78), Color(0.86, 0.90, 0.96), Color(1.0, 1.0, 1.0)], 41)
	_ore_cluster(_cell(P.ORE_IRON, ROW_PROPS), [Color(0.25, 0.27, 0.32), Color(0.31, 0.33, 0.39), Color(0.38, 0.40, 0.46)], [Color(0.70, 0.32, 0.10), Color(0.95, 0.56, 0.18), Color(1.0, 0.80, 0.45)], 42)
	_ore_cluster(_cell(P.ORE_GOLD, ROW_PROPS), [Color(0.40, 0.34, 0.28), Color(0.48, 0.41, 0.33), Color(0.56, 0.48, 0.38)], [Color(0.72, 0.52, 0.10), Color(1.0, 0.82, 0.25), Color(1.0, 0.96, 0.62)], 43)
	# Cụm nấm nâu.
	o = _cell(P.SHROOMS, ROW_PROPS)
	for p in [Vector2i(5, 10), Vector2i(9, 12), Vector2i(11, 9)]:
		_px(o.x, o.y, p.x, p.y + 1, Color(0.90, 0.86, 0.78))
		for dx in range(-1, 2):
			_px(o.x, o.y, p.x + dx, p.y, Color(0.62, 0.42, 0.26))
		_px(o.x, o.y, p.x, p.y - 1, Color(0.70, 0.50, 0.32))

# Một cụm đá 32x32: các khối đá chia mặt theo điểm hạt (mỗi mặt một sắc, khe giữa các mặt
# tối), viền đậm, sáng phía trên trái; rải tinh thể quặng khối vuông có mặt sáng, mặt tối.
func _ore_cluster(o: Vector2i, rock: Array, ore: Array, s: int) -> void:
	var outline := Color(0.12, 0.12, 0.15)
	var seeds: Array[Vector2] = []
	for i in 10:
		seeds.append(Vector2(5 + _h(i, 1, s) * 22, 8 + _h(i, 2, s) * 18))
	var inside := func(x: int, y: int) -> bool:
		if x < 0 or y < 0 or x >= 32 or y >= 32:
			return false
		var mound := pow((x - 15.5) / 13.5, 2) + pow((y - 18.5) / 10.5, 2) <= 1.0
		var pebble := pow((x - 26.5) / 3.5, 2) + pow((y - 27.0) / 2.5, 2) <= 1.0
		return mound or pebble
	var facet_of := func(x: int, y: int) -> int:
		var best := 0
		var best_d := INF
		for i in seeds.size():
			var d := Vector2(x, y).distance_squared_to(seeds[i])
			if d < best_d:
				best_d = d
				best = i
		return best
	_ellipse_shadow(o, 32, 32, Vector2(16, 28), Vector2(14, 3.5), 0.35)
	for y in 32:
		for x in 32:
			if not inside.call(x, y):
				continue
			if not inside.call(x - 1, y) or not inside.call(x + 1, y) or not inside.call(x, y - 1) or not inside.call(x, y + 1):
				_put(o, 32, 32, x, y, outline)
				continue
			var f: int = facet_of.call(x, y)
			if facet_of.call(x + 1, y) != f or facet_of.call(x, y + 1) != f:
				_put(o, 32, 32, x, y, Color(rock[0]).darkened(0.35))
				continue
			var c: Color = rock[int(_h(f, 3, s) * 3)]
			# Mặt trên của khối sáng hơn, chân khối tối hơn.
			if y < seeds[f].y - 2:
				c = c.lightened(0.12)
			elif y > seeds[f].y + 3:
				c = c.darkened(0.12)
			_put(o, 32, 32, x, y, c)
	for i in 9:
		var size := 2 + int(_h(i, 4, s) * 3)
		var p := Vector2i(5 + int(_h(i, 5, s) * 20), 9 + int(_h(i, 6, s) * 15))
		if i == 8:
			p = Vector2i(25, 26)
			size = 2
		for dy in size:
			for dx in size:
				if not inside.call(p.x + dx, p.y + dy):
					continue
				var c: Color = ore[1]
				if dx == 0 or dy == 0:
					c = ore[2]
				elif dx == size - 1 or dy == size - 1:
					c = ore[0]
				_put(o, 32, 32, p.x + dx, p.y + dy, c)

const GROUND_SHADER := """
shader_type canvas_item;
// Đổi sắc theo mảng lớn trong không gian thế giới: nền không còn một màu.
uniform sampler2D variation : repeat_enable, filter_linear;
varying vec2 world_pos;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float big = texture(variation, world_pos / 1100.0).r;
	float mid = texture(variation, world_pos / 330.0 + vec2(0.37, 0.71)).r;
	c.rgb *= mix(0.97, 1.13, big * 0.7 + mid * 0.3);
	c.rgb = mix(c.rgb, c.rgb * vec3(1.06, 1.04, 0.9), smoothstep(0.6, 0.85, mid) * 0.4);
	COLOR = c;
}
"""

func _ground_material() -> ShaderMaterial:
	var noise := FastNoiseLite.new()
	noise.seed = 404
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	var shader := Shader.new()
	shader.code = GROUND_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("variation", tex)
	return mat

# Gò đất cao ở vùng rìa, xa người/quái/tài nguyên và đường mòn: chỉ trên cỏ, rừng.
var _grove_noise: FastNoiseLite

# Cây mọc thành cụm: hệ số mật độ theo nhiễu tần số thấp.
func _grove(c: Vector2i) -> float:
	if not _grove_noise:
		_grove_noise = FastNoiseLite.new()
		_grove_noise.seed = 1234
		_grove_noise.frequency = 0.07
	var n := _grove_noise.get_noise_2d(c.x, c.y)
	return 2.6 if n > 0.2 else (1.0 if n > -0.1 else 0.3)

# Loại cây nhỏ (TREE.*) sang ô atlas: phần lớn dùng cây to 3x3.
func _tree_coords(kind: int, x: int, y: int) -> Vector2i:
	# Rừng Nguyệt Ảnh chỉ một loại cây: cây trăng tán xanh bạc; cây khô ở Tàn Tích.
	if kind == TREE.DEAD:
		return Vector2i(TREE.DEAD, ROW_TREE)
	if _ai_art:
		# Hình AI có ba biến thể cây tán xanh bạc ở cột 12, 0, 3 (xem tools/ai_art.gd).
		# (2026-11-17) Bỏ biến thể cột 12 theo yêu cầu chủ dự án, rừng chỉ dùng cột 0 và 3.
		var k := _h(x, y, 77)
		return Vector2i(BIG.OAK if k < 0.6 else BIG.DARK, ROW_BIGTREE)
	return Vector2i(BIG.MOON, ROW_BIGTREE)

# Mảng cỏ cao, đất trống, đồng hoa trên cỏ/rừng/bùn (không đổi loại nền).
func _patches(cells: Vector2i, solid: Dictionary, types: Dictionary, trail: Dictionary) -> Dictionary:
	var a := FastNoiseLite.new()
	a.seed = 501
	a.frequency = 0.06
	var b := FastNoiseLite.new()
	b.seed = 502
	b.frequency = 0.07
	var m := FastNoiseLite.new()
	m.seed = 503
	m.frequency = 0.06
	var result := {}
	for x in range(_o.x, _o.x + cells.x):
		for y in range(_o.y, _o.y + cells.y):
			var c := Vector2i(x, y)
			if solid.has(c) or trail.has(c):
				continue
			var t: int = types[c]
			match t:
				G.GRASS:
					if a.get_noise_2d(x, y) > 0.33:
						result[c] = ROW_TALL
					elif b.get_noise_2d(x, y) > 0.48:
						result[c] = ROW_BARE
					elif m.get_noise_2d(x, y) > 0.45:
						result[c] = ROW_MEADOW
				G.FOREST:
					if a.get_noise_2d(x, y) > 0.38:
						result[c] = ROW_TALL
				G.MUD:
					if a.get_noise_2d(x, y) > 0.35:
						result[c] = ROW_TALL
	# Bỏ ô lẻ để mảng có hình khối, không lấm tấm.
	for c in result.keys():
		var n := 0
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if result.get(c + d, -1) == result[c]:
				n += 1
		if n == 0:
			result.erase(c)
	return result

# Vật thể lớn: tảng đá, bụi hoa, gốc cây, khúc gỗ, dương xỉ, đá rêu, nấm.
func _pick_prop(c: Vector2i, t: int, solid: Dictionary, trail: Dictionary, avoid: Array[Vector2i], props: Dictionary) -> Vector2i:
	var r := _h(c.x, c.y, 351)
	var k := _h(c.x, c.y, 352)
	var item := -1
	match t:
		# (2026-11-17) Bỏ bụi hoa 2x2; hòn đá nhỏ (MOSSROCK) giờ là điểm nhặt đá (_pick_pebble).
		G.GRASS:
			if r < 0.006: item = P.BOULDER
			elif r < 0.010: item = P.STUMP
			elif r < 0.013: item = P.LOG
		G.FOREST:
			if r < 0.02: item = P.STUMP
			elif r < 0.026: item = P.LOG
			elif r < 0.05: item = P.FERN
			elif r < 0.06: item = P.SHROOMS
			elif r < 0.066: item = P.BOULDER
		G.MUD:
			if r < 0.01: item = P.LOG
			elif r < 0.02: item = P.SHROOMS
		G.STONE, G.RUST, G.GOLD:
			if r < 0.008: item = P.BOULDER
		G.RUIN:
			if r < 0.006: item = P.BOULDER
	if item < 0:
		return Vector2i(-1, -1)
	var big := item in [P.BOULDER, P.LOG]
	for dx in range(-2, 3):
		for dy in range(-2, 2):
			var n := c + Vector2i(dx, dy)
			if props.has(n):
				return Vector2i(-1, -1)
			if big and absi(dx) <= 1 and absi(dy) <= 1 and (solid.has(n) or trail.has(n)):
				return Vector2i(-1, -1)
	if big:
		for p in avoid:
			if absi(p.x - c.x) <= 2 and absi(p.y - c.y) <= 2:
				return Vector2i(-1, -1)
	return Vector2i(item, ROW_PROPS)

# ================================================================ bố cục rừng
# Bước "-- layout": dựng lại loại nền của Rừng Nguyệt Ảnh từ đầu (ghi vào lớp
# Ground/Obstacles), sau đó chạy "-- paint" để tô. Không xếp ô: mọi khu là mảng
# tự nhiên theo nhiễu. Giữ vị trí Trại, tài nguyên, quái, cổng như trong main.tscn.

# Tâm Trại (đống lửa) theo BaseManager.CAMP_CENTER.
const CAMP_CELL := Vector2(59.0, 37.5)
# Sông: từ mép bắc xuống phía đông Trại rồi uốn về tây nam đổ vào hồ (tọa độ px).
const RIVER_POINTS := [Vector2(1300, -20), Vector2(1310, 180), Vector2(1290, 420), Vector2(1305, 640), Vector2(1260, 790), Vector2(1140, 880), Vector2(960, 960), Vector2(780, 1000), Vector2(600, 1040), Vector2(470, 1070)]
# Cầu: [điểm px, true = lối đi đông-tây (sông chảy dọc)].
const RIVER_OUT_POINTS := [Vector2(300, 1110), Vector2(200, 1150), Vector2(80, 1190), Vector2(-40, 1230)]
# Hình vùng chơi: siêu elip bậc 4, giống world_terrain.gd (PLAY_RADIUS_CELLS).
const PLAY_CENTER_PX := Vector2(1280, 720)
const PLAY_RADIUS_PX := Vector2(76 * 16, 42 * 16)

func _shape_value(c: Vector2i) -> float:
	var rel := (Vector2(c) * T + Vector2(8, 8) - PLAY_CENTER_PX) / PLAY_RADIUS_PX
	return pow(absf(rel.x), 4.0) + pow(absf(rel.y), 4.0)

const BRIDGES := [[Vector2(1300, 200), true], [Vector2(1300, 600), true], [Vector2(1180, 860), false], [Vector2(800, 1000), false]]
const LAKE_CENTER := Vector2(380, 1080)
const LAKE_RADIUS := Vector2(150, 100)
# Vòng vách quanh Tàn Tích, khe ở đúng cổng RuinsGate (2128, 736), rộng 96.
const RUINS_CENTER := Vector2(2120, 1060)
const RUINS_RADIUS := Vector2(392, 316)
const RUINS_WALL := 40.0
const GATE_X := Vector2(2080, 2176)

func _layout() -> void:
	var packed := load(MAP_SCENE) as PackedScene
	var map_root := packed.instantiate()
	var ground := map_root.get_node("Ground") as TileMapLayer
	var obstacles := map_root.get_node("Obstacles") as TileMapLayer
	# Bố cục chỉ dựng phần Rừng Nguyệt Ảnh cũ (160x90 ô); sau đó chạy -- expand để nối ra lục địa.
	var cells: Vector2i = OLD_FOREST_CELLS
	_o = Vector2i.ZERO
	var avoid: Array[Vector2i] = await _gameplay_cells()
	var noise := FastNoiseLite.new()
	noise.seed = 7001
	noise.frequency = 0.05
	var wobble := FastNoiseLite.new()
	wobble.seed = 7002
	wobble.frequency = 0.15
	var types := {}
	var solid := {}
	for x in range(_o.x, _o.x + cells.x):
		for y in range(_o.y, _o.y + cells.y):
			var c := Vector2i(x, y)
			var px := Vector2(x, y) * T + Vector2(8, 8)
			var n := noise.get_noise_2d(x, y)
			var w := wobble.get_noise_2d(x, y)
			var border := _border(Vector2i(x, y), cells)
			var t := G.GRASS
			# Rừng: mảng lớn theo nhiễu, dày ở rìa, khu Rừng phía bắc luôn là rừng.
			if n > 0.05 or border < 5 + int(w * 3):
				t = G.FOREST
			if _in_patch(px, Vector2(1610, 200), Vector2(330, 170), w):
				t = G.FOREST
			# Chỗ xuất phát và Trại là trảng cỏ.
			if _in_patch(px, Vector2(640, 330), Vector2(230, 170), w):
				t = G.GRASS
			if _in_patch(px, CAMP_CELL * T, Vector2(330, 330), w):
				t = G.GRASS
			if _in_patch(px, CAMP_CELL * T, Vector2(170, 150), w * 0.6):
				t = G.DIRT
			# Bãi đá lộ quặng.
			if _in_patch(px, Vector2(2240, 195), Vector2(300, 150), w):
				t = G.STONE
			if _in_patch(px, Vector2(1620, 545), Vector2(260, 120), w):
				t = G.RUST
			if _in_patch(px, Vector2(2250, 555), Vector2(230, 110), w):
				t = G.GOLD
			for p in [Vector2(980, 900), Vector2(1300, 860), Vector2(1500, 1100)]:
				if _in_patch(px, p, Vector2(56, 44), w):
					t = G.STONE
			for p in [Vector2(1120, 1240), Vector2(1520, 1320)]:
				if _in_patch(px, p, Vector2(56, 44), w):
					t = G.GOLD
			# Tàn Tích: nền đá cổ trong vòng vách.
			var rd := ((px - RUINS_CENTER) / RUINS_RADIUS).length()
			if rd < 0.82 + w * 0.08:
				t = G.RUIN
			elif rd < 1.0:
				t = G.FOREST
			types[c] = t
			# Vòng vách, chừa khe ở cổng.
			var wall_inner := 1.0 - RUINS_WALL / RUINS_RADIUS.y
			if rd <= 1.0 and rd >= wall_inner and not (px.x > GATE_X.x and px.x < GATE_X.y and px.y < RUINS_CENTER.y):
				solid[c] = G.CLIFF
			# Hồ.
			if _in_patch(px, LAKE_CENTER, LAKE_RADIUS, w):
				solid[c] = G.WATER
				types[c] = G.GRASS
			# Sông.
			var meander := Vector2(sin(px.y / 95.0) * 30.0 + sin(px.y / 37.0) * 6.0, cos(px.x / 120.0) * 18.0)
			if _near_polyline(px + meander, RIVER_POINTS) < 22.0 + w * 6.0:
				solid[c] = G.WATER
			# Nhánh từ hồ chảy ra mép tây nam, nối với sông trên lục địa.
			if _near_polyline(px + meander * 0.5, RIVER_OUT_POINTS) < 18.0 + w * 5.0:
				solid[c] = G.WATER
			# Ngoài hình bầu dục bo tròn: ô chặn trong suốt dưới mây.
			if _shape_value(c) > 1.0:
				solid[c] = G.VOID
				types[c] = G.FOREST
	# Cầu: bỏ nước ở chỗ cầu, ghi lại để bước tô vẽ ván cầu.
	var bridges: Array = []
	for b in BRIDGES:
		var p: Vector2 = b[0]
		var east_west: bool = b[1]
		var base := Vector2i((p / T).floor())
		for k in range(-6, 7):
			for side in 2:
				var c := base + (Vector2i(k, side) if east_west else Vector2i(side, k))
				if solid.get(c, -1) == G.WATER:
					solid.erase(c)
					types[c] = G.DIRT
					bridges.append([c, east_west])
	# Báo chỗ có người/quái/tài nguyên bị nước hay vách đè lên.
	for p in avoid:
		if solid.has(p):
			print("CẢNH BÁO: vật thể ở ô %s nằm trên %s" % [p, "nước" if solid[p] == G.WATER else "vách"])
	ground.clear()
	obstacles.clear()
	for c in types:
		ground.set_cell(c, 0, Vector2i(0, types[c]))
	for c in solid:
		var kind_tile := Vector2i(0, ROW_WATER) if solid[c] == G.WATER else (Vector2i(2, ROW_BRIDGE) if solid[c] == G.VOID else Vector2i(0, ROW_CLIFF))
		obstacles.set_cell(c, 0, kind_tile)
	map_root.set_meta("bridges", bridges)
	map_root.set_meta("water_rounded", true)
	map_root.remove_meta("highlands_added")
	var scene := PackedScene.new()
	scene.pack(map_root)
	ResourceSaver.save(scene, MAP_SCENE)
	print("Đã dựng bố cục mới: %d ô nước/vách, %d ô cầu." % [solid.size(), bridges.size()])

# ---------------------------------------------------------------- nối bản đồ ra lục địa

# Mép phía bắc vùng chơi (chủ dự án vẽ trên bản đồ M, 2026-11-15), tính theo ô lục địa.
# Phía nam đường này tới bờ biển là vùng chơi; phía bắc là mây.
const NORTH_EDGE := [
	Vector2(0, 145), Vector2(7, 139), Vector2(22, 125), Vector2(41, 119), Vector2(63, 117), Vector2(73, 119),
	Vector2(82, 114), Vector2(88, 101), Vector2(96, 91), Vector2(107, 86), Vector2(116, 78), Vector2(128, 85),
	Vector2(139, 87), Vector2(156, 88), Vector2(164, 78), Vector2(177, 71), Vector2(190, 65), Vector2(204, 62),
	Vector2(213, 64), Vector2(225, 72), Vector2(238, 81), Vector2(255, 90), Vector2(274, 95), Vector2(289, 100),
	Vector2(300, 101), Vector2(317, 110), Vector2(320, 112),
]

# Độ cao trung bình của một ô lục địa (2x2 điểm ảnh).
func _cell_elevation(elev: PackedFloat32Array, wc: Vector2i) -> float:
	var e := 0.0
	for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var p: Vector2i = (wc * 2 + d).clamp(Vector2i.ZERO, CONT_SIZE - Vector2i.ONE)
		e += elev[p.y * CONT_SIZE.x + p.x] * 0.25
	return e

func _north_edge_y(x: float) -> float:
	for i in NORTH_EDGE.size() - 1:
		var a: Vector2 = NORTH_EDGE[i]
		var b: Vector2 = NORTH_EDGE[i + 1]
		if x <= b.x:
			return lerpf(a.y, b.y, clampf((x - a.x) / maxf(b.x - a.x, 0.001), 0.0, 1.0))
	return NORTH_EDGE[NORTH_EDGE.size() - 1].y

# Mở rộng vùng chơi ra lục địa: giữ nguyên Rừng Nguyệt Ảnh (ô 0..160 x 0..90, trừ
# ô ngoài hình bầu dục cũ), phần còn lại lấy địa hình theo độ cao/độ ẩm của ảnh lục địa
# (biển, cát, cỏ, rừng, đất cao, núi đá chặn đường, sông). Ghi ảnh mặt nạ vùng chơi.
# Chạy xong thì chạy --import rồi -- paint để tô lại.
func _expand() -> void:
	var packed := load(MAP_SCENE) as PackedScene
	var map_root := packed.instantiate()
	var ground := map_root.get_node("Ground") as TileMapLayer
	var obstacles := map_root.get_node("Obstacles") as TileMapLayer
	var cells: Vector2i = map_root.MAP_CELLS
	_o = map_root.MAP_ORIGIN
	var region: Vector2i = map_root.REGION_OFFSET
	var old_rect := Rect2i(Vector2i.ZERO, OLD_FOREST_CELLS)
	var old_types := {}
	var old_solid := {}
	var old_tiles := {}
	for c in ground.get_used_cells():
		if old_rect.has_point(c):
			old_types[c] = int(ground.get_cell_tile_data(c).get_custom_data("ground"))
	for c in obstacles.get_used_cells():
		if old_rect.has_point(c):
			old_solid[c] = int(obstacles.get_cell_tile_data(c).get_custom_data("ground"))
			old_tiles[c] = obstacles.get_cell_atlas_coords(c)
	var elev := _continent_elevation()
	var moist := _moisture_noise()
	var cont := Image.load_from_file(ProjectSettings.globalize_path(CONTINENT_PNG))
	var wobble := FastNoiseLite.new()
	wobble.seed = 9101
	wobble.frequency = 0.08
	# Cùng nhiễu rừng/cỏ với bố cục Rừng Nguyệt Ảnh (_layout) để chỗ nối liền mạch.
	var forest_noise := FastNoiseLite.new()
	forest_noise.seed = 7001
	forest_noise.frequency = 0.05
	var types := {}
	var solid := {}
	var kept := 0
	for x in range(_o.x, _o.x + cells.x):
		for y in range(_o.y, _o.y + cells.y):
			var c := Vector2i(x, y)
			if old_types.has(c) and old_solid.get(c, -1) != G.VOID:
				types[c] = old_types[c]
				if old_solid.has(c):
					solid[c] = old_solid[c]
				# Bố cục cũ làm rừng dày dọc mép khung 160x90; bỏ dải đó để không lộ đường thẳng.
				var old_border := mini(mini(x, OLD_FOREST_CELLS.x - 1 - x), mini(y, OLD_FOREST_CELLS.y - 1 - y))
				# (2026-11-15) Cát và vách sót dọc mép khung cũ cũng bỏ, để không thành dải lạc giữa đất liền.
				var near_ruins := ((Vector2(c) * T + Vector2(8, 8) - RUINS_CENTER) / RUINS_RADIUS).length() <= 1.1
				if old_border < 6 and solid.get(c, -1) == G.CLIFF and not near_ruins:
					solid.erase(c)
				if old_border < 12 and not solid.has(c) and old_types[c] == G.SAND:
					types[c] = G.FOREST if forest_noise.get_noise_2d(x, y) > 0.05 else G.GRASS
				if old_border < 8 and not solid.has(c) and old_types[c] in [G.GRASS, G.FOREST]:
					types[c] = G.FOREST if forest_noise.get_noise_2d(x, y) > 0.05 else G.GRASS
				kept += 1
				continue
			# Vòng vách Tàn Tích từng bị hình bầu dục cũ cắt (phần đó là mây): đắp lại vách
			# để vẫn chỉ vào được qua cổng.
			var cell_px := Vector2(c) * T + Vector2(8, 8)
			var ruins_rd := ((cell_px - RUINS_CENTER) / RUINS_RADIUS).length()
			if old_types.has(c) and ruins_rd <= 1.0:
				types[c] = G.RUIN if ruins_rd < 0.82 else G.FOREST
				if ruins_rd >= 1.0 - RUINS_WALL / RUINS_RADIUS.y:
					solid[c] = G.CLIFF
				continue
			var wc := c + region
			# Phía bắc đường ranh: mây. Phía nam mở hết tới mép khung (cả biển sâu); chỉ chừa 3 ô sát mép khung cho mây che mép.
			if _border(c, cells) < 3 or wc.y < _north_edge_y(wc.x) + wobble.get_noise_2d(x, y) * 3.0:
				solid[c] = G.VOID
				types[c] = G.FOREST
				continue
			var px := wc * 2
			var e := 0.0
			var river := false
			for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var p: Vector2i = (px + d).clamp(Vector2i.ZERO, CONT_SIZE - Vector2i.ONE)
				e += elev[p.y * CONT_SIZE.x + p.x] * 0.25
				if cont.get_pixelv(p).is_equal_approx(RIVER_COLOR):
					river = true
			var m := moist.get_noise_2d(px.x, px.y) * 0.5 + 0.5
			var t := G.GRASS
			if e < 0.385:
				t = G.SAND
			elif e > 0.60:
				t = G.DIRT
			elif forest_noise.get_noise_2d(x, y) > 0.05 or m > 0.66:
				t = G.FOREST
			types[c] = t
			# (2026-11-15) Bỏ cát giữa đất liền và các dải vách trên đất cao: chủ dự án thấy lộn xộn.
			# Cát chỉ còn ở ven nước (e < 0.385), lục địa không có vách.
			if river or e < 0.355:
				solid[c] = G.WATER
	_save_play_mask(types, solid, cells)
	ground.clear()
	obstacles.clear()
	for c in types:
		ground.set_cell(c, 0, Vector2i(0, types[c]))
	for c in solid:
		if old_tiles.has(c) and old_solid.get(c, -1) != G.VOID:
			obstacles.set_cell(c, 0, old_tiles[c])
		else:
			var kind_tile := Vector2i(0, ROW_WATER) if solid[c] == G.WATER else (Vector2i(2, ROW_BRIDGE) if solid[c] == G.VOID else Vector2i(0, ROW_CLIFF))
			obstacles.set_cell(c, 0, kind_tile)
	var scene := PackedScene.new()
	scene.pack(map_root)
	ResourceSaver.save(scene, MAP_SCENE)
	print("Đã nối bản đồ ra lục địa: %d ô, giữ %d ô Rừng Nguyệt Ảnh cũ." % [types.size(), kept])

# Ảnh mặt nạ vùng chơi: mỗi ô một điểm ảnh, khoảng cách có dấu tới mép (xem world_terrain.gd).
func _save_play_mask(types: Dictionary, solid: Dictionary, cells: Vector2i) -> void:
	var w := cells.x
	var h := cells.y
	var inside := PackedByteArray()
	inside.resize(w * h)
	for x in w:
		for y in h:
			var c := Vector2i(x, y) + _o
			inside[y * w + x] = 0 if solid.get(c, -1) == G.VOID or not types.has(c) else 1
	var to_out := _chamfer(inside, w, h, 0)
	var to_in := _chamfer(inside, w, h, 1)
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var range_cells: float = load(TERRAIN_SCRIPT).PLAY_MASK_RANGE
	for x in w:
		for y in h:
			var i := y * w + x
			var signed := to_out[i] - to_in[i]
			var v := clampf((signed + range_cells) / (2.0 * range_cells), 0.0, 1.0)
			image.set_pixel(x, y, Color(v, v, v, 1.0))
	_save(image, PLAY_MASK_PNG)

# Khoảng cách (ô) từ mỗi ô tới ô gần nhất có inside == target (chamfer 2 lượt).
func _chamfer(inside: PackedByteArray, w: int, h: int, target: int) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	d.resize(w * h)
	for i in w * h:
		d[i] = 0.0 if inside[i] == target else 1e9
	var forward := [[-1, 0, 1.0], [0, -1, 1.0], [-1, -1, 1.414], [1, -1, 1.414]]
	for y in h:
		for x in w:
			for k in forward:
				var nx: int = x + k[0]
				var ny: int = y + k[1]
				if nx >= 0 and ny >= 0 and nx < w and ny < h:
					d[y * w + x] = minf(d[y * w + x], d[ny * w + nx] + k[2])
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			for k in forward:
				var nx: int = x - k[0]
				var ny: int = y - k[1]
				if nx >= 0 and ny >= 0 and nx < w and ny < h:
					d[y * w + x] = minf(d[y * w + x], d[ny * w + nx] + k[2])
	return d

# Ô nằm trong mảng hình bầu dục có mép lượn theo nhiễu.
func _in_patch(px: Vector2, center: Vector2, radius: Vector2, w: float) -> bool:
	return ((px - center) / radius).length() < 1.0 + w * 0.22

func _near_polyline(p: Vector2, points: Array) -> float:
	var best := INF
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + (b - a) * t))
	return best

func _bridge(o: Vector2i, east_west: bool) -> void:
	for y in T:
		for x in T:
			var along := x if east_west else y
			var across := y if east_west else x
			var c := Color(0.55, 0.38, 0.22) if (along / 4) % 2 == 0 else Color(0.50, 0.34, 0.20)
			if along % 4 == 3:
				c = Color(0.33, 0.22, 0.12)
			if across <= 1 or across >= T - 2:
				c = Color(0.38, 0.25, 0.14)
			if across == 0 or across == T - 1:
				c = Color(0.25, 0.16, 0.09)
			_px(o.x, o.y, x, y, c)
