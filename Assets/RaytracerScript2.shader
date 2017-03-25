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



		/////////////////////////////////////////////
		#define drand rand_1_05(float2(45.0f,25.0f))

		vec3 random_in_unit_sphere() {
			vec3 p;
			do {
				p = 2.0*vec3(drand, drand, drand) - vec3(1, 1, 1);
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

		float hit_sphere(vec3 center, float radius, ray r)
		{
			vec3 oc = r.origin() - center;
			float a = dot(r.direction(), r.direction());
			float b = 2.0 * dot(oc, r.direction());
			float c = dot(oc, oc) - radius*radius;
			float discriminant = b*b - 4*a*c;
			if (discriminant < 0) {
				return -1.0;
			}
			else {
				return (-b - sqrt(discriminant)) / (2.0*a);
			}
		}

		struct hit_record {
			float t;
			vec3 p;
			vec3 normal;
		};

		interface hitable {
			bool hit(ray r, float t_min, float t_max, inout hit_record rec);
		};

		class sphere : hitable {
			void init(vec3 cen, float r) { center = cen; radius = r; }
			bool hit(ray r, float t_min, float t_max, inout hit_record rec) {
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
						return true;
					}
					temp = (-b + sqrt(b*b - a*c)) / a;
					if (temp < t_max && temp > t_min) {
						rec.t = temp;
						rec.p = r.point_at_parameter(rec.t);
						rec.normal = (rec.p - center) / radius;
						return true;
					}
				}
				return false;
			}

			vec3 center;
			float radius;
		};

		class hitable_list : hitable {
			void init() { count = 0; }
			void add(sphere s) {
				items[count] = s;
				count++;
			}
			bool hit(ray r, float t_min, float t_max, inout hit_record rec) {
				hit_record temp_rec;
				temp_rec.t = 0;
				temp_rec.p = vec3(0, 0, 0);
				temp_rec.normal = vec3(0, 0, 0);

				bool hit_anything = false;
				float closest_so_far = t_max;
				for (int i = 0; i < count; i++) {
					if (items[i].hit(r, t_min, closest_so_far, temp_rec)) {
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
			int		index[2];
			sphere  items[2];
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

		
		col3 color(ray r, hitable_list world) 
		{
			const float MAXFLOAT = 1.7014116317805962808001687976863 * pow(10, 38);
			hit_record rec;
			rec.t = 0;
			rec.p = vec3(0, 0, 0);
			rec.normal = vec3(0, 0, 0);

			if (world.hit(r, 0.0, MAXFLOAT, rec)) {
				vec3 target = rec.p + rec.normal + random_in_unit_sphere();
				ray rb;
				rb.init(rec.p, target - rec.p);
				return 0.5*color(rb, world);
			}
			else {
				vec3 unit_direction = unit_vector(r.direction());
				float t = 0.5*(unit_direction.y + 1.0);
				return (1.0 - t)*vec3(1.0, 1.0, 1.0) + t*vec3(0.5, 0.7, 1.0);
			}
		}

		fixed4 frag(v2f i) : SV_Target
		{
		
		
		camera cam;
		cam.init();
		
		hitable_list world;
		world.init();
		sphere s;
		s.init(vec3(0, 0, -1), 0.5);
		world.add(s);
		s.init(vec3(0, -100.5, -1), 100);
		world.add(s);
		
		ray r = cam.get_ray(i.uv.x, i.uv.y);
		col3 col = color(r, world);
		return fixed4(col,1);
		}
		
		ENDCG

}}}