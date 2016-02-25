//
//  QuadRender.swift
//  MetalSand
//
//  Created by M.Ike on 2016/01/17.
//  Copyright © 2016年 M.Ike. All rights reserved.
//

import UIKit
import MetalKit

/* シェーダとやりとりする用 */
struct VertexData {
    var position: float4
    var color: float4
}


// MARK: -
class QuadRender: RenderProtocol {

    // Indices of vertex attribute in descriptor.
    enum VertexAttribute: Int {
        case Position = 0
        case Uniform = 1
        func index() -> Int { return self.rawValue }
    }

    private var pipelineState: MTLRenderPipelineState! = nil
    private var depthState: MTLDepthStencilState! = nil
    
    private var renderBuffer: MTLBuffer! = nil
    private var frameUniformBuffers: [MTLBuffer] = []
    
    // Uniforms
    var modelMatrix = float4x4(matrix_identity_float4x4)
    
    func setup() -> Bool {
        let device = Render.current.device
        let mtkView = Render.current.mtkView
        let library = Render.current.library
        
        /* render */
        guard let vertex_pg = library.newFunctionWithName("quadVertex") else { return false }
        guard let fragment_pg = library.newFunctionWithName("quadFragment") else { return false }
        
        // Create a reusable pipeline state
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "quadPipeLine"
        pipelineDescriptor.sampleCount = mtkView.sampleCount
        pipelineDescriptor.vertexFunction = vertex_pg
        pipelineDescriptor.fragmentFunction = fragment_pg
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        do {
            pipelineState = try device.newRenderPipelineStateWithDescriptor(pipelineDescriptor)
        } catch {
            return false
        }
        
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .Less
        depthDescriptor.depthWriteEnabled = true
        depthState = device.newDepthStencilStateWithDescriptor(depthDescriptor)
        
        let count = 6
        let verts = [
            float4(-0.5, 0, -0.5, 1),
            float4(0.5, 0, -0.5, 1),
            float4(-0.5, 0, 0.5, 1),
            float4(0.5, 0, -0.5, 1),
            float4(-0.5, 0, 0.5, 1),
            float4(0.5, 0, 0.5, 1),
        ]
        
        renderBuffer = device.newBufferWithLength(sizeof(VertexData) * count, options: .CPUCacheModeDefaultCache)
        let p_buf = UnsafeMutablePointer<VertexData>(renderBuffer.contents())
        let color = float4(0.5, 0.5, 0.5, 1)
        for i in 0..<count {
            let vertex = VertexData(position: verts[i], color: color)
            p_buf.advancedBy(i).memory = vertex
        }
        
        for _ in 0..<Render.BufferCount {
            frameUniformBuffers += [device.newBufferWithLength(sizeof(float4x4), options: .CPUCacheModeDefaultCache)]
        }
        
        modelMatrix = Matrix.scale(x: 0.5, y: 1, z: 0.5)
        
        return true
    }
    
    func update() {
        let ren = Render.current
        
        let p = UnsafeMutablePointer<float4x4>(frameUniformBuffers[ren.activeBufferNumber].contents())
        let mat = ren.projectionMatrix * ren.cameraMatrix * modelMatrix
        p.memory = mat
    }
    
    func render(renderEncoder: MTLRenderCommandEncoder) {
        renderEncoder.pushDebugGroup("Texture Quad")
        
        // Set context state.
        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.setRenderPipelineState(pipelineState)
        
        // Set the our per frame uniforms.
        let no = Render.current.activeBufferNumber
        renderEncoder.setVertexBuffer(renderBuffer, offset: 0, atIndex: VertexAttribute.Position.index())
        renderEncoder.setVertexBuffer(frameUniformBuffers[no], offset: 0, atIndex: VertexAttribute.Uniform.index())
        
        renderEncoder.drawPrimitives(.Triangle, vertexStart: 0, vertexCount: 6)
        
        renderEncoder.popDebugGroup()
    }

}

