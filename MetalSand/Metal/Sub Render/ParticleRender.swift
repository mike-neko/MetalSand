//
//  ParticleRender.swift
//  MetalParticle
//
//  Created by M.Ike on 2015/12/31.
//  Copyright © 2015年 M.Ike. All rights reserved.
//

import UIKit
import MetalKit

/* シェーダとやりとりする用 */
struct ParticleData {
    var position: float4
    var acc: float3
}

struct ParticleParameter {
    var count: float4
}

struct ParticleUniforms {
    var position: float4
    var color: float4
}

struct LaminateBuffer {
    var height: Float
}

// MARK: -
class ParticleRender: RenderProtocol, ComputeProtocol {
    static let Square = 512
    
    // Indices for buffer bind points.
    enum VertexBuffer: Int {
        case Position = 0
        case Parameter = 1
        func index() -> Int { return self.rawValue }
    }
    
    enum ComputeBuffer: Int {
        case Particle = 0
        case Parameter = 1
        case Laminate = 2
        case Output = 3
        func index() -> Int { return self.rawValue }
    }

    /* render */
    private var pipelineState: MTLRenderPipelineState! = nil
    private var depthState: MTLDepthStencilState! = nil
    
    private var drawBuffers: [MTLBuffer] = []
    private var renderBuffers: [MTLBuffer] = []
    
    private(set) var maxCount = ParticleRender.Square * ParticleRender.Square
    
    /* compute */
    private var computeState: MTLComputePipelineState! = nil
    
    private var particleBuffer: MTLBuffer! = nil

    private var threadgroupSize: MTLSize! = nil
    private var threadgroupCount: MTLSize! = nil
    
    private var parameter: ParticleParameter! = nil
    private var parameterBuffer: MTLBuffer! = nil
    
    private var laminateBuffer: MTLBuffer! = nil

    func setup() -> Bool {
        let device = Render.current.device
        let mtkView = Render.current.mtkView
        let library = Render.current.library
        
        guard let vertex_pg = library.newFunctionWithName("particleVertex") else { return false }
        guard let fragment_pg = library.newFunctionWithName("particleFragment") else { return false }
        
        // Create a reusable pipeline state
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "ParticlePipeLine"
        pipelineDescriptor.sampleCount = mtkView.sampleCount
        pipelineDescriptor.vertexFunction = vertex_pg
        pipelineDescriptor.fragmentFunction = fragment_pg
        pipelineDescriptor.colorAttachments[0].pixelFormat = .BGRA8Unorm
        pipelineDescriptor.colorAttachments[0].writeMask = .All
        
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
        
        // Create a particle buffer
        for _ in 0..<Render.BufferCount {
            drawBuffers += [device.newBufferWithLength(sizeof(ParticleUniforms) * maxCount, options: .CPUCacheModeDefaultCache)]
            renderBuffers += [device.newBufferWithLength(sizeof(float4x4), options: .CPUCacheModeDefaultCache)]
        }
        
        /* compute */
        guard let pg = library.newFunctionWithName("particleCompute") else { return false }
        do {
            computeState = try device.newComputePipelineStateWithFunction(pg)
        } catch {
            return false
        }
        
        particleBuffer = device.newBufferWithLength(sizeof(ParticleData) * maxCount, options: .CPUCacheModeDefaultCache)
        
        let p_buf = UnsafeMutablePointer<ParticleData>(particleBuffer.contents())
        for i in 0..<maxCount {
            let pat = ParticleData(
                position: float4(
                    Float(arc4random_uniform(UInt32(1000))) / 1000 * 0.003 + 0.0015,
                    -Float(i) * 0.003 - 0.1,
                    Float(arc4random_uniform(UInt32(1000))) / 1000 * 0.003 + 0.0015,
                    1),
                acc: float3(0, 9.8 * 1 / 60 / 10, 0)
            )
            p_buf.advancedBy(i).memory = pat
        }

        // スレッド数は32の倍数（64-192）
        threadgroupSize = MTLSize(width: ParticleRender.Square, height: ParticleRender.Square, depth: 1)
        threadgroupCount = MTLSize(width: 1, height: 1, depth: 1)
        
        /* parameter */
        parameterBuffer = device.newBufferWithLength(sizeof(ParticleParameter), options: .CPUCacheModeDefaultCache)
        parameter = ParticleParameter(count: float4())

        laminateBuffer = device.newBufferWithLength(sizeof(LaminateBuffer) * maxCount, options: .CPUCacheModeDefaultCache)
        let p_lam = UnsafeMutablePointer<LaminateBuffer>(laminateBuffer.contents())
        for i in 0..<maxCount {
            let lam = LaminateBuffer(height: 0)
            p_lam.advancedBy(i).memory = lam
        }
        
        return true
    }
    
    func compute(commandBuffer: MTLCommandBuffer) {
        let p_param = UnsafeMutablePointer<ParticleParameter>(parameterBuffer.contents())
        p_param.memory = parameter

        let computeEncoder = commandBuffer.computeCommandEncoder()
        
        computeEncoder.setComputePipelineState(computeState)
        computeEncoder.setBuffer(particleBuffer, offset: 0, atIndex: ComputeBuffer.Particle.index())
        computeEncoder.setBuffer(parameterBuffer, offset: 0, atIndex: ComputeBuffer.Parameter.index())
        computeEncoder.setBuffer(laminateBuffer, offset: 0, atIndex: ComputeBuffer.Laminate.index())
        computeEncoder.setBuffer(drawBuffers[Render.current.activeBufferNumber], offset: 0, atIndex: ComputeBuffer.Output.index())
        computeEncoder.dispatchThreadgroups(threadgroupSize, threadsPerThreadgroup: threadgroupCount)
        computeEncoder.endEncoding()
    }

    func update() {
        let ren = Render.current
        
        let p_pos_buf = UnsafeMutablePointer<float4x4>(renderBuffers[ren.activeBufferNumber].contents())
        var mat = p_pos_buf.memory
        mat = ren.projectionMatrix * ren.cameraMatrix
        p_pos_buf.memory = mat
    }
        
    func render(renderEncoder: MTLRenderCommandEncoder) {
        renderEncoder.pushDebugGroup("Particle")
        
        // Set context state.
        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setCullMode(.None)
        
        // Set the our per frame uniforms.
        let no = Render.current.activeBufferNumber
        renderEncoder.setVertexBuffer(drawBuffers[no], offset: 0, atIndex: VertexBuffer.Position.index())
        renderEncoder.setVertexBuffer(renderBuffers[no], offset: 0, atIndex: VertexBuffer.Parameter.index())
        renderEncoder.drawPrimitives(.Point, vertexStart: 0, vertexCount: maxCount)
        
        renderEncoder.popDebugGroup()
    }
    
    func postRender() {
    }

}

