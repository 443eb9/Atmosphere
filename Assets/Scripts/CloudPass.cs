using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

public class CloudPass : ScriptableRenderPass
{
    private Material _material;

    public CloudPass(Material material, RenderPassEvent renderPassEvent)
    {
        _material = material;
        this.renderPassEvent = renderPassEvent;
    }

    public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
    {
    }
}