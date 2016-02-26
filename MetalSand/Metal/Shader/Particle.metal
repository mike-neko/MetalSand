//
//  Particle.metal
//  MetalParticle
//
//  Created by M.Ike on 2015/12/31.
//  Copyright © 2015年 M.Ike. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
using namespace simd;

#define M_PI  3.14159265358979323846264338327950288

constant float PI = float(M_PI);
constant float PI_30 = 30.f * PI / 180.f;

// パーティクルシェーダ

constant int TextureSquare = 512;

struct ParticleData {
    float4      position;
    float3      acc;
};

struct LaminateData {
    float       height;
};

struct VertexInOut {
    float4      position;
    float4      color;
};

struct VertexOut {
    float4      position        [[ position ]];
    float4      color;
    float       pointSize       [[ point_size ]];
};

inline int calcPosition(float2 uv) {
    uv = uv * TextureSquare + TextureSquare / 2;
    return (int)uv.x + (int)uv.y * TextureSquare;
}

inline float2 calcAngle(float angle) {
    float cosval;
    float sinval = sincos(angle, cosval);
    return float2(cosval, sinval) * 1.0f / TextureSquare;
}

kernel void particleCompute(device ParticleData* in [[ buffer(0) ]],
                            device LaminateData* laminate [[ buffer(1) ]],
                            device VertexInOut* out [[ buffer(2) ]],
                            uint2 id [[ thread_position_in_grid ]],
                            uint2 size [[ threads_per_grid ]]) {
    uint pos = id.x + id.y * size.x;
    ParticleData data = in[pos];

    if (data.acc.y > 0) {
        float height = data.position.y + data.acc.y;
        int base = calcPosition(data.position.xz);
        float base_h = laminate[base].height;
        if (height < base_h) {
            data.position.y = height;
        } else {
            int min_index = 0;
            float a = (rotate(id.y, id.x) % 360) * PI / 180.f;
            float2 xy[13];
            xy[0] = float2(0, 0);
            xy[1] = calcAngle(PI_30 * 1 + a);
            xy[2] = calcAngle(PI_30 * 2 + a);
            xy[3] = calcAngle(PI_30 * 3 + a);
            xy[4] = calcAngle(PI_30 * 4 + a);
            xy[5] = calcAngle(PI_30 * 5 + a);
            xy[6] = calcAngle(PI_30 * 6 + a);
            xy[7] = calcAngle(PI_30 * 7 + a);
            xy[8] = calcAngle(PI_30 * 8 + a);
            xy[9] = calcAngle(PI_30 * 9 + a);
            xy[10] = calcAngle(PI_30 * 10 + a);
            xy[11] = calcAngle(PI_30 * 11 + a);
            xy[12] = calcAngle(PI_30 * 12 + a);
            
            float h[13];
            h[0] = laminate[calcPosition(xy[0] + data.position.xz)].height;
            h[1] = laminate[calcPosition(xy[1] + data.position.xz)].height;
            h[2] = laminate[calcPosition(xy[2] + data.position.xz)].height;
            h[3] = laminate[calcPosition(xy[3] + data.position.xz)].height;
            h[4] = laminate[calcPosition(xy[4] + data.position.xz)].height;
            h[5] = laminate[calcPosition(xy[5] + data.position.xz)].height;
            h[6] = laminate[calcPosition(xy[6] + data.position.xz)].height;
            h[7] = laminate[calcPosition(xy[7] + data.position.xz)].height;
            h[8] = laminate[calcPosition(xy[8] + data.position.xz)].height;
            h[9] = laminate[calcPosition(xy[9] + data.position.xz)].height;
            h[10] = laminate[calcPosition(xy[10] + data.position.xz)].height;
            h[11] = laminate[calcPosition(xy[11] + data.position.xz)].height;
            h[12] = laminate[calcPosition(xy[12] + data.position.xz)].height;
            
            min_index = mix((float)min_index, 1.f, not(step(h[1], h[min_index])));
            min_index = mix((float)min_index, 2.f, not(step(h[2], h[min_index])));
            min_index = mix((float)min_index, 3.f, not(step(h[3], h[min_index])));
            min_index = mix((float)min_index, 4.f, not(step(h[4], h[min_index])));
            min_index = mix((float)min_index, 5.f, not(step(h[5], h[min_index])));
            min_index = mix((float)min_index, 6.f, not(step(h[6], h[min_index])));
            min_index = mix((float)min_index, 7.f, not(step(h[7], h[min_index])));
            min_index = mix((float)min_index, 8.f, not(step(h[8], h[min_index])));
            min_index = mix((float)min_index, 9.f, not(step(h[9], h[min_index])));
            min_index = mix((float)min_index, 10.f, not(step(h[10], h[min_index])));
            min_index = mix((float)min_index, 11.f, not(step(h[11], h[min_index])));
            min_index = mix((float)min_index, 12.f, not(step(h[12], h[min_index])));
            
            if (min_index == 0) {
                data.acc.y = 0;
                laminate[base].height = base_h - 0.002;
            } else {
                data.position.x += xy[min_index].x;
                data.position.z += xy[min_index].y;
            }
            data.position.y = base_h;
        }
        in[pos] = data;
    }

    VertexInOut result;
    result.position = data.position;
    result.color = float4(pos % 2, pos % 2 - 1, 1, 1);
    out[pos] = result;
}

vertex VertexOut particleVertex(device VertexInOut* in [[ buffer(0) ]],
                                constant float4x4& mvp [[ buffer(1) ]],
                                uint vid [[ vertex_id ]]) {

    float4 position = in[vid].position;
    float4 color = in[vid].color;
    
    VertexOut out;
    out.position = mvp * position;
    out.pointSize = 7 / out.position.w;     // 視錐台の拡大率
    out.color = color;
    
    return out;
}

fragment float4 particleFragment(VertexInOut in [[ stage_in ]]) {
    return in.color;
}
