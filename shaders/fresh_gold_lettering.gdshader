shader_type spatial;
render_mode unshaded;
uniform float text_left = -0.1;
uniform float text_width = 0.2;
varying float text_x;
void vertex() { text_x = (VERTEX.x-text_left)/max(text_width,0.001); }
void fragment() {
 float broad = 1.0-smoothstep(.035,.09,abs(text_x-.66));
 float sharp = 1.0-smoothstep(.008,.022,abs(text_x-.64));
 vec3 gold=mix(vec3(.65,.32,.035),vec3(1.0,.71,.19),smoothstep(0.0,.55,text_x));
 gold=mix(gold,vec3(1.0,.90,.50),broad*.75);
 ALBEDO=mix(gold,vec3(1.0,.98,.80),sharp*.9);
}
