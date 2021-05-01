shader_type canvas_item;

uniform sampler2D u_skybox;

uniform vec2 u_resolution = vec2(1920, 1080);
uniform float MAX_DIST = 99999.0;
uniform float sky = 0.0;
uniform vec3 u_pos = vec3(-5.0, 0.0, 0.0);
uniform vec2 u_mouse = vec2(0.0, 0.0);
uniform vec2 u_seed1;
uniform vec2 u_seed2;

const vec3 light = (vec3(-0.5, 0.75, -1.0));

uint TausStep(uint z, int S1, int S2, int S3, uint M)
{
	uint b = (((z << uint(S1)) ^ z) >> uint(S2));
	return (((z & M) << uint(S3)) ^ b);
}

uint LCGStep(uint z, uint A, uint C)
{
	return (A * z + C);	
}

vec2 hash22(vec2 p)
{
	p += u_seed1.x;
	vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
	p3 += dot(p3, p3.yzx+33.33);
	return fract((p3.xx+p3.yz)*p3.zy);
}

float random(inout uvec4 R_STATE)
{
	R_STATE.x = TausStep(R_STATE.x, 13, 19, 12, uint(4294967294));
	R_STATE.y = TausStep(R_STATE.y, 2, 25, 4, uint(4294967288));
	R_STATE.z = TausStep(R_STATE.z, 3, 11, 17, uint(4294967280));
	R_STATE.w = LCGStep(R_STATE.w, uint(1664525), uint(1013904223));
	return 2.3283064365387e-10 * float((R_STATE.x ^ R_STATE.y ^ R_STATE.z ^ R_STATE.w));
}

vec3 randomOnSphere(inout uvec4 R_STATE) {
	vec3 rand = vec3(random(R_STATE), random(R_STATE), random(R_STATE));
	float theta = rand.x * 2.0 * 3.14159265;
	float v = rand.y;
	float phi = acos(2.0 * v - 1.0);
	float r = pow(rand.z, 1.0 / 3.0);
	float x = r * sin(phi) * cos(theta);
	float y = r * sin(phi) * sin(theta);
	float z = r * cos(phi);
	return vec3(x, y, z);
}


mat2 rot(float a){
	float s = sin(a);
	float c = cos(a);
	return mat2(vec2(c, -s), vec2(s, c));
}

vec2 sphIntersect(in vec3 ro, in vec3 rd, float ra){
	float b = dot(ro, rd);
	float c = dot(ro, ro) - ra * ra;
	float h = b * b - c;
	if(h < 0.0) return vec2(-1.0);
	h = sqrt(h);
	return vec2(-b - h, -b + h);
}

vec2 boxIntersection(in vec3 ro, in vec3 rd, in vec3 rad, out vec3 oN){
	vec3 m = 1.0 /rd;
	vec3 n = m * ro;
	vec3 k = abs(m) * rad;
	vec3 t1 = -n - k;
	vec3 t2 = -n + k;
	float tN = max(max(t1.x, t1.y), t1.z);
	float tF = min(min(t2.x, t2.y), t2.z);
	if (tN > tF || tF < 0.0) return vec2(-1.0);
	oN = -sign(rd) * step(t1.yzx, t1.xyz) * step(t1.zxy, t1.xyz);
	return vec2(tN, tF);
}

float plaIntersect(in vec3 ro, in vec3 rd, in vec4 p) {
	return -(dot(ro, p.xyz) + p.w) / dot(rd, p.xyz);
}

vec3 getSky(vec3 rd){ //SKYBOX
	vec2 uv = vec2(atan(rd.x, rd.y) , asin(rd.z) * 2.0);
	uv /= 3.14159265;
	uv = uv * 0.5 + 0.5;
	vec3 col = texture(u_skybox, uv).rgb;
	vec3 sun = vec3(0.95, 0.9, 1.0);
	sun *= max(0.0, pow(dot(rd, normalize(light)), 256.0));
	col *= max(0.0, dot(normalize(light), vec3(0.0, 0.0, -sky)));
	return clamp(sun + col * 0.01, 0.0, 1.0);
}
/*
vec3 getSky(vec3 rd) {
	vec3 col = vec3(0.3, 0.6, 1.0);
	vec3 sun = vec3(0.95, 0.9, 1.0);
	sun *= max(0.0, pow(dot(rd, normalize(light)), 256.0));
	col *= max(0.0, dot(normalize(light), vec3(0.0, 0.0, -sky)));
	return clamp(sun + col * 0.01, 0.0, 1.0);
}
*/
vec4 castRay(inout vec3 ro,inout vec3 rd,inout uvec4 R_STATE, float time){
	vec4 col;
	vec2 minIt = vec2(MAX_DIST);
	vec2 it;
	vec3 n;
	
	vec4 spherespos[6];
	vec4 spherescol[6];
	
	spherespos[0] = vec4(-1.0, 0.0, -0.01, 1.0);
	spherespos[1] = vec4(0.0, 4.5, -0.01, 1.0);
	spherespos[2] = vec4(1.0, -2.0, -0.01, 1.0);
	spherespos[3] = vec4(3.5 + cos(time), -1.0, 0.5, 0.5);
	spherespos[4] = vec4(-3.5, -1.0 + cos(time), 0.0, 0.5);
	spherespos[5] = vec4(-5.5, -0.5, -0.01, 1.0);
	
	spherescol[0] = vec4(1.0, 1.0, 1.0, -0.5);
	spherescol[1] = vec4(1.0, 1.0, 1.0, 0.5);
	spherescol[2] = vec4(1.0, 0.0, 0.5, 1.0);
	spherescol[3] = vec4(1.0, 1.0, 1.0, -2.0);
	spherescol[4] = vec4(0.5, 1.0, 0.5, -2.0);
	spherescol[5] = vec4(0.5, 0.5, 0.5, 0.0);
	
	for(int i = 0; i < spherespos.length(); i++) {
		it = sphIntersect(ro - spherespos[i].xyz, rd, spherespos[i].w);
		if(it.x > 0.0 && it.x < minIt.x){
			minIt = it;
			vec3 itPos = ro + rd * it.x;
			n = normalize(itPos - spherespos[i].xyz);
			col = spherescol[i];
		}
	}
	vec3 boxN;
	it = boxIntersection(ro - vec3(0.0, 2.0, 0.0), rd, vec3(1.0), boxN);
	if(it.x > 0.0 && it.x < minIt.x){
		minIt = it;
		n = boxN;
		col = vec4(0.4, 0.6, 0.8, 1.0);
	}
	
	vec3 planeNormal = vec3(0.0, 0.0, -1.0);
	it = vec2(plaIntersect(ro, rd, vec4(planeNormal, 1.0)));
	if(it.x > 0.0 && it.x < minIt.x){
		minIt = it;
		n = planeNormal;
		col = vec4(0.5, 0.25, 0.1, 0.01);
	}
	if(minIt.x == MAX_DIST) return vec4(getSky(rd), -2.0);
	if(col.a == -2.0) return col;
	vec3 reflected = reflect(rd, n);
	if(col.a < 0.0) {
		float fresnel = 1.0 - abs(dot(-rd, n));
		if(random(R_STATE) - 0.1 < fresnel * fresnel) {
			rd = reflected;
			return col;
		}
		ro += rd * (minIt.y + 0.001);
		rd = refract(rd, n, 1.0 / (1.0 - col.a));
		return col;
	}
	vec3 itPos = ro + rd * it.x;
	vec3 r = randomOnSphere(R_STATE);
	vec3 diffuse = normalize(r * dot(r, n));
	ro += rd * (minIt.x - 0.001);
	rd = mix(diffuse, reflected, col.a);
	return col;
}

vec3 traceRay(vec3 ro, vec3 rd,inout uvec4 R_STATE, float time){
	vec3 col = vec3(1.0);
	for (int i = 0; i < 32; i++){
		vec4 refCol = castRay(ro, rd, R_STATE, time);
		col *= refCol.rgb;
		if(refCol.a == -2.0) return col;
	}
	return vec3(0.0);
}

void fragment(){
	vec2 uv = (UV - 0.5) * u_resolution / u_resolution.y;
	vec2 uvRes = hash22(uv + 1.0) * u_resolution + u_resolution;
	uvec4 R_STATE;
	R_STATE.x = uint(u_seed1.x + uvRes.x);
	R_STATE.y = uint(u_seed1.y + uvRes.x);
	R_STATE.z = uint(u_seed2.x + uvRes.y);
	R_STATE.w = uint(u_seed2.y + uvRes.y);
	vec3 rayOrigin = u_pos;
	vec3 rayDirection = normalize(vec3(1.0, uv));
	rayDirection.zx *= rot(-u_mouse.y);
	rayDirection.xy *= rot(u_mouse.x);
	vec3 col = vec3(0.0);
	int samples = 128; //128 - normal quality //EDIT THIS FOR BEST QUALITY. MORE SAMPLES = MORE QUALITY
	for(int i = 0; i < samples; i++) {
		col += traceRay(rayOrigin, rayDirection, R_STATE, TIME);
	}
	col /= float(samples);
	float white = 20.0;
	col *= white * 16.0;
	col = (col * (1.0 + col / white / white)) / (1.0 + col);
	COLOR = vec4(col, 1.0);
}
