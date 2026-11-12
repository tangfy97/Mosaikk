import CoreGraphics
import CoreImage
import Foundation

/// Photo filters, made from Core Image building blocks.
public enum Filter: String, Codable, CaseIterable, Hashable, Sendable {
    case none, vivid, warm, cool, golden, fade, matte, film, chrome, instant, mono, noir, silver, sepia, dramatic, dusk

    public var title: String {
        switch self {
        case .none: String(localized: "Original")
        case .vivid: String(localized: "Vivid")
        case .warm: String(localized: "Warm")
        case .cool: String(localized: "Cool")
        case .golden: String(localized: "Golden")
        case .fade: String(localized: "Fade")
        case .matte: String(localized: "Matte")
        case .film: String(localized: "Film")
        case .chrome: String(localized: "Chrome")
        case .instant: String(localized: "Instant")
        case .mono: String(localized: "Mono")
        case .noir: String(localized: "Noir")
        case .silver: String(localized: "Silver")
        case .sepia: String(localized: "Sepia")
        case .dramatic: String(localized: "Dramatic")
        case .dusk: String(localized: "Dusk")
        }
    }
}

/// Applies a `Look` to an image. Used for the canvas and for export, so both match.
public enum LookRenderer {
    /// One shared context; Core Image contexts are thread-safe and expensive to create.
    static let context = CIContext(options: [.cacheIntermediates: false, .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])

    public static func apply(_ look: Look, to image: CGImage) -> CGImage {
        guard !look.isNeutral else { return image }
        let input = CIImage(cgImage: image)
        let extent = input.extent
        var output = filtered(input, look.filter)
        if look.filter != .none && look.intensity < 1 {
            output = output.applyingFilter("CIDissolveTransition", parameters: [
                kCIInputTargetImageKey: input, "inputTime": 1 - look.intensity,
            ])
        }
        output = adjusted(output, look, scale: max(extent.width, extent.height))
        let space = image.colorSpace?.model == .rgb ? image.colorSpace! : CGColorSpace(name: CGColorSpace.sRGB)!
        return context.createCGImage(output.cropped(to: extent), from: extent, format: .RGBA8, colorSpace: space) ?? image
    }

    static func filtered(_ image: CIImage, _ filter: Filter) -> CIImage {
        switch filter {
        case .none:
            return image
        case .vivid:
            return image.applyingFilter("CIVibrance", parameters: ["inputAmount": 0.6])
                .applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.08, kCIInputSaturationKey: 1.12])
        case .warm:
            return image.applyingFilter("CITemperatureAndTint", parameters: [
                "inputNeutral": CIVector(x: 6500, y: 0), "inputTargetNeutral": CIVector(x: 5200, y: 0)])
        case .cool:
            return image.applyingFilter("CITemperatureAndTint", parameters: [
                "inputNeutral": CIVector(x: 6500, y: 0), "inputTargetNeutral": CIVector(x: 8200, y: 0)])
        case .golden:
            return image.applyingFilter("CITemperatureAndTint", parameters: [
                "inputNeutral": CIVector(x: 6500, y: 0), "inputTargetNeutral": CIVector(x: 4800, y: 10)])
                .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.15, kCIInputContrastKey: 1.05])
                .applyingFilter("CIVignette", parameters: [kCIInputIntensityKey: 0.4, kCIInputRadiusKey: 1.6])
        case .fade:
            return image.applyingFilter("CIPhotoEffectFade")
        case .matte:
            return image.applyingFilter("CIToneCurve", parameters: [
                "inputPoint0": CIVector(x: 0, y: 0.12), "inputPoint1": CIVector(x: 0.25, y: 0.27),
                "inputPoint2": CIVector(x: 0.5, y: 0.5), "inputPoint3": CIVector(x: 0.75, y: 0.73),
                "inputPoint4": CIVector(x: 1, y: 0.92)])
                .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0.85])
        case .film:
            return image.applyingFilter("CIPhotoEffectTransfer")
        case .chrome:
            return image.applyingFilter("CIPhotoEffectChrome")
        case .instant:
            return image.applyingFilter("CIPhotoEffectInstant")
        case .mono:
            return image.applyingFilter("CIPhotoEffectMono")
        case .noir:
            return image.applyingFilter("CIPhotoEffectNoir")
        case .silver:
            return image.applyingFilter("CIPhotoEffectTonal")
                .applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.1, kCIInputBrightnessKey: 0.03])
        case .sepia:
            return image.applyingFilter("CISepiaTone", parameters: [kCIInputIntensityKey: 0.8])
        case .dramatic:
            return image.applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.3, kCIInputSaturationKey: 0.85])
                .applyingFilter("CIVignette", parameters: [kCIInputIntensityKey: 0.9, kCIInputRadiusKey: 1.4])
        case .dusk:
            return image.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1.05, y: 0, z: 0.05, w: 0), "inputGVector": CIVector(x: 0, y: 0.92, z: 0.05, w: 0),
                "inputBVector": CIVector(x: 0.05, y: 0, z: 1.08, w: 0), "inputBiasVector": CIVector(x: 0.02, y: 0, z: 0.04, w: 0)])
                .applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.06])
        }
    }

    static func adjusted(_ image: CIImage, _ look: Look, scale: Double) -> CIImage {
        var image = image
        let extent = image.extent
        if look.exposure != 0 {
            image = image.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: look.exposure * 1.5])
        }
        if look.brightness != 0 || look.contrast != 0 || look.saturation != 0 {
            image = image.applyingFilter("CIColorControls", parameters: [
                kCIInputBrightnessKey: look.brightness * 0.25,
                kCIInputContrastKey: 1 + look.contrast * (look.contrast > 0 ? 0.5 : 0.4),
                kCIInputSaturationKey: 1 + look.saturation,
            ])
        }
        if look.warmth != 0 || look.tint != 0 {
            image = image.applyingFilter("CITemperatureAndTint", parameters: [
                "inputNeutral": CIVector(x: 6500, y: 0),
                "inputTargetNeutral": CIVector(x: 6500 - look.warmth * 2500, y: look.tint * 60),
            ])
        }
        if look.highlights != 0 || look.shadows != 0 {
            image = image.applyingFilter("CIHighlightShadowAdjust", parameters: [
                "inputHighlightAmount": 1 + min(0, look.highlights),
                "inputShadowAmount": look.shadows,
            ])
            if look.highlights > 0 {
                image = image.applyingFilter("CIToneCurve", parameters: [
                    "inputPoint0": CIVector(x: 0, y: 0), "inputPoint1": CIVector(x: 0.25, y: 0.25),
                    "inputPoint2": CIVector(x: 0.5, y: 0.5), "inputPoint3": CIVector(x: 0.75, y: 0.75 + look.highlights * 0.12),
                    "inputPoint4": CIVector(x: 1, y: 1)])
            }
        }
        if look.hue != 0 {
            image = image.applyingFilter("CIHueAdjust", parameters: [kCIInputAngleKey: look.hue * .pi])
        }
        if look.sharpness > 0 {
            image = image.applyingFilter("CISharpenLuminance", parameters: [kCIInputSharpnessKey: look.sharpness * 1.2,
                                                                            kCIInputRadiusKey: max(1, scale / 1000) * 1.5])
        }
        if look.blur > 0 {
            image = image.clampedToExtent()
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: look.blur * scale * 0.02])
                .cropped(to: extent)
        }
        if look.vignette > 0 {
            image = image.applyingFilter("CIVignette", parameters: [kCIInputIntensityKey: look.vignette * 1.6,
                                                                    kCIInputRadiusKey: 1.2 + (1 - look.vignette)])
        }
        return image
    }

    /// A blurred, optionally darkened copy for photo backgrounds.
    public static func background(_ image: CGImage, blur: Double, dim: Double) -> CGImage {
        guard blur > 0 || dim != 0 else { return image }
        var output = CIImage(cgImage: image)
        let extent = output.extent
        if blur > 0 {
            output = output.clampedToExtent()
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: blur * max(extent.width, extent.height) * 0.05])
                .cropped(to: extent)
        }
        if dim != 0 {
            output = output.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: -dim * 2])
        }
        return context.createCGImage(output, from: extent, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)) ?? image
    }
}
