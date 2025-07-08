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

vec4 box = vec4(0.0,0.0,-2.0,.5);
vec3 lp = vec3(uLpos,2.0,-2.0);
vec4 sph = vec4(0.0,0.0,uCpos,0.1);

float sdf0(vec3 p, float rad) {
    return length(p) - rad;
}

bool rayBoxInt(inout float tmin, inout float tmax, Ray r) {
    vec3 f;
    vec3 lb = vec3(-box.w,-box.w,box.z-box.w);
    vec3 rt = vec3(box.w,box.w,box.z+box.w);

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
    float mi; float ma;
    bool res = rayBoxInt(mi,ma, ray);
    if (res) {
        vec3 ss = vec3(0.1, 0.1,0.1);//sample size
        float maxIter = 128.0;
        float st = sqrt(3.0)*2.0*box.w/maxIter;
        float t   = max(0.0,mi); 
        float acc = 0.0;
        for (float i = 0.0; i < maxIter;++i) {
            vec3 p = ray.origin + t * ray.dir;
            vec3 c = (p - box.xyz)/box.w; c.z = -c.z;
            c      = (c+1.0)/2.0;
            
            //---------------secondary ray accumulation---------------
            Ray secRay; secRay.origin = p; secRay.dir = normalize(lp - p);
            float mi0 = 0.0; float ma0 = 0.0; float acc0 = 0.;
            rayBoxInt(mi0,ma0,secRay);
            float t0  = max(0.0, mi0);
            for (float j = 0.0; j < maxIter; ++j) {
                vec3 p0 = secRay.origin + t0 * secRay.dir;   
                vec3 c0 = (p0 - box.xyz)/box.w; c0.z = -c0.z;
                c0      = (c0+1.0)/2.0;
                acc0  += no3((c0+vec3(0.0,0.1*uTime,0.0)))*st*uPerc;
                t0 += st;
                if (t0 > ma0) {break;}
            }
            //--------------------------------------------------------

            float factor = no3((c+vec3(0.0,0.1*uTime,0.0)))*st*uPerc;
            acc += factor*exp(-acc0*uPow);
            t   += st;
            if (t > ma) {break;}
        }
        vec3 cl = vec3(exp(-acc*0.1));
        hit.c  = mix(hit.c, cl, acc);
    }
    col = hit.c;
    //col = vec3(no3(vec3(uv, 0.1*uTime)));
	FragColor = vec4(col, 1.);
}
