using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

public class AerialPerspectivePass : ScriptableRenderPass
{
    private Material _material;
    private MaterialPropertyBlock _properties;

    public AerialPerspectivePass(Material material, RenderPassEvent renderPassEvent)
    {
        _material = material;
        _properties = new MaterialPropertyBlock();
        this.renderPassEvent = renderPassEvent;
    }
    
    public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
    {
        var luts = frameData.GetOrCreate<AtmosphereLuts>();
        // Don't need to init. This pass runs after AtmospherePass, which inits textures.
        // luts.Init(renderGraph);
        var resourcesData = frameData.Get<UniversalResourceData>();
        
        using (var builder =
               renderGraph.AddRasterRenderPass<Sky.DummyPassData>(Sky.SkyPassNames.AerialPerspectivePrecomputation, out _))
        {
            builder.UseTexture(luts.transmittanceLut);
            builder.UseTexture(luts.multiScatteringLut);
            builder.SetRenderAttachment(luts.aerialPerspectiveLut, 0);
            builder.AllowPassCulling(false);

            builder.SetRenderFunc((Sky.DummyPassData _, RasterGraphContext context) =>
            {
                _properties.SetTexture(Sky.SkyShaderExtraProps.TransmittanceLut, luts.transmittanceLut);
                _properties.SetTexture(Sky.SkyShaderExtraProps.MultiScatteringLut, luts.multiScatteringLut);

                context.cmd.DrawProcedural(
                    Matrix4x4.identity,
                    _material,
                    (int)Sky.SkyPassIndices.AerialPerspectivePrecomputation,
                    MeshTopology.Triangles,
                    3,
                    1,
                    _properties
                );
            });
        }

        using (var builder =
               renderGraph.AddRasterRenderPass<Sky.DummyPassData>(Sky.SkyPassNames.AerialPerspectiveLookup, out _))
        {
            builder.UseTexture(luts.aerialPerspectiveLut);
            builder.SetRenderAttachment(resourcesData.activeColorTexture, 0);

            builder.SetRenderFunc((Sky.DummyPassData _, RasterGraphContext context) =>
            {
                _properties.SetTexture(Sky.SkyShaderExtraProps.AerialPerspectiveLut, luts.aerialPerspectiveLut);

                context.cmd.DrawProcedural(
                    Matrix4x4.identity,
                    _material,
                    (int)Sky.SkyPassIndices.AerialPerspectiveLookup,
                    MeshTopology.Triangles,
                    3,
                    1,
                    _properties
                );
            });
        }
    }
}