//
//  ChatBackgroundAppearance.swift
//  TalkMVP
//

import SwiftUI
import ImageIO
import UIKit

/// Light or dark controls for a chat's own background. A bright gradient or photo under the
/// dark appearance's gray text (reply suggestions, the message field, times) left it hard to
/// read, so a chat with its own background takes the appearance whose text stands out on it.
/// The line between the two is WCAG's: above a relative luminance of about 0.179, black text
/// has more contrast than white.
nonisolated enum ChatBackgroundAppearance {
    /// Where white and black text have the same contrast ratio on a background.
    static let threshold = 0.179

    /// WCAG relative luminance of an sRGB color, components from 0 to 1.
    static func relativeLuminance(red: Double, green: Double, blue: Double) -> Double {
        func linear(_ c: Double) -> Double {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    static func colorScheme(forLuminance luminance: Double) -> ColorScheme {
        luminance > threshold ? .light : .dark
    }

    /// A solid color's appearance; nil when the hex can't be read.
    static func colorScheme(color hex: String?) -> ColorScheme? {
        luminance(hex: hex).map(colorScheme(forLuminance:))
    }

    /// A gradient's appearance, by the average of its two ends.
    static func colorScheme(gradientFrom start: String?, to end: String?) -> ColorScheme? {
        guard let first = luminance(hex: start), let second = luminance(hex: end) else { return nil }
        return colorScheme(forLuminance: (first + second) / 2)
    }

    /// A photo's appearance, by the average luminance of a small thumbnail; nil when it can't
    /// be decoded.
    static func colorScheme(imageData: Data) -> ColorScheme? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceThumbnailMaxPixelSize: 32,
              ] as CFDictionary)
        else { return nil }

        // Redraw into a known RGBA layout before reading the pixels.
        let width = thumbnail.width, height = thumbnail.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else { return false }
            context.draw(thumbnail, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn, width * height > 0 else { return nil }

        var total = 0.0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            total += relativeLuminance(
                red: Double(pixels[index]) / 255,
                green: Double(pixels[index + 1]) / 255,
                blue: Double(pixels[index + 2]) / 255
            )
        }
        return colorScheme(forLuminance: total / Double(width * height))
    }

    /// Reads "#RGB", "#RRGGBB" or "#AARRGGBB", as `Color(hex:)` does, ignoring alpha.
    private static func luminance(hex: String?) -> Double? {
        guard let hex else { return nil }
        let digits = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard let value = UInt64(digits, radix: 16) else { return nil }
        let red, green, blue: UInt64
        switch digits.count {
        case 3: (red, green, blue) = ((value >> 8) * 17, (value >> 4 & 0xF) * 17, (value & 0xF) * 17)
        case 6, 8: (red, green, blue) = (value >> 16 & 0xFF, value >> 8 & 0xFF, value & 0xFF)
        default: return nil
        }
        return relativeLuminance(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }
}

extension ChatRoom {
    /// What `backgroundColorScheme` depends on, to recompute it only when the background changes.
    var backgroundAppearanceKey: String {
        [backgroundType, backgroundColor ?? "", gradientStartColor ?? "", gradientEndColor ?? "",
         backgroundImageData.map { "\($0.count)-\($0.hashValue)" } ?? ""].joined(separator: "|")
    }

    /// The appearance the chat's own background calls for, or nil for the default background,
    /// which follows the app's appearance. Decodes a photo, so read it once per background.
    var backgroundColorScheme: ColorScheme? {
        switch backgroundType {
        case "color": ChatBackgroundAppearance.colorScheme(color: backgroundColor)
        case "gradient": ChatBackgroundAppearance.colorScheme(gradientFrom: gradientStartColor, to: gradientEndColor)
        case "image": backgroundImageData.flatMap(ChatBackgroundAppearance.colorScheme(imageData:))
        default: nil
        }
    }
}

/// Draws a chat in the appearance its background calls for, title bar included; nil keeps the
/// app's own. Always applied, so a change of background doesn't rebuild the conversation.
struct ChatBackgroundColorScheme: ViewModifier {
    let scheme: ColorScheme?
    @Environment(\.colorScheme) private var appScheme

    func body(content: Content) -> some View {
        content
            .environment(\.colorScheme, scheme ?? appScheme)
            .toolbarColorScheme(scheme, for: .navigationBar)
    }
}
