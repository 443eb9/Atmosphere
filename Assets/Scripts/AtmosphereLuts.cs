using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;

public class AtmosphereLuts : ContextItem
{
    public TextureHandle transmittanceLut;
    public TextureHandle multiScatteringLut;
    public TextureHandle skyViewLut;
    public TextureHandle aerialPerspectiveLut;

    public void Init(RenderGraph renderGraph)
    {
        var desc = new TextureDesc(0, 0);
        desc.colorFormat = GraphicsFormat.B10G11R11_UFloatPack32;

        desc.width = 512;
        desc.height = 256;
        transmittanceLut = renderGraph.CreateTexture(desc);

        desc.width = 32;
        desc.height = 32;
        multiScatteringLut = renderGraph.CreateTexture(desc);

        desc.width = 512;
        desc.height = 256;
        skyViewLut = renderGraph.CreateTexture(desc);

        desc.width = 32 * 32;
        desc.height = 32;
        aerialPerspectiveLut = renderGraph.CreateTexture(desc);
    }

    public override void Reset()
    {
        transmittanceLut = TextureHandle.nullHandle;
        multiScatteringLut = TextureHandle.nullHandle;
        skyViewLut = TextureHandle.nullHandle;
        aerialPerspectiveLut = TextureHandle.nullHandle;
    }
}