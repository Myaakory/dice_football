shader_type canvas_item;
// Rozmyte tło stadionu nocą: niebo, plamy trybun w barwach klubu i murawa z szerokimi pasami. Liczone w jednostkach
// ekranu bazowego 1920×1080, więc wygląda tak samo przy każdej rozdzielczości. Łączenia niebo–trybuny i
// trybuny–murawa są szerokimi przejściami, bez widocznej krawędzi.

uniform sampler2D grass_texture : repeat_enable, filter_linear;
uniform vec3 crowd_color : source_color = vec3(0.72, 0.2, 0.16);

const vec2 SCREEN = vec2(1920.0, 1080.0);
const float STAND_TOP = 300.0;
const float HORIZON = 660.0;
const float SKY_BLEND = 170.0;
const float GRASS_BLEND = 120.0;
const float STRIPE_WIDTH = 240.0;
const float STRIPE_BLEND = 10.0;
const float GRASS_TILE = 128.0;
const vec3 SKY_TOP = vec3(0.047, 0.133, 0.22);
const vec3 SKY_LOW = vec3(0.114, 0.353, 0.478);
const vec3 STAND_DARK = vec3(0.06, 0.15, 0.23);
const vec3 STAND_LIGHT = vec3(0.13, 0.31, 0.43);
const vec3 FLOOD_COLOR = vec3(0.75, 0.92, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), u.x),
			mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), u.x), u.y);
}

float flood_light(vec2 p, vec2 center) {
	vec2 d = (p - center) / vec2(300.0, 190.0);
	return exp(-dot(d, d));
}

// Murawa uśredniona z kilku próbek: tekstura zostaje jako delikatna faktura, nie ostry pixel art.
vec3 soft_grass(vec2 p) {
	vec2 uv = p / GRASS_TILE;
	vec3 sum = texture(grass_texture, uv).rgb;
	sum += texture(grass_texture, uv + vec2(0.03, 0.01)).rgb;
	sum += texture(grass_texture, uv + vec2(-0.02, 0.03)).rgb;
	sum += texture(grass_texture, uv + vec2(0.01, -0.03)).rgb;
	return sum / 4.0;
}

void fragment() {
	vec2 p = UV * SCREEN;
	vec3 sky = mix(SKY_TOP, SKY_LOW, clamp(p.y / (STAND_TOP + SKY_BLEND), 0.0, 1.0));

	float blotches = value_noise(p / vec2(90.0, 46.0));
	float fans = smoothstep(0.55, 0.85, value_noise((p + vec2(400.0, 90.0)) / vec2(64.0, 38.0)));
	vec3 stand = mix(STAND_DARK, STAND_LIGHT, blotches);
	stand = mix(stand, crowd_color * 0.65, fans * 0.6);

	float stripe = smoothstep(-STRIPE_BLEND, STRIPE_BLEND, abs(mod(p.x, STRIPE_WIDTH * 2.0) - STRIPE_WIDTH) - STRIPE_WIDTH * 0.5);
	vec3 grass = soft_grass(p) * mix(0.76, 1.0, stripe);
	grass = mix(grass, grass * vec3(0.55, 0.68, 0.72), 0.45);

	vec3 color = mix(sky, stand, smoothstep(STAND_TOP - SKY_BLEND, STAND_TOP + SKY_BLEND, p.y));
	color = mix(color, grass, smoothstep(HORIZON - GRASS_BLEND, HORIZON + GRASS_BLEND, p.y));

	float light = flood_light(p, vec2(150.0, 70.0)) + flood_light(p, vec2(960.0, 40.0)) + flood_light(p, vec2(1770.0, 70.0));
	color += FLOOD_COLOR * light * 0.5;
	COLOR.rgb = color;
}
