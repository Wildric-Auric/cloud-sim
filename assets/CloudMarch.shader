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
uniform sampler2D uTex2;

uniform float	  uTime;
uniform vec2	  uRes;
uniform float     uPow  = 1.0;
uniform float     uPerc = 1.0;
uniform float     uLpos = 3.0;
uniform float     uCpos = 3.0;
uniform int       uNoise = 0;
in vec2			  coord;

out vec4 FragColor;
#define pi 3.1415
//--------------------------------------
float sdTorus( vec3 p, vec2 t ) {
  p = p - vec3(0.5);
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}
float sdSphere(vec3 p, float r) {
    p = p - vec3(0.5);
    return length(p) - r;
}
float sdBox( vec3 p, vec3 b ) {
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}




float morph(vec3 p) {
    float d;
//    d = min(sdSphere(p-vec3(0.1,0.0,0.0),0.25), sdSphere(p+vec3(0.3,0.0,0.0),0.1));
//    d = min(d,sdSphere(p+vec3(0.0,0.2,0.0),0.1));
    d = sdTorus(p,vec2(0.3,0.1))*6.0; 
    float f = smoothstep(0.8,1.0,1.0 - d);

    //return 1.0;
    #define st(off,channel) smoothstep(0.0,off,channel)*(1.0-smoothstep(1.0-off,1.0,channel))
    return st(0.2,p.x)*st(0.2,p.y)*st(0.2,p.z);//*(1.0-smoothstep(0.9,1.0,p.z));


    return texture(uTex2,p.xy).x * smoothstep(0.5,0.8,p.z) * (1.0-smoothstep(0.5,0.8,p.z));
}

float no3(vec3 p) {
    float s = texture(uTex1, p*1.0+vec3(0.0,-uTime*0.1,0.0)).x; s = pow(s,1.0);
    float d = sdTorus(p,vec2(0.3,0.1))*6.0; 
    float f = morph(p);
    float r = max(0.0,s*f);
    return r;
}
//-------------------------------
float hg(float d, float g) {
    float gp = g*g;
    return (1.0-gp)/(pow(1.0+gp-2.*g*d,1.5)*(4.0*pi));
}

float beer(float d, float a) {
    return exp(-d*a);
}

float beerpdr(float d, float a) {
    return exp(-d*a)*pow(1.0 - exp(-d*d*a), 0.2);
}

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
vec3 lp = vec3(0.,10.,0.);

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

const float maxIter  = 64.0;
const float maxIter2 = 4.0; 

void main() {
    lp.z = uLpos; 
    vec2 uv = (coord*uRes)/uRes.xx - vec2(0.5, 0.5*uRes.y/uRes.x);
    
    if (uNoise != 0) {
        //FragColor = vec4(vec3(no3(vec3(coord, mod(0.0,1.0))+vec3(uTime,uTime,0.))),1.0);
        FragColor = vec4(texture(uTex1,vec3(uv,0.0)).xyz, 1.0);
        return;
    }

    eps = 1.0 / uRes.x * 0.01;
    vec3 col;
    Ray ray;
    Cam cam;
    Hit hit;
    hit.c = vec3(-uv.y+.3, 0.2,uv.y + 0.3);
    //hit.c = vec3(-uv.y+0.9,-uv.y+0.9, 1.0);
    ray.origin = vec3(0.0,0.0,uCpos);
    ray.t      = 0.0;
    
    vec3 forward = normalize(box.xyz - ray.origin);
    vec3 right   = normalize(cross(forward, vec3(0.,1.,0.)));
    vec3 upDir   = normalize(cross(right, forward));
    float fov = 1.;
    //ray.dir = normalize(forward + uv.x * right * fov + uv.y * upDir * fov);    
    ray.dir = normalize(vec3(uv,-1.0));

    float mi; float ma;
    bool res = rayBoxInt(mi,ma, ray);

    if (!res) {
        col = hit.c;
	    FragColor = vec4(col, 1.);
        return;
    }

    vec3 ss = vec3(0.1, 0.1,0.1);//sample size
    float st = sqrt(3.0)*2.0*box.w/maxIter;
    mi = max(0.0,mi)+0.001;
    st = (ma - mi) / maxIter; 
    float t    = mi; 
    float acc  = 0.0;
    float cacc = 0.0;
    float i;
    vec4 scatTr = vec4(vec3(0.),1.0);
    vec3 lcol = vec3(255.,215.,130.)/255.0;
    vec3 amb  = vec3(0.3);
    for (i = 0.0; i < maxIter;++i) {
        vec3 p = ray.origin + t * ray.dir;
        vec3 c = (p - box.xyz)/box.w; c.z = -c.z;
        c      = (c+1.0)/2.0;
        
        //---------------secondary ray accumulation---------------
        Ray secRay; secRay.origin = p; secRay.dir = normalize(lp - p);
        float mi0 = 0.0; float ma0 = 0.0; float acc0 = 0.;
        rayBoxInt(mi0,ma0,secRay);
        float t0  = 0.0;
        ma0       = min(ma0, distance(lp,p));
        float st0 = ma0/maxIter2;
        for (float j = 0.0; j < maxIter2; ++j) {
            vec3 p0 = secRay.origin + t0 * secRay.dir;   
            vec3 c0 = (p0 - box.xyz)/box.w; c0.z = -c0.z;
            c0      = (c0+1.0)/2.0;
            float factor = no3(c0);
            acc0   += factor;
            t0 += st0;
        }
        //--------------------------------------------------------
        float ext         = no3(c);
        float trans       = beer(ext*st,uPerc); 
        float phase       = hg(dot(secRay.dir, -ray.dir),0.6);
        vec3 lum          = amb + lcol*10.0*acc0*phase*beerpdr(acc0*st0*2.0,uPow);
        scatTr.xyz += (lum * (1.0 - trans))*scatTr.w;
        scatTr.w   *= trans;

        t    += st;
        if (scatTr.w < 0.001) {scatTr.w = 0.0; break;};
        if (t > ma) {break;}
    }
    hit.c = hit.c * scatTr.w + scatTr.xyz;
	FragColor = vec4(hit.c, 1.);
}
