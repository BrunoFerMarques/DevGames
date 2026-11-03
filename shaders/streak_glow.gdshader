shader_type canvas_item;
// Brilho nas bordas da tela (StreakGlow): mais forte na beirada, some em
// direcao ao centro, pulsando. Mistura normal (nao aditiva): laranja somado
// ao mar azul virava rosa.
render_mode unshaded;

uniform vec4 glow_color : source_color = vec4(0.952941, 0.768627, 0.294118, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
// Largura / altura do retangulo, pra borda ter a mesma espessura nos 4 lados.
uniform float aspect = 1.7778;
// Espessura do brilho, em fracao da altura.
uniform float width = 0.2;

void fragment() {
	float dx = min(UV.x, 1.0 - UV.x) * aspect;
	float dy = min(UV.y, 1.0 - UV.y);
	float edge = 1.0 - smoothstep(0.0, width, min(dx, dy));
	float pulse = 0.8 + 0.2 * sin(TIME * 6.0);
	COLOR = vec4(glow_color.rgb, glow_color.a * intensity * edge * edge * pulse);
}
