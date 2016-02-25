//
//  Matrix.swift
//  MetalModel
//
//  Created by M.Ike on 2015/12/30.
//  Copyright © 2015年 M.Ike. All rights reserved.
//

import UIKit
import simd

/* 行列周りのユーティリティ */
class Matrix {
    // 透視変換
    static func perspective(fovY fovY: Float, aspect: Float, nearZ: Float, farZ: Float) -> float4x4 {
        let yScale = 1 / simd.tan(fovY * 0.5)
        let xScale = yScale / aspect
        let zScale = farZ / (farZ - nearZ)
        
        return float4x4([
            float4(xScale, 0, 0, 0),
            float4(0, yScale, 0, 0),
            float4(0, 0, zScale, 1),
            float4(0, 0, -nearZ * zScale, 0)])
    }

    // 平行移動
    static func translation(x x:Float, y: Float, z: Float) -> float4x4 {
        var m = matrix_identity_float4x4
        m.columns.3 = vector_float4(x, y, z, 1)
        return float4x4(m)
    }
    
    // 回転
    static func rotation(radians radians: Float, x: Float, y: Float, z: Float) -> float4x4 {
        let v = vector_normalize(vector_float3(x, y, z))
        let cos = simd.cosf(radians)
        let cosp = 1 - cos
        let sin = simd.sinf(radians)

        return float4x4([
            float4(
                cos + cosp * v.x * v.x,
                cosp * v.x * v.y + v.z * sin,
                cosp * v.x * v.z - v.y * sin,
                0),
            float4(
                cosp * v.x * v.y - v.z * sin,
                cos + cosp * v.y * v.y,
                cosp * v.y * v.z + v.x * sin,
                0),
            float4(
                cosp * v.x * v.z + v.y * sin,
                cosp * v.y * v.z - v.x * sin,
                cos + cosp * v.z * v.z,
                0),
            float4(0, 0, 0, 1)])
    }

    // 拡大縮小
    static func scale(x x: Float, y: Float, z: Float) -> float4x4 {
        return float4x4(diagonal: float4(x, y, z, 1))
    }
    
    static func lookAt(camera camera: float3, target: float3, up: float3) -> float4x4 {
        let F = simd.normalize(target - camera)
        let S = simd.normalize(simd.cross(F, simd.normalize(up)))
        let U = simd.normalize(simd.cross(S, F))
        
        let result = float4x4([
            float4(S.x, S.y, S.z, 0),
            float4(U.x, U.y, U.z, 0),
            float4(-F.x, -F.y, -F.z, 0),
            float4(0, 0, 0, 1)])
        
        return result * translation(x: -camera.x, y: -camera.y, z: camera.z)
    }

}
