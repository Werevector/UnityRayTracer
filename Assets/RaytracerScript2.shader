﻿// Fra https://docs.unity3d.com/Manual/SL-VertexFragmentShaderExamples.html
//https://msdn.microsoft.com/en-us/library/windows/desktop/bb509640(v=vs.85).aspx
//https://msdn.microsoft.com/en-us/library/windows/desktop/ff471421(v=vs.85).aspx
// rand num generator http://gamedev.stackexchange.com/questions/32681/random-number-hlsl
// http://www.reedbeta.com/blog/2013/01/12/quick-and-easy-gpu-random-numbers-in-d3d11/
// https://docs.unity3d.com/Manual/RenderDocIntegration.html
// https://docs.unity3d.com/Manual/SL-ShaderPrograms.html

Shader "Unlit/SingleColor"
{
	Properties
	{
		_SpherePos("sphere position", Vector) = (0, 0, -1, 1)
		_SphereCol("sphere color", Color) = (1,0,0,1)
		_FloorCol("Floor sphere color", Color) = (0.5,0.5,0.5,1)
	}
	SubShader{ Pass	{
		CGPROGRAM

		//TYPEDEFS
		#pragma vertex vert
		#pragma fragment frag

		typedef vector <float, 3> vec3;
		typedef vector <float, 2> vec2;
		typedef vector <fixed, 3> col3;
		//TYPEDEFS_END

		struct appdata
		{
			float4 vertex : POSITION;
			float2 uv : TEXCOORD0;
		};
		
		struct v2f
		{
			float2 uv : TEXCOORD0;
			float4 vertex : SV_POSITION;
		};
		
		v2f vert(appdata v)
		{
			v2f o;
			o.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
			o.uv = v.uv;
			return o;
		}
	
		float rand_1_05(in float2 uv)
		{
			float2 noise = (frac(sin(dot(uv, float2(12.9898, 78.233)*2.0)) * 43758.5453));
			return abs(noise.x + noise.y) * 0.5;
		}

		vec3 unit_vector(vec3 v)
		{
			return v / length(v);
		}

		vec3 random_in_unit_sphere(float2 uv) {
			vec3 p;
			do {
				p = 2.0*vec3(rand_1_05(uv), rand_1_05(uv+5), rand_1_05(uv+10)) - vec3(1, 1, 1);
			} while (length(p) >= 1.0);
			return p;
		}

		class ray
		{
			void init(vec3 a, vec3 b) { A = a; B = b; }
			vec3 point_at_parameter(float t) { return A + t*B; }
			vec3 origin()		{ return A; }
			vec3 direction()	{ return B; }
			vec3 A;
			vec3 B;
		};

		struct hit_record {
			float t;
			vec3 p;
			vec3 normal;
			float2 uv;
		};

		vec3 reflect(in vec3 v, in vec3 n) {
			return v - 2 * dot(v, n)*n;
		}

		bool refract(in vec3 v, in vec3 n, in float ni_over_nt, inout vec3 refracted) {
			vec3 uv = unit_vector(v);
			float dt = dot(uv, n);
			float discriminant = 1.0 - ni_over_nt*ni_over_nt*(1 - dt*dt);
			if (discriminant > 0) {
				refracted = ni_over_nt*(uv - n*dt) - n*sqrt(discriminant);
				return true;
			}
			else
			{
				return false;
			}
		}

		float schlick(in float cosine, in float ref_idx) {
			float r0 = (1 - ref_idx) / (1 + ref_idx);
			r0 = r0*r0;
			return r0 + (1 - r0)*pow((1 - cosine), 5);
		}

		class material {
			void init(in vec3 a, in int t, float f = 1)
			{ 
				albedo = a; 
				type = t; 
				if (f < 1) 
				{ 
					fuzz = f;
				} 
				else 
				{ 
					fuzz = 1; 
				} 
			}
			bool scatter(in ray r, inout hit_record rec, inout vec3 attenuation, inout ray scattered) {
				if(type == 0) {
					return scatterLam(r, rec, attenuation, scattered);
				}
				else if (type == 1) {
					return scatterMet(r, rec, attenuation, scattered);
				}
				else if (type == 2){
					return scatterDie(r, rec, attenuation, scattered);
				}
				else {
					return scatterLam(r, rec, attenuation, scattered);
				}
			}

			bool scatterLam(in ray r_in, inout hit_record rec, inout vec3 attenuation, inout ray scattered) {
				vec3 target = rec.p + rec.normal + random_in_unit_sphere(rec.uv);
				ray s;
				s.init(rec.p, target - rec.p);
				scattered = s;
				attenuation = albedo;
				return true;
			}

			bool scatterMet(in ray r_in, inout hit_record rec, inout vec3 attenuation, inout ray scattered) {
				vec3 reflected = reflect(unit_vector(r_in.direction()), rec.normal);
				ray s;
				s.init(rec.p, reflected + fuzz*random_in_unit_sphere(rec.uv));
				scattered = s;
				attenuation = albedo;
				return (dot(scattered.direction(), rec.normal) > 0);
			}
			
			bool scatterDie(in ray r_in, inout hit_record rec, inout vec3 attenuation, inout ray scattered) {
				float ref_idx = 1.5f;
				vec3 outward_normal;
				vec3 reflected = reflect(r_in.direction(), rec.normal);
				float ni_over_nt;
				attenuation = vec3(1.0, 1.0, 1.0);
				vec3 refracted;
				float reflect_prob;
				float cosine;
				if (dot(r_in.direction(), rec.normal) > 0) {
					outward_normal = -rec.normal;
					ni_over_nt = ref_idx;
					cosine = ref_idx * dot(r_in.direction(), rec.normal) / length(r_in.direction());
				}
				else {
					outward_normal = rec.normal;
					ni_over_nt = 1.0 / ref_idx;
					cosine = -dot(r_in.direction(), rec.normal) / length(r_in.direction());
				}
				if (refract(r_in.direction(), outward_normal, ni_over_nt, refracted)) {
					reflect_prob = schlick(cosine, ref_idx);
				}
				else {
					ray s;
					s.init(rec.p, reflected);
					scattered = s;
					reflect_prob = 1.0;
				}
				if ((rand_1_05(rec.uv)) < reflect_prob) {
					ray s;
					s.init(rec.p, reflected);
					scattered = s;
				}
				else {
					ray s;
					s.init(rec.p, refracted);
					scattered = s;
				}
				return true;
			}

			int type;
			vec3 albedo;
			float fuzz;
		};

		interface hitable {
			bool hit(ray r, float t_min, float t_max, inout hit_record rec, inout material mat_ptr);
		};

		class sphere : hitable {
			void init(vec3 cen, float r, material m) { center = cen; radius = r; mat = m; }
			bool hit(ray r, float t_min, float t_max, inout hit_record rec, inout material mat_ptr) {
				vec3 oc = r.origin() - center;
				float a = dot(r.direction(), r.direction());
				float b = dot(oc, r.direction());
				float c = dot(oc, oc) - radius*radius;
				float discriminant = b*b - a*c;
				if (discriminant > 0) {
					float temp = (-b - sqrt(b*b - a*c)) / a;
					if (temp < t_max && temp > t_min) {
						rec.t = temp;
						rec.p = r.point_at_parameter(rec.t);
						rec.normal = (rec.p - center) / radius;
						mat_ptr = mat;
						return true;
					}
					temp = (-b + sqrt(b*b - a*c)) / a;
					if (temp < t_max && temp > t_min) {
						rec.t = temp;
						rec.p = r.point_at_parameter(rec.t);
						rec.normal = (rec.p - center) / radius;
						mat_ptr = mat;
						return true;
					}
				}
				return false;
			}

			vec3 center;
			float radius;
			material mat;
		};

		class hitable_list : hitable {
			void init() { count = 0; }
			void add(sphere s) {
				items[count] = s;
				count++;
			}
			bool hit(ray r, float t_min, float t_max, inout hit_record rec, inout material mat_ptr) {
				hit_record temp_rec;
				temp_rec.t = 0;
				temp_rec.p = vec3(0, 0, 0);
				temp_rec.normal = vec3(0, 0, 0);
				temp_rec.uv = rec.uv;

				bool hit_anything = false;
				float closest_so_far = t_max;
				for (int i = 0; i < count; i++) {
					if (items[i].hit(r, t_min, closest_so_far, temp_rec, mat_ptr)) {
						hit_anything = true;
						closest_so_far = temp_rec.t;
						rec = temp_rec;
					}
				}
				return hit_anything;
			}

			//hitables
			int		count;
			int		length;
			sphere  items[4];
		};

		class camera {
			void init() {
				lower_left_corner = vec3(-2.0, -1.0, -1.0);
				horizontal = vec3(4.0, 0.0, 0.0);
				vertical = vec3(0.0, 2.0, 0.0);
				origin = vec3(0.0, 0.0, 0.0);
			}
			ray get_ray(float u, float v) {
				ray r;
				r.init(origin, lower_left_corner + u*horizontal + v*vertical - origin);
				return r;
			}
			vec3 lower_left_corner;
			vec3 horizontal;
			vec3 vertical;
			vec3 origin;
		};

		col3 background(ray r) {
			vec3 unit_direction = unit_vector(r.direction());
			float t = 0.5*(unit_direction.y + 1.0);
			return (1.0 - t)*vec3(1.0, 1.0, 1.0) + t*vec3(0.5, 0.7, 1.0);
		}

		col3 color(ray r, hitable_list world, float2 uv) 
		{
			const float MAXFLOAT = 1.7014116317805962808001687976863 * pow(10, 38);
			hit_record rec;
			rec.t = 0;
			rec.p = vec3(0, 0, 0);
			rec.normal = vec3(0, 0, 0);
			rec.uv = uv;
			
			material mat;
			mat.init(vec3(0, 0, 0), 0);

			ray scattered;
			scattered.init(rec.p, rec.normal);
			vec3 attenuation = vec3(0, 0, 0);

			int depth = 0;

			col3 color = background(r);	
			bool done = false;
			do {
				if (world.hit(r, 0.001, MAXFLOAT, rec, mat)) {
					if (mat.scatter(r, rec, attenuation, scattered)) {
						color *= attenuation;
						r = scattered;
						depth++;
					}
					else {
						color *= vec3(0, 0, 0);
						depth++;
					}
				}
				else {
					done = true;
					return color;
				}
			} while (!done && depth < 5);
			
			return color;
			
		}

		float4 _SpherePos;
		fixed4 _SphereCol;
		fixed4 _FloorCol;

		fixed4 frag(v2f i) : SV_Target
		{
		
		camera cam;
		cam.init();
		
		hitable_list world;
		world.init();

		material m;
		m.init(_SphereCol, 0);

		sphere s;
		s.init(_SpherePos, 0.5, m);
		world.add(s);

		//material << (color, type, fuzz(optional))
		m.init(vec3(1.0, 1.0, 1.0), 1, 0);
		s.init(vec3(-1, 0, -1), 0.5, m);
		world.add(s);

		m.init(vec3(1, 1, 1), 2);
		s.init(vec3(1, 0, -1), 0.5, m);
		world.add(s);

		m.init(_FloorCol, 0);
		s.init(vec3(0, -100.5, -1), 100, m);
		world.add(s);

		int samples = 60;
		col3 col = col3(0.0, 0.0, 0.0);
		
		for (int sa = 0; sa < samples; sa++ ) {
			float xr = rand_1_05(i.uv + sa) / 110;
			float yr = rand_1_05(i.uv + sa + 1) / 110;
			ray r = cam.get_ray(i.uv.x + xr, i.uv.y + yr);
			col += color(r, world, i.uv+sa);
		}
		col /= (float)samples;

		return fixed4(col,1);
		}
		
		ENDCG

}}}