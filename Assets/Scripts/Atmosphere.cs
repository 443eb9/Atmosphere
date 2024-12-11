using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

public class Atmosphere : ScriptableRendererFeature
{
    public enum AtmosphereComputation
    {
        BruteForceRayMarching,
        PrecomputedTransmittance,
        PrecomputedSkyView,
    }

    public class AtmospherePass : ScriptableRenderPass
    {
        public enum PassIndices
        {
            RayMarchingAtmosphere,
            TransmittancePrecomputation,
            SkyViewPrecomputation,
            SkyViewLookup,
            RayMarchingSkyView,
        }

        public class PassNames
        {
            public const string RayMarchingAtmosphere = "Ray Marching Atmosphere";
            public const string TransmittancePrecomputation = "Transmittance Precomputation";
            public const string SkyViewPrecomputation = "Sky View Precomputation";
            public const string SkyViewLookup = "Sky View Lookup";
            public const string RayMarchingSkyView = "Ray Marching Sky View";
        }

        public class ShaderProps
        {
            public static int TransmittanceLut = Shader.PropertyToID("_TransmittanceLut");
            public static int SkyViewLut = Shader.PropertyToID("_SkyViewLut");
        }

        public class DummyPassData
        {
        }

        private TextureHandle _transmittanceLut;
        private TextureHandle _skyViewLut;

        private Material _material;
        private MaterialPropertyBlock _properties;
        private AtmosphereComputation _approach;

        public AtmospherePass(Material material, RenderPassEvent renderPassEvent, AtmosphereComputation approach)
        {
            _material = material;
            _properties = new MaterialPropertyBlock();
            _approach = approach;
            this.renderPassEvent = renderPassEvent;
        }

        private void InitTextures(RenderGraph renderGraph, TextureHandle cameraTarget)
        {
            if (!_transmittanceLut.IsValid())
            {
                var desc = renderGraph.GetTextureDesc(cameraTarget);
                desc.width = 512;
                desc.height = 256;
                _transmittanceLut = renderGraph.CreateTexture(desc);
            }

            if (!_skyViewLut.IsValid())
            {
                var desc = renderGraph.GetTextureDesc(cameraTarget);
                desc.width = 512;
                desc.height = 256;
                _skyViewLut = renderGraph.CreateTexture(desc);
            }
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            var resourcesData = frameData.Get<UniversalResourceData>();

            if (_approach == AtmosphereComputation.BruteForceRayMarching)
            {
                using (var builder =
                       renderGraph.AddRasterRenderPass<DummyPassData>(PassNames.RayMarchingAtmosphere, out _))
                {
                    builder.SetRenderAttachment(resourcesData.activeColorTexture, 0);

                    builder.SetRenderFunc((DummyPassData _, RasterGraphContext context) =>
                    {
                        context.cmd.DrawProcedural(
                            Matrix4x4.identity,
                            _material,
                            (int)PassIndices.RayMarchingAtmosphere,
                            MeshTopology.Triangles,
                            3,
                            1,
                            _properties
                        );
                    });
                }

                return;
            }

            InitTextures(renderGraph, resourcesData.activeColorTexture);

            using (var builder =
                   renderGraph.AddRasterRenderPass<DummyPassData>(PassNames.TransmittancePrecomputation, out _))
            {
                builder.SetRenderAttachment(_transmittanceLut, 0);

                builder.SetRenderFunc((DummyPassData _, RasterGraphContext context) =>
                {
                    context.cmd.DrawProcedural(
                        Matrix4x4.identity,
                        _material,
                        (int)PassIndices.TransmittancePrecomputation,
                        MeshTopology.Triangles,
                        3,
                        1,
                        _properties
                    );
                });
            }

            if (_approach == AtmosphereComputation.PrecomputedSkyView)
            {
                using (var builder =
                       renderGraph.AddRasterRenderPass<DummyPassData>(PassNames.SkyViewPrecomputation, out _))
                {
                    builder.UseTexture(_transmittanceLut);
                    builder.SetRenderAttachment(_skyViewLut, 0);

                    builder.SetRenderFunc((DummyPassData _, RasterGraphContext context) =>
                    {
                        _properties.SetTexture(ShaderProps.TransmittanceLut, _transmittanceLut);

                        context.cmd.DrawProcedural(
                            Matrix4x4.identity,
                            _material,
                            (int)PassIndices.SkyViewPrecomputation,
                            MeshTopology.Triangles,
                            3,
                            1,
                            _properties
                        );
                    });
                }
            }

            if (_approach == AtmosphereComputation.PrecomputedTransmittance)
            {
                using (var builder =
                       renderGraph.AddRasterRenderPass<DummyPassData>(PassNames.RayMarchingSkyView, out _))
                {
                    builder.UseTexture(_transmittanceLut);
                    builder.SetRenderAttachment(resourcesData.activeColorTexture, 0);

                    builder.SetRenderFunc((DummyPassData _, RasterGraphContext context) =>
                    {
                        if (!_properties.HasTexture(ShaderProps.TransmittanceLut))
                            _properties.SetTexture(ShaderProps.TransmittanceLut, _transmittanceLut);

                        context.cmd.DrawProcedural(
                            Matrix4x4.identity,
                            _material,
                            (int)PassIndices.RayMarchingSkyView,
                            MeshTopology.Triangles,
                            3,
                            1,
                            _properties
                        );
                    });
                }

                return;
            }

            using (var builder =
                   renderGraph.AddRasterRenderPass<DummyPassData>(PassNames.SkyViewLookup, out _))
            {
                builder.UseTexture(_transmittanceLut);
                builder.UseTexture(_skyViewLut);
                builder.SetRenderAttachment(resourcesData.activeColorTexture, 0);

                builder.SetRenderFunc((DummyPassData _, RasterGraphContext context) =>
                {
                    _properties.SetTexture(ShaderProps.TransmittanceLut, _transmittanceLut);
                    _properties.SetTexture(ShaderProps.SkyViewLut, _skyViewLut);

                    context.cmd.DrawProcedural(
                        Matrix4x4.identity,
                        _material,
                        (int)PassIndices.SkyViewLookup,
                        MeshTopology.Triangles,
                        3,
                        1,
                        _properties
                    );
                });
            }
        }
    }

    private AtmospherePass _pass;

    public Material material;
    public RenderPassEvent renderPassEvent;
    public AtmosphereComputation approach;

    public override void Create()
    {
        _pass = new AtmospherePass(material, renderPassEvent, approach);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(_pass);
    }
}