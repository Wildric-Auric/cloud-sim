#pragma vertex
#version 330 core

layout(location = 0) in vec3 attribPos;
layout(location = 1) in vec2 texCoord;

uniform mat4 uMvp = mat4(1.0);
uniform vec2 uResolution;

out vec2 coord;

void main() {
	gl_Position = uMvp * vec4(attribPos, 1.0);
	coord = texCoord;
};

#pragma fragment
#version 330 core



uniform sampler2D uTex0;
uniform sampler3D uTex1;

//--------------------------------------
float no3(vec3 p) {
    return max(0.0,texture(uTex1, p).x);
}
//-------------------------------

uniform float	  uTime;
uniform vec2	  uRes;
uniform float     uPow  = 1.0;
uniform float     uPerc = 1.0;
uniform float     uLpos = 3.0;
uniform float     uCpos = 3.0;
in vec2			  coord;

out vec4 FragColor;

struct Cam {
    vec3 pos;
};
struct Ray {
    vec3  origin;
    float t;
    vec3  dir;
};
struct Hit {
    vec3 c;
    float op;
    vec3 p;
};

float eps;

vec3 lp = vec3(uLpos,0.0,0.0);
vec4 sph = vec4(0.0,0.0,uCpos,0.1);

float sdf0(vec3 p, float rad) {
    return length(p) - rad;
}

bool rayBoxInt(inout float tmin, inout float tmax, Ray r) {
    vec3 f;
    vec3 lb = vec3(-0.1,-0.1,-1.0);
    vec3 rt = vec3(0.1,0.1,  -0.9);

    f.x = 1.0f / r.dir.x;
    f.y = 1.0f / r.dir.y;
    f.z = 1.0f / r.dir.z;
    // lb is the corner of AABB with minimal coordinates - left bottom, rt is maximal corner
    // r.org is origin of ray
    float t1 = (lb.x - r.origin.x)*f.x;
    float t2 = (rt.x - r.origin.x)*f.x;
    float t3 = (lb.y - r.origin.y)*f.y;
    float t4 = (rt.y - r.origin.y)*f.y;
    float t5 = (lb.z - r.origin.z)*f.z;
    float t6 = (rt.z - r.origin.z)*f.z;

    tmin = max(max(min(t1, t2), min(t3, t4)), min(t5, t6));
    tmax = min(min(max(t1, t2), max(t3, t4)), max(t5, t6));
    return !(tmax < 0 || tmin > tmax);
}


float sdftor( vec3 p, vec2 t ) {
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}

int cldfxmrc2(inout Ray ray,inout Hit hit) {
    vec3 n = normalize(hit.p - sph.xyz); //todo::don't recalculate
    vec3 op;
    float l  = 0.0;
    float d  = -1.0;
    float st = 0.005;
    float acc = 0.0;
    int i = 0;
    for (i = 0; i < 16;++i) {
        if (d > 0.0001) break;
        l += st;
        op = hit.p + ray.dir * l; 
        vec3 co = (sph.xyz + vec3(-sph.w, -sph.w, sph.w));
        co = 0.5 * (op - co) / sph.w;
        co.z = -co.z;
        float no = no3(co + vec3(0.0,uTime*0.1,0.0));
        no  = pow(no,uPow);
        acc += max(no,0.0);
        d = sdf0(op - sph.xyz, sph.w); 
    }
    float v = exp(-acc*uPerc);
    v = clamp(v,0.0,1.0);
    hit.c = vec3(v);
    ray.t += l+2.0*eps+2.0*sph.w;
    return 1;
}


int cldfxmrc(inout Ray ray,inout Hit hit) {
    vec3 n = normalize(hit.p - sph.xyz); //todo::don't recalculate
    vec3 op;
    float l  = 0.0;
    float d  = -1.0;
    float st = 0.0005;
    float acc = 0.0;
    int i = 0;
    for (i = 0; i < 128;++i) {
        if (d > 0.0001) break;
        l += st;
        op = hit.p + ray.dir * l; 
        Hit lh;
        Ray lr;
        hit.p     = op;
        lr.origin = op;
        lr.dir    = normalize(lp - op);
        lr.t      = 0.0;
        lh.c = vec3(0.0);
        lh.p = op;
        vec3 co = (sph.xyz + vec3(-sph.w, -sph.w, sph.w));
        co = 0.5 * (op - co) / sph.w;
        co.z = -co.z;
        float no = no3(co + vec3(0.0,uTime*0.1,0.0));
        no  = pow(no,uPow);
        cldfxmrc2(lr,lh);
        no  *= lh.c.y;
        acc += max(no,0.0);
        d = sdf0(op - sph.xyz, sph.w); 
    }
    float v = exp(-acc*uPerc);
    v = clamp(v,0.0,1.0);
    hit.c = mix(vec3(1.0), hit.c,v);
    ray.t += l+2.0*eps+2.0*sph.w;
    return 1;
}

void raymarch(inout Cam cam, inout Ray ray, inout Hit hit) {
    float d;
    vec3 p;
    int j = 0;
    for (int i = 0; i < 64; ++i) {
        p = ray.origin + ray.t * ray.dir;      
        vec3 n = normalize(p - sph.xyz); 
        vec2 suv;
        #define PI 3.1415
        suv.x =  atan(n.x, - n.z) / (PI*2.0) + 0.5;
        suv.y =  0.5 + asin(n.y)/PI;
        //float off = simplex3d_fractal(vec3(vec2(suv)*20.0,0.0));
        //sph.w += off*0.03;
        d = sdf0((p - sph.xyz), sph.w); 
        if (d <= eps) { 
            hit.p = p;
            cldfxmrc(ray,hit);
        }
        if (length(p) > 1000.0) { break;}
        ray.t += d;
    }
}

void main() {
    vec2 uv = (coord*uRes)/uRes.xx - vec2(0.5, 0.5*uRes.y/uRes.x);
    eps = 1.0 / uRes.x * 0.01;
    vec3 col;
    Ray ray;
    Cam cam;
    Hit hit;
    hit.c = vec3(uv.y + 0.2,0.2,-uv.y+0.4);
    ray.origin = vec3(0.0,0.0,uCpos);
    ray.t      = 0.0;
    ray.dir    = normalize(vec3(uv.x, uv.y, -1.0));
    //raymarch(cam, ray, hit);
    float mi; float ma;
    bool res = rayBoxInt(mi,ma, ray);
    if (res) {
        hit.c = vec3(ma - mi) / 0.1;
    }
    col = hit.c;
    //col = vec3(no3(vec3(uv, 0.0)));
	FragColor = vec4(col, 1.);
}
