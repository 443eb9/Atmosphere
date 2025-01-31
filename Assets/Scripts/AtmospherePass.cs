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
               renderGraph.AddRasterRenderPass<Sky.DummyPassData>(Sky.SkyPassNames.TransmittancePrecomputation, out _))
        {
            builder.SetRenderAttachment(luts.transmittanceLut, 0);

            builder.SetRenderFunc((Sky.DummyPassData _, RasterGraphContext context) =>
            {
                context.cmd.DrawProcedural(
                    Matrix4x4.identity,
                    _material,
                    (int)Sky.SkyPassIndices.TransmittancePrecomputation,
                    MeshTopology.Triangles,
                    3,
                    1,
                    _properties
                );
            });
        }

        using (var builder =
               renderGraph.AddRasterRenderPass<Sky.DummyPassData>(Sky.SkyPassNames.MultiScatteringPrecomputation, out _))
        {
            builder.UseTexture(luts.transmittanceLut);
            builder.SetRenderAttachment(luts.multiScatteringLut, 0);

            builder.SetRenderFunc((Sky.DummyPassData _, RasterGraphContext context) =>
            {
                context.cmd.DrawProcedural(
                    Matrix4x4.identity,
                    _material,
                    (int)Sky.SkyPassIndices.MultiScatteringPrecomputation,
                    MeshTopology.Triangles,
                    3,
                    1,
                    _properties
                );
            });
        }

        using (var builder =
               renderGraph.AddRasterRenderPass<Sky.DummyPassData>(Sky.SkyPassNames.SkyViewPrecomputation, out _))
        {
            builder.UseTexture(luts.transmittanceLut);
            builder.UseTexture(luts.multiScatteringLut);
            builder.SetRenderAttachment(luts.skyViewLut, 0);

            builder.SetRenderFunc((Sky.DummyPassData _, RasterGraphContext context) =>
            {
                _properties.SetTexture(Sky.SkyShaderExtraProps.TransmittanceLut, luts.transmittanceLut);
                _properties.SetTexture(Sky.SkyShaderExtraProps.MultiScatteringLut, luts.multiScatteringLut);

                context.cmd.DrawProcedural(
                    Matrix4x4.identity,
                    _material,
                    (int)Sky.SkyPassIndices.SkyViewPrecomputation,
                    MeshTopology.Triangles,
                    3,
                    1,
                    _properties
                );
            });
        }

        using (var builder =
               renderGraph.AddRasterRenderPass<Sky.DummyPassData>(Sky.SkyPassNames.SkyViewLookup, out _))
        {
            builder.UseTexture(luts.transmittanceLut);
            builder.UseTexture(luts.skyViewLut);
            builder.SetRenderAttachment(resourcesData.activeColorTexture, 0);

            builder.SetRenderFunc((Sky.DummyPassData _, RasterGraphContext context) =>
            {
                _properties.SetTexture(Sky.SkyShaderExtraProps.TransmittanceLut, luts.transmittanceLut);
                _properties.SetTexture(Sky.SkyShaderExtraProps.SkyViewLut, luts.skyViewLut);

                context.cmd.DrawProcedural(
                    Matrix4x4.identity,
                    _material,
                    (int)Sky.SkyPassIndices.SkyViewLookup,
                    MeshTopology.Triangles,
                    3,
                    1,
                    _properties
                );
            });
        }
    }
}