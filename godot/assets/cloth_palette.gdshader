shader_type canvas_item;
uniform vec4 cloth_color : source_color = vec4(0.3,0.5,0.4,1.0);
void fragment(){
 vec4 tex = texture(TEXTURE,UV);
 float teal = step(tex.r * 1.12,tex.g) * step(tex.r * 1.07,tex.b) * step(0.07,tex.g);
 float shade = max(max(tex.r,tex.g),tex.b);
 COLOR = vec4(mix(tex.rgb,cloth_color.rgb * shade * 1.8,teal * 0.82),tex.a);
}
