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

vec3 lp = vec3(uLpos,3.0,10.0);
vec4 sph = vec4(0.0,0.0,uCpos,1.0);

float sdf0(vec3 p, float rad) {
    return length(p) - rad;
}

float sdftor( vec3 p, vec2 t ) {
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}

int cldfxmrc(inout Ray ray,inout Hit hit) {
    vec3 n = normalize(hit.p - sph.xyz); //todo::don't recalculate
    float ld; //= max(0.0,dot(n,normalize(lp-p)));
    vec3 lightc = vec3(ld) + 0.05;
    vec3 op;
    float l  = 0.0;
    float d  = -1.0;
    float st = 0.005;
    float acc = 0.0;
    int i = 0;
    for (i = 0; i < 100;++i) {
        if (d > 0.0001) break;
        l += st;
        op = hit.p + ray.dir * l; 
        ld = max(0.0,dot(n,normalize(lp-op)));
        Hit lh;
        Ray lr;
        lr.origin = op;
        lr.dir    = normalize(lp - op);
        lr.t      = 0.0;
        lh.c = vec3(1.0);
        //cldfxmrc2(lr,lh);
        vec3 co = (sph.xyz + vec3(-sph.w, -sph.w, sph.w));
        co = 0.5 * (op - co) / sph.w;
        co.z = -co.z;
        float no = no3(co + vec3(0.0,uTime*0.1,0.0));
        float v  = pow(no,uPow);
        //v *= abs(dot(lr.dir,n));
        acc += max(v,0.0);
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
            //hit.c = vec3(d);
        }
        if (length(p) > 1000.0) { break;}
        ray.t += d;
    }
}

void main() {
    vec2 uv = (coord*uRes)/uRes.xx - vec2(0.5, 0.5*uRes.y/uRes.x);
    eps = 1.0 / uRes.x * 0.1;
    vec3 col;
    Ray ray;
    Cam cam;
    Hit hit;
    hit.c = vec3(uv.y + 0.2,0.2,-uv.y+0.4);
    ray.origin = vec3(0.0);
    ray.t      = 0.0;
    ray.dir    = normalize(vec3(uv.x, uv.y, -1.0));
    raymarch(cam, ray, hit);
    col = hit.c;
    //col = vec3(no3(vec3(uv, 0.0)));
	FragColor = vec4(col, 1.);
}
