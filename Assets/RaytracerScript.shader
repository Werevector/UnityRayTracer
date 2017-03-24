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
// Upgrade NOTE: excluded shader from DX11, OpenGL ES 2.0 because it uses unsized arrays
#pragma exclude_renderers d3d11 gles
		
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

		#define drand rand_1_05(1)

		//TODO::IMPLEMENT DRAND
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
			} while (p.squared_length() >= 1.0);
			return p;
		}

		//CLASSES
		class ray
		{
			void init(vec3 a, vec3 b) { A = a; B = b; }
			vec3 point_at_parameter(float t) { return A + t*B; }
			vec3 A;
			vec3 B;
		};

		class material
		{
			void init(vec3 a) { albedo = a; }
			bool scatter(ray r_in, vec3 p, vec3 normal, material mat, vec3 attenuation, ray scattered)
			{
				vec3 target = p + normal + random_in_unit_sphere();
				scattered = ray(p, target - p);
				attenuation = albedo;
				return true;
			}
			vec3 albedo;
		};

		//struct hit_record {
		//	float t;
		//	vec3 p;
		//	vec3 normal;
		//	material mat_ptr;
		//}

		//sphere hitable
		class hitable
		{
			void init(vec3 cen, float r, material mat) { center = cen; radius = r; mat_ptr = mat; }
			bool hit(ray r, float t_min, float t_max, float rt, vec3 rp, vec3 rnormal, material rmat)
			{
				vec3 oc = r.origin() - center;
				float a = dot(r.direction(), r.direction());
				float b = dot(oc, r.direction());
				float c = dot(oc, oc) - radius*radius;
				float discriminant = b*b - a*c;

				if (discriminant > 0) {
					float temp = (-b - sqrt(b*b - a*c)) / a;
					if (temp < t_max && temp > t_min) {
						rt = temp;
						rp = r.point_at_parameter(rt);
						rnormal = (rp - center) / radius;
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

		class hitable_list
		{
			void init(hitable[], int n) { list = l; list_size = n; }
			bool hit(ray r, float t_min, float t_max, float rt, vec3 rp, vec3 rnormal, material rmat)
			{
				//hit_record temp_rec;
				float t_rt = 0.0;
				vec3 t_rp = vec3(0, 0, 0);
				vec3 t_rnormal = vec3(0, 1, 0);
				material t_mat;
				bool hit_anything = false;
				double closest_so_far = t_max;
				for (int i = 0; i < list_size; i++)
				{
					if (list[i].hit(r, t_min, closest_so_far, t_rt, t_rp, t_rnormal, t_mat)) {
						hit_anything = true;
						closest_so_far = temp_rec.t;
						rt = t_rt;
						rp = t_rp;
						rnormal = t_rnormal;
						rmat = t_mat;
					}
				}
				return hit_anything;
			}

			hitable[] list;
			int list_size;
		};
		//CLASSES_END

		

		FLT_MAX = 10000;
		col3 color_from_ray(ray r, hitable world, int depth) 
		{
			//hit_record rec;
			float t_rt = 0.0;
			vec3 t_rp = vec3(0, 0, 0);
			vec3 t_rnormal = vec3(0, 1, 0);
			material t_mat;
			
			if (world.hit(r, 0.001, FLT_MAX, t_rt, t_rp, t_rnormal, t_mat)) {
				ray scattered;
				vec3 attenuation;
				if (depth < 3 && t_mat.scatter(r, t_rt, t_rp, t_rnormal, t_mat, attenuation, scattered)) {
					return attenuation*color_from_ray(scattered, world, depth + 1);
				}
				else {
					return vec3(0, 0, 0);
				}
			}
			else {
				vec3 unit_direction = normalize(r.direction());
				float t = 0.5*(unit_direction.y() + 1.0);
				return (1.0 - t)*vec3(1.0, 1.0, 1.0) + t*vec3(0.5, 0.7, 1.0);
			}
		}

		fixed4 frag(v2f i) : SV_Target
		{
			/*hitable[] list = new hitable[1];
			hitable h;
			material m;
			m.init(vec3(1.0,0.0,0.0));
			h.init(vec3(0, 0.5, 0), 0.5, m);
			list[0] = h;
			hitable_list hlist;
			hlist.init(list, 1);
			
			ray r;
			r.init(vec3(0, 0, 0), vec3(i.uv.x, i.uv.y, 0));*/
			//vec3 p = r.point_at_parameter(2.0);
			col3 colorOut = col3(0,1,1);
			//colorOut = color_from_ray(r, hlist, 0);



			return fixed4(colorOut,1); 
		}
		
		ENDCG

}}}