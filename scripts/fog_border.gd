extends Node2D

# Mây đen bao quanh vùng đang chơi (Rừng Nguyệt Ảnh, hình bầu dục bo tròn): phần lục địa chưa làm bị
# che kín, mây trôi chậm và lấn vào mép bản đồ một chút để che tường biên.
# Vẽ bằng shader trên một hình chữ nhật lớn, không tốn công vẽ từng đám mây.

const MARGIN: float = 1400.0
const SHADER_CODE := """
shader_type canvas_item;
uniform vec2 map_size;
uniform float margin;
uniform vec2 play_radius;
uniform float inner_reach = 44.0;
uniform sampler2D cloud_noise : repeat_enable, filter_linear;

void fragment() {
	vec2 p = UV * (map_size + 2.0 * margin) - margin;
	// Mép vùng chơi là siêu elip bậc 4 (world_terrain.gd), không phải khung chữ nhật.
	vec2 rel = abs(p - map_size * 0.5) / play_radius;
	float shape = pow(pow(rel.x, 4.0) + pow(rel.y, 4.0), 0.25);
	float signed_dist = (shape - 1.0) * play_radius.y;
	float big = texture(cloud_noise, p / 640.0 + vec2(TIME * 0.006, TIME * 0.004)).r;
	float small = texture(cloud_noise, p / 210.0 - vec2(TIME * 0.012, -TIME * 0.005)).r;
	float cloud = big * 0.65 + small * 0.35;
	float alpha = smoothstep(-inner_reach, 70.0, signed_dist + (cloud - 0.5) * 110.0);
	// Ra ngoài mép một đoạn thì mây đặc kín, không lộ tile hay mép khung bản đồ.
	alpha = max(alpha, smoothstep(0.015, 0.05, shape - 1.0));
	float glow = cloud * (1.0 - smoothstep(0.0, 260.0, signed_dist));
	vec3 color = mix(vec3(0.015, 0.015, 0.03), vec3(0.17, 0.16, 0.22), glow);
	COLOR = vec4(color, alpha);
}
"""

func _ready() -> void:
	z_index = 10
	var terrain := get_parent()
	var map_size := Vector2(terrain.MAP_CELLS * terrain.TILE_SIZE)
	var rect := ColorRect.new()
	rect.name = "Clouds"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = -Vector2.ONE * MARGIN
	rect.size = map_size + Vector2.ONE * MARGIN * 2.0
	var noise := FastNoiseLite.new()
	noise.seed = 31
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.noise = noise
	var shader := Shader.new()
	shader.code = SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("map_size", map_size)
	material.set_shader_parameter("margin", MARGIN)
	material.set_shader_parameter("play_radius", terrain.PLAY_RADIUS_CELLS * float(terrain.TILE_SIZE))
	material.set_shader_parameter("cloud_noise", texture)
	rect.material = material
	add_child(rect)

# Vùng chơi được; ngoài vùng này là mây.
func get_play_rect() -> Rect2:
	var terrain := get_parent()
	return Rect2(Vector2.ZERO, Vector2(terrain.MAP_CELLS * terrain.TILE_SIZE))
