shader_type canvas_item;
uniform vec2 panel_size=vec2(610.0,126.0);
void fragment() {
	vec2 p=UV*panel_size;
	vec2 q=abs(p-panel_size*.5)-(panel_size*.5-vec2(12.0));
	float edge=length(max(q,vec2(0)))+min(max(q.x,q.y),0.0)-8.0;
	float grain=fract(sin(dot(floor(p*1.5),vec2(12.9898,78.233)))*43758.5453);
	float fleck=smoothstep(.91,1.0,grain)*.13;
	float rim=(1.0-smoothstep(.4,1.6,abs(edge+2.0)))*.22;
	COLOR=vec4(vec3(1.0,.91,.70),max(fleck,rim)*(1.0-smoothstep(-1.0,0.0,edge)));
}
