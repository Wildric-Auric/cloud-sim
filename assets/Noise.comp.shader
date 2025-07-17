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

float random31(vec3 p3) {
	p3  = fract(p3 * .1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

#define s(i,j,k) random31(fl + vec3(fl.x+i<s-1?i:-fl.x,fl.y+j<s-1?j:-fl.y,fl.z+k<s-1?k:-fl.z));
float valueNoise(vec3 p, float s) {
    vec3 uv = p * s;
    vec3 fl = floor(uv);
    vec3 x  = smoothstep(vec3(0.),vec3(1.),fract(uv));
    float a = s(0,0,0); float b = s(1,0,0); 
    float c = s(1,1,0); float d = s(0,1,0); 
    float e = s(0,0,1); float f = s(1,0,1); 
    float g = s(1,1,1); float h = s(0,1,1); 

    float t  = mix(mix(a,b,x.x), mix(d,c,x.x),x.y);
    float t1 = mix(mix(e,f,x.x), mix(h,g,x.x),x.y);

    return mix(t,t1,x.z);
}

//---------------------------------------------


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

float fbm(vec3 p, float s) {
    float x = 0.;
    vec2 a = vec2(1.0,s);
    for (float i = 0.; i < 10.0; ++i) {
        x   += a.x * valueNoise(p,a.y);
        a.x /=2.0;
        a.y *=2.0;
    }
    return x/2.;
}

float worleyFbm(vec3 p, float s) {
    float x = 0.;
    vec2 a = vec2(1.0,s);
    for (float i = 0.; i < 5.0; ++i) {
        x   += a.x * worley(p,a.y);
        a.x /=2.0;
        a.y *=2.0;
    }
    //return pow(x*1.,100.0);
    return pow(x,16.);
}


//---------------------------------------------

void main() {
	//int idx		 = int(gl_GlobalInvocationID.y * 16 + gl_GlobalInvocationID.x);
	vec4  value		 = vec4(0.0, 0.0, 0.0, 1.0);
	ivec3 tc = ivec3(gl_GlobalInvocationID.xyz);
    vec3 uv  = vec3(tc) / uDispatchSize;
    float v = fbm(uv,10.0);
    float v1 = worleyFbm(uv,10.0); 
    value.xyz =vec3(mix(v1,v,0.0));
	imageStore(imgOutput, tc, value);
}
