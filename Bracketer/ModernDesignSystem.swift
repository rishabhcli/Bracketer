import SwiftUI

// MARK: - Modern iOS 18+ Design System
/// Apple Camera app inspired design system with Halide professional features
/// Implements iOS 18+ design patterns and modern interface elements

struct ModernDesignSystem {
    
    // MARK: - iOS 18+ Colors
    struct Colors {
        // Primary system colors (iOS 18+)
        static let systemBackground = Color(.systemBackground)
        static let secondarySystemBackground = Color(.secondarySystemBackground)
        static let tertiarySystemBackground = Color(.tertiarySystemBackground)
        
        // Camera interface colors
        static let cameraBackground = Color.black
        static let cameraOverlay = Color.black.opacity(0.3)
        static let cameraControl = Color.white
        static let cameraControlActive = Color.yellow
        static let cameraControlSecondary = Color.white.opacity(0.6)
        
        // Professional colors (Halide inspired)
        static let professional = Color.blue
        static let warning = Color.orange
        static let success = Color.green
        static let error = Color.red
        
        // iOS 18+ accent colors
        static let accent = Color.accentColor
        static let accentSecondary = Color.blue
        static let accentTertiary = Color.purple
        
        // Glass morphism colors
        static let glassBackground = Color.white.opacity(0.1)
        static let glassBorder = Color.white.opacity(0.2)
    }
    
    // MARK: - iOS 18+ Typography
    struct Typography {
        // System fonts with iOS 18+ sizing
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
        static let title = Font.system(size: 28, weight: .bold, design: .default)
        static let title2 = Font.system(size: 22, weight: .bold, design: .default)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .default)
        
        // Body text
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let bodyEmphasized = Font.system(size: 17, weight: .medium, design: .default)
        static let bodyBold = Font.system(size: 17, weight: .semibold, design: .default)
        
        // Caption and small text
        static let callout = Font.system(size: 16, weight: .regular, design: .default)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
        static let footnote = Font.system(size: 13, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .regular, design: .default)
        static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
        
        // Technical/monospace fonts
        static let monospace = Font.system(size: 14, weight: .medium, design: .monospaced)
        static let monospaceLarge = Font.system(size: 16, weight: .semibold, design: .monospaced)
        static let monospaceSmall = Font.system(size: 12, weight: .medium, design: .monospaced)
    }
    
    // MARK: - iOS 18+ Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
    }
    
    // MARK: - iOS 18+ Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xlarge: CGFloat = 20
        static let xxlarge: CGFloat = 24
        static let round: CGFloat = 50
    }
    
    // MARK: - iOS 18+ Shadows
    struct Shadows {
        static let small = ModernShadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        static let medium = ModernShadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        static let large = ModernShadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        static let xlarge = ModernShadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
    }
    
    // MARK: - iOS 18+ Animations
    struct Animations {
        static let quick = Animation.easeInOut(duration: 0.2)
        static let smooth = Animation.easeInOut(duration: 0.3)
        static let spring = Animation.spring(response: 0.4, dampingFraction: 0.8)
        static let bouncy = Animation.spring(response: 0.3, dampingFraction: 0.6)
        static let gentle = Animation.spring(response: 0.5, dampingFraction: 0.9)

        static func motionAware(_ animation: Animation, reduceMotionEnabled: Bool) -> Animation? {
            reduceMotionEnabled ? nil : animation
        }

        static func motionAwareSpring(reduceMotionEnabled: Bool) -> Animation? {
            motionAware(spring, reduceMotionEnabled: reduceMotionEnabled)
        }
    }
}

// MARK: - Modern Shadow Extension
struct ModernShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

extension View {
    func applyModernShadow(_ shadow: ModernShadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

// MARK: - iOS 18+ Button Styles
struct iOSButtonStyle: ButtonStyle {
    let variant: ButtonVariant
    let size: ButtonSize
    
    enum ButtonVariant {
        case primary, secondary, tertiary, destructive
        
        var background: Color {
            switch self {
            case .primary: return ModernDesignSystem.Colors.cameraControl
            case .secondary: return ModernDesignSystem.Colors.glassBackground
            case .tertiary: return ModernDesignSystem.Colors.cameraControlSecondary
            case .destructive: return ModernDesignSystem.Colors.error
            }
        }
        
        var foreground: Color {
            switch self {
            case .primary: return ModernDesignSystem.Colors.cameraBackground
            case .secondary: return ModernDesignSystem.Colors.cameraControl
            case .tertiary: return ModernDesignSystem.Colors.cameraControl
            case .destructive: return ModernDesignSystem.Colors.cameraControl
            }
        }
    }
    
    enum ButtonSize {
        case small, medium, large, xlarge
        
        var frame: CGFloat {
            switch self {
            case .small: return 32
            case .medium: return 44
            case .large: return 56
            case .xlarge: return 72
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .small: return ModernDesignSystem.CornerRadius.small
            case .medium: return ModernDesignSystem.CornerRadius.medium
            case .large: return ModernDesignSystem.CornerRadius.large
            case .xlarge: return ModernDesignSystem.CornerRadius.round
            }
        }
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size.frame, height: size.frame)
            .background(
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .fill(variant.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: size.cornerRadius)
                            .stroke(ModernDesignSystem.Colors.glassBorder, lineWidth: 1)
                    )
            )
            .foregroundColor(variant.foreground)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(ModernDesignSystem.Animations.quick, value: configuration.isPressed)
    }
}

// MARK: - Glass Morphism Effect
struct GlassMorphism: ViewModifier {
    let intensity: Double
    
    init(intensity: Double = 0.1) {
        self.intensity = intensity
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                    .fill(.ultraThinMaterial)
                    .opacity(intensity)
            )
    }
}

extension View {
    func glassMorphism(intensity: Double = 0.1) -> some View {
        self.modifier(GlassMorphism(intensity: intensity))
    }
}

// MARK: - iOS 18+ Card Style
struct ModernCardStyle: ViewModifier {
    let variant: CardVariant
    
    enum CardVariant {
        case primary, secondary, overlay, glass
        
        var background: Color {
            switch self {
            case .primary: return ModernDesignSystem.Colors.secondarySystemBackground
            case .secondary: return ModernDesignSystem.Colors.tertiarySystemBackground
            case .overlay: return ModernDesignSystem.Colors.cameraOverlay
            case .glass: return ModernDesignSystem.Colors.glassBackground
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .primary: return ModernDesignSystem.CornerRadius.large
            case .secondary: return ModernDesignSystem.CornerRadius.medium
            case .overlay: return ModernDesignSystem.CornerRadius.medium
            case .glass: return ModernDesignSystem.CornerRadius.medium
            }
        }
    }
    
    func body(content: Content) -> some View {
        content
            .background(variant.background)
            .cornerRadius(variant.cornerRadius)
            .applyModernShadow(ModernDesignSystem.Shadows.medium)
    }
}

extension View {
    func modernCardStyle(_ variant: ModernCardStyle.CardVariant = .primary) -> some View {
        self.modifier(ModernCardStyle(variant: variant))
    }
}

// MARK: - iOS 18+ Progress Ring
struct iOSProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let color: Color
    let backgroundColor: Color
    
    init(progress: Double, lineWidth: CGFloat = 4, color: Color = ModernDesignSystem.Colors.cameraControlActive, backgroundColor: Color = ModernDesignSystem.Colors.cameraControlSecondary) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.color = color
        self.backgroundColor = backgroundColor
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, lineWidth: lineWidth)
                .rotationEffect(.degrees(-90))
                .animation(ModernDesignSystem.Animations.smooth, value: progress)
        }
    }
}

// MARK: - iOS 18+ Status Indicator
struct iOSStatusIndicator: View {
    let status: Status
    let size: CGFloat
    
    enum Status {
        case active, inactive, warning, error, success
        
        var color: Color {
            switch self {
            case .active: return ModernDesignSystem.Colors.cameraControlActive
            case .inactive: return ModernDesignSystem.Colors.cameraControlSecondary
            case .warning: return ModernDesignSystem.Colors.warning
            case .error: return ModernDesignSystem.Colors.error
            case .success: return ModernDesignSystem.Colors.success
            }
        }
    }
    
    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(ModernDesignSystem.Colors.cameraBackground, lineWidth: 2)
            )
    }
}
