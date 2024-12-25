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
               renderGraph.AddRasterRenderPass<Atmosphere.DummyPassData>(Atmosphere.PassNames.AerialPerspectivePrecomputation, out _))
        {
            builder.UseTexture(luts.transmittanceLut);
            builder.UseTexture(luts.multiScatteringLut);
            builder.SetRenderAttachment(luts.aerialPerspectiveLut, 0);
            builder.AllowPassCulling(false);

            builder.SetRenderFunc((Atmosphere.DummyPassData _, RasterGraphContext context) =>
            {
                _properties.SetTexture(Atmosphere.ShaderProps.TransmittanceLut, luts.transmittanceLut);
                _properties.SetTexture(Atmosphere.ShaderProps.MultiScatteringLut, luts.multiScatteringLut);

                context.cmd.DrawProcedural(
                    Matrix4x4.identity,
                    _material,
                    (int)Atmosphere.PassIndices.AerialPerspectivePrecomputation,
                    MeshTopology.Triangles,
                    3,
                    1,
                    _properties
                );
            });
        }

        using (var builder =
               renderGraph.AddRasterRenderPass<Atmosphere.DummyPassData>(Atmosphere.PassNames.AerialPerspectiveLookup, out _))
        {
            builder.UseTexture(luts.aerialPerspectiveLut);
            builder.SetRenderAttachment(resourcesData.activeColorTexture, 0);

            builder.SetRenderFunc((Atmosphere.DummyPassData _, RasterGraphContext context) =>
            {
                _properties.SetTexture(Atmosphere.ShaderProps.AerialPerspectiveLut, luts.aerialPerspectiveLut);

                context.cmd.DrawProcedural(
                    Matrix4x4.identity,
                    _material,
                    (int)Atmosphere.PassIndices.AerialPerspectiveLookup,
                    MeshTopology.Triangles,
                    3,
                    1,
                    _properties
                );
            });
        }
    }
}