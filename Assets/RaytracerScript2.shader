// Fra https://docs.unity3d.com/Manual/SL-VertexFragmentShaderExamples.html
//https://msdn.microsoft.com/en-us/library/windows/desktop/bb509640(v=vs.85).aspx
//https://msdn.microsoft.com/en-us/library/windows/desktop/ff471421(v=vs.85).aspx
// rand num generator http://gamedev.stackexchange.com/questions/32681/random-number-hlsl
// http://www.reedbeta.com/blog/2013/01/12/quick-and-easy-gpu-random-numbers-in-d3d11/
// https://docs.unity3d.com/Manual/RenderDocIntegration.html
// https://docs.unity3d.com/Manual/SL-ShaderPrograms.html

Shader "Unlit/SingleColor"
{
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

		interface material {
			bool scatter(in ray r, inout hit_record rec, inout vec3 attenuation, inout ray scattered);
		};

		class lambertian : material {
			void init(in vec3 a) { albedo = a; }
			bool scatter(in ray r_in, inout hit_record rec, inout vec3 attenuation, inout ray scattered) {
				vec3 target = rec.p + rec.normal + random_in_unit_sphere(rec.uv);
				ray s;
				s.init(rec.p, target - rec.p);
				scattered = s;
				attenuation = albedo;
				return true;
			}
			vec3 albedo;
		};

		class metal : material {
			void init(in vec3 a) { albedo = a; }
			bool scatter(in ray r_in, inout hit_record rec, inout vec3 attenuation, inout ray scattered) {
				vec3 reflected = reflect(unit_vector(r_in.direction()), rec.normal);
				ray s;
				s.init(rec.p, reflected);
				scattered = s;
				attenuation = albedo;
				return (dot(scattered.direction(), rec.normal) > 0);
			}
			vec3 albedo;
		};

		interface hitable {
			bool hit(ray r, float t_min, float t_max, inout hit_record rec, inout lambertian mat_ptr);
		};

		class sphere : hitable {
			void init(vec3 cen, float r, lambertian m) { center = cen; radius = r; mat = m; }
			bool hit(ray r, float t_min, float t_max, inout hit_record rec, inout lambertian mat_ptr) {
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
			lambertian mat;
		};

		class hitable_list : hitable {
			void init() { count = 0; }
			void add(sphere s) {
				items[count] = s;
				count++;
			}
			bool hit(ray r, float t_min, float t_max, inout hit_record rec, inout lambertian mat_ptr) {
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
			sphere  items[3];
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
			
			lambertian mat;
			mat.init(vec3(0, 0, 0));

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
					}
				}
				else {
					done = true;
					return color;
				}
			} while (!done && depth < 50);
			
			return color;
			
		}

		fixed4 frag(v2f i) : SV_Target
		{
		
		camera cam;
		cam.init();
		
		hitable_list world;
		world.init();

		lambertian m;
		m.init(vec3(1.0, 0.0, 0.0));

		sphere s;
		s.init(vec3(0, 0, -1), 0.5, m);
		world.add(s);
		m.init(vec3(0.0, 1.0, 0.0));
		s.init(vec3(0, -100.5, -1), 100, m);
		world.add(s);

		int samples = 70;
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