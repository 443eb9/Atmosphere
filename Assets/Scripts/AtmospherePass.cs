using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

public class AtmospherePass : ScriptableRenderPass
{
    private Material _material;
    private MaterialPropertyBlock _properties;

    public AtmospherePass(Material material, RenderPassEvent renderPassEvent)
    {
        _material = material;
        _properties = new MaterialPropertyBlock();
        this.renderPassEvent = renderPassEvent;
    }

    public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
    {
        var luts = frameData.GetOrCreate<AtmosphereLuts>();
        luts.Init(renderGraph);
        var resourcesData = frameData.Get<UniversalResourceData>();

        using (var builder =
               renderGraph.AddRasterRenderPass<Atmosphere.DummyPassData>(Atmosphere.PassNames.TransmittancePrecomputation, out _))
        {
            builder.SetRenderAttachment(luts.transmittanceLut, 0);

            builder.SetRenderFunc((Atmosphere.DummyPassData _, RasterGraphContext context) =>
            {
                context.cmd.DrawProcedural(
                    Matrix4x4.identity,
                    _material,
                    (int)Atmosphere.PassIndices.TransmittancePrecomputation,
                    MeshTopology.Triangles,
                    3,
                    1,
                    _properties
                );
            });
        }

        using (var builder =
               renderGraph.AddRasterRenderPass<Atmosphere.DummyPassData>(Atmosphere.PassNames.MultiScatteringPrecomputation, out _))
        {
            builder.UseTexture(luts.transmittanceLut);
            builder.SetRenderAttachment(luts.multiScatteringLut, 0);

            builder.SetRenderFunc((Atmosphere.DummyPassData _, RasterGraphContext context) =>
            {
                context.cmd.DrawProcedural(
                    Matrix4x4.identity,
                    _material,
                    (int)Atmosphere.PassIndices.MultiScatteringPrecomputation,
                    MeshTopology.Triangles,
                    3,
                    1,
                    _properties
                );
            });
        }

        using (var builder =
               renderGraph.AddRasterRenderPass<Atmosphere.DummyPassData>(Atmosphere.PassNames.SkyViewPrecomputation, out _))
        {
            builder.UseTexture(luts.transmittanceLut);
            builder.UseTexture(luts.multiScatteringLut);
            builder.SetRenderAttachment(luts.skyViewLut, 0);

            builder.SetRenderFunc((Atmosphere.DummyPassData _, RasterGraphContext context) =>
            {
                _properties.SetTexture(Atmosphere.ShaderProps.TransmittanceLut, luts.transmittanceLut);
                _properties.SetTexture(Atmosphere.ShaderProps.MultiScatteringLut, luts.multiScatteringLut);

                context.cmd.DrawProcedural(
                    Matrix4x4.identity,
                    _material,
                    (int)Atmosphere.PassIndices.SkyViewPrecomputation,
                    MeshTopology.Triangles,
                    3,
                    1,
                    _properties
                );
            });
        }

        using (var builder =
               renderGraph.AddRasterRenderPass<Atmosphere.DummyPassData>(Atmosphere.PassNames.SkyViewLookup, out _))
        {
            builder.UseTexture(luts.transmittanceLut);
            builder.UseTexture(luts.skyViewLut);
            builder.SetRenderAttachment(resourcesData.activeColorTexture, 0);

            builder.SetRenderFunc((Atmosphere.DummyPassData _, RasterGraphContext context) =>
            {
                _properties.SetTexture(Atmosphere.ShaderProps.TransmittanceLut, luts.transmittanceLut);
                _properties.SetTexture(Atmosphere.ShaderProps.SkyViewLut, luts.skyViewLut);

                context.cmd.DrawProcedural(
                    Matrix4x4.identity,
                    _material,
                    (int)Atmosphere.PassIndices.SkyViewLookup,
                    MeshTopology.Triangles,
                    3,
                    1,
                    _properties
                );
            });
        }
    }
}