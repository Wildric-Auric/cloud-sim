#pragma compute
#version 430 core
layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
layout(rgba8, binding = 0) uniform image3D imgOutput;

uniform ivec3 uDispatchSize; 

vec3 random3(vec3 p3) {
	p3 = fract(p3 * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz+33.33);
    return fract((p3.xxy + p3.yxx)*p3.zyx);
}

const float F3 =  0.3333333;
const float G3 =  0.1666667;

//---------------------------------------------

float simplex3d(vec3 p) {
	 vec3 s = floor(p + dot(p, vec3(F3)));
	 vec3 x = p - s + dot(s, vec3(G3));
	 
	 vec3 e = step(vec3(0.0), x - x.yzx);
	 vec3 i1 = e*(1.0 - e.zxy);
	 vec3 i2 = 1.0 - e.zxy*(1.0 - e);
	 	
	 vec3 x1 = x - i1 + G3;
	 vec3 x2 = x - i2 + 2.0*G3;
	 vec3 x3 = x - 1.0 + 3.0*G3;
	 
	 vec4 w, d;
	 
	 w.x = dot(x, x);
	 w.y = dot(x1, x1);
	 w.z = dot(x2, x2);
	 w.w = dot(x3, x3);
	 
	 w = max(0.6 - w, 0.0);
	 
	 d.x = dot(random3(s), x);
	 d.y = dot(random3(s + i1), x1);
	 d.z = dot(random3(s + i2), x2);
	 d.w = dot(random3(s + 1.0), x3);
	 
	 w *= w;
	 w *= w;
	 d *= w;
	 
	 return dot(d, vec4(52.0));
}

const mat3 rot1 = mat3(-0.37, 0.36, 0.85,-0.14,-0.93, 0.34,0.92, 0.01,0.4);
const mat3 rot2 = mat3(-0.55,-0.39, 0.74, 0.33,-0.91,-0.24,0.77, 0.12,0.63);
const mat3 rot3 = mat3(-0.71, 0.52,-0.47,-0.08,-0.72,-0.68,-0.7,-0.45,0.56);

float simplex3d_fractal(vec3 m) {
    return   1.0*0.5 + 0.5333333*simplex3d(m*rot1)
			+0.2666667*simplex3d(2.0*m*rot2)
			+0.1333333*simplex3d(4.0*m*rot3)
			+0.0666667*simplex3d(8.0*m);
}

float worley(vec3 p, float s){
    vec3 uv = p * s;
    vec3 id = floor(uv);
    vec3 fd = fract(uv);
    float n = 0.;
    float m = 9999.; float d;
    vec3  c; vec3  r;
    for(float x = -1.; x <=1.; x++){
    for(float y = -1.; y <=1.; y++){
    for(float z = -1.; z <=1.; z++){
        c = id+vec3(x,y,z);
        r = (c+random3(mod(c,vec3(s))));
        d = distance(uv,r); 
        m = min(d,m);
    }}}
    return 1.0-m;
}

//---------------------------------------------
float sdTorus( vec3 p, vec2 t ) {
  p = p - vec3(0.5);
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}

void main() {
	//int idx		 = int(gl_GlobalInvocationID.y * 16 + gl_GlobalInvocationID.x);
	vec4  value		 = vec4(0.0, 0.0, 0.0, 1.0);
	ivec3 tc = ivec3(gl_GlobalInvocationID.xyz);
    vec3 uv  = vec3(tc) / uDispatchSize;
    float v  = simplex3d_fractal(uv * 5.0);
    float v1 = worley(uv,10.0); 
    value.xyz =vec3(mix(v1*3.5,v,0.0));
    //value.xyz = vec3(1.);
    float d = distance(uv,vec3(0.5));
    d = 0.0;
    d = clamp(sdTorus(uv,vec2(0.3,0.1))*6.,0.,1.0);
//    if (d < 0.0) {
//        d = 1.0;
//    } else d = 0.0;
    //value.xyz = vec3(1.0 - d*10.);
    value.xyz *= smoothstep(0.5,1.0,1.0 - d);
	imageStore(imgOutput, tc, value);
}
