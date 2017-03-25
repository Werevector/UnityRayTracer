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

		struct hit_record {
			float t;
			vec3 p;
			vec3 normal;
		};
				
		float rand_1_05(in float2 uv)
		{
			float2 noise = (frac(sin(dot(uv, float2(12.9898, 78.233)*2.0)) * 43758.5453));
			return abs(noise.x + noise.y) * 0.5;
		}

		#define drand rand_1_05(1)

		vec3 random_in_unit_disk() {
			vec3 p;
			do {
				p = 2.0*vec3(drand, drand, 0) - vec3(1, 1, 0);
			} while (dot(p, p) >= 1.0);
			return p;
		}

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
			vec3 origin() { return A; }
			vec3 direction() { return B; }
			vec3 A;
			vec3 B;
		};

		class material
		{
			void init(vec3 a) { albedo = a; }
			bool scatter(ray r_in, hit_record rec, vec3 attenuation, ray scattered)
			{
				vec3 target = rec.p + rec.normal + random_in_unit_sphere();
				scattered.init(rec.p, target - rec.p);
				attenuation = albedo;
				return true;
			}
			vec3 albedo;
		};

		class hitable
		{
			void init(vec3 cen, float r, material m) { center = cen; radius = r; mat = m; }
			bool hit(ray r, float t_min, float t_max, hit_record rec, material rmat)
			{
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
						rmat = mat;
						return true;
					}
				}
				return false;
			}

			vec3 center;
			float radius;
			material mat;
		};

		const float M_PI = 3.141592;
		class camera 
		{
			void init(vec3 lookfrom, vec3 lookat, vec3 vup, float vfov, float aspect, float aperture, float focus_dist) {
				lens_radius = aperture / 2;
				float theta = vfov*M_PI / 180;
				float half_height = tan(theta / 2);
				float half_width = aspect * half_height;
				origin = lookfrom;
				w = normalize(lookfrom - lookat);
				u = normalize(cross(vup, w));
				v = cross(w, u);

				lower_left_corner = origin - half_width*focus_dist*u - half_height*focus_dist*v - focus_dist*w;
				horizontal = 2 * half_width*focus_dist*u;
				vertical = 2 * half_height*focus_dist*v;
			}

			ray get_ray(float s, float t) {
				ray r;
				//vec3 rd = lens_radius*random_in_unit_disk();
				vec3 rd = lens_radius;
				//vec3 offset = u* rd.x + v *rd.y;
				vec3 offset = 0;
				r.init(origin + offset, lower_left_corner + s*horizontal + t*vertical - origin - offset);
				return r;
			}

			vec3 origin;
			vec3 lower_left_corner;
			vec3 horizontal;
			vec3 vertical;
			vec3 u, v, w;
			float lens_radius;
		};

		const int FLT_MAX = 10000;
		col3 color_from_ray(ray r, hitable world) 
		{
			col3 fcolor = col3(0,0,0);
			hit_record rec;
			material t_mat;
			
			ray current_ray = r;
			int depth = 0;
			const int max_depth = 3;
			
			if(world.hit(current_ray, 0.001, FLT_MAX, rec, t_mat))
			{
				/*ray scattered;
				vec3 attenuation;
				if (t_mat.scatter(r, rec, attenuation, scattered)) {
					fcolor * attenuation;
					current_ray = scattered;
					depth++;
					fcolor = col3(1, 0, 0);
				}
				
				do
				{
					if (world.hit(r, 0.001, FLT_MAX, rec, t_mat)) {
						ray scattered;
						vec3 attenuation;
						if (t_mat.scatter(r, rec, attenuation, scattered)) {
							fcolor * attenuation;
							current_ray = scattered;
							depth++;
						}
						else {
							fcolor * col3(0, 0, 0);
							depth++;
						}
					}
					else {
						depth++;
					}
				} while (depth < max_depth);*/
				fcolor = col3(1, 0, 0);
			}
			else
			{
				vec3 unit_direction = normalize(r.direction());
				float t = 0.5*(unit_direction.y + 1.0);
				fcolor = (1.0 - t)*vec3(1.0, 1.0, 1.0) + t*vec3(0.5, 0.7, 1.0);
				//fcolor = current_ray.direction() - current_ray.origin();
			}
			return fcolor;
		}


		fixed4 frag(v2f i) : SV_Target
		{

		material m;
		m.init(col3(1, 0, 0));

		hitable world;
		world.init(vec3(0,0,0), 0.1, m);
		
		vec3 lookfrom = vec3(2, 2, 2);
		vec3 lookat = vec3(0, 0, 0);
		float dist_to_focus = 10.0;
		float aperture = 0.1;
		camera cam;
		cam.init(lookfrom, lookat, vec3(0, 1, 0), 20, 8/16, aperture, dist_to_focus);

		ray r;
		//r.init(vec3(0, 0, 0), vec3(i.uv.x, i.uv.y, 0));
		r = cam.get_ray(i.uv.x, i.uv.y);
		col3 col = col3(0, 0, 0);
		col += color_from_ray(r, world);
		//col += r.direction();
		return fixed4(col,1);
		}
		
		ENDCG

}}}