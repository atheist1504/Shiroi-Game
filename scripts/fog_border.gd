extends Node2D

# Mây đen bao quanh vùng chơi (mặt nạ vùng chơi của world_terrain.gd, theo địa hình lục địa):
# phần chưa làm bị che kín, mây trôi chậm và lấn vào mép vùng chơi một chút.
# Vẽ bằng shader trên một hình chữ nhật lớn, không tốn công vẽ từng đám mây.

const MARGIN: float = 1400.0
const SHADER_CODE := """
shader_type canvas_item;
uniform vec2 rect_origin;
uniform vec2 rect_size;
uniform vec2 map_origin;
uniform vec2 map_size;
uniform float mask_range;
uniform float inner_reach = 44.0;
uniform sampler2D play_mask : filter_linear, repeat_disable;
uniform sampler2D cloud_noise : repeat_enable, filter_linear;

void fragment() {
	vec2 p = rect_origin + UV * rect_size;
	vec2 m = (p - map_origin) / map_size;
	// Khoảng cách tới mép vùng chơi, dương là ra ngoài; ngoài khung bản đồ coi như rất xa.
	float signed_dist = mask_range * 2.0;
	if (m.x >= 0.0 && m.y >= 0.0 && m.x <= 1.0 && m.y <= 1.0) {
		signed_dist = -(texture(play_mask, m).r * 2.0 - 1.0) * mask_range;
	}
	float big = texture(cloud_noise, p / 640.0 + vec2(TIME * 0.006, TIME * 0.004)).r;
	float small = texture(cloud_noise, p / 210.0 - vec2(TIME * 0.012, -TIME * 0.005)).r;
	float cloud = big * 0.65 + small * 0.35;
	float alpha = smoothstep(-inner_reach, 70.0, signed_dist + (cloud - 0.5) * 110.0);
	// Ra ngoài mép một đoạn thì mây đặc kín, không lộ tile hay mép khung bản đồ.
	alpha = max(alpha, smoothstep(40.0, 120.0, signed_dist));
	float glow = cloud * (1.0 - smoothstep(0.0, 260.0, signed_dist));
	vec3 color = mix(vec3(0.015, 0.015, 0.03), vec3(0.17, 0.16, 0.22), glow);
	COLOR = vec4(color, alpha);
}
"""

func _ready() -> void:
	z_index = 10
	var terrain := get_parent()
	var map_rect: Rect2 = terrain.map_rect()
	var rect := ColorRect.new()
	rect.name = "Clouds"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = map_rect.position - Vector2.ONE * MARGIN
	rect.size = map_rect.size + Vector2.ONE * MARGIN * 2.0
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
	material.set_shader_parameter("rect_origin", rect.position)
	material.set_shader_parameter("rect_size", rect.size)
	material.set_shader_parameter("map_origin", map_rect.position)
	material.set_shader_parameter("map_size", map_rect.size)
	material.set_shader_parameter("mask_range", terrain.PLAY_MASK_RANGE * float(terrain.TILE_SIZE))
	material.set_shader_parameter("play_mask", load(terrain.PLAY_MASK_IMAGE))
	material.set_shader_parameter("cloud_noise", texture)
	rect.material = material
	add_child(rect)

# Khung bản đồ; ngoài mặt nạ vùng chơi là mây.
func get_play_rect() -> Rect2:
	return get_parent().map_rect()
