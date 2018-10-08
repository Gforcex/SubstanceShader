using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class SubstanceSetting : MonoBehaviour
{
    public enum ShadowType { None, Lightweight, Average, Intensive }
    public enum NormalType { Disable, Combine, Replace }
    public enum AoType { Disable = 0, Replace = 1, Multiply = 4}
    public enum EnvType { Cube, Equirectangular }
    public enum SpecularMode { Substance, UE4, RealTime }

    public SpecularMode specularMode = SpecularMode.Substance;

    [Header("Enviroment")]
    public EnvType envMode = EnvType.Equirectangular;
    public Texture2D EnvironmentMap;
    public Cubemap EnvironmentCubeMap;
    [Range(0, 1)]
    public float EnvironmentRotation = 0;
    [Range(0, 4)]
    public float EnvironmentExposure = 1;

    [Header("Shadows")]
    public ShadowType shadow = ShadowType.None;

    [Header("Common Parameters")]
    [Range(1, 256)]
    public int SamplesQuality = 16;
    [Range(0, 10)]
    public float horizonFade = 1;
    [Range(0.01f, 10)]
    public float HeightForce = 1;

    [Header("ao")]
    public AoType aoType = AoType.Disable;
    [Header("SSS")]
    public bool enableSSS = false;
    public float sssSceneScale = 1;
    public int sssType = 0; //Translucent": 0, "Skin": 1

    [Header("Normal")]
    public bool DetialNormal = false;
    public bool NormalYCoeff = false;
    public NormalType NoramlBlending = NormalType.Disable;
    public bool Facing = false;
    [Range(0, 3)]
    public float GlobalRoughness = 1;

    Prefilter irradPrefilter = new Prefilter();
    bool isPrefilter = false;
    void initIrradMat()
    {
        if(!isPrefilter)
        {
            if (envMode == EnvType.Equirectangular)
                irradPrefilter.PrefilterEnvMap(EnvironmentMap);
            else
                irradPrefilter.PrefilterCube(EnvironmentCubeMap);
            isPrefilter = true;
        }
    }

    private void SetMaterialInfo()
    {
        if (specularMode == SpecularMode.UE4)
        {
            Shader.EnableKeyword("_UE4BRDF");
            Shader.DisableKeyword("_SUBSTANCE");
            Shader.DisableKeyword("_REALTIME");
        }
        else if (specularMode == SpecularMode.Substance)
        {
            Shader.DisableKeyword("_UE4BRDF");
            Shader.EnableKeyword("_SUBSTANCE");
            Shader.DisableKeyword("_REALTIME");
        }            
        else
        {
            Shader.DisableKeyword("_UE4BRDF");
            Shader.DisableKeyword("_SUBSTANCE");
            Shader.EnableKeyword("_REALTIME");
        }
        Shader.SetGlobalMatrix("irrad_mat_red", irradPrefilter.GetMatrix(0));
        Shader.SetGlobalMatrix("irrad_mat_green", irradPrefilter.GetMatrix(1));
        Shader.SetGlobalMatrix("irrad_mat_blue", irradPrefilter.GetMatrix(2));
        Shader.SetGlobalTexture("environment_texture", EnvironmentMap);
        Shader.SetGlobalTexture("environment_texture_cube", EnvironmentCubeMap);
        Shader.SetGlobalFloat("environment_rotation", EnvironmentRotation);
        Shader.SetGlobalFloat("environment_exposure", EnvironmentExposure);

        int maxLod = 8;
        if (envMode == EnvType.Cube)
            maxLod = (int)(Mathf.Log(EnvironmentCubeMap.width) / Mathf.Log(2));
            //maxLod = EnvironmentCubeMap.mipmapCount;
        else
            maxLod = (int)(Mathf.Log(Mathf.Min(EnvironmentMap.height, EnvironmentMap.width)) / Mathf.Log(2));
            //maxLod = EnvironmentMap.mipmapCount;

        Shader.SetGlobalInt("maxLod", maxLod);
        Shader.SetGlobalInt("nbSamples", SamplesQuality);
        Shader.SetGlobalFloat("horizonFade", horizonFade);
        Shader.SetGlobalFloat("height_force", HeightForce);

        Shader.SetGlobalInt("channel_ao_is_set", aoType == AoType.Disable ? 0 : 1 );
        Shader.SetGlobalInt("ao_blending_mode", (int)aoType);

        Shader.SetGlobalInt("sssEnabled", enableSSS ? 1 : 0);
        Shader.SetGlobalFloat("sssSceneScale", sssSceneScale);

        int normalBlend = 0;
        switch(NoramlBlending)
        {
            case NormalType.Disable: normalBlend = 0; break;
            case NormalType.Combine: normalBlend = 1; break;
            case NormalType.Replace: normalBlend = 26; break;
        }

        Shader.SetGlobalInt("channel_normal_is_set", DetialNormal ? 1 : 0);
        Shader.SetGlobalInt("normal_blending_mode", normalBlend);
        Shader.SetGlobalFloat("base_normal_y_coeff", NormalYCoeff ? 1 : -1);
        Shader.SetGlobalInt("facing", Facing? 0 : 1 );
        Shader.SetGlobalFloat("global_roughness", GlobalRoughness);

        Shader.SetGlobalInt("is_perspective", Camera.main.orthographic ? 0 : 1);
        Shader.SetGlobalInt("is2DView", false ? 0 : 1);
    }

    private void OnEnable()
    {
        initIrradMat();
        SetMaterialInfo();
    }

    private void OnDestroy()
    {
        isPrefilter = false;
    }

    private void OnValidate()
    {
        isPrefilter = false;
        SetMaterialInfo();
    }
}
