extends RefCounted

# Ghép hình pixel do công cụ AI vẽ (chủ dự án cung cấp, ảnh ở assets/tiles/source/)
# vào game. Được gen_world_art.gd gọi ở bước "-- images":
#   apply_tiles(img): dán cây, vật thể, quặng, cầu... lên ảnh terrain_tiles.png
#                     đúng bố cục ghi ở đầu gen_world_art.gd.
#   make_sprites():   ghi hình công trình, đống lửa, bàn rèn, bụi thảo dược vào
#                     assets/art_ai/ (base_building.gd, base_plot.gd... dùng).
# Ảnh gốc có nền ô vuông vẽ giả (không trong suốt thật): nền được xóa bằng cách
# loang từ mép ảnh qua các điểm xám nhạt. Mỗi món cắt theo khung (x, y, rộng, cao)
# trên ảnh gốc 1024 điểm ngang; đổi ảnh gốc thì phải đo lại các khung này.
# Thu nhỏ: mỗi điểm đích lấy màu gốc gần với màu trung bình nhất (giữ bảng màu,
# không nhòe), điểm phủ dưới một nửa thì để trong suốt.

const SRC_DIR := "res://assets/tiles/source/"
const SPRITE_DIR := "res://assets/art_ai/"
const T := 16

var _sheets := {}
var _bg := {}
var _tones := {}

func has_sources() -> bool:
	return FileAccess.file_exists(ProjectSettings.globalize_path(SRC_DIR + "ai_trees.webp"))

# ------------------------------------------------------------------ đọc ảnh gốc

func _sheet(name: String) -> Image:
	if _sheets.has(name):
		return _sheets[name]
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC_DIR + name + ".webp"))
	img.convert(Image.FORMAT_RGBA8)
	_sheets[name] = img
	var w := img.get_width()
	var h := img.get_height()
	var bg := PackedByteArray()
	bg.resize(w * h)
	var stack: Array[int] = []
	for x in w:
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y in h:
		stack.append(y * w)
		stack.append(y * w + w - 1)
	while not stack.is_empty():
		var j: int = stack.pop_back()
		if bg[j] == 1:
			continue
		var c := img.get_pixel(j % w, j / w)
		if c.s >= 0.07 or c.v <= 0.40:
			continue
		bg[j] = 1
		var jx := j % w
		var jy := j / w
		if jx > 0: stack.append(j - 1)
		if jx < w - 1: stack.append(j + 1)
		if jy > 0: stack.append(j - w)
		if jy < h - 1: stack.append(j + w)
	_bg[name] = bg
	# Hai sắc ô vuông của nền giả (đọc ở góc trên trái).
	_tones[name] = [img.get_pixel(2, 2).v, img.get_pixel(10, 2).v]
	return img

# Cắt một món: trả ảnh RGBA, nền trong suốt.
# opts: "holes" xóa cả ô vuông nền lọt bên trong (lan can, chân tháp...),
#       "no_green" xóa cỏ dưới chân (lều tranh vẽ trên một ô cỏ),
#       "recolor" = "stone" | "iron" đổi màu quặng vàng.
func cut(sheet: String, r: Rect2i, opts: Dictionary = {}) -> Image:
	var img := _sheet(sheet)
	var bg: PackedByteArray = _bg[sheet]
	var tones: Array = _tones[sheet]
	var w := img.get_width()
	var out := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	for y in r.size.y:
		for x in r.size.x:
			var sx := r.position.x + x
			var sy := r.position.y + y
			if sx >= w or sy >= img.get_height() or bg[sy * w + sx] == 1:
				continue
			var c := img.get_pixel(sx, sy)
			if opts.get("holes", false) and c.s < 0.05 and (absf(c.v - tones[0]) < 0.05 or absf(c.v - tones[1]) < 0.05):
				continue
			if opts.get("no_green", false) and c.h > 0.17 and c.h < 0.45 and c.s > 0.3:
				continue
			match opts.get("recolor", ""):
				"stone":
					if c.h > 0.07 and c.h < 0.2 and c.s > 0.35 and c.v > 0.55:
						c = Color.from_hsv(0.6, 0.06, c.v * 0.85)
				"iron":
					if c.h > 0.07 and c.h < 0.2 and c.s > 0.35 and c.v > 0.55:
						c = Color.from_hsv(0.05, c.s * 0.9, c.v * 0.85)
			c.a = 1.0
			out.set_pixel(x, y, c)
	return out

# Thu nhỏ cho vừa khung tw x th, giữ tỉ lệ (stretch = true thì kéo đúng khung).
func fit(src: Image, tw: int, th: int, stretch := false) -> Image:
	var sw := src.get_width()
	var sh := src.get_height()
	var kx := float(tw) / sw
	var ky := float(th) / sh
	if not stretch:
		kx = minf(kx, ky)
		ky = kx
	var ow := maxi(1, roundi(sw * kx))
	var oh := maxi(1, roundi(sh * ky))
	var out := Image.create(ow, oh, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	for oy in oh:
		for ox in ow:
			var x0 := int(floor(ox / kx))
			var x1 := maxi(x0 + 1, int(floor((ox + 1) / kx)))
			var y0 := int(floor(oy / ky))
			var y1 := maxi(y0 + 1, int(floor((oy + 1) / ky)))
			var n := 0
			var cov := 0
			var sum := Color(0, 0, 0, 0)
			var cols: Array[Color] = []
			for y in range(y0, mini(y1, sh)):
				for x in range(x0, mini(x1, sw)):
					n += 1
					var c := src.get_pixel(x, y)
					if c.a > 0.5:
						cov += 1
						sum += c
						cols.append(c)
			if n == 0 or cov * 2 < n:
				continue
			var avg := sum / float(cov)
			var best := cols[0]
			var bd := 99.0
			for c in cols:
				var d := (c.r - avg.r) ** 2 + (c.g - avg.g) ** 2 + (c.b - avg.b) ** 2
				if d < bd:
					bd = d
					best = c
			best.a = 1.0
			out.set_pixel(ox, oy, best)
	# Bỏ điểm lẻ loi (vụn nền giả còn sót quanh mép).
	var lone: Array[Vector2i] = []
	for oy in oh:
		for ox in ow:
			if out.get_pixel(ox, oy).a == 0.0:
				continue
			var near := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var p := Vector2i(ox + dx, oy + dy)
					if (dx != 0 or dy != 0) and p.x >= 0 and p.y >= 0 and p.x < ow and p.y < oh and out.get_pixelv(p).a > 0.0:
						near += 1
			if near <= 1:
				lone.append(Vector2i(ox, oy))
	for p in lone:
		out.set_pixelv(p, Color(0, 0, 0, 0))
	return out


# Làm phẳng cho hợp nền vẽ bằng code: gom về k màu (k-means), hạ độ rực,
# viền tối 1 điểm quanh hình. Hình AI gốc nhiều sắc độ nên thu nhỏ trông như
# ảnh dán lên nền phẳng.
const OUTLINE := Color(0.12, 0.10, 0.11)

func flatten(img: Image, k := 6, outline := true, sat := 0.8, val := 0.95) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var cols: Array[Color] = []
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				cols.append(c)
	if cols.is_empty():
		return img
	var sorted := cols.duplicate()
	sorted.sort_custom(func(a: Color, b: Color) -> bool: return a.get_luminance() < b.get_luminance())
	k = mini(k, sorted.size())
	var centers: Array[Color] = []
	for i in k:
		centers.append(sorted[int((i + 0.5) * sorted.size() / k)])
	var label := PackedInt32Array()
	label.resize(cols.size())
	for it in 8:
		var sums: Array[Color] = []
		var counts := PackedInt32Array()
		sums.resize(k)
		counts.resize(k)
		for i in k:
			sums[i] = Color(0, 0, 0, 0)
		for i in cols.size():
			var c := cols[i]
			var best := 0
			var bd := 99.0
			for j in k:
				var d := (c.r - centers[j].r) ** 2 + (c.g - centers[j].g) ** 2 + (c.b - centers[j].b) ** 2
				if d < bd:
					bd = d
					best = j
			label[i] = best
			sums[best] += c
			counts[best] += 1
		for j in k:
			if counts[j] > 0:
				centers[j] = sums[j] / float(counts[j])
	for j in k:
		var c := centers[j]
		centers[j] = Color.from_hsv(c.h, clampf(c.s * sat, 0.0, 1.0), clampf(c.v * val, 0.0, 1.0))
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var i := 0
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.0:
				out.set_pixel(x, y, centers[label[i]])
				i += 1
	if not outline:
		return out
	# Viền: điểm sát chỗ trong suốt thì tối hẳn.
	var edge: Array[Vector2i] = []
	for y in h:
		for x in w:
			if out.get_pixel(x, y).a == 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h or out.get_pixelv(p).a == 0.0:
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		out.set_pixelv(p, out.get_pixelv(p).lerp(OUTLINE, 0.7))
	return out

# Lộ quặng trên cụm đá: chia hình thành khối 2x2 điểm, chọn ngẫu nhiên (cố định theo seed)
# khoảng 30% khối, điểm sáng trong khối thành màu quặng sáng, điểm vừa thành màu quặng tối.
func ore_tint(src: Image, light: Color, mid: Color, seed: int) -> Image:
	var out := src.duplicate() as Image
	for y in out.get_height():
		for x in out.get_width():
			var c := out.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var bx := x / 2
			var by := y / 2
			var n: int = (bx * 73856093) ^ (by * 19349663) ^ (seed * 83492791)
			n = (n ^ (n >> 13)) * 1274126177
			if float((n >> 8) & 0xFF) / 255.0 > 0.3:
				continue
			var l := c.get_luminance()
			if l > 0.55:
				out.set_pixel(x, y, light)
			elif l > 0.38:
				out.set_pixel(x, y, mid)
	return out

# Xóa khung (ô) trên ảnh tile rồi dán hình vào, căn giữa ngang, sát đáy.
func _paste(dst: Image, col: int, row: int, cells: Vector2i, art: Image) -> void:
	var box := Rect2i(col * T, row * T, cells.x * T, cells.y * T)
	dst.fill_rect(box, Color(0, 0, 0, 0))
	var at := Vector2i(box.position.x + (box.size.x - art.get_width()) / 2, box.end.y - art.get_height())
	dst.blend_rect(art, Rect2i(Vector2i.ZERO, art.get_size()), at)

func _put(dst: Image, col: int, row: int, cells: Vector2i, sheet: String, r: Rect2i, opts := {}, size := Vector2i.ZERO) -> void:
	var box := size if size != Vector2i.ZERO else cells * T
	var art := fit(cut(sheet, r, opts), box.x, box.y)
	if not opts.get("keep", false):
		art = flatten(art, opts.get("k", 6), true, opts.get("sat", 0.8))
	_paste(dst, col, row, cells, art)

# ------------------------------------------------------------------ ảnh tile

# Vị trí cột/hàng theo bố cục ở đầu gen_world_art.gd.
func apply_tiles(img: Image) -> void:
	# Cây to 3x3 ô (hàng 21): 0 sồi, 3 sồi sẫm, 6 cây thu, 9 cây hoa hồng, 12 cây trăng.
	# Rừng Nguyệt Ảnh dùng ba biến thể cây tán xanh bạc ở cột 0, 3, 12.
	_put(img, 0, 21, Vector2i(3, 3), "ai_trees", Rect2i(196, 16, 141, 152))
	_put(img, 3, 21, Vector2i(3, 3), "ai_trees", Rect2i(354, 17, 139, 152))
	_put(img, 6, 21, Vector2i(3, 3), "ai_trees", Rect2i(884, 30, 106, 135))
	_put(img, 9, 21, Vector2i(3, 3), "ai_trees", Rect2i(26, 172, 146, 158))
	_put(img, 12, 21, Vector2i(3, 3), "ai_trees", Rect2i(24, 7, 159, 162))
	# Cây 2x2 ô (hàng 16): 0 sồi, 2 thông, 4 cây trăng, 6 cây khô.
	_put(img, 0, 16, Vector2i(2, 2), "ai_trees", Rect2i(656, 185, 121, 150))
	_put(img, 2, 16, Vector2i(2, 2), "ai_trees", Rect2i(784, 180, 105, 175))
	_put(img, 4, 16, Vector2i(2, 2), "ai_trees", Rect2i(502, 13, 167, 156))
	_put(img, 6, 16, Vector2i(2, 2), "ai_trees", Rect2i(692, 53, 83, 113))
	# Vật thể (hàng 24-25).
	_put(img, 2, 24, Vector2i(2, 2), "ai_trees", Rect2i(434, 485, 60, 48), {}, Vector2i(28, 24))
	_put(img, 4, 24, Vector2i(1, 1), "ai_trees", Rect2i(108, 350, 54, 47))
	_put(img, 5, 24, Vector2i(2, 1), "ai_trees", Rect2i(291, 344, 119, 44))
	_put(img, 7, 24, Vector2i(1, 1), "ai_trees", Rect2i(363, 416, 57, 46))
	# Cụm đá xám giữ nguyên hình AI (chủ dự án thấy hợp), dùng cả cho tảng đá (cột 0) và hòn đá nhỏ (hàng 15 cột 5).
	_put(img, 10, 24, Vector2i(2, 2), "ai_resources", Rect2i(532, 43, 121, 90), {"keep": true})
	_put(img, 0, 24, Vector2i(2, 2), "ai_resources", Rect2i(532, 43, 121, 90), {"keep": true}, Vector2i(26, 20))
	_put(img, 5, 15, Vector2i(1, 1), "ai_resources", Rect2i(532, 43, 121, 90), {"keep": true}, Vector2i(14, 11))
	# Quặng sắt, vàng: cùng cụm đá xám (chủ dự án chọn kiểu này), lộ vân quặng trên các mặt sáng.
	var rock := fit(cut("ai_resources", Rect2i(532, 43, 121, 90)), 32, 32)
	_paste(img, 12, 24, Vector2i(2, 2), ore_tint(rock, Color(0.80, 0.46, 0.26), Color(0.55, 0.31, 0.21), 11))
	_paste(img, 14, 24, Vector2i(2, 2), ore_tint(rock, Color(1.0, 0.86, 0.34), Color(0.80, 0.60, 0.18), 23))
	# Trang trí nhỏ (hàng 15): cột 8 cột đá đổ, 9 tinh thể.
	_put(img, 8, 15, Vector2i(1, 1), "ai_resources", Rect2i(537, 309, 66, 75))
	_put(img, 9, 15, Vector2i(1, 1), "ai_resources", Rect2i(665, 144, 137, 144))
	# Cầu gỗ (hàng 27): một khúc giữa cầu, lặp theo chiều dài.
	_paste(img, 0, 27, Vector2i(1, 1), flatten(fit(cut("ai_cliff_bridge", Rect2i(235, 365, 100, 103), {"holes": true}), T, T, true), 4, false))
	_paste(img, 1, 27, Vector2i(1, 1), flatten(fit(cut("ai_cliff_bridge", Rect2i(766, 330, 89, 89), {"holes": true}), T, T, true), 4, false))

# ------------------------------------------------------------------ hình công trình

const SPRITES := {
	"house_1": ["ai_buildings", Rect2i(19, 14, 116, 110), {"no_green": true, "holes": true}, Vector2i(48, 48)],
	"house_2": ["ai_buildings", Rect2i(414, 23, 175, 171), {}, Vector2i(60, 60)],
	"house_3": ["ai_buildings", Rect2i(623, 29, 189, 190), {}, Vector2i(64, 66)],
	"watchtower": ["ai_buildings", Rect2i(871, 16, 88, 199), {"holes": true}, Vector2i(32, 72)],
	"shed": ["ai_buildings", Rect2i(866, 242, 105, 119), {}, Vector2i(48, 56)],
	"mine_gold": ["ai_buildings", Rect2i(512, 212, 174, 141), {}, Vector2i(48, 44)],
	"mine_stone": ["ai_buildings", Rect2i(512, 212, 174, 141), {"recolor": "stone"}, Vector2i(48, 44)],
	"mine_iron": ["ai_buildings", Rect2i(512, 212, 174, 141), {"recolor": "iron"}, Vector2i(48, 44)],
	"herb_garden": ["ai_buildings", Rect2i(719, 256, 110, 100), {}, Vector2i(48, 44)],
	"fence": ["ai_buildings", Rect2i(664, 387, 139, 48), {"holes": true}, Vector2i(32, 16)],
	"anvil": ["ai_buildings", Rect2i(551, 378, 84, 72), {"holes": true}, Vector2i(28, 24)],
	"campfire": ["ai_buildings", Rect2i(553, 470, 71, 67), {}, Vector2i(24, 24)],
	"herb_bush": ["ai_trees", Rect2i(434, 410, 60, 55), {}, Vector2i(28, 26)],
	"log": ["ai_trees", Rect2i(291, 344, 119, 44), {}, Vector2i(24, 10)],
}

func make_sprites() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SPRITE_DIR))
	for key in SPRITES:
		var s: Array = SPRITES[key]
		var art := flatten(fit(cut(s[0], s[1], s[2]), s[3].x, s[3].y), 8)
		art.save_png(ProjectSettings.globalize_path(SPRITE_DIR + key + ".png"))
