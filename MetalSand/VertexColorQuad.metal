//
//  VertexColorQuad.metal
//  MetalSand
//
//  Created by M.Ike on 2016/01/18.
//  Copyright © 2016年 M.Ike. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

// 板ポリ描画用シェーダ

struct ShaderInOut {
    float4      position        [[ position ]];
    float4      color;
};

vertex ShaderInOut quadVertex(const device ShaderInOut* in [[ buffer(0) ]],
                              constant float4x4& mvp [[ buffer(1) ]],
                              uint vid [[ vertex_id ]]) {
    ShaderInOut out;
    out.position = mvp * in[vid].position;
    out.color = in[vid].color;
    return out;
}

fragment float4 quadFragment(ShaderInOut in [[ stage_in ]]) {
    return in.color;
}
