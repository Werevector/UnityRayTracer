using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SceneScript : MonoBehaviour {

    Material rayMaterial;
    float x = 0;
	// Use this for initialization
	void Start () {
        rayMaterial = GetComponent<Renderer>().material;
        
    }

    void Update()
    {
        x += 0.1f;
        Vector4 pos = rayMaterial.GetVector("_SpherePos");
        pos.y = (Mathf.Abs((float)Mathf.Sin(x / 1) * 0.5f)) + 1;
        rayMaterial.SetVector("_SpherePos", pos);
    }
}
