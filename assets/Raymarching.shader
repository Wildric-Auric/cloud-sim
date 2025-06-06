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



//--------------------------------------
vec3 random3(vec3 c) {
	float j = 4096.0*sin(dot(c,vec3(17.0, 59.4, 15.0)));
	vec3 r;
	r.z = fract(512.0*j);
	j *= .125;
	r.x = fract(512.0*j);
	j *= .125;
	r.y = fract(512.0*j);
	return r-0.5;
}

const float F3 =  0.3333333;
const float G3 =  0.1666667;

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


//-------------------------------
uniform sampler2D uTex0;

uniform float	  uTime;
uniform vec2	  uRes;
uniform float     uPow  = 1.0;
uniform float     uPerc = 1.0;
uniform float     uLpos = 3.0;
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
    float d;
    vec3 p;
    vec3 lp = vec3(uLpos,3.0,10.0);
    vec4 sph = vec4(0.0,0.0,-5.0,1.0);
    for (int i = 0; i < 256; ++i) {
        p = ray.origin + ray.t * ray.dir;      
        vec3 n = normalize(p - sph.xyz); 
        vec2 suv;
        #define PI 3.1415
        suv.x =  atan(n.x, - n.z) / (PI*2.0) + 0.5;
        suv.y =  0.5 + asin(n.y)/PI;
        float off = simplex3d_fractal(vec3(vec2(suv)*20.0,0.0));
        sph.w += off*0.03;
        d = distance(p, sph.xyz) - sph.w; 
        if (d <= eps) { 
            hit.p = p;
            float ld = max(0.0,dot(n,normalize(lp-p)));
            vec3 lightc = vec3(ld) + 0.05;
            //hit.c = lightc;
            float l = 0.0;
            vec3 op;
            d = -1.0;
            float st = 0.005;
            //hit.c *= 0.0;
            float acc = 0.0;
            while (d < 0.0) {
                l += st;
                op = p + ray.dir * l; 
                ld = max(0.0,dot(n,normalize(lp-op)));
                acc += max((st * pow(simplex3d_fractal(op*5.0+vec3(0.,uTime,uTime)),uPow)),0.0) * ld;
                //acc += ld;
                d = distance(op, sph.xyz) - sph.w; 
            }
            if (l > st) {
                //l = l + st - (distance(p, sph.xyz) - sph.w); 
                hit.c *=  vec3(clamp(exp(-acc*uPerc),0.0,1.0));
            }
            break; 
        }
        if (length(p) > 1000.0) {
            break;
        }
        ray.t += d;
    }
    col = hit.c;
	FragColor = vec4(col, 1.);
}
