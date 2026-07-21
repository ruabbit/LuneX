#include <metal_stdlib>

using namespace metal;

namespace lunex {

constant uint matrixRec2020 = 1;
constant uint transferPQ = 1;
constant uint gamutSRGB = 0;
constant uint gamutDisplayP3 = 1;
constant uint gamutRec2020 = 2;
constant uint mappingEDR = 1;

constant float rec709Alpha = 1.099296826809442f;
constant float rec709Beta = 0.018053968510807f;
constant float referenceWhiteNits = 100.0f;
constant float pqPeakLuminanceNits = 10000.0f;
constant float shoulderStrength = 4.0f;

struct VideoUniforms {
    uint inputBitDepth;
    uint yCbCrMatrix;
    uint transferFunction;
    uint outputGamut;
    uint mappingMode;
    float sourcePeakNits;
    float currentHeadroom;
    float reserved;
};

struct GeometryUniforms {
    float textureOriginX;
    float textureOriginY;
    float textureScaleX;
    float textureScaleY;
};

struct RasterData {
    float4 position [[position]];
    float2 textureCoordinate;
};

float3 normalizeVideoRange(float luma, float2 chroma, uint bitDepth) {
    if (bitDepth == 10) {
        constexpr float unorm16Maximum = 65535.0f;
        constexpr float storageScale = 64.0f;
        float lumaCode = luma * unorm16Maximum / storageScale;
        float2 chromaCode = chroma * unorm16Maximum / storageScale;
        return float3(
            (lumaCode - 64.0f) / 876.0f,
            (chromaCode.x - 512.0f) / 896.0f,
            (chromaCode.y - 512.0f) / 896.0f
        );
    }
    float lumaCode = luma * 255.0f;
    float2 chromaCode = chroma * 255.0f;
    return float3(
        (lumaCode - 16.0f) / 219.0f,
        (chromaCode.x - 128.0f) / 224.0f,
        (chromaCode.y - 128.0f) / 224.0f
    );
}

float3 nonlinearRGB(float3 yCbCr, uint matrix) {
    float y = yCbCr.x;
    float cb = yCbCr.y;
    float cr = yCbCr.z;
    if (matrix == matrixRec2020) {
        return float3(
            y + 1.4746f * cr,
            y - 0.164553f * cb - 0.571353f * cr,
            y + 1.8814f * cb
        );
    }
    return float3(
        y + 1.5748f * cr,
        y - 0.187324f * cb - 0.468124f * cr,
        y + 1.8556f * cb
    );
}

float decodeRec709Component(float encoded) {
    float breakpoint = 4.5f * rec709Beta;
    return encoded < breakpoint
        ? encoded / 4.5f
        : pow((encoded + rec709Alpha - 1.0f) / rec709Alpha, 1.0f / 0.45f);
}

float3 decodeRec709(float3 encoded) {
    return float3(
        decodeRec709Component(encoded.x),
        decodeRec709Component(encoded.y),
        decodeRec709Component(encoded.z)
    );
}

float decodePQComponent(float encoded) {
    constexpr float m1 = 2610.0f / 16384.0f;
    constexpr float m2 = 2523.0f / 32.0f;
    constexpr float c1 = 3424.0f / 4096.0f;
    constexpr float c2 = 2413.0f / 128.0f;
    constexpr float c3 = 2392.0f / 128.0f;
    float powered = pow(clamp(encoded, 0.0f, 1.0f), 1.0f / m2);
    float numerator = max(powered - c1, 0.0f);
    float denominator = max(c2 - c3 * powered, numeric_limits<float>::min());
    return pqPeakLuminanceNits * pow(numerator / denominator, 1.0f / m1);
}

float3 decodePQToNits(float3 encoded) {
    return float3(
        decodePQComponent(encoded.x),
        decodePQComponent(encoded.y),
        decodePQComponent(encoded.z)
    );
}

float3 rgbToXYZ(float3 rgb, uint gamut) {
    if (gamut == gamutDisplayP3) {
        return float3(
            dot(float3(0.4865709486f, 0.2656676932f, 0.1982172852f), rgb),
            dot(float3(0.2289745641f, 0.6917385218f, 0.0792869141f), rgb),
            dot(float3(0.0f, 0.0451133819f, 1.0439443689f), rgb)
        );
    }
    if (gamut == gamutRec2020) {
        return float3(
            dot(float3(0.6369580483f, 0.1446169036f, 0.1688809752f), rgb),
            dot(float3(0.2627002120f, 0.6779980715f, 0.0593017165f), rgb),
            dot(float3(0.0f, 0.0280726930f, 1.0609850577f), rgb)
        );
    }
    return float3(
        dot(float3(0.4123907993f, 0.3575843394f, 0.1804807884f), rgb),
        dot(float3(0.2126390059f, 0.7151686788f, 0.0721923154f), rgb),
        dot(float3(0.0193308187f, 0.1191947798f, 0.9505321522f), rgb)
    );
}

float3 xyzToRGB(float3 xyz, uint gamut) {
    if (gamut == gamutDisplayP3) {
        return float3(
            dot(float3(2.4934969119f, -0.9313836179f, -0.4027107845f), xyz),
            dot(float3(-0.8294889696f, 1.7626640603f, 0.0236246858f), xyz),
            dot(float3(0.0358458302f, -0.0761723893f, 0.9568845240f), xyz)
        );
    }
    if (gamut == gamutRec2020) {
        return float3(
            dot(float3(1.7166511880f, -0.3556707838f, -0.2533662814f), xyz),
            dot(float3(-0.6666843518f, 1.6164812366f, 0.0157685458f), xyz),
            dot(float3(0.0176398574f, -0.0427706133f, 0.9421031212f), xyz)
        );
    }
    return float3(
        dot(float3(3.2409699419f, -1.5373831776f, -0.4986107603f), xyz),
        dot(float3(-0.9692436363f, 1.8759675015f, 0.0415550574f), xyz),
        dot(float3(0.0556300797f, -0.2039769589f, 1.0569715142f), xyz)
    );
}

float3 convertLinearGamut(float3 rgb, uint sourceGamut, uint targetGamut) {
    return sourceGamut == targetGamut ? rgb : xyzToRGB(rgbToXYZ(rgb, sourceGamut), targetGamut);
}

float mapLuminance(float luminanceNits, float sourcePeakNits, float headroom) {
    float luminance = max(luminanceNits, 0.0f);
    if (luminance <= referenceWhiteNits) {
        return luminance / referenceWhiteNits;
    }
    float sourcePeak = clamp(sourcePeakNits, referenceWhiteNits, pqPeakLuminanceNits);
    float currentHeadroom = clamp(headroom, 1.0f, 64.0f);
    float boundedLuminance = min(luminance, sourcePeak);
    float direct = boundedLuminance / referenceWhiteNits;
    float sourceHeadroom = sourcePeak / referenceWhiteNits;
    if (sourceHeadroom <= currentHeadroom) {
        return min(direct, currentHeadroom);
    }
    if (currentHeadroom <= 1.0f) {
        return 1.0f;
    }
    float progress = (boundedLuminance - referenceWhiteNits)
        / (sourcePeak - referenceWhiteNits);
    float compression = (sourceHeadroom - currentHeadroom) / (sourceHeadroom - 1.0f);
    float strength = shoulderStrength * compression;
    float shoulder = strength > numeric_limits<float>::epsilon()
        ? log(1.0f + strength * progress) / log(1.0f + strength)
        : progress;
    float result = 1.0f + (currentHeadroom - 1.0f) * shoulder;
    return clamp(min(result, direct), 1.0f, currentHeadroom);
}

float3 mapLuminance(float3 luminanceNits, float sourcePeakNits, float headroom) {
    return float3(
        mapLuminance(luminanceNits.x, sourcePeakNits, headroom),
        mapLuminance(luminanceNits.y, sourcePeakNits, headroom),
        mapLuminance(luminanceNits.z, sourcePeakNits, headroom)
    );
}

} // namespace lunex

vertex lunex::RasterData lunex_hdr_video_vertex(
    uint vertexID [[vertex_id]],
    constant lunex::GeometryUniforms &geometry [[buffer(0)]]) {
    constexpr float2 positions[] = {
        float2(-1.0f, -1.0f),
        float2(3.0f, -1.0f),
        float2(-1.0f, 3.0f)
    };
    constexpr float2 textureCoordinates[] = {
        float2(0.0f, 1.0f),
        float2(2.0f, 1.0f),
        float2(0.0f, -1.0f)
    };
    lunex::RasterData output;
    output.position = float4(positions[vertexID], 0.0f, 1.0f);
    output.textureCoordinate = float2(
        geometry.textureOriginX
            + textureCoordinates[vertexID].x * geometry.textureScaleX,
        geometry.textureOriginY
            + textureCoordinates[vertexID].y * geometry.textureScaleY
    );
    return output;
}

fragment float4 lunex_hdr_video_fragment(
    lunex::RasterData input [[stage_in]],
    texture2d<float, access::sample> lumaTexture [[texture(0)]],
    texture2d<float, access::sample> chromaTexture [[texture(1)]],
    constant lunex::VideoUniforms &uniforms [[buffer(0)]]) {
    constexpr sampler videoSampler(
        coord::normalized,
        address::clamp_to_edge,
        filter::linear
    );
    float luma = lumaTexture.sample(videoSampler, input.textureCoordinate).r;
    float2 chroma = chromaTexture.sample(videoSampler, input.textureCoordinate).rg;
    float3 yCbCr = lunex::normalizeVideoRange(luma, chroma, uniforms.inputBitDepth);
    float3 nonlinear = lunex::nonlinearRGB(yCbCr, uniforms.yCbCrMatrix);
    float3 output;
    if (uniforms.transferFunction == lunex::transferPQ) {
        float3 nits = lunex::decodePQToNits(nonlinear);
        float3 converted = lunex::convertLinearGamut(
            nits,
            lunex::gamutRec2020,
            uniforms.outputGamut
        );
        output = lunex::mapLuminance(
            max(converted, 0.0f),
            uniforms.sourcePeakNits,
            uniforms.mappingMode == lunex::mappingEDR
                ? uniforms.currentHeadroom
                : 1.0f
        );
    } else {
        float3 linear = lunex::decodeRec709(nonlinear);
        output = lunex::convertLinearGamut(
            linear,
            lunex::gamutSRGB,
            uniforms.outputGamut
        );
        output = clamp(output, 0.0f, 1.0f);
    }
    if (!all(isfinite(output))) {
        output = float3(0.0f);
    }
    return float4(output, 1.0f);
}
