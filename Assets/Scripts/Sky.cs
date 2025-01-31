using UnityEngine;
using UnityEngine.Rendering.Universal;

public class Sky : ScriptableRendererFeature
{
    public enum SkyPassIndices
    {
        RayMarchingAtmosphere,
        TransmittancePrecomputation,
        MultiScatteringPrecomputation,
        SkyViewPrecomputation,
        SkyViewLookup,
        RayMarchingSkyView,
        AerialPerspectivePrecomputation,
        AerialPerspectiveLookup,
    }

    public class SkyPassNames
    {
        public const string RayMarchingAtmosphere = "Ray Marching Atmosphere";
        public const string TransmittancePrecomputation = "Transmittance Precomputation";
        public const string MultiScatteringPrecomputation = "Multi-Scattering Precomputation";
        public const string SkyViewPrecomputation = "Sky View Precomputation";
        public const string SkyViewLookup = "Sky View Lookup";
        public const string RayMarchingSkyView = "Ray Marching Sky View";

        public const string AerialPerspectivePrecomputation = "Aerial Perspective Precomputation";
        public const string AerialPerspectiveLookup = "Aerial Perspective Lookup";
        
        // public const string 
    }

    public class SkyShaderExtraProps
    {
        public static int TransmittanceLut = Shader.PropertyToID("_TransmittanceLut");
        public static int MultiScatteringLut = Shader.PropertyToID("_MultiScatteringLut");
        public static int SkyViewLut = Shader.PropertyToID("_SkyViewLut");
        public static int AerialPerspectiveLut = Shader.PropertyToID("_AerialPerspectiveLut");
    }

    public class DummyPassData
    {
    }

    private AtmospherePass _atmoPass;
    private AerialPerspectivePass _aerialPass;
    private CloudPass _cloudPass;

    public Material material;

    public override void Create()
    {
        _atmoPass = new AtmospherePass(material, RenderPassEvent.BeforeRenderingShadows);
        _aerialPass = new AerialPerspectivePass(material, RenderPassEvent.AfterRenderingPostProcessing);
        _cloudPass = new CloudPass(material, RenderPassEvent.AfterRenderingPostProcessing);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(_atmoPass);
        renderer.EnqueuePass(_aerialPass);
        renderer.EnqueuePass(_cloudPass);
    }
}