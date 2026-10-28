shader_type canvas_item;
// "Sharp bilinear" dla pixel artu przy niecałkowitej skali (np. 1440p: ×1,33): środek każdego piksela tekstury
// jest pełny i ostry, a filtrowanie liniowe działa tylko na szerokości jednego piksela ekranu na granicy pikseli.
// Wymaga filtra LINEAR na węźle (PixelArt.apply). Przy skali ×1 i ×2 wynik jest identyczny jak przy nearest.
// Na tekst (atlas czcionki w rozdzielczości ekranu) nie ma wpływu: przy próbkowaniu 1:1 zostaje zwykły bilinear.
// COLOR we fragment() zawiera już kolor tekstury, więc modulację (kolor wierzchołka) bierzemy z vertex().

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	vec2 texture_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 texel = UV * texture_size;
	vec2 seam = floor(texel + 0.5);
	vec2 texels_per_pixel = max(fwidth(texel), vec2(1e-5));
	texel = seam + clamp((texel - seam) / texels_per_pixel, -0.5, 0.5);
	COLOR = texture(TEXTURE, texel / texture_size) * modulate;
}
