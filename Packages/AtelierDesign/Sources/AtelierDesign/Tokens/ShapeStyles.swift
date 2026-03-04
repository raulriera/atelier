import SwiftUI

// MARK: - Surfaces

/// Default window/view background.
public struct SurfaceDefault: ShapeStyle {
    public func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        Color("surfaceDefault", bundle: .module)
    }
}

/// User messages, active elements.
public struct SurfaceTinted: ShapeStyle {
    public func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        Color("surfaceTinted", bundle: .module)
    }
}

/// Cards, popovers, elevated content.
public struct SurfaceElevated: ShapeStyle {
    public func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        Color("surfaceElevated", bundle: .module)
    }
}

/// Code block backgrounds.
public struct SurfaceCode: ShapeStyle {
    public func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        Color("surfaceCode", bundle: .module)
    }
}

/// Overlays, dimming layers.
public struct SurfaceOverlay: ShapeStyle {
    public func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        Color("surfaceOverlay", bundle: .module)
    }
}

// MARK: - Content

/// Main text, headings.
public struct ContentPrimary: ShapeStyle {
    public func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        Color("contentPrimary", bundle: .module)
    }
}

/// Captions, metadata, timestamps.
public struct ContentSecondary: ShapeStyle {
    public func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        Color("contentSecondary", bundle: .module)
    }
}

/// Placeholders, disabled text.
public struct ContentTertiary: ShapeStyle {
    public func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        Color("contentTertiary", bundle: .module)
    }
}

/// Interactive elements, links. Resolves to the system accent color
/// so it respects the user's macOS accent color setting.
public struct ContentAccent: ShapeStyle {
    public func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        Color.accentColor
    }
}

// MARK: - Status

/// Completed actions, positive states.
public struct StatusSuccess: ShapeStyle {
    public func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        Color("statusSuccess", bundle: .module)
    }
}

/// Caution states, budget alerts.
public struct StatusWarning: ShapeStyle {
    public func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        Color("statusWarning", bundle: .module)
    }
}

/// Failed actions, destructive states.
public struct StatusError: ShapeStyle {
    public func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        Color("statusError", bundle: .module)
    }
}

// MARK: - AI Glow

/// Apple Intelligence-style rainbow gradient for AI-related elements.
/// Use as a border, background accent, or subtle glow.
public enum AIGlow {
    /// The Siri-like rainbow gradient colors.
    public static let colors: [Color] = [
        Color(red: 0.55, green: 0.36, blue: 0.96),  // purple
        Color(red: 0.38, green: 0.51, blue: 1.00),   // blue
        Color(red: 0.30, green: 0.75, blue: 0.93),   // cyan
        Color(red: 0.95, green: 0.55, blue: 0.40),   // orange
        Color(red: 0.92, green: 0.38, blue: 0.55),   // pink
        Color(red: 0.55, green: 0.36, blue: 0.96),   // purple (wrap)
    ]

    /// Angular gradient for circular/ring glows.
    public static let angular = AngularGradient(colors: colors, center: .center)

    /// Linear gradient for borders and accents.
    public static let linear = LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - ShapeStyle Extensions

extension ShapeStyle where Self == SurfaceDefault {
    /// Default window/view background.
    public static var surfaceDefault: SurfaceDefault { SurfaceDefault() }
}

extension ShapeStyle where Self == SurfaceTinted {
    /// User messages, active elements.
    public static var surfaceTinted: SurfaceTinted { SurfaceTinted() }
}

extension ShapeStyle where Self == SurfaceElevated {
    /// Cards, popovers, elevated content.
    public static var surfaceElevated: SurfaceElevated { SurfaceElevated() }
}

extension ShapeStyle where Self == SurfaceCode {
    /// Code block backgrounds.
    public static var surfaceCode: SurfaceCode { SurfaceCode() }
}

extension ShapeStyle where Self == SurfaceOverlay {
    /// Overlays, dimming layers.
    public static var surfaceOverlay: SurfaceOverlay { SurfaceOverlay() }
}

extension ShapeStyle where Self == ContentPrimary {
    /// Main text, headings.
    public static var contentPrimary: ContentPrimary { ContentPrimary() }
}

extension ShapeStyle where Self == ContentSecondary {
    /// Captions, metadata, timestamps.
    public static var contentSecondary: ContentSecondary { ContentSecondary() }
}

extension ShapeStyle where Self == ContentTertiary {
    /// Placeholders, disabled text.
    public static var contentTertiary: ContentTertiary { ContentTertiary() }
}

extension ShapeStyle where Self == ContentAccent {
    /// Interactive elements, links.
    public static var contentAccent: ContentAccent { ContentAccent() }
}

extension ShapeStyle where Self == StatusSuccess {
    /// Completed actions, positive states.
    public static var statusSuccess: StatusSuccess { StatusSuccess() }
}

extension ShapeStyle where Self == StatusWarning {
    /// Caution states, budget alerts.
    public static var statusWarning: StatusWarning { StatusWarning() }
}

extension ShapeStyle where Self == StatusError {
    /// Failed actions, destructive states.
    public static var statusError: StatusError { StatusError() }
}
