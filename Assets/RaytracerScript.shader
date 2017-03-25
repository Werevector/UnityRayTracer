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

		const int FLT_MAX = 10000;
		col3 color_from_ray(ray r, hitable world, int depth) 
		{
			hit_record rec;
			material t_mat;
			
			if (world.hit(r, 0.001, FLT_MAX, rec, t_mat)) {
				ray scattered;
				vec3 attenuation;
				if (depth < 3 && t_mat.scatter(r, rec, attenuation, scattered)) {
					return attenuation*color_from_ray(scattered, world, depth + 1);
				}
				else {
					return vec3(0, 0, 0);
				}
			}
			else {
				vec3 unit_direction = normalize(r.direction());
				float t = 0.5*(unit_direction.y + 1.0);
				return (1.0 - t)*vec3(1.0, 1.0, 1.0) + t*vec3(0.5, 0.7, 1.0);
			}
		}

		fixed4 frag(v2f i) : SV_Target
		{
			col3 col = col3(1,1,0);

		return fixed4(col,1);
		}
		
		ENDCG

}}}