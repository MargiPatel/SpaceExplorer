import SwiftUI
import UIKit
import AudioToolbox

// MARK: - Tab Bar Helper Functions
/// Helper to find and control tab bar across navigation hierarchy
private func setTabBarHidden(_ hidden: Bool) {
    DispatchQueue.main.async {
        var tabBarController: UITabBarController?
        
        // Search all scenes and windows
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            
            for window in windowScene.windows where window.isKeyWindow {
                tabBarController = findTabBarController(in: window.rootViewController)
                if tabBarController != nil { break }
            }
            
            if tabBarController == nil {
                for window in windowScene.windows {
                    tabBarController = findTabBarController(in: window.rootViewController)
                    if tabBarController != nil { break }
                }
            }
            
            if tabBarController != nil { break }
        }
        
        // Apply the change
        if let tabBar = tabBarController?.tabBar {
            print(hidden ? "✅ Hiding tab bar (Deep Space)" : "✅ Showing tab bar (Deep Space)")
            UIView.animate(withDuration: 0.25) {
                tabBar.isHidden = hidden
            }
        }
    }
}

private func findTabBarController(in viewController: UIViewController?) -> UITabBarController? {
    if let tabBarController = viewController as? UITabBarController {
        return tabBarController
    }
    
    if let navigationController = viewController as? UINavigationController,
       let tabBar = findTabBarController(in: navigationController.viewControllers.first) {
        return tabBar
    }
    
    if let presented = viewController?.presentedViewController,
       let tabBar = findTabBarController(in: presented) {
        return tabBar
    }
    
    for child in viewController?.children ?? [] {
        if let tabBar = findTabBarController(in: child) {
            return tabBar
        }
    }
    
    return nil
}

// MARK: - Galaxy Star Model
struct GalaxyStar: Identifiable {
    let id: Int
    var position: CGPoint
    var dragOffset: CGSize = .zero
    var opacity: Double = 1.0
    var scale: CGFloat = 1.0
    var isCollected: Bool = false
    
    // Floating animation properties
    var floatOffsetY: CGFloat = 0
    var floatOffsetX: CGFloat = 0
}

// MARK: - Galaxy Stars Overlay
struct GalaxyStarsOverlay: View {
    @Binding var stars: [GalaxyStar]
    @Binding var draggedStarIndex: Int?
    @Binding var starsCollected: Int  // Track number of collected stars
    @Binding var galaxyAbsorptionScale: CGFloat
    @Binding var galaxyAbsorptionGlow: Double
    
    // Particle burst animation states
    @State private var particleBursts: [ParticleBurst] = []
    
    struct ParticleBurst: Identifiable {
        let id = UUID()
        let position: CGPoint
        var opacity: Double = 1.0
        var scale: CGFloat = 0.1
    }
    
    var body: some View {
        GeometryReader { geo in
            let galaxyFrame = CGRect(
                x: 50,  // Left padding
                y: 70,  // Top offset for galaxy image position (original position)
                width: UIScreen.main.bounds.width - 100,
                height: 250
            )
            
            let galaxyCenter = CGPoint(
                x: galaxyFrame.midX,
                y: galaxyFrame.midY
            )
            
            ZStack {
                ForEach(stars.indices, id: \.self) { idx in
                    let star = stars[idx]
                    let isBeingDragged = draggedStarIndex == idx
                    
                    if !star.isCollected {
                        ZStack {
                            // Yellow star background for glow
                            Text("⭐️")
                                .font(.system(size: 50))
                                .blur(radius: 8)
                                .opacity(0.6)
                            
                            // Outer glow
                            Text("✧")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.4))
                                .blur(radius: 10)
                            
                            // Main star
                            Text("✧")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                            
                            // Trailing particles when dragged
                            if isBeingDragged {
                                ForEach(0..<3) { i in
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                colors: [
                                                    Color.yellow.opacity(0.8),
                                                    Color.orange.opacity(0.4),
                                                    Color.clear
                                                ],
                                                center: .center,
                                                startRadius: 0,
                                                endRadius: 8
                                            )
                                        )
                                        .frame(width: 12, height: 12)
                                        .offset(
                                            x: CGFloat.random(in: -15...15),
                                            y: CGFloat.random(in: -15...15)
                                        )
                                        .opacity(0.7 - Double(i) * 0.2)
                                        .blur(radius: 2)
                                }
                            }
                        }
                        .opacity(star.opacity)
                        .scaleEffect(star.scale)
                        .position(
                            x: star.position.x + star.dragOffset.width + star.floatOffsetX,
                            y: star.position.y + star.dragOffset.height + star.floatOffsetY
                        )
                        .onAppear {
                            // Start floating animation for this star
                            startFloatingAnimation(for: idx)
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    stars[idx].dragOffset = value.translation
                                    draggedStarIndex = idx
                                }
                                .onEnded { value in
                                    draggedStarIndex = nil
                                    
                                    // Calculate final position
                                    let finalX = star.position.x + value.translation.width
                                    let finalY = star.position.y + value.translation.height
                                    let finalPoint = CGPoint(x: finalX, y: finalY)
                                    
                                    // Check if dropped on galaxy image
                                    if galaxyFrame.contains(finalPoint) {
                                        // Spawn particle burst at absorption point
                                        spawnParticleBurst(at: finalPoint)
                                        
                                        // Animate galaxy absorption (pulse + glow)
                                        animateGalaxyAbsorption()
                                        
                                        // Spiral absorption animation toward galaxy center
                                        animateStarAbsorption(index: idx, from: finalPoint, to: galaxyCenter)
                                        
                                        // Mark as collected
                                        stars[idx].isCollected = true
                                        starsCollected += 1
                                        
                                        // Play success sound
                                        AudioServicesPlaySystemSound(1057)  // Pop sound
                                        
                                        // Haptic feedback
                                        let generator = UIImpactFeedbackGenerator(style: .medium)
                                        generator.impactOccurred()
                                        
                                    } else {
                                        // Snap back to original position
                                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                                            stars[idx].dragOffset = .zero
                                        }
                                    }
                                }
                        )
                        .shadow(
                            color: isBeingDragged ? .cyan.opacity(0.8) : .white.opacity(0.5),
                            radius: isBeingDragged ? 20 : 12
                        )
                        .shadow(
                            color: isBeingDragged ? .purple.opacity(0.6) : .white.opacity(0.3),
                            radius: isBeingDragged ? 15 : 8
                        )
                        .zIndex(isBeingDragged ? 100 : Double(idx))
                    }
                }
                
                // Particle burst effects
                ForEach(particleBursts) { burst in
                    ZStack {
                        // Expanding ring
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.yellow.opacity(burst.opacity),
                                        Color.purple.opacity(burst.opacity * 0.7),
                                        Color.cyan.opacity(burst.opacity * 0.5)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                            .frame(width: 40, height: 40)
                            .scaleEffect(burst.scale)
                            .opacity(burst.opacity)
                        
                        // Star particles shooting outward
                        ForEach(0..<8) { i in
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color.yellow.opacity(burst.opacity),
                                            Color.orange.opacity(burst.opacity * 0.6),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 6
                                    )
                                )
                                .frame(width: 10, height: 10)
                                .offset(y: -30 * burst.scale)
                                .rotationEffect(.degrees(Double(i) * 45))
                                .opacity(burst.opacity)
                        }
                        
                        // Center flash
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(burst.opacity),
                                        Color.yellow.opacity(burst.opacity * 0.7),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 20
                                )
                            )
                            .frame(width: 40, height: 40)
                            .scaleEffect(burst.scale * 0.5)
                            .opacity(burst.opacity)
                            .blur(radius: 3)
                    }
                    .position(burst.position)
                }
                
                // Hint text below galaxy image
                if starsCollected < 5 {
                    Text("Drag stars into the galaxy! ✨ (\(starsCollected)/5)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.purple.opacity(0.9))
                        .shadow(color: .black.opacity(0.8), radius: 5)
                        .position(x: galaxyCenter.x, y: galaxyFrame.maxY + 30)
                } else {
                    // Success message when all stars collected
                    Text("🌟 Galaxy grew bigger as more stars joined! 🌟")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.yellow)
                        .shadow(color: .black.opacity(0.8), radius: 5)
                        .position(x: galaxyCenter.x, y: galaxyFrame.maxY + 30)
                }
            }
        }
    }
    
    // MARK: - Floating Animation
    private func startFloatingAnimation(for index: Int) {
        // Skip animation if star is being dragged or collected
        guard !stars[index].isCollected else { return }
        
        // Create unique animation timing for each star
        let baseDelay = Double(index) * 0.3
        let verticalDuration = 2.0 + Double(index) * 0.2  // Vary duration per star
        let horizontalDuration = 2.5 + Double(index) * 0.3
        
        // Vertical floating (up and down)
        withAnimation(
            .easeInOut(duration: verticalDuration)
            .repeatForever(autoreverses: true)
            .delay(baseDelay)
        ) {
            stars[index].floatOffsetY = CGFloat.random(in: -8...8)
        }
        
        // Horizontal floating (left and right) - slightly slower
        withAnimation(
            .easeInOut(duration: horizontalDuration)
            .repeatForever(autoreverses: true)
            .delay(baseDelay + 0.5)
        ) {
            stars[index].floatOffsetX = CGFloat.random(in: -10...10)
        }
        
        // Subtle scale pulsing for twinkling effect
        withAnimation(
            .easeInOut(duration: 1.8)
            .repeatForever(autoreverses: true)
            .delay(baseDelay + 0.2)
        ) {
            stars[index].scale = CGFloat.random(in: 0.95...1.05)
        }
    }
    
    // MARK: - Particle Burst Animation
    private func spawnParticleBurst(at position: CGPoint) {
        let burst = ParticleBurst(position: position)
        particleBursts.append(burst)
        
        // Animate the burst
        if let index = particleBursts.firstIndex(where: { $0.id == burst.id }) {
            // Expand ring and particles
            withAnimation(.easeOut(duration: 0.6)) {
                particleBursts[index].scale = 3.0
            }
            
            // Fade out
            withAnimation(.easeIn(duration: 0.4).delay(0.2)) {
                particleBursts[index].opacity = 0
            }
            
            // Remove after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                particleBursts.removeAll(where: { $0.id == burst.id })
            }
        }
    }
    
    // MARK: - Galaxy Absorption Animation
    private func animateGalaxyAbsorption() {
        // Quick scale pulse (like galaxy "eating" the star)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            galaxyAbsorptionScale = 1.15
        }
        
        // Intense glow flash
        withAnimation(.easeOut(duration: 0.2)) {
            galaxyAbsorptionGlow = 1.0
        }
        
        // Return to normal size
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                galaxyAbsorptionScale = 1.0
            }
            
            // Fade glow back to baseline
            withAnimation(.easeIn(duration: 0.4)) {
                galaxyAbsorptionGlow = 0.7
            }
        }
    }
    
    // MARK: - Star Absorption Animation
    private func animateStarAbsorption(index: Int, from startPoint: CGPoint, to endPoint: CGPoint) {
        // Calculate the path curve (spiral effect)
        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        
        // Animate along a spiral path toward galaxy center
        let duration: Double = 0.8
        let steps: Int = 60
        
        for step in 0..<steps {
            let progress = Double(step) / Double(steps)
            let t = progress
            
            // Ease-in curve for acceleration
            let easedT = t * t
            
            // Spiral angle
            let spiralRotation = progress * 2 * .pi
            let spiralRadius = (1.0 - progress) * 30.0  // Shrinking spiral
            
            let spiralOffsetX = cos(spiralRotation) * spiralRadius
            let spiralOffsetY = sin(spiralRotation) * spiralRadius
            
            // Interpolated position with spiral
            let newX = startPoint.x + dx * easedT + spiralOffsetX
            let newY = startPoint.y + dy * easedT + spiralOffsetY
            
            DispatchQueue.main.asyncAfter(deadline: .now() + duration * progress) {
                // Update star position incrementally
                stars[index].position = CGPoint(x: newX, y: newY)
                stars[index].dragOffset = .zero
                
                // Scale down as it approaches
                stars[index].scale = CGFloat(1.0 - progress * 0.7)
                
                // Fade out near the end
                if progress > 0.7 {
                    stars[index].opacity = 1.0 - (progress - 0.7) / 0.3
                }
            }
        }
    }
}

// MARK: - Constellation Stars Overlay
struct ConstellationStarsOverlay: View {
    @Binding var stars: [GalaxyStar]
    @Binding var draggedStarIndex: Int?
    @Binding var starsPlaced: Int
    
    var body: some View {
        GeometryReader { geo in
            // Constellation image frame (matching the detail view layout)
            let constellationFrame = CGRect(
                x: 50,
                y: 90,  // Top offset for constellation image position
                width: UIScreen.main.bounds.width - 100,
                height: 250
            )
            
            let constellationCenter = CGPoint(
                x: constellationFrame.midX,
                y: constellationFrame.midY
            )
            
            ZStack {
                ForEach(stars.indices, id: \.self) { idx in
                    let star = stars[idx]
                    let isBeingDragged = draggedStarIndex == idx
                    
                    if !star.isCollected {
                        ZStack {
                            // Yellow star background for glow
                       //     Text("⭐️")
                       //         .font(.system(size: 45))
                       //         .blur(radius: 6)
                        //        .opacity(0.5)
                            
                            // Outer glow
                            Text("✧")
                                .font(.system(size: 36))
                                .foregroundColor(.cyan.opacity(0.4))
                                .blur(radius: 8)
                            
                            // Main star
                            Text("✧")
                                .font(.system(size: 24))
                                .foregroundColor(.cyan)
                            
                            // Trailing particles when dragged
                            if isBeingDragged {
                                ForEach(0..<3) { i in
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                colors: [
                                                    Color.cyan.opacity(0.8),
                                                    Color.blue.opacity(0.4),
                                                    Color.clear
                                                ],
                                                center: .center,
                                                startRadius: 0,
                                                endRadius: 8
                                            )
                                        )
                                        .frame(width: 12, height: 12)
                                        .offset(
                                            x: CGFloat.random(in: -15...15),
                                            y: CGFloat.random(in: -15...15)
                                        )
                                        .opacity(0.7 - Double(i) * 0.2)
                                        .blur(radius: 2)
                                }
                            }
                        }
                        .opacity(star.opacity)
                        .scaleEffect(star.scale)
                        .position(
                            x: star.position.x + star.dragOffset.width + star.floatOffsetX,
                            y: star.position.y + star.dragOffset.height + star.floatOffsetY
                        )
                        .onAppear {
                            // Start floating animation for this star
                            startFloatingAnimation(for: idx)
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    stars[idx].dragOffset = value.translation
                                    draggedStarIndex = idx
                                }
                                .onEnded { value in
                                    draggedStarIndex = nil
                                    
                                    // Calculate final position
                                    let finalX = star.position.x + value.translation.width
                                    let finalY = star.position.y + value.translation.height
                                    let finalPoint = CGPoint(x: finalX, y: finalY)
                                    
                                    // Check if dropped on constellation image
                                    if constellationFrame.contains(finalPoint) {
                                        // Animate star absorption toward constellation center
                                        animateStarAbsorption(index: idx, from: finalPoint, to: constellationCenter)
                                        
                                        // Mark as collected
                                        stars[idx].isCollected = true
                                        starsPlaced += 1
                                        
                                        // Play success sound
                                        AudioServicesPlaySystemSound(1057)  // Pop sound
                                        
                                        // Haptic feedback
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred()
                                        
                                    } else {
                                        // Snap back to original position
                                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                                            stars[idx].dragOffset = .zero
                                        }
                                    }
                                }
                        )
                        .shadow(
                            color: isBeingDragged ? .cyan.opacity(0.8) : .blue.opacity(0.5),
                            radius: isBeingDragged ? 20 : 12
                        )
                        .shadow(
                            color: isBeingDragged ? .blue.opacity(0.6) : .cyan.opacity(0.3),
                            radius: isBeingDragged ? 15 : 8
                        )
                        .zIndex(isBeingDragged ? 100 : Double(idx))
                    }
                }
                
                // Hint text below constellation image
                if starsPlaced < 6 {
                    Text("Drag stars onto the constellation! ✨ (\(starsPlaced)/6)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.cyan.opacity(0.9))
                        .shadow(color: .black.opacity(0.8), radius: 5)
                        .position(x: constellationCenter.x, y: constellationFrame.maxY + 30)
                } else {
                    // Success message when all stars placed
                    Text("✨ Constellation complete! ✨")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.cyan)
                        .shadow(color: .black.opacity(0.8), radius: 5)
                        .position(x: constellationCenter.x, y: constellationFrame.maxY + 30)
                }
            }
        }
    }
    
    // MARK: - Floating Animation
    private func startFloatingAnimation(for index: Int) {
        // Skip animation if star is collected
        guard !stars[index].isCollected else { return }
        
        // Create unique animation timing for each star
        let baseDelay = Double(index) * 0.3
        let verticalDuration = 2.0 + Double(index) * 0.2
        let horizontalDuration = 2.5 + Double(index) * 0.3
        
        // Vertical floating (up and down)
        withAnimation(
            .easeInOut(duration: verticalDuration)
            .repeatForever(autoreverses: true)
            .delay(baseDelay)
        ) {
            stars[index].floatOffsetY = CGFloat.random(in: -8...8)
        }
        
        // Horizontal floating (left and right)
        withAnimation(
            .easeInOut(duration: horizontalDuration)
            .repeatForever(autoreverses: true)
            .delay(baseDelay + 0.5)
        ) {
            stars[index].floatOffsetX = CGFloat.random(in: -10...10)
        }
        
        // Subtle scale pulsing for twinkling effect
        withAnimation(
            .easeInOut(duration: 1.8)
            .repeatForever(autoreverses: true)
            .delay(baseDelay + 0.2)
        ) {
            stars[index].scale = CGFloat.random(in: 0.95...1.05)
        }
    }
    
    // MARK: - Star Absorption Animation
    private func animateStarAbsorption(index: Int, from startPoint: CGPoint, to endPoint: CGPoint) {
        // Calculate the path
        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        
        // Animate along a gentle curve toward constellation center
        let duration: Double = 0.6
        let steps: Int = 45
        
        for step in 0..<steps {
            let progress = Double(step) / Double(steps)
            let t = progress
            
            // Ease-in curve
            let easedT = t * t
            
            // Gentle curve effect
            let curveOffset = sin(progress * .pi) * 20.0
            
            // Interpolated position with curve
            let newX = startPoint.x + dx * easedT + curveOffset
            let newY = startPoint.y + dy * easedT
            
            DispatchQueue.main.asyncAfter(deadline: .now() + duration * progress) {
                // Update star position incrementally
                stars[index].position = CGPoint(x: newX, y: newY)
                stars[index].dragOffset = .zero
                
                // Scale down as it approaches
                stars[index].scale = CGFloat(1.0 - progress * 0.6)
                
                // Fade out near the end
                if progress > 0.6 {
                    stars[index].opacity = 1.0 - (progress - 0.6) / 0.4
                }
            }
        }
    }
}

// MARK: - Cosmic Object Model
struct CosmicObject: Identifiable {
    let id: String
    let name: String
    let imageName: String
    let color: String
    let position: CGPoint
    let size: CGFloat
    let description: String
    let facts: [String]
    
    init(name: String, imageName: String, color: String, position: CGPoint, size: CGFloat, description: String, facts: [String]) {
        self.id = name // Use name as stable ID
        self.name = name
        self.imageName = imageName
        self.color = color
        self.position = position
        self.size = size
        self.description = description
        self.facts = facts
    }
}

// MARK: - Deep Space Explore View
struct DeepSpaceExploreView: View {
    @EnvironmentObject var gameProgress: GameProgress
    @EnvironmentObject var audioNarrator: AudioNarrator
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedObject: CosmicObject?
    @State private var glowAnimations: [String: Bool] = [:]
    @State private var showQuiz = false
    
    private let spaceObjects: [CosmicObject] = [
        CosmicObject(
            name: "Star",
            imageName: "Star",
            color: "#FFD700",
            position: CGPoint(x: 0.22, y: 0.25),
            size: 110,
            description: "A luminous sphere of plasma held together by gravity",
            facts: [
                "Stars are bright, glowing balls in space.",
                "Our Sun is a medium-sized star",
                "Some stars are small and cool, and some are giant and super-duper hot!"
            ]
        ),
        CosmicObject(
            name: "Galaxy",
            imageName: "Galaxy",
            color: "#9D7CBF",
            position: CGPoint(x: 0.75, y: 0.22),
            size: 140,
            description: "A massive system of stars, gas, and dust",
            facts: [
                "A galaxy is a big group of stars.",
                "We live in a galaxy called the Milky Way.",
                "There are many, many galaxies in space — and they come in different shapes!"
            ]
        ),
        CosmicObject(
            name: "Constellation",
            imageName: "Constellation",
            color: "#4A90E2",
            position: CGPoint(x: 0.50, y: 0.12),
            size: 130,
            description: "A pattern of stars as seen from Earth",
            facts: [
                "Constellations are groups of stars that make shapes in the sky.",
                "Some look like animals or people.",
                "They help us find our way in the night sky!"
            ]
        ),
        CosmicObject(
            name: "Black Hole",
            imageName: "Blackhole",
            color: "#8B00FF",
            position: CGPoint(x: 0.50, y: 0.45),
            size: 145,
            description: "A region of spacetime with gravity so strong that nothing can escape",
            facts: [
                "A black hole has super strong gravity.",
                "Black holes are made when big stars explode",
                "We can’t see a black hole."
            ]
        ),
        CosmicObject(
            name: "Nebula",
            imageName: "Nebula",
            color: "#FF6B9D",
            position: CGPoint(x: 0.75, y: 0.65),
            size: 125,
            description: "A giant cloud of dust and gas in space",
            facts: [
                "A nebula is a big cloud in space.",
                "Baby stars are born inside nebulae.",
                "Nebulae can glow in pretty colors."
            ]
        ),
        CosmicObject(
            name: "Supernova",
            imageName: "Supernova",
            color: "#FF4500",
            position: CGPoint(x: 0.25, y: 0.75),
            size: 130,
            description: "The explosive death of a massive star",
            facts: [
                "A supernova is a big star explosion.",
                "It shines very, very bright.",
                "Supernovas help make new things."
            ]
        )
    ]
    
    var body: some View {
        ZStack {
            // Background layer (ignores safe area)
            Color.black
                .ignoresSafeArea(.all)
            
            ZStack {
                // Space background image
                Image("space_background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    .clipped()
                
                // Twinkling stars overlay
          /*      ForEach(0..<50, id: \.self) { _ in
                    Circle()
                        .fill(Color.white.opacity(Double.random(in: 0.3...0.9)))
                        .frame(width: CGFloat.random(in: 1...3))
                        .position(
                            x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                            y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                        )
                        .opacity(Double.random(in: 0.5...1.0))
                }*/
            }
            .ignoresSafeArea(.all)
            
            // Content layer (respects safe area)
            VStack(spacing: 10) {
                // Header
                ZStack {
                    // Title in center
                    VStack(spacing: 4) {
                        Text("✨ Deep Space ✨")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .purple.opacity(0.9), radius: 12)
                            .shadow(color: .cyan.opacity(0.6), radius: 8)
                            .shadow(color: .black.opacity(0.8), radius: 4)
                        
                        Text("Tap the cosmic wonders!")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan)
                            .shadow(color: .cyan.opacity(0.8), radius: 6)
                            .shadow(color: .black.opacity(0.8), radius: 3)
                    }
                    
                    // Back button on left
                    HStack {
                        BackButton {
                            audioNarrator.playTapSound()
                            dismiss()
                        }
                        
                        Spacer()
                        
                        // Quiz button on right
                        QuizButton(topic: .deepSpace)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 90)
                .padding(.bottom, 10)
                
                // Space objects
                GeometryReader { geometry in
                    ZStack {
                        ForEach(spaceObjects) { object in
                            SpaceObjectView(
                                object: object,
                                isGlowing: glowAnimations[object.id] ?? false,
                                geometry: geometry,
                                onTap: {
                                    audioNarrator.stop()  // Stop deepSpace audio
                                    selectedObject = object
                                    audioNarrator.playTapSound()
                                }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(item: $selectedObject) { object in
            DeepSpaceDetailView(object: object)
        }
        .sheet(isPresented: $showQuiz) {
            QuizGameView(topic: .deepSpace)
                .environmentObject(gameProgress)
                .environmentObject(audioNarrator)
        }
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            print("🔄 DeepSpaceExploreView appeared")
            setTabBarHidden(true)
            
            // Start glow animations
            startGlowAnimations()
            
            // Play deep space intro audio
            audioNarrator.playAudioFile(named: "deepSpace")
        }
        .onDisappear {
            print("🔄 DeepSpaceExploreView disappeared")
            audioNarrator.stop()
            setTabBarHidden(false)
        }
    }
    
    private func startGlowAnimations() {
        // Show objects in specific sequence with 2 second initial delay and 1 second between each
        // Sequence: Star → Nebula → Supernova → Black Hole → Galaxy → Constellation
        
        let sequenceOrder = ["Star", "Nebula", "Supernova", "Black Hole", "Galaxy", "Constellation"]
        let initialDelay: Double = 3.5  // 2 seconds before first object
        let delayBetweenObjects: Double = 1.5  // 1 second between each object
        
        for (sequenceIndex, objectName) in sequenceOrder.enumerated() {
            // Find the object with this name
            if let object = spaceObjects.first(where: { $0.name == objectName }) {
                let totalDelay = initialDelay + (Double(sequenceIndex) * delayBetweenObjects)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) {
                    withAnimation(.easeIn(duration: 0.8)) {
                        glowAnimations[object.id] = true
                    }
                }
            }
        }
    }
}

// MARK: - Space Object View
struct SpaceObjectView: View {
    let object: CosmicObject
    let isGlowing: Bool
    let geometry: GeometryProxy
    let onTap: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var glowIntensity: Double = 0.9
    @State private var glowRadius: CGFloat = 15
    
    // Enhanced glow settings for Constellation
    private var enhancedGlowIntensity: Double {
        object.name == "Constellation" ? glowIntensity * 1.5 : glowIntensity
    }
    
    private var enhancedGlowRadius: CGFloat {
        object.name == "Constellation" ? glowRadius * 1.4 : glowRadius
    }
    
    var body: some View {
        ZStack {
            // Outer glow with pulsing animation
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: object.color).opacity(enhancedGlowIntensity),
                            Color(hex: object.color).opacity(enhancedGlowIntensity * 0.5),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 15,
                        endRadius: enhancedGlowRadius * 2.5
                    )
                )
                .frame(width: object.size * 1.4, height: object.size * 1.4)
                .blur(radius: enhancedGlowRadius * 0.7)
                .scaleEffect(scale * 1.1)
                .allowsHitTesting(false)  // Prevent glow from intercepting taps
            
            // Middle glow layer
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: object.color).opacity(enhancedGlowIntensity * 1.5),
                            Color(hex: object.color).opacity(enhancedGlowIntensity * 0.8),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: enhancedGlowRadius * 1.5
                    )
                )
                .frame(width: object.size * 1.2, height: object.size * 1.2)
                .blur(radius: enhancedGlowRadius * 0.5)
                .scaleEffect(scale * 1.05)
                .allowsHitTesting(false)  // Prevent glow from intercepting taps
            
            // Object image with zoom animation (NO ROTATION)
            Image(object.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: object.size, height: object.size)
                .scaleEffect(scale)
                .shadow(color: Color(hex: object.color).opacity(enhancedGlowIntensity * 2), radius: enhancedGlowRadius)
                .shadow(color: Color(hex: object.color).opacity(enhancedGlowIntensity), radius: enhancedGlowRadius * 0.6)
                .contentShape(Rectangle())  // Make only the image frame tappable
                .onTapGesture {
                    onTap()
                }
            }
        .position(
            x: geometry.size.width * object.position.x,
            y: geometry.size.height * object.position.y
        )
        .opacity(isGlowing ? 1 : 0.6)  // Start at 30% opacity, full when activated
        .animation(.easeIn(duration: 0.8), value: isGlowing)  // Smooth fade-in animation
        .onAppear {
            // Start subtle animations immediately for all objects
            withAnimation(
                .easeInOut(duration: 3)
                .repeatForever(autoreverses: true)
            ) {
                scale = 1.15
            }
        }
        .task(id: isGlowing) {
            // Enhance animations when isGlowing becomes true
            if isGlowing {
                print("🌟 Starting glow animations for \(object.name)")
                
                // Pulsing glow intensity
                withAnimation(
                    .easeInOut(duration: 2.5)
                    .repeatForever(autoreverses: true)
                ) {
                    glowIntensity = 0.8
                }
                
                // Pulsing glow radius
                withAnimation(
                    .easeInOut(duration: 2.5)
                    .repeatForever(autoreverses: true)
                ) {
                    glowRadius = 22
                }
            }
        }
    }
}

// MARK: - Deep Space Detail View
struct DeepSpaceDetailView: View {
    let object: CosmicObject
    @EnvironmentObject var gameProgress: GameProgress
    @EnvironmentObject var audioNarrator: AudioNarrator
    @Environment(\.dismiss) var dismiss
    
    @State private var currentFactIndex = 0
    @State private var showingFact = false
    @State private var scale: CGFloat = 1.0
    @State private var glowPulse: Double = 0.6
    
    // Galaxy stars state
    @State private var galaxyStars: [GalaxyStar] = []
    @State private var draggedStarIndex: Int? = nil
    @State private var starsCollected: Int = 0
    @State private var galaxyAbsorptionScale: CGFloat = 1.0
    @State private var galaxyAbsorptionGlow: Double = 0.7

    // Star temperature slider — 0 = Red (coolest), 1 = Blue (hottest)
    @State private var starTemperature: Double = 0.5   // default = Yellow

    // The five temperature stops mapped to [0, 0.25, 0.5, 0.75, 1.0]
    private let temperatureStops: [(value: Double, color: Color, label: String, temp: String)] = [
        (0.00, Color(red: 1.0, green: 0.2, blue: 0.1),  "Red",    "< 3,500 degrees"),
        (0.25, Color(red: 1.0, green: 0.55, blue: 0.1), "Orange", "3,500–5,000 degrees"),
        (0.50, Color(red: 1.0, green: 0.95, blue: 0.3), "Yellow", "5,000–7,500 degrees"),
        (0.75, Color(red: 1.0, green: 1.0,  blue: 1.0), "White",  "7,500–30,000 degrees"),
        (1.00, Color(red: 0.4, green: 0.6,  blue: 1.0), "Blue",   "> 30,000 degrees")
    ]

    /// Interpolated star color for the current slider value.
    private var starColor: Color {
        // Find the two surrounding stops and lerp between them
        let stops = temperatureStops
        if starTemperature <= stops.first!.value { return stops.first!.color }
        if starTemperature >= stops.last!.value  { return stops.last!.color }

        for i in 0..<(stops.count - 1) {
            let lo = stops[i], hi = stops[i + 1]
            if starTemperature >= lo.value && starTemperature <= hi.value {
                let t = (starTemperature - lo.value) / (hi.value - lo.value)
                return lerp(lo.color, hi.color, t: t)
            }
        }
        return stops[2].color
    }

    /// Label for the nearest stop.
    private var temperatureLabel: (name: String, range: String) {
        let nearest = temperatureStops.min(by: {
            abs($0.value - starTemperature) < abs($1.value - starTemperature)
        })!
        return (nearest.label, nearest.temp)
    }

    /// Linearly interpolate between two SwiftUI Colors.
    private func lerp(_ a: Color, _ b: Color, t: Double) -> Color {
        let (ar, ag, ab) = a.rgbComponents
        let (br, bg, bb) = b.rgbComponents
        return Color(
            red:   ar + (br - ar) * t,
            green: ag + (bg - ag) * t,
            blue:  ab + (bb - ab) * t
        )
    }

    var body: some View {
        ZStack {
            // Background gradient — uses starColor when object is Star
            LinearGradient(
                colors: [
                    (object.name == "Star" ? starColor : Color(hex: object.color)).opacity(0.4),
                    Color(hex: "#0a0a1a"),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.4), value: starTemperature)
            
            // Animated background stars
            ForEach(0..<30, id: \.self) { _ in
                Circle()
                    .fill(Color.white.opacity(Double.random(in: 0.3...0.8)))
                    .frame(width: CGFloat.random(in: 1...3))
                    .position(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                    )
            }

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    CloseButton {
                        audioNarrator.playTapSound()
                        dismiss()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)  // Reduced to 10px for better spacing on detail overlay

                // ── Non-scrollable content area ──
                if object.name != "Nebula" && object.name != "Constellation" && object.name != "Supernova" && object.name != "Black Hole" {
                    VStack(spacing: 0) {
                        // Object image with enhanced glow and zoom (non-scrollable)
                        ZStack {
                            let displayColor = object.name == "Star" ? starColor : Color(hex: object.color)

                            // Glow layers - SKIP for Galaxy
                            if object.name != "Galaxy" {
                                Circle()
                                    .fill(RadialGradient(colors: [displayColor.opacity(glowPulse * 0.4), displayColor.opacity(glowPulse * 0.2), Color.clear], center: .center, startRadius: 80, endRadius: 200))
                                    .frame(width: 400, height: 400).blur(radius: 40).scaleEffect(scale)

                                Circle()
                                    .fill(RadialGradient(colors: [displayColor.opacity(glowPulse * 0.6), displayColor.opacity(glowPulse * 0.3), Color.clear], center: .center, startRadius: 50, endRadius: 150))
                                    .frame(width: 300, height: 300).blur(radius: 30).scaleEffect(scale * 1.05)

                                Circle()
                                    .fill(RadialGradient(colors: [displayColor.opacity(glowPulse), displayColor.opacity(glowPulse * 0.5), Color.clear], center: .center, startRadius: 30, endRadius: 100))
                                    .frame(width: 200, height: 200).blur(radius: 20).scaleEffect(scale * 1.1)
                            }

                            if object.name == "Star" {
                                Image("Star_transparent")
                                    .resizable().aspectRatio(contentMode: .fit)
                                    .frame(width: 220, height: 220)
                                    .colorMultiply(starColor)
                                    .scaleEffect(scale)
                                    .shadow(color: starColor.opacity(glowPulse), radius: 50)
                                    .shadow(color: starColor.opacity(glowPulse * 0.8), radius: 30)
                                    .animation(.easeInOut(duration: 0.4), value: starTemperature)
                            } else if object.name == "Galaxy" {
                                // Use Galaxy1 or Galaxy2 image based on collected stars
                                ZStack {
                                    // Dynamic absorption glow (pulses when star is consumed)
                                    Circle()
                                        .fill(RadialGradient(
                                            colors: [
                                                Color.yellow.opacity(galaxyAbsorptionGlow * 0.3),
                                                Color.purple.opacity(galaxyAbsorptionGlow * 0.25),
                                                Color.blue.opacity(galaxyAbsorptionGlow * 0.2),
                                                Color.cyan.opacity(galaxyAbsorptionGlow * 0.15),
                                                Color.clear
                                            ],
                                            center: .center,
                                            startRadius: 30,
                                            endRadius: 180
                                        ))
                                        .frame(width: 360, height: 360)
                                        .blur(radius: 25)
                                        .scaleEffect(scale * galaxyAbsorptionScale)
                                    
                                    // Celebratory glow when galaxy grows
                                    if starsCollected >= 5 {
                                        Circle()
                                            .fill(RadialGradient(
                                                colors: [
                                                    Color.purple.opacity(0.4),
                                                    Color.blue.opacity(0.3),
                                                    Color.cyan.opacity(0.2),
                                                    Color.clear
                                                ],
                                                center: .center,
                                                startRadius: 50,
                                                endRadius: 200
                                            ))
                                            .frame(width: 400, height: 400)
                                            .blur(radius: 30)
                                            .scaleEffect(scale)
                                    }
                                    
                                    Image(starsCollected >= 5 ? "Galaxy2" : "Galaxy1")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: UIScreen.main.bounds.width - 100, height: 250)
                                        .scaleEffect(scale * galaxyAbsorptionScale)
                                        .shadow(color: Color.purple.opacity(galaxyAbsorptionGlow * 0.4), radius: 20)
                                        .shadow(color: Color.cyan.opacity(galaxyAbsorptionGlow * 0.3), radius: 15)
                                }
                                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: starsCollected)
                                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: galaxyAbsorptionScale)
                                .animation(.easeInOut(duration: 0.3), value: galaxyAbsorptionGlow)
                            } else {
                                Image(object.imageName)
                                    .resizable().aspectRatio(contentMode: .fit)
                                    .frame(width: 250, height: 250)
                                    .scaleEffect(scale)
                                    .shadow(color: displayColor.opacity(glowPulse), radius: 50)
                                    .shadow(color: displayColor.opacity(glowPulse * 0.8), radius: 30)
                            }
                        }
                        .padding(.top, 20)
                        .frame(height: 290)  // Fixed height for Galaxy image area

                        // Star temperature slider (non-scrollable)
                        if object.name == "Star" {
                            StarTemperatureSlider(
                                temperature: $starTemperature,
                                starColor: starColor,
                                label: temperatureLabel
                            )
                            .padding(.horizontal, 28)
                            .padding(.top, 12)
                            .padding(.bottom, 8)
                        }

                        // Object name (non-scrollable)
                        Text(object.name)
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: (object.name == "Star" ? starColor : Color(hex: object.color)).opacity(0.8), radius: 10)
                            .animation(.easeInOut(duration: 0.4), value: starTemperature)
                            .padding(.top, 8)

                        // Description (non-scrollable)
                        Text(object.description)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .padding(.top, 8)

                        // Facts section (SCROLLABLE ONLY)
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 16) {
                                ForEach(Array(object.facts.enumerated()), id: \.offset) { index, fact in
                                    DeepSpaceFactCard(
                                        number: index + 1,
                                        fact: fact,
                                        color: object.name == "Star" ? starColor : Color(hex: object.color),
                                        isVisible: showingFact && currentFactIndex >= index
                                    )
                                    .onTapGesture {
                                        // Play specific audio file for Star and Galaxy facts
                                        if object.name == "Star" {
                                            let audioFileName = "stars_fact\(index + 1)"
                                            audioNarrator.playAudioFile(named: audioFileName)
                                        } else if object.name == "Galaxy" {
                                            let audioFileName = "galaxy_fact\(index + 1)"
                                            audioNarrator.playAudioFile(named: audioFileName)
                                        } else {
                                            audioNarrator.narrate(fact)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                            .padding(.bottom, 40)
                        }
                    }
                }
                
                // For Nebula, show game area with title/description above it
                if object.name == "Nebula" {
                    VStack(spacing: 0) {
                        // Non-scrollable game area
                        ZStack {
                            Color.clear
                                .frame(height: 395)  // Space for NebulaBuildView game area
                            
                            VStack(spacing: 8) {
                                Spacer()
                                    .frame(height: 418)  // Increased from 358 to move down 60px
                                
                                // Object name
                                Text(object.name)
                                    .font(.system(size: 42, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .shadow(color: Color(hex: object.color).opacity(0.8), radius: 10)

                                // Description
                                Text(object.description)
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                    .padding(.top, 4)
                            }
                            .allowsHitTesting(false)  // Let touches pass through to game
                        }
                        
                        // Facts section (SCROLLABLE ONLY)
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 16) {
                                ForEach(Array(object.facts.enumerated()), id: \.offset) { index, fact in
                                    DeepSpaceFactCard(
                                        number: index + 1,
                                        fact: fact,
                                        color: Color(hex: object.color),
                                        isVisible: showingFact && currentFactIndex >= index
                                    )
                                    .onTapGesture {
                                        // Play specific audio file for Nebula facts
                                        let audioFileName = "nebula_fact\(index + 1)"
                                        audioNarrator.playAudioFile(named: audioFileName)
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                            .padding(.bottom, 40)
                        }
                    }
                }
                
                // For Constellation, show game (no static image needed)
                if object.name == "Constellation" {
                    VStack(spacing: 0) {
                        // Non-scrollable game area
                        ZStack {
                            Color.clear
                                .frame(height: 395)  // Space for ConstellationBuildView game area
                            
                            VStack(spacing: 8) {
                                Spacer()
                                    .frame(height: 418)  // Moved down 60px
                                
                                // Object name
                                Text(object.name)
                                    .font(.system(size: 42, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .shadow(color: Color(hex: object.color).opacity(0.8), radius: 10)

                                // Description
                                Text(object.description)
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                    .padding(.top, 4)
                            }
                            .allowsHitTesting(false)  // Let touches pass through to game
                        }
                        
                        // Facts section (SCROLLABLE ONLY)
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 16) {
                                ForEach(Array(object.facts.enumerated()), id: \.offset) { index, fact in
                                    DeepSpaceFactCard(
                                        number: index + 1,
                                        fact: fact,
                                        color: Color(hex: object.color),
                                        isVisible: showingFact && currentFactIndex >= index
                                    )
                                    .onTapGesture {
                                        // Play specific audio file for Constellation facts
                                        let audioFileName = "constellations_fact\(index + 1)"
                                        audioNarrator.playAudioFile(named: audioFileName)
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                            .padding(.bottom, 10)
                        }
                    }
                }
                
                // For Supernova, show game area with title/description above it
                if object.name == "Supernova" {
                    VStack(spacing: 0) {
                        // Non-scrollable game area
                        ZStack {
                            Color.clear
                                .frame(height: 395)  // Space for SupernovaCollapseView game area
                            
                            VStack(spacing: 8) {
                                Spacer()
                                    .frame(height: 418)  // Increased from 358 to move down 60px
                                
                                // Object name
                                Text(object.name)
                                    .font(.system(size: 42, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .shadow(color: Color(hex: object.color).opacity(0.8), radius: 10)

                                // Description
                                Text(object.description)
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                    .padding(.top, 4)
                            }
                            .allowsHitTesting(false)  // Let touches pass through to game
                        }
                        
                        // Facts section (SCROLLABLE ONLY)
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 16) {
                                ForEach(Array(object.facts.enumerated()), id: \.offset) { index, fact in
                                    DeepSpaceFactCard(
                                        number: index + 1,
                                        fact: fact,
                                        color: Color(hex: object.color),
                                        isVisible: showingFact && currentFactIndex >= index
                                    )
                                    .onTapGesture {
                                        // Play specific audio file for Supernova facts
                                        let audioFileName = "supernova_fact\(index + 1)"
                                        audioNarrator.playAudioFile(named: audioFileName)
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                            .padding(.bottom, 10)
                        }
                    }
                }
                
                // For Black Hole, show game area with title/description above it
                if object.name == "Black Hole" {
                    VStack(spacing: 0) {
                        // Non-scrollable game area
                        ZStack {
                            Color.clear
                                .frame(height: 395)  // Space for BlackHoleAbsorptionView game area
                            
                            VStack(spacing: 8) {
                                Spacer()
                                    .frame(height: 418)  // Increased from 358 to move down 60px
                                
                                // Object name
                                Text(object.name)
                                    .font(.system(size: 42, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .shadow(color: Color(hex: object.color).opacity(0.8), radius: 10)

                                // Description
                                Text(object.description)
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                    .padding(.top, 4)
                            }
                            .allowsHitTesting(false)  // Let touches pass through to game
                        }
                        
                        // Facts section (SCROLLABLE ONLY)
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 16) {
                                ForEach(Array(object.facts.enumerated()), id: \.offset) { index, fact in
                                    DeepSpaceFactCard(
                                        number: index + 1,
                                        fact: fact,
                                        color: Color(hex: object.color),
                                        isVisible: showingFact && currentFactIndex >= index
                                    )
                                    .onTapGesture {
                                        // Play specific audio file for Black Hole facts
                                        let audioFileName = "blackhole_fact\(index + 1)"
                                        audioNarrator.playAudioFile(named: audioFileName)
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                            .padding(.bottom, 10)
                        }
                    }
                }
            }
            
            // ── Nebula cloud drag game (on top, not blocked by ScrollView) ──
            if object.name == "Nebula" {
                NebulaBuildView()
                    .zIndex(10)  // Ensure it's on top
            }
            
            // ── Supernova collapse game (on top, not blocked by ScrollView) ──
            if object.name == "Supernova" {
                SupernovaCollapseView()
                    .environmentObject(audioNarrator)
                    .zIndex(10)  // Ensure it's on top
            }
            
            // ── Black Hole absorption game (on top, not blocked by ScrollView) ──
            if object.name == "Black Hole" {
                BlackHoleAbsorptionView()
                    .environmentObject(audioNarrator)
                    .zIndex(10)  // Ensure it's on top
            }
            
            // ── Galaxy interactive stars (on top of Galaxy image) ──
            if object.name == "Galaxy" {
                GalaxyStarsOverlay(
                    stars: $galaxyStars,
                    draggedStarIndex: $draggedStarIndex,
                    starsCollected: $starsCollected,
                    galaxyAbsorptionScale: $galaxyAbsorptionScale,
                    galaxyAbsorptionGlow: $galaxyAbsorptionGlow
                )
                .zIndex(10)  // Ensure it's on top
            }
            
            // ── Constellation build game (connect-the-stars interactive experience) ──
            if object.name == "Constellation" {
                ConstellationBuildView()
                    .zIndex(10)  // Ensure it's on top
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) { scale = 1.15 }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { glowPulse = 0.9 }
            
            // Initialize galaxy stars if viewing Galaxy
            if object.name == "Galaxy" {
                spawnGalaxyStars()
                
                // Play galaxy_build audio after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    audioNarrator.playAudioFile(named: "galaxy_build")
                }
            }
            
            // Play audio sequence for Star object
            if object.name == "Star" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    playStarAudioSequence()
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { revealFacts() }
            gameProgress.completeActivity("deepspace_\(object.name)")
        }
        .onChange(of: starsCollected) { newValue in
            // Celebrate when all 5 stars are collected
            if newValue == 5 {
                celebrateGalaxyGrowth()
            }
        }
        .onDisappear { audioNarrator.stop() }
    }
    
    private func spawnGalaxyStars() {
        let screenWidth = UIScreen.main.bounds.width
        let screenCenter = screenWidth / 2
        
        // Position stars in top section above galaxy (spread horizontally)
        let startY: CGFloat = 80  // Top section position
        let horizontalSpacing: CGFloat = 70  // Horizontal spacing between stars
        
        // Calculate starting X to center the stars
        let totalWidth = CGFloat(4) * horizontalSpacing  // 4 spaces between 5 stars
        let startX = screenCenter - (totalWidth / 2)
        
        galaxyStars = (0..<5).map { idx in
            GalaxyStar(
                id: idx,
                position: CGPoint(
                    x: startX + CGFloat(idx) * horizontalSpacing,
                    y: startY
                )
            )
        }
    }
    
    private func celebrateGalaxyGrowth() {
        // Play success sound
        audioNarrator.playAudioFile(named: "galaxy_swirl")
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Brief scale animation on the galaxy
        withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
            scale = 1.25
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                scale = 1.15
            }
        }
    }
    
    private func revealFacts() {
        showingFact = true
        audioNarrator.playSuccessSound()
        
        // Reveal facts one by one
        for index in 0..<object.facts.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.3) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    currentFactIndex = index
                }
            }
        }
    }
    
    private func playStarAudioSequence() {
        let audioFiles = [
            "stars_colors",
            "blue_star",
            "red_star",
            "color_intro",
            "move_slider"
        ]
        
        audioNarrator.playAudioSequence(audioFiles)
    }
}

// MARK: - Nebula Build Game

struct NebulaBuildView: View {
    
    @EnvironmentObject var audioNarrator: AudioNarrator

    enum Phase { case idle, clouds, complete }

    @State private var phase: Phase = .idle
    @State private var nebulaOpacity: Double = 1.0

    struct CloudState: Identifiable {
        let id: Int
        let imageName: String
        var spawnOffset: CGSize   // offset from view center
        var dragOffset: CGSize    // live drag delta
        var opacity: Double = 0
        var placed: Bool = false
    }

    @State private var clouds: [CloudState] = []
    @State private var starScale: CGFloat = 0.1
    @State private var starGlow: Double = 0
    @State private var starOpacity: Double = 0
    @State private var cloudsGroupOpacity: Double = 1
    @State private var burstScale: CGFloat = 0
    @State private var burstOpacity: Double = 0
    @State private var innerBurstScale: CGFloat = 0
    @State private var innerBurstOpacity: Double = 0
    @State private var particlesScale: CGFloat = 0
    @State private var particlesOpacity: Double = 0
    
    // Central nebula cloud animation
    @State private var centralNebulaScale: CGFloat = 1.0  // Changed from 0.3 to 1.0 (base size)
    @State private var centralNebulaOpacity: Double = 0
    @State private var centralNebulaRotation: Double = 0

    private let centerZoneRadius: CGFloat = 70

    // Fixed offsets from the view center so images always stay in the top half
    private let spawnOffsets: [CGSize] = [
        CGSize(width: -130, height: -190),  // top-left
        CGSize(width:  130, height: -170),  // top-right
        CGSize(width: -140, height:  -60),  // mid-left
        CGSize(width:  140, height:  -80)   // mid-right
    ]

    private var placedCount: Int { clouds.filter(\.placed).count }

    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height * 0.38   // drop-zone sits in the upper third

            ZStack {

                // ── Nebula image (fades out after 2 s) ─────────────────
                Image("Nebula")
                    .resizable().aspectRatio(contentMode: .fit)
                    .frame(width: 220, height: 220)
                    .opacity(nebulaOpacity)
                    .animation(.easeOut(duration: 1.2), value: nebulaOpacity)
                    .position(x: cx, y: cy)
                    .allowsHitTesting(false)  // Don't block cloud drag gestures

                // ── Drop-zone ring + hint ──────────────────────────────
                if phase == .clouds {
                    ZStack {
                        // Central nebula cloud (nebula_cloud2) - animated (increased size)
                        Image("nebula_cloud2")
                            .resizable()
                            .renderingMode(.original)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 200, height: 200)  // Increased from 200 to 280
                            .scaleEffect(centralNebulaScale)
                            .rotationEffect(.degrees(centralNebulaRotation))
                            .opacity(centralNebulaOpacity)
                            .blur(radius: 1)
                        
                        Circle()
                            .strokeBorder(
                                Color.pink.opacity(0.55),
                                style: StrokeStyle(lineWidth: 0, dash: [7, 4])
                            )
                            .frame(width: centerZoneRadius * 2,
                                   height: centerZoneRadius * 2)

                        Text("Drag all the clouds here\nand see what happens")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.pink.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .offset(y: centerZoneRadius + 22)
                    }
                    .position(x: cx, y: cy)
                    .allowsHitTesting(false)
                }

                // ── Draggable cloud images ─────────────────────────────
                ForEach(clouds.indices, id: \.self) { idx in
                    let cloud = clouds[idx]

                    Image(cloud.imageName)
                        .resizable()
                        .renderingMode(.original)  // Preserve transparency
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 75, height: 75)  // Reduced from 85 to 75
                        .opacity(cloud.placed ? 0 : cloud.opacity * cloudsGroupOpacity)  // Fade to 0 when placed
                        .scaleEffect(cloud.placed ? 0.5 : 1.0)  // Shrink when placed
                        .shadow(color: .pink.opacity(cloud.placed ? 0 : 0.6), radius: 14)
                        .animation(.easeOut(duration: 0.5), value: cloud.placed)  // Smooth fade animation
                        .contentShape(Rectangle())  // Hit testing area
                        .position(
                            x: cx + cloud.spawnOffset.width + cloud.dragOffset.width,
                            y: cy + cloud.spawnOffset.height + cloud.dragOffset.height
                        )
                        .simultaneousGesture(
                            cloud.placed ? nil :
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    // Update drag offset relative to spawn position
                                    clouds[idx].dragOffset = CGSize(
                                        width: value.translation.width,
                                        height: value.translation.height
                                    )
                                }
                                .onEnded { value in
                                    // Calculate final position
                                    let finalX = cx + cloud.spawnOffset.width + clouds[idx].dragOffset.width
                                    let finalY = cy + cloud.spawnOffset.height + clouds[idx].dragOffset.height
                                    let dist = hypot(finalX - cx, finalY - cy)

                                    if dist < centerZoneRadius {
                                        // Cloud placed in center - fade it out
                                        withAnimation(.easeOut(duration: 0.5)) {
                                            // Move spawn offset to center and clear drag
                                            clouds[idx].spawnOffset = .zero
                                            clouds[idx].dragOffset = .zero
                                            clouds[idx].placed = true
                                        }
                                        
                                        // Grow central nebula cloud
                                        growCentralNebula()
                                        
                                        checkCompletion()
                                    } else {
                                        // Snap back to original spawn position
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                                            clouds[idx].dragOffset = .zero
                                        }
                                    }
                                }
                        )
                        .zIndex(cloud.placed ? 0 : 1)  // Unplaced clouds on top
                }

                // ── Born star ──────────────────────────────────────────
                if phase == .complete {
                    ZStack {
                        // ═══ BURST EFFECTS ════════════════════════════════
                        
                        // Outer burst ring (slowest, largest)
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(burstOpacity * 0.8),
                                        Color.yellow.opacity(burstOpacity * 0.6),
                                        Color.orange.opacity(burstOpacity * 0.4)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 4
                            )
                            .frame(width: 120, height: 120)
                            .scaleEffect(burstScale)
                            .opacity(burstOpacity)
                            .blur(radius: 2)
                        
                        // Middle burst ring
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.yellow.opacity(burstOpacity),
                                        Color.orange.opacity(burstOpacity * 0.7)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                            .frame(width: 100, height: 100)
                            .scaleEffect(burstScale * 1.1)
                            .opacity(burstOpacity * 1.2)
                        
                        // Inner burst (fastest)
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(innerBurstOpacity),
                                        Color.yellow.opacity(innerBurstOpacity * 0.8),
                                        Color.orange.opacity(innerBurstOpacity * 0.5),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 80
                                )
                            )
                            .frame(width: 160, height: 160)
                            .scaleEffect(innerBurstScale)
                            .opacity(innerBurstOpacity)
                            .blur(radius: 5)
                        
                        // ═══ SPARKLE PARTICLES ════════════════════════════
                        
                        // 12 large sparkle rays
                        ForEach(0..<12) { i in
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color.white.opacity(particlesOpacity),
                                            Color.yellow.opacity(particlesOpacity * 0.6),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 20
                                    )
                                )
                                .frame(width: 30, height: 30)
                                .offset(y: -100)
                                .rotationEffect(.degrees(Double(i) * 30))
                                .scaleEffect(particlesScale)
                                .opacity(particlesOpacity)
                        }
                        
                        // 8 smaller sparkles (offset rotation)
                        ForEach(0..<8) { i in
                            Circle()
                                .fill(Color.white.opacity(particlesOpacity * 0.8))
                                .frame(width: 12, height: 12)
                                .offset(y: -70)
                                .rotationEffect(.degrees(Double(i) * 45 + 22.5))
                                .scaleEffect(particlesScale * 0.9)
                                .opacity(particlesOpacity)
                        }
                        
                        // Tiny sparkles (between main rays)
                        ForEach(0..<16) { i in
                            Circle()
                                .fill(Color.yellow.opacity(particlesOpacity * 0.6))
                                .frame(width: 6, height: 6)
                                .offset(y: -50)
                                .rotationEffect(.degrees(Double(i) * 22.5))
                                .scaleEffect(particlesScale * 1.2)
                                .opacity(particlesOpacity)
                        }
                        
                        // ═══ STAR GLOW LAYERS ══════════════════════════════
                        
                        // Outer glow
                        Circle()
                            .fill(RadialGradient(
                                colors: [Color.yellow.opacity(starGlow * 0.55),
                                         Color.orange.opacity(starGlow * 0.25), .clear],
                                center: .center, startRadius: 40, endRadius: 150))
                            .frame(width: 300, height: 300)
                            .blur(radius: 35)
                            .scaleEffect(starScale)

                        // Middle glow
                        Circle()
                            .fill(RadialGradient(
                                colors: [Color.yellow.opacity(starGlow),
                                         Color.orange.opacity(starGlow * 0.5), .clear],
                                center: .center, startRadius: 10, endRadius: 70))
                            .frame(width: 150, height: 150)
                            .blur(radius: 18)
                            .scaleEffect(starScale)
                        
                        // Inner bright core
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(starOpacity * 0.9),
                                        Color.yellow.opacity(starOpacity * 0.7),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 35
                                )
                            )
                            .frame(width: 70, height: 70)
                            .blur(radius: 8)
                            .scaleEffect(starScale)

                        // Star image
                        Image("Star_transparent")
                            .resizable().aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                            .colorMultiply(.yellow)
                            .scaleEffect(starScale)
                            .shadow(color: .yellow.opacity(starGlow), radius: 40)
                            .shadow(color: .orange.opacity(starGlow * 0.8), radius: 20)
                            .shadow(color: .white.opacity(starOpacity * 0.5), radius: 10)

                        // Success message
                        Text("A Star is Born! 🌟")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(.yellow)
                            .shadow(color: .yellow.opacity(0.9), radius: 8)
                            .shadow(color: .white.opacity(0.5), radius: 5)
                            .offset(y: 90)
                            .opacity(starOpacity)
                    }
                    .position(x: cx, y: cy)
                    .opacity(starOpacity)
                    .allowsHitTesting(false)  // Don't block interactions
                }
            }
            .onAppear { startSequence() }
        }
    }

    private func startSequence() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 1.2)) { nebulaOpacity = 0 }

            clouds = (0..<4).map { i in
                CloudState(id: i,
                           imageName: "nebula_cloud\(i + 1)",
                           spawnOffset: spawnOffsets[i],
                           dragOffset: .zero)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                phase = .clouds
                
                // Start central nebula cloud animations
                startCentralNebulaAnimation()
                
                for i in clouds.indices {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.45) {
                        withAnimation(.easeIn(duration: 0.9)) {
                            clouds[i].opacity = 1.0
                        }
                    }
                }
                
                // Play audio when floating clouds appear (after first cloud fades in)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    audioNarrator.playAudioFile(named: "nebula_spaceclouds")
                }
            }
        }
    }
    
    private func startCentralNebulaAnimation() {
        // Fade in central nebula
        withAnimation(.easeIn(duration: 0.8)) {
            centralNebulaOpacity = 0.6
        }
        
        // Continuous slow rotation
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            centralNebulaRotation = 360
        }
        
        // Gentle pulsing scale (subtle breathing effect)
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            centralNebulaScale = 1.05  // Changed from 0.35 - gentle pulse from 1.0 to 1.05
        }
    }
    
    private func growCentralNebula() {
        let newScale: CGFloat
        let newOpacity: Double
        
        switch placedCount {
        case 1:
            newScale = 1.15  // Changed from 0.5 - grows 15%
            newOpacity = 0.7
        case 2:
            newScale = 1.30  // Changed from 0.7 - grows 30%
            newOpacity = 0.8
            
            // Play audio after 2 clouds are placed
            audioNarrator.playAudioFile(named: "nebula_bigger")
            
        case 3:
            newScale = 1.50  // Changed from 0.9 - grows 50%
            newOpacity = 0.9
        case 4:
            newScale = 1.75  // Changed from 1.1 - grows 75% (ready for star birth!)
            newOpacity = 1.0
        default:
            return
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) {
            centralNebulaScale = newScale
            centralNebulaOpacity = newOpacity
        }
    }

    private func checkCompletion() {
        guard clouds.filter(\.placed).count == clouds.count else { return }

        // Small delay after last cloud is placed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            phase = .complete
            
            // ═══ SIMULTANEOUS START: Clouds fade + Central nebula fades + Star appears ═══
            
            // Fade out individual clouds immediately
            withAnimation(.easeIn(duration: 0.6)) {
                cloudsGroupOpacity = 0
            }
            
            // Fade out central nebula cloud simultaneously
            withAnimation(.easeIn(duration: 0.6)) {
                centralNebulaOpacity = 0
            }
            
            // ═══ PHASE 1: INNER BURST (simultaneous with cloud fadeout) ═══
            // Inner burst (fast expansion from center) - starts immediately
            innerBurstOpacity = 1.0
            innerBurstScale = 0.1
            withAnimation(.easeOut(duration: 0.5)) {
                innerBurstScale = 2.0
            }
            withAnimation(.easeIn(duration: 0.4).delay(0.3)) {
                innerBurstOpacity = 0
            }
            
            // ═══ PHASE 2: STAR EMERGES (no delay - appears as clouds vanish) ═══
            // Star fades in immediately as clouds fade out
            withAnimation(.spring(response: 1.0, dampingFraction: 0.55)) {
                starScale = 1.25  // Overshoots
                starOpacity = 1.0
            }
            
            // ═══ PHASE 3: MAIN BURST RINGS ═══
            // Start slightly after (0.2s delay for dramatic effect)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                burstOpacity = 1.0
                burstScale = 0.2
                
                // Expanding rings (slower, larger)
                withAnimation(.easeOut(duration: 1.2)) {
                    burstScale = 4.5
                }
                withAnimation(.easeIn(duration: 0.8).delay(0.5)) {
                    burstOpacity = 0
                }
            }
            
            // ═══ PHASE 4: PARTICLES SHOOT OUT ═══
            // Particles shoot out (0.3s delay)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                particlesOpacity = 1.0
                particlesScale = 0.3
                
                withAnimation(.easeOut(duration: 1.0)) {
                    particlesScale = 1.5
                }
                withAnimation(.easeIn(duration: 0.7).delay(0.4)) {
                    particlesOpacity = 0
                }
            }
            
            // ═══ PHASE 5: STAR SETTLES ═══
            // Star settles to normal size
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                    starScale = 1.0
                    audioNarrator.playAudioFile(named: "nebula_babystar")
                }
            }
            
            // ═══ PHASE 6: CONTINUOUS GLOW ═══
            // Start pulsing glow (0.4s delay)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    starGlow = 1.0
                }
            }
        }
    }
}

// MARK: - Star Temperature Slider

struct StarTemperatureSlider: View {
    @Binding var temperature: Double
    let starColor: Color
    let label: (name: String, range: String)

    var body: some View {
        VStack(spacing: 12) {

            // ── Current temperature label ──────────────────────────────
            VStack(spacing: 2) {
                Text("\(label.name) Star")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(starColor)
                    .shadow(color: starColor.opacity(0.7), radius: 8)
                    .animation(.easeInOut(duration: 0.3), value: temperature)

                Text(label.range)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }

            // ── Track + thumb ──────────────────────────────────────────
            ZStack(alignment: .leading) {
                // Rainbow gradient track
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color(red: 1.0, green: 0.2, blue: 0.1), location: 0.00),
                                .init(color: Color(red: 1.0, green: 0.55, blue: 0.1), location: 0.25),
                                .init(color: Color(red: 1.0, green: 0.95, blue: 0.3), location: 0.50),
                                .init(color: Color(red: 1.0, green: 1.0,  blue: 1.0), location: 0.75),
                                .init(color: Color(red: 0.4, green: 0.6,  blue: 1.0), location: 1.00)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)

                // Draggable thumb
                GeometryReader { geo in
                    let thumbX = temperature * (geo.size.width - 28) + 14

                    ZStack {
                        // Glow behind thumb
                        Circle()
                            .fill(starColor.opacity(0.5))
                            .frame(width: 38, height: 38)
                            .blur(radius: 8)

                        // Thumb circle
                        Circle()
                            .fill(starColor)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.9), lineWidth: 2.5)
                            )
                            .shadow(color: starColor, radius: 10)
                            .shadow(color: .black.opacity(0.4), radius: 3)
                    }
                    .position(x: thumbX, y: geo.size.height / 2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let new = (value.location.x - 14) / (geo.size.width - 28)
                                temperature = min(max(new, 0), 1)
                            }
                    )
                    .animation(.interactiveSpring(), value: temperature)
                }
                .frame(height: 14)
            }

            // ── Cool / Hot labels ──────────────────────────────────────
            HStack {
                Label("Coolest", systemImage: "thermometer.low")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(red: 1.0, green: 0.2, blue: 0.1).opacity(0.9))
                Spacer()
                Label("Hottest", systemImage: "thermometer.high")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.9))
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

// MARK: - Color RGB helper

private extension Color {
    /// Returns (r, g, b) in 0…1 range for the built-in named colors used above.
    var rgbComponents: (Double, Double, Double) {
        // Resolve via UIColor
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }
}

// MARK: - Black Hole Absorption Game

struct BlackHoleAbsorptionView: View {
    
    @EnvironmentObject var audioNarrator: AudioNarrator
    
    enum Phase { case idle, showingBlackHole, active, complete }
    
    @State private var phase: Phase = .idle
    @State private var blackHoleOpacity: Double = 0
    @State private var blackHoleScale: CGFloat = 1.7  // Default larger scale
    @State private var blackHoleGlow: Double = 0
    @State private var accretionDiskRotation: Double = 0
    @State private var objectsOpacity: Double = 0
    
    struct FloatingObject: Identifiable {
        let id: Int
        let imageName: String
        var position: CGPoint
        var dragOffset: CGSize = .zero
        var isBeingPulled: Bool = false
        var isPulledIn: Bool = false
        var opacity: Double = 1.0
        var scale: CGFloat = 1.0
        var rotation: Double = 0
        var floatOffset: CGSize = .zero
    }
    
    @State private var objects: [FloatingObject] = []
    @State private var draggedObjectIndex: Int? = nil
    @State private var objectsAbsorbed: Int = 0  // Track number of absorbed objects
    
    // Initial demo objects (cloud and sun)
    @State private var demoCloudPosition: CGPoint = .zero
    @State private var demoCloudOpacity: Double = 0
    @State private var demoCloudScale: CGFloat = 1.0
    @State private var demoCloudRotation: Double = 0
    
    @State private var demoSunPosition: CGPoint = .zero
    @State private var demoSunOpacity: Double = 0
    @State private var demoSunScale: CGFloat = 1.0
    @State private var demoSunRotation: Double = 0
    
    private let objectImages = ["comet", "Star", "moon", "nebula_cloud1"]
    private let pullRadius: CGFloat = 150  // Distance to start pulling (increased)
    private let absorptionRadius: CGFloat = 50  // Distance to be absorbed
    
    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height * 0.38
            
            ZStack {
                // ── Black Hole with rotating vortex behind image ───────
                ZStack {
                    // Layer 1: Outer glow (ultra-minimal)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.purple.opacity(blackHoleGlow * 0.02),   // Reduced from 0.05 (60% cut)
                                    Color.blue.opacity(blackHoleGlow * 0.015),    // Reduced from 0.0375 (60% cut)
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 60,
                                endRadius: 160
                            )
                        )
                        .frame(width: 320, height: 320)
                        .blur(radius: 20)
                        .scaleEffect(blackHoleScale)
                        .opacity(blackHoleOpacity)
                    
                    // Layer 2: Accretion disk (rotating partial ring - reduced size)
                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color.orange.opacity(0.8),
                                    Color.red.opacity(0.7),
                                    Color.yellow.opacity(0.6),
                                    Color.orange.opacity(0.8)
                                ],
                                center: .center
                            ),
                            lineWidth: 5  // Reduced from 10 to 5
                        )
                        .frame(width: 110, height: 110)  // Reduced from 220 to 110
                        .blur(radius: 3)  // Reduced from 5 to 3
                        .rotationEffect(.degrees(accretionDiskRotation))
                        .opacity(blackHoleOpacity * 0.8)
                    
                    // Layer 3: Rotating black center vortex (BEHIND image - reduced 10% more)
                    ZStack {
                        // Swirling gradient layers
                        ForEach(0..<3) { i in
                            Circle()
                                .fill(
                                    AngularGradient(
                                        colors: [
                                            Color.black,
                                            Color.purple.opacity(0.04),   // Reduced from 0.1 (60% cut)
                                            Color.black,
                                            Color.blue.opacity(0.03),     // Reduced from 0.075 (60% cut)
                                            Color.black
                                        ],
                                        center: .center,
                                        startAngle: .degrees(Double(i) * 120),
                                        endAngle: .degrees(Double(i) * 120 + 360)
                                    )
                                )
                                .frame(width: 76 - CGFloat(i) * 11, height: 76 - CGFloat(i) * 11)  // Reduced from 84/72/60 to 76/65/54
                                .blur(radius: 4.5 - CGFloat(i) * 1.1)  // Adjusted blur: 4.5/3.4/2.3
                                .rotationEffect(.degrees(accretionDiskRotation * 1.5 + Double(i) * 40))
                        }
                        
                        // Pure black center (singularity)
                        Circle()
                            .fill(Color.black)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.purple.opacity(0.05),   // Reduced from 0.125 (60% cut)
                                                Color.blue.opacity(0.04)      // Reduced from 0.1 (60% cut)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                    }
                    .opacity(blackHoleOpacity)
                    .scaleEffect(blackHoleScale)
                    
                    // Layer 4: Blackhole_detail image (ON TOP, rotated 10 degrees)
                    Image("Blackhole_detail")
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(10))  // Added 10-degree rotation
                        .opacity(blackHoleOpacity)
                        .scaleEffect(blackHoleScale)
                        .shadow(color: .purple.opacity(blackHoleOpacity * 0.03), radius: 10)   // Reduced from 0.075 (60% cut)
                        .shadow(color: .blue.opacity(blackHoleOpacity * 0.02), radius: 6)      // Reduced from 0.05 (60% cut)
                    
                    // Layer 5: Event horizon glow ring (barely visible)
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.purple.opacity(0.03),   // Reduced from 0.075 (60% cut)
                                    Color.blue.opacity(0.02),     // Reduced from 0.05 (60% cut)
                                    Color.purple.opacity(0.03)    // Reduced from 0.075 (60% cut)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 200, height: 200)
                        .blur(radius: 2)
                        .opacity(blackHoleOpacity * 0.05)  // Reduced from 0.125 (60% cut)
                        .scaleEffect(blackHoleScale)
                    
                    // Layer 6: Inner radial glow (barely visible)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.black,
                                    Color.black,
                                    Color.purple.opacity(blackHoleGlow * 0.02),  // Reduced from 0.05 (60% cut)
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .blur(radius: 10)
                        .opacity(blackHoleOpacity * 0.04)  // Reduced from 0.1 (60% cut)
                        .scaleEffect(blackHoleScale)
                }
                .position(x: cx, y: cy)
                .allowsHitTesting(false)
                
                // ── Initial demo objects (cloud and sun) - get sucked in ──
                if phase == .idle || phase == .showingBlackHole {
                    // Demo cloud (nebula_cloud1)
                    Image("nebula_cloud1")
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 90, height: 90)
                        .opacity(demoCloudOpacity)
                        .scaleEffect(demoCloudScale)
                        .rotationEffect(.degrees(demoCloudRotation))
                        .position(demoCloudPosition)
                        .shadow(color: .purple.opacity(0.6), radius: 15)
                    
                    // Demo sun (Star_transparent)
                    Image("Star_transparent")
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 90, height: 90)
                        .colorMultiply(.yellow)
                        .opacity(demoSunOpacity)
                        .scaleEffect(demoSunScale)
                        .rotationEffect(.degrees(demoSunRotation))
                        .position(demoSunPosition)
                        .shadow(color: .yellow.opacity(0.6), radius: 15)
                }
                
                // ── Hint text ──────────────────────────────────────────
                if phase == .active && !objects.allSatisfy({ $0.isPulledIn }) {
                    Text("Drag objects near the black hole\nto see them get pulled in!")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.purple.opacity(0.95))
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.8), radius: 5)
                        .position(x: cx, y: cy + 140)
                        .allowsHitTesting(false)
                        .opacity(objectsOpacity)
                }
                
                // ── Floating objects (fixed drag glitch) ──────────────
                if phase == .active || phase == .complete {
                    ForEach(objects.indices, id: \.self) { idx in
                        let object = objects[idx]
                        
                        if !object.isPulledIn {
                            let isBeingDragged = draggedObjectIndex == idx
                            let shouldFloat = !isBeingDragged && !object.isBeingPulled
                            
                            Image(object.imageName)
                                .resizable()
                                .renderingMode(.original)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 90, height: 90)  // Increased from 70 to 90
                                .opacity(object.opacity * objectsOpacity)
                                .scaleEffect(object.scale)
                                .rotationEffect(.degrees(object.rotation))
                                .position(
                                    x: object.position.x + object.dragOffset.width + (shouldFloat ? object.floatOffset.width : 0),
                                    y: object.position.y + object.dragOffset.height + (shouldFloat ? object.floatOffset.height : 0)
                                )
                                .gesture(
                                    object.isBeingPulled ? nil :
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            // Direct dragging - update offset
                                            objects[idx].dragOffset = value.translation
                                            draggedObjectIndex = idx
                                            
                                            // Stop any floating animation
                                            objects[idx].floatOffset = .zero
                                            
                                            // Check distance to black hole in real-time
                                            let currentX = object.position.x + value.translation.width
                                            let currentY = object.position.y + value.translation.height
                                            let distance = hypot(currentX - cx, currentY - cy)
                                            
                                            // Visual feedback based on distance
                                            if distance < pullRadius * 0.5 {
                                                // Very close - shrink slightly
                                                withAnimation(.easeOut(duration: 0.1)) {
                                                    objects[idx].scale = 0.85
                                                }
                                            } else if distance < pullRadius {
                                                // Within pull radius - slight scale change
                                                withAnimation(.easeOut(duration: 0.1)) {
                                                    objects[idx].scale = 0.95
                                                }
                                            } else {
                                                // Far away - normal size
                                                withAnimation(.easeOut(duration: 0.1)) {
                                                    objects[idx].scale = 1.0
                                                }
                                            }
                                        }
                                        .onEnded { value in
                                            draggedObjectIndex = nil
                                            
                                            // Calculate final position after drag
                                            let finalX = object.position.x + value.translation.width
                                            let finalY = object.position.y + value.translation.height
                                            let distance = hypot(finalX - cx, finalY - cy)
                                            
                                            // If within pull radius, gravity takes over!
                                            if distance < pullRadius {
                                                // Lock position to where user released
                                                objects[idx].position = CGPoint(x: finalX, y: finalY)
                                                objects[idx].dragOffset = .zero
                                                objects[idx].floatOffset = .zero
                                                
                                                // Start gravitational pull immediately
                                                startPulling(index: idx, centerX: cx, centerY: cy)
                                            } else {
                                                // Too far - snap back to original position with animation
                                                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                                                    objects[idx].dragOffset = .zero
                                                    objects[idx].scale = 1.0
                                                }
                                                // Floating will resume automatically
                                            }
                                        }
                                )
                                .shadow(
                                    color: object.isBeingPulled ? .purple.opacity(0.9) :
                                           isBeingDragged ? .cyan.opacity(0.6) : .white.opacity(0.4),
                                    radius: object.isBeingPulled ? 25 : isBeingDragged ? 15 : 10
                                )
                                .zIndex(isBeingDragged ? 100 : Double(idx))
                        }
                    }
                }
                
                // ── Completion message ─────────────────────────────────
                if phase == .complete {
                    VStack(spacing: 12) {
                        Text("Black Hole Fed! 🌀")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(.purple)
                            .shadow(color: .purple.opacity(0.8), radius: 15)
                            .shadow(color: .white.opacity(0.5), radius: 8)
                        
                        Text("All objects absorbed!")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.cyan)
                            .shadow(color: .black.opacity(0.8), radius: 5)
                    }
                    .position(x: cx, y: cy + 140)
                }
            }
            .onAppear { startSequence() }
        }
    }
    
    private func startSequence() {
        // Play audio when black hole screen opens
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            audioNarrator.playAudioFile(named: "blackhole_look")
        }
        
        // Phase 1: Fade in black hole only
        phase = .showingBlackHole
        
        withAnimation(.easeIn(duration: 0.8)) {
            blackHoleOpacity = 1.0
        }
        
        // Start accretion disk rotation immediately
        withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
            accretionDiskRotation = 360
        }
        
        // Start pulsing glow
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            blackHoleGlow = 1.0
        }
        
        // ═══ DEMO ANIMATION: Cloud and Sun get sucked in (0-3 seconds) ═══
        animateDemoObjects()
        
        // Phase 2: After demo (3 seconds), spawn draggable objects
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            phase = .active
            spawnObjects()
            
            // Fade in objects
            withAnimation(.easeIn(duration: 1.0)) {
                objectsOpacity = 1.0
            }
            
            // Play audio when floating objects appear
            audioNarrator.playAudioFile(named: "blackhole_drag")
        }
    }
    
    private func animateDemoObjects() {
        // Get screen center where black hole is
        let screenWidth = UIScreen.main.bounds.width
        let cx = screenWidth / 2
        let cy = UIScreen.main.bounds.height * 0.38
        
        // Initial positions (close to black hole, on opposite sides)
        let cloudStartX = cx - 130  // Left side
        let cloudStartY = cy - 100   // Above
        
        let sunStartX = cx + 120     // Right side
        let sunStartY = cy + 90      // Below
        
        // Set initial positions
        demoCloudPosition = CGPoint(x: cloudStartX, y: cloudStartY)
        demoSunPosition = CGPoint(x: sunStartX, y: sunStartY)
        
        // Fade in demo objects (0.5s delay after black hole appears)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeIn(duration: 0.4)) {
                demoCloudOpacity = 1.0
                demoSunOpacity = 1.0
            }
            
            // Start spiral absorption animation toward black hole center
            // Duration: 3 seconds total (from fade-in to complete absorption)
            let absorptionDuration: Double = 4.5
            let steps: Int = 80
            
            // Animate cloud absorption
            for step in 0..<steps {
                let progress = Double(step) / Double(steps)
                let delay = absorptionDuration * progress
                
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    let t = progress * progress  // Ease-in (accelerate)
                    
                    // Spiral effect
                    let spiralRotation = progress * 3 * .pi  // 1.5 rotations
                    let spiralRadius = (1.0 - progress) * 40.0
                    
                    let spiralOffsetX = cos(spiralRotation) * spiralRadius
                    let spiralOffsetY = sin(spiralRotation) * spiralRadius
                    
                    // Interpolate toward center
                    let newX = cloudStartX + (cx - cloudStartX) * t + spiralOffsetX
                    let newY = cloudStartY + (cy - cloudStartY) * t + spiralOffsetY
                    
                    withAnimation(.linear(duration: absorptionDuration / Double(steps))) {
                        demoCloudPosition = CGPoint(x: newX, y: newY)
                        demoCloudRotation += 15  // Rotate as it spirals
                        demoCloudScale = 1.0 - progress * 0.9  // Shrink
                        
                        // Fade out near end
                        if progress > 0.7 {
                            demoCloudOpacity = 1.0 - (progress - 0.7) / 0.3
                        }
                    }
                }
            }
            
            // Animate sun absorption (same timing but different path)
            for step in 0..<steps {
                let progress = Double(step) / Double(steps)
                let delay = absorptionDuration * progress
                
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    let t = progress * progress  // Ease-in (accelerate)
                    
                    // Spiral effect (opposite direction from cloud)
                    let spiralRotation = -progress * 3 * .pi  // Counter-clockwise
                    let spiralRadius = (1.0 - progress) * 45.0
                    
                    let spiralOffsetX = cos(spiralRotation) * spiralRadius
                    let spiralOffsetY = sin(spiralRotation) * spiralRadius
                    
                    // Interpolate toward center
                    let newX = sunStartX + (cx - sunStartX) * t + spiralOffsetX
                    let newY = sunStartY + (cy - sunStartY) * t + spiralOffsetY
                    
                    withAnimation(.linear(duration: absorptionDuration / Double(steps))) {
                        demoSunPosition = CGPoint(x: newX, y: newY)
                        demoSunRotation += 12  // Rotate as it spirals
                        demoSunScale = 1.0 - progress * 0.9  // Shrink
                        
                        // Fade out near end
                        if progress > 0.7 {
                            demoSunOpacity = 1.0 - (progress - 0.7) / 0.3
                        }
                    }
                }
            }
            
            // Pulse black hole when objects are absorbed
            DispatchQueue.main.asyncAfter(deadline: .now() + absorptionDuration) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    blackHoleScale = 2.0
                    blackHoleGlow = 1.5
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        blackHoleScale = 1.7
                    }
                }
            }
        }
    }
    
    private func spawnObjects() {
        let screenWidth = UIScreen.main.bounds.width
        let topY: CGFloat = 120  // Moved up from 140 to 120 (20px higher)
        let spacing = screenWidth / CGFloat(objectImages.count + 1)
        
        objects = objectImages.enumerated().map { idx, imageName in
            let spawnX = spacing * CGFloat(idx + 1)
            
            let object = FloatingObject(
                id: idx,
                imageName: imageName,
                position: CGPoint(x: spawnX, y: topY)
            )
            
            // Start floating animation
            startFloating(index: idx)
            
            return object
        }
    }
    
    private func startFloating(index: Int) {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            guard !objects[index].isBeingPulled && !objects[index].isPulledIn && draggedObjectIndex != index else {
                timer.invalidate()
                return
            }
            
            let time = Date().timeIntervalSince1970
            let speed = 0.5 + Double(index) * 0.1
            let phaseOffset = Double(index) * 1.5
            
            let floatX = sin(time * speed + phaseOffset) * 15
            let floatY = cos(time * (speed * 0.7) + phaseOffset) * 10
            
            withAnimation(.linear(duration: 0.05)) {
                objects[index].floatOffset = CGSize(width: floatX, height: floatY)
            }
        }
    }
    
    private func startPulling(index: Int, centerX: CGFloat, centerY: CGFloat) {
        objects[index].isBeingPulled = true
        objects[index].floatOffset = .zero  // Ensure no float offset during pull
        
        // Lock current position (base + drag) as starting point
        let startX = objects[index].position.x + objects[index].dragOffset.width
        let startY = objects[index].position.y + objects[index].dragOffset.height
        
        // Update position to include drag offset, then zero drag
        objects[index].position = CGPoint(x: startX, y: startY)
        objects[index].dragOffset = .zero
        
        // Animate pulling toward center with improved spiral effect
        let baseDuration = 0.015  // Faster pull
        
        Timer.scheduledTimer(withTimeInterval: baseDuration, repeats: true) { timer in
            guard objects[index].isBeingPulled else {
                timer.invalidate()
                return
            }
            
            let currentPosX = objects[index].position.x + objects[index].dragOffset.width
            let currentPosY = objects[index].position.y + objects[index].dragOffset.height
            
            let dx = centerX - currentPosX
            let dy = centerY - currentPosY
            let dist = hypot(dx, dy)
            
            if dist < absorptionRadius {
                // Absorbed!
                withAnimation(.easeIn(duration: 0.25)) {
                    objects[index].opacity = 0
                    objects[index].scale = 0.05
                }
                
                // Pulse black hole with bigger glow (to 2.0 scale)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    blackHoleScale = 2.0  // Changed from 1.2 to 2.0
                    blackHoleGlow = 1.5
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        blackHoleScale = 1.7  // Return to new default 1.7
                    }
                }
                
                objects[index].isPulledIn = true
                objectsAbsorbed += 1
                
                // Play audio after 2 objects are absorbed
                if objectsAbsorbed == 2 {
                    audioNarrator.playAudioFile(named: "blackhole_sucked")
                }
                
                timer.invalidate()
                checkCompletion()
            } else {
                // Pull toward center with stronger acceleration
                let pullStrength: CGFloat = 0.2 + (1.0 - dist / pullRadius) * 0.15
                
                withAnimation(.linear(duration: baseDuration)) {
                    objects[index].dragOffset.width += dx * pullStrength
                    objects[index].dragOffset.height += dy * pullStrength
                    
                    // Add faster spiral rotation
                    objects[index].rotation += 12
                    
                    // Fade as approaching
                    let fadeStart: CGFloat = 100
                    if dist < fadeStart {
                        objects[index].opacity = Double(max(0.2, dist / fadeStart))
                    }
                    
                    // Shrink as approaching
                    let shrinkStart: CGFloat = 90
                    if dist < shrinkStart {
                        objects[index].scale = 0.3 + (dist / shrinkStart) * 0.6
                    }
                }
            }
        }
    }
    
    private func checkCompletion() {
        guard objects.allSatisfy({ $0.isPulledIn }) else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            phase = .complete
            
            // Black hole satisfied pulse (bigger from 1.7 base)
            withAnimation(.spring(response: 0.8, dampingFraction: 0.5)) {
                blackHoleScale = 2.2  // Changed from 1.2 to 2.2
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    blackHoleScale = 1.7  // Return to new default 1.7
                }
            }
        }
    }
}

// MARK: - Constellation Build Game (Ursa Major)

struct ConstellationBuildView: View {
    
    @EnvironmentObject var audioNarrator: AudioNarrator
    
    enum Phase { case idle, building, complete }
    
    enum ConstellationType: String, CaseIterable {
        case ursaMajor = "Ursa Major (The Great Bear)"
        case leo = "Leo (The Lion)"
        case scorpius = "Scorpius (The Scorpion)"
        
        var points: [CGPoint] {
            switch self {
            case .ursaMajor:
                // Big Dipper shape - 7 stars
                return [
                    CGPoint(x: -100, y: -80),   // Handle start
                    CGPoint(x: -70, y: -50),    // Handle middle
                    CGPoint(x: -40, y: -20),    // Handle end / Bowl start
                    CGPoint(x: 20, y: -15),     // Bowl corner
                    CGPoint(x: 80, y: -10),     // Bowl far corner
                    CGPoint(x: 75, y: 40),      // Bowl bottom right
                    CGPoint(x: 15, y: 35)       // Bowl bottom left
                ]
            case .leo:
                // Lion shape - 10 stars (enhanced)
                return [
                    CGPoint(x: -100, y: -50),   // Head/nose
                    CGPoint(x: -80, y: -30),    // Face
                    CGPoint(x: -50, y: -45),    // Mane top
                    CGPoint(x: -50, y: -10),    // Neck
                    CGPoint(x: -20, y: -30),    // Shoulder
                    CGPoint(x: 10, y: -25),     // Back
                    CGPoint(x: 40, y: -35),     // Mid back
                    CGPoint(x: 70, y: -15),     // Rear/tail start
                    CGPoint(x: 90, y: 20),      // Tail tip
                    CGPoint(x: -30, y: 30)      // Chest/front leg
                ]
            case .scorpius:
                // Scorpion shape - 12 stars (enhanced)
                return [
                    CGPoint(x: -110, y: -40),   // Claw left
                    CGPoint(x: -90, y: -20),    // Pincer left
                    CGPoint(x: -60, y: -10),    // Head
                    CGPoint(x: -30, y: -5),     // Body segment 1
                    CGPoint(x: 0, y: 0),        // Body segment 2 (heart)
                    CGPoint(x: 30, y: 5),       // Body segment 3
                    CGPoint(x: 55, y: 15),      // Tail start
                    CGPoint(x: 75, y: -5),      // Tail curve up
                    CGPoint(x: 90, y: -30),     // Tail high point
                    CGPoint(x: 100, y: -55),    // Tail hook
                    CGPoint(x: 95, y: -75),     // Stinger base
                    CGPoint(x: -70, y: 20)      // Claw right
                ]
            }
        }
        
        var connections: [(Int, Int)] {
            switch self {
            case .ursaMajor:
                return [
                    (0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 2)
                ]
            case .leo:
                // Enhanced lion connections
                return [
                    (0, 1),   // Face
                    (1, 2),   // Face to mane
                    (2, 3),   // Mane to neck
                    (1, 3),   // Face to neck
                    (3, 4),   // Neck to shoulder
                    (4, 5),   // Shoulder to back
                    (5, 6),   // Back continues
                    (6, 7),   // Back to rear
                    (7, 8),   // Tail
                    (3, 9),   // Neck to chest
                    (4, 9)    // Shoulder to chest (leg)
                ]
            case .scorpius:
                // Enhanced scorpion connections
                return [
                    (0, 1),   // Left claw
                    (1, 2),   // Claw to head
                    (11, 2),  // Right claw to head
                    (2, 3),   // Head to body
                    (3, 4),   // Body segment
                    (4, 5),   // Body segment
                    (5, 6),   // Body to tail
                    (6, 7),   // Tail curves
                    (7, 8),   // Tail rises
                    (8, 9),   // Tail hooks
                    (9, 10)   // Stinger
                ]
            }
        }
        
        var starCount: Int {
            points.count
        }
    }
    
    @State private var phase: Phase = .idle
    @State private var constellationOpacity: Double = 1.0
    @State private var selectedConstellation: ConstellationType
    
    init() {
        // Randomly select constellation on init
        _selectedConstellation = State(initialValue: ConstellationType.allCases.randomElement()!)
    }
    
    struct StarState: Identifiable {
        var id: Int  // Changed to var - will be updated to target position when placed
        let targetPosition: CGPoint  // Where star should be placed (not used for matching anymore)
        var currentPosition: CGPoint  // Where star currently is
        var isPlaced: Bool = false
        var dragOffset: CGSize = .zero
        var floatOffset: CGSize = .zero  // For floating animation
    }
    
    @State private var stars: [StarState] = []
    @State private var glowIntensity: Double = 0
    @State private var completionScale: CGFloat = 1.0
    @State private var constellationScale: CGFloat = 1.5  // Reduced from 1.8 to 1.5
    
    private var ursaMajorPoints: [CGPoint] { selectedConstellation.points }
    private var connections: [(Int, Int)] { selectedConstellation.connections }
    private var starCount: Int { selectedConstellation.starCount }
    
    private let snapDistance: CGFloat = 40  // How close to snap
    
    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height * 0.35
            
            ZStack {
                // ── Initial Constellation image (fades out) ────────────
                Image("Constellation")
                    .resizable().aspectRatio(contentMode: .fit)
                    .frame(width: 220, height: 220)
                    .opacity(constellationOpacity)
                    .animation(.easeOut(duration: 1.2), value: constellationOpacity)
                    .position(x: cx, y: cy)
                    .allowsHitTesting(false)
                
                // ── Constellation lines (outline only) ─────────────────
                if phase == .building || phase == .complete {
                    ZStack {
                        ForEach(connections.indices, id: \.self) { idx in
                            let connection = connections[idx]
                            let start = ursaMajorPoints[connection.0]
                            let end = ursaMajorPoints[connection.1]
                            
                            Path { path in
                                path.move(to: CGPoint(
                                    x: cx + start.x * constellationScale,
                                    y: cy + start.y * constellationScale
                                ))
                                path.addLine(to: CGPoint(
                                    x: cx + end.x * constellationScale,
                                    y: cy + end.y * constellationScale
                                ))
                            }
                            .stroke(
                                phase == .complete ?
                                    LinearGradient(
                                        colors: [
                                            Color.cyan.opacity(0.8 + glowIntensity * 0.2),
                                            Color.blue.opacity(0.6 + glowIntensity * 0.2)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ) :
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.3), Color.blue.opacity(0.2)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                style: StrokeStyle(lineWidth: phase == .complete ? 4 : 3, dash: phase == .complete ? [] : [8, 5])
                            )
                            .shadow(
                                color: phase == .complete ? .cyan.opacity(glowIntensity * 0.8) : .clear,
                                radius: phase == .complete ? 15 : 0
                            )
                        }
                    }
                    .scaleEffect(completionScale)
                }
                
                // ── Target positions (small circles) ───────────────────
                if phase == .building {
                    ForEach(ursaMajorPoints.indices, id: \.self) { idx in
                        let point = ursaMajorPoints[idx]
                        let isOccupied = stars.indices.contains(where: { stars[$0].isPlaced && stars[$0].id == idx })
                        
                        Circle()
                            .strokeBorder(
                                isOccupied ? Color.cyan.opacity(0.6) : Color.white.opacity(0.4),
                                lineWidth: 2
                            )
                            .frame(width: 35, height: 35)
                            .position(
                                x: cx + point.x * constellationScale,
                                y: cy + point.y * constellationScale
                            )
                            .opacity(isOccupied ? 0 : 1)
                            .animation(.easeOut(duration: 0.3), value: isOccupied)
                    }
                }
                
                // ── Hint text ──────────────────────────────────────────
                if phase == .building {
                    Text("Drag stars to complete\n\(selectedConstellation.rawValue)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.cyan.opacity(0.95))
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.8), radius: 5)
                        .position(x: cx, y: cy + 130)
                        .allowsHitTesting(false)
                }
                
                // ── Draggable star emojis (✧) ──────────────────────────────
                if phase == .building {
                    ForEach(stars.indices, id: \.self) { idx in
                        let star = stars[idx]
                        
                        if !star.isPlaced {
                            ZStack {
                                // Outer glow
                                Text("✧")
                                    .font(.system(size: 32))
                                    .foregroundColor(.cyan.opacity(0.3))
                                    .blur(radius: 8)
                                
                                // Main star with gradient effect
                                Text("✧")
                                    .font(.system(size: 24))
                                    .foregroundColor(
                                        Color(red: 0.7, green: 0.9, blue: 1.0)  // Cyan-white
                                    )
                            }
                            .position(
                                x: star.currentPosition.x + star.dragOffset.width + star.floatOffset.width,
                                y: star.currentPosition.y + star.dragOffset.height + star.floatOffset.height
                            )
                            .onAppear {
                                // Start floating animation when star appears
                                startFloatingAnimation(for: idx)
                            }
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        stars[idx].dragOffset = value.translation
                                    }
                                    .onEnded { _ in
                                        let finalX = star.currentPosition.x + stars[idx].dragOffset.width
                                        let finalY = star.currentPosition.y + stars[idx].dragOffset.height
                                        
                                        // Check distance to ANY empty target position
                                        var closestTarget: Int? = nil
                                        var minDistance: CGFloat = snapDistance
                                        
                                        for (targetIdx, targetPoint) in ursaMajorPoints.enumerated() {
                                            // Skip if this position is already occupied
                                            let isOccupied = stars.contains(where: { $0.isPlaced && $0.id == targetIdx })
                                            if isOccupied { continue }
                                            
                                            let targetX = cx + targetPoint.x * constellationScale
                                            let targetY = cy + targetPoint.y * constellationScale
                                            let distance = hypot(finalX - targetX, finalY - targetY)
                                            
                                            if distance < minDistance {
                                                minDistance = distance
                                                closestTarget = targetIdx
                                            }
                                        }
                                        
                                        if let targetIdx = closestTarget {
                                            // Snap to closest empty target
                                            let targetPoint = ursaMajorPoints[targetIdx]
                                            let targetX = cx + targetPoint.x * constellationScale
                                            let targetY = cy + targetPoint.y * constellationScale
                                            
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                                stars[idx].currentPosition = CGPoint(x: targetX, y: targetY)
                                                stars[idx].dragOffset = .zero
                                                stars[idx].floatOffset = .zero  // Stop floating
                                                stars[idx].isPlaced = true
                                                stars[idx].id = targetIdx  // Assign to this position
                                            }
                                            checkCompletion()
                                        } else {
                                            // Snap back
                                            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                                                stars[idx].dragOffset = .zero
                                            }
                                        }
                                    }
                            )
                            .shadow(color: .cyan.opacity(0.6), radius: 12)
                            .shadow(color: .yellow.opacity(0.4), radius: 8)
                        }
                    }
                }
                
                // ── Placed stars (on constellation) ────────────────────
                ForEach(stars.indices, id: \.self) { idx in
                    let star = stars[idx]
                    
                    if star.isPlaced {
                        ZStack {
                            // Outer glow (larger when complete)
                            Text("✧")
                                .font(.system(size: phase == .complete ? 40 : 32))
                                .foregroundColor(.cyan.opacity(phase == .complete ? 0.4 : 0.3))
                                .blur(radius: phase == .complete ? 12 : 8)
                            
                            // Main star
                            Text("✧")
                                .font(.system(size: phase == .complete ? 30 : 24))
                                .foregroundColor(
                                    Color(red: 0.6 + glowIntensity * 0.2, green: 0.85 + glowIntensity * 0.1, blue: 1.0)
                                )
                        }
                        .position(x: star.currentPosition.x, y: star.currentPosition.y)
                        .shadow(
                            color: phase == .complete ? .cyan.opacity(glowIntensity * 0.8) : .cyan.opacity(0.5),
                            radius: phase == .complete ? 20 : 10
                        )
                        .shadow(
                            color: phase == .complete ? .yellow.opacity(glowIntensity * 0.6) : .yellow.opacity(0.3),
                            radius: phase == .complete ? 15 : 8
                        )
                        .scaleEffect(phase == .complete ? completionScale : 1.0)
                    }
                }
                
                // ── Completion message ─────────────────────────────────
                if phase == .complete {
                    Text("\(selectedConstellation.rawValue) Complete! ✨")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.cyan)
                        .shadow(color: .cyan.opacity(glowIntensity), radius: 15)
                        .shadow(color: .yellow.opacity(glowIntensity * 0.7), radius: 10)
                        .position(x: cx, y: cy + 160)
                        .scaleEffect(completionScale)
                }
            }
            .onAppear { 
                startSequence()
                
                // Play constellation_build audio after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    audioNarrator.playAudioFile(named: "constellation_build")
                }
            }
        }
    }
    
    private func startSequence() {
        // Phase 1: Fade out constellation image after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 1.2)) {
                constellationOpacity = 0
            }
            
            // Phase 2: Show constellation outline and spawn stars
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                phase = .building
                spawnStars()
            }
        }
    }
    
    private func spawnStars() {
        // Position stars horizontally above the constellation
        let screenWidth = UIScreen.main.bounds.width
        let aboveY: CGFloat = 80  // Position above constellation (matching other games)
        let spacing = screenWidth / CGFloat(starCount + 1)
        
        stars = ursaMajorPoints.enumerated().map { idx, targetPoint in
            // Spread stars horizontally across the top
            let spawnX = spacing * CGFloat(idx + 1)
            
            return StarState(
                id: idx,
                targetPosition: targetPoint,
                currentPosition: CGPoint(x: spawnX, y: aboveY),
                isPlaced: false
            )
        }
    }
    
    private func startFloatingAnimation(for index: Int) {
        // Skip if star is placed
        guard !stars[index].isPlaced else { return }
        
        // Create unique animation timing for each star
        let baseDelay = Double(index) * 0.2
        let verticalDuration = 2.0 + Double(index) * 0.15
        let horizontalDuration = 2.3 + Double(index) * 0.2
        
        // Vertical floating (up and down)
        withAnimation(
            .easeInOut(duration: verticalDuration)
            .repeatForever(autoreverses: true)
            .delay(baseDelay)
        ) {
            stars[index].floatOffset.height = CGFloat.random(in: -8...8)
        }
        
        // Horizontal floating (left and right)
        withAnimation(
            .easeInOut(duration: horizontalDuration)
            .repeatForever(autoreverses: true)
            .delay(baseDelay + 0.4)
        ) {
            stars[index].floatOffset.width = CGFloat.random(in: -10...10)
        }
    }
    
    private func checkCompletion() {
        guard stars.allSatisfy({ $0.isPlaced }) else { return }
        
        // All stars placed!
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            phase = .complete
            
            // Play constellation-specific completion audio
            switch selectedConstellation {
            case .leo:
                audioNarrator.playAudioFile(named: "constellation_leo")
            case .scorpius:
                audioNarrator.playAudioFile(named: "constellation_scorpius")
            case .ursaMajor:
                audioNarrator.playAudioFile(named: "constellation_ursamajor")
                break
            }
            
            // Glow animation
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowIntensity = 1.0
            }
            
            // Pulse animation
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                completionScale = 1.15
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                    completionScale = 1.0
                }
            }
        }
    }
}

// MARK: - Supernova Collapse Game

struct SupernovaCollapseView: View {
    
    @EnvironmentObject var audioNarrator: AudioNarrator
    
    enum Phase { case idle, elements, complete }
    
    @State private var phase: Phase = .idle
    @State private var supernovaOpacity: Double = 1.0
    
    struct ElementState: Identifiable {
        let id: Int
        let imageName: String
        var spawnOffset: CGSize
        var dragOffset: CGSize
        var opacity: Double = 0
        var placed: Bool = false
        var floatOffset: CGSize = .zero
    }
    
    @State private var elements: [ElementState] = []
    @State private var sunOpacity: Double = 0
    @State private var sunScale: CGFloat = 1.0
    @State private var sunColor: Color = Color(red: 1.0, green: 0.9, blue: 0.3)  // Default yellow
    @State private var shakeOffset: CGFloat = 0
    @State private var explosionScale: CGFloat = 0.1
    @State private var explosionGlow: Double = 0
    @State private var explosionOpacity: Double = 0
    @State private var elementsGroupOpacity: Double = 1
    @State private var shockwaveScale: CGFloat = 0
    @State private var shockwaveOpacity: Double = 0
    
    private let centerZoneRadius: CGFloat = 80
    
    // Spawn positions scattered in circular pattern around star (5 elements)
    // Using polar coordinates converted to offsets for natural circular distribution
    private let spawnOffsets: [CGSize] = [
        CGSize(width: -150, height: -120),  // Upper-left (10 o'clock)
        CGSize(width: 80, height: -170),    // Upper-right (1 o'clock)
        CGSize(width: 165, height: -50),    // Right (3 o'clock)
        CGSize(width: 90, height: 140),     // Lower-right (5 o'clock)
        CGSize(width: -140, height: 110)    // Lower-left (7 o'clock)
    ]
    
    private var placedCount: Int { elements.filter(\.placed).count }
    
    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height * 0.38
            
            ZStack {
                // ── Initial Supernova image (fades out) ──────────────
                Image("Supernova")
                    .resizable().aspectRatio(contentMode: .fit)
                    .frame(width: 220, height: 220)
                    .opacity(supernovaOpacity)
                    .animation(.easeOut(duration: 1.2), value: supernovaOpacity)
                    .position(x: cx, y: cy)
                    .allowsHitTesting(false)
                
                // ── Central Sun (Star_transparent with expanding size and color) ──
                if phase == .elements || phase == .complete {
                    ZStack {
                        // Outer glow (largest, color changes with sun)
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        sunColor.opacity(sunOpacity * 0.6),
                                        sunColor.opacity(sunOpacity * 0.4),
                                        sunColor.opacity(sunOpacity * 0.2),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 40,
                                    endRadius: 120
                                )
                            )
                            .frame(width: 240, height: 240)
                            .blur(radius: 30)
                            .scaleEffect(sunScale)
                        
                        // Middle glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        sunColor.opacity(sunOpacity * 0.8),
                                        sunColor.opacity(sunOpacity * 0.5),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 70
                                )
                            )
                            .frame(width: 140, height: 140)
                            .blur(radius: 20)
                            .scaleEffect(sunScale)
                        
                        // Inner bright core
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(sunOpacity),
                                        sunColor.opacity(sunOpacity * 0.8),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 5,
                                    endRadius: 40
                                )
                            )
                            .frame(width: 80, height: 80)
                            .blur(radius: 10)
                            .scaleEffect(sunScale)
                        
                        // Star_transparent image with shake and color multiply
                        Image("Star_transparent")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                            .opacity(sunOpacity)
                            .colorMultiply(sunColor)
                            .scaleEffect(sunScale)
                            .offset(x: shakeOffset, y: shakeOffset * 0.7)
                            .shadow(color: sunColor.opacity(sunOpacity * 0.8), radius: 20)
                            .shadow(color: .white.opacity(sunOpacity * 0.5), radius: 10)
                    }
                    .position(x: cx, y: cy)
                    .allowsHitTesting(false)
                }
                
                // ── Drop zone hint (text only, no circle) ────────────
                if phase == .elements && placedCount < 5 {
                    Text("Drag all elements to the Sun\nto trigger the explosion!")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.orange.opacity(0.95))
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.8), radius: 5)
                        .position(x: cx, y: cy + centerZoneRadius + 30)
                        .allowsHitTesting(false)
                }
                
                // ── Draggable floating elements ───────────────────────
                ForEach(elements.indices, id: \.self) { idx in
                    let element = elements[idx]
                    
                    Image(element.imageName)
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 90, height: 90)
                        .opacity(element.placed ? 0 : element.opacity * elementsGroupOpacity)  // Fade to 0 when placed
                        .scaleEffect(element.placed ? 0.3 : 1.0)  // Shrink when placed
                        .shadow(color: .orange.opacity(element.placed ? 0 : 0.7), radius: 15)
                        .animation(.easeOut(duration: 0.6), value: element.placed)  // Smooth fade animation
                        .contentShape(Rectangle())
                        .position(
                            x: cx + element.spawnOffset.width + element.dragOffset.width + element.floatOffset.width,
                            y: cy + element.spawnOffset.height + element.dragOffset.height + element.floatOffset.height
                        )
                        .simultaneousGesture(
                            element.placed ? nil :
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    elements[idx].dragOffset = CGSize(
                                        width: value.translation.width,
                                        height: value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    let finalX = cx + element.spawnOffset.width + elements[idx].dragOffset.width
                                    let finalY = cy + element.spawnOffset.height + elements[idx].dragOffset.height
                                    let dist = hypot(finalX - cx, finalY - cy)
                                    
                                    if dist < centerZoneRadius {
                                        // Element placed in sun - fade it out
                                        withAnimation(.easeOut(duration: 0.6)) {
                                            elements[idx].spawnOffset = .zero
                                            elements[idx].dragOffset = .zero
                                            elements[idx].placed = true
                                        }
                                        
                                        // Trigger sun transformation
                                        updateSunAppearance()
                                        
                                        // Check if all elements are placed
                                        checkCompletion()
                                    } else {
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                                            elements[idx].dragOffset = .zero
                                        }
                                    }
                                }
                        )
                        .zIndex(element.placed ? 0 : 1)
                }
                
                // ── Supernova explosion ───────────────────────────────
                if phase == .complete {
                    ZStack {
                        // Shockwave rings
                        ForEach(0..<3) { i in
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.orange.opacity(shockwaveOpacity * 0.8),
                                            Color.red.opacity(shockwaveOpacity * 0.5),
                                            Color.yellow.opacity(shockwaveOpacity * 0.3)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 4
                                )
                                .frame(width: 150, height: 150)
                                .scaleEffect(shockwaveScale * (1.0 + Double(i) * 0.15))
                                .opacity(shockwaveOpacity * (1.0 - Double(i) * 0.3))
                        }
                        
                        // Explosion burst
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(explosionGlow),
                                        Color.yellow.opacity(explosionGlow * 0.8),
                                        Color.orange.opacity(explosionGlow * 0.6),
                                        Color.red.opacity(explosionGlow * 0.4),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 200
                                )
                            )
                            .frame(width: 400, height: 400)
                            .scaleEffect(explosionScale)
                            .blur(radius: 30)
                        
                        // Core explosion
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(explosionGlow * 1.2),
                                        Color.orange.opacity(explosionGlow),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 100
                                )
                            )
                            .frame(width: 200, height: 200)
                            .scaleEffect(explosionScale)
                            .blur(radius: 15)
                        
                        // Supernova image (final result)
                        Image("Supernova")
                            .resizable().aspectRatio(contentMode: .fit)
                            .frame(width: 180, height: 180)
                            .scaleEffect(explosionScale)
                            .opacity(explosionOpacity)
                            .shadow(color: .orange.opacity(explosionGlow), radius: 50)
                            .shadow(color: .red.opacity(explosionGlow * 0.8), radius: 30)
                        
                        Text("Supernova Explosion! 💥")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(.orange)
                            .shadow(color: .orange.opacity(0.9), radius: 8)
                            .shadow(color: .white.opacity(0.5), radius: 5)
                            .offset(y: 100)
                            .opacity(explosionOpacity)
                    }
                    .position(x: cx, y: cy)
                    .opacity(explosionOpacity)
                    .allowsHitTesting(false)
                }
            }
            .onAppear { startSequence() }
        }
    }
    
    private func updateSunAppearance() {
        let count = placedCount
        
        // Progressive color and size changes based on how many elements are placed
        switch count {
        case 1:
            // First element: Dark yellow/orange
            withAnimation(.easeInOut(duration: 0.8)) {
                sunColor = Color(red: 1.0, green: 0.85, blue: 0.3)  // Warm yellow
                sunScale = 1.3  // Increased from 1.15
            }
            
            // Play audio when first object is added
            audioNarrator.playAudioFile(named: "supernova_glowing")
            
        case 2:
            // Second element: Bright yellow → white
            withAnimation(.easeInOut(duration: 0.8)) {
                sunColor = Color(red: 1.0, green: 0.95, blue: 0.65)  // Yellow-white
                sunScale = 1.65  // Increased from 1.35
            }
            
        case 3:
            // Third element: White with blue tint
            withAnimation(.easeInOut(duration: 0.8)) {
                sunColor = Color(red: 0.9, green: 0.95, blue: 1.0)  // White-blue
                sunScale = 2.1  // Increased from 1.6
            }
            
        case 4:
            // Fourth element: Blue (very hot)
            withAnimation(.easeInOut(duration: 0.8)) {
                sunColor = Color(red: 0.65, green: 0.8, blue: 1.0)  // Light blue
                sunScale = 2.6  // Increased from 1.85
            }
            
        case 5:
            // Fifth element: Intense blue, ready to explode
            withAnimation(.easeInOut(duration: 0.7)) {
                sunColor = Color(red: 0.5, green: 0.7, blue: 1.0)  // Deep blue
                sunScale = 3.2  // Increased from 2.1 - massive!
            }
            
        default:
            break
        }
    }
    
    private func startShaking() {
        // Violent shaking before explosion
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if phase == .complete {
                timer.invalidate()
                return
            }
            
            let intensity: CGFloat = 8.0  // Shake intensity
            shakeOffset = CGFloat.random(in: -intensity...intensity)
        }
    }
    
    private func startSequence() {
        // Phase 1: Fade out initial supernova (after 2 seconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 1.2)) {
                supernovaOpacity = 0
            }
            
            // Phase 2: Fade in sun and spawn elements
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeIn(duration: 0.8)) {
                    sunOpacity = 1.0
                }
                
                // Create 5 elements: 3 hydrogen + 2 dust
                elements = [
                    ElementState(id: 0, imageName: "supernova_hydrogen", spawnOffset: spawnOffsets[0], dragOffset: .zero),
                    ElementState(id: 1, imageName: "supernova_hydrogen", spawnOffset: spawnOffsets[1], dragOffset: .zero),
                    ElementState(id: 2, imageName: "supernova_hydrogen", spawnOffset: spawnOffsets[2], dragOffset: .zero),
                    ElementState(id: 3, imageName: "supernova_dust", spawnOffset: spawnOffsets[3], dragOffset: .zero),
                    ElementState(id: 4, imageName: "supernova_dust", spawnOffset: spawnOffsets[4], dragOffset: .zero)
                ]
                
                phase = .elements
                
                // Fade in elements one by one with staggered timing
                for i in elements.indices {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.35) {
                        withAnimation(.easeIn(duration: 0.9)) {
                            elements[i].opacity = 1.0
                        }
                        startFloating(index: i)
                    }
                }
                
                // Play audio when floating objects appear
                audioNarrator.playAudioFile(named: "supernova_starfeed")
            }
        }
    }
    
    private func startFloating(index: Int) {
        // Orbital-like floating animation with circular motion
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            guard phase == .elements, !elements[index].placed else {
                timer.invalidate()
                return
            }
            
            let time = Date().timeIntervalSince1970
            // Each element has unique orbital characteristics
            let baseSpeed = 0.4 + Double(index) * 0.08  // Different orbital speeds
            let phaseOffset = Double(index) * 1.3  // Stagger the orbits
            
            // Circular motion (like orbiting)
            let orbitRadius: CGFloat = 25 + CGFloat(index) * 5  // Varied orbit sizes
            let angle = time * baseSpeed + phaseOffset
            
            let floatX = cos(angle) * orbitRadius
            let floatY = sin(angle) * orbitRadius * 0.7  // Elliptical (not perfect circle)
            
            // Add some gentle drift
            let driftX = sin(time * 0.3 + phaseOffset) * 8
            let driftY = cos(time * 0.25 + phaseOffset) * 6
            
            withAnimation(.linear(duration: 0.05)) {
                elements[index].floatOffset = CGSize(
                    width: floatX + driftX,
                    height: floatY + driftY
                )
            }
        }
    }
    
    private func checkCompletion() {
        guard elements.filter(\.placed).count == elements.count else { return }

        // All elements placed - start final sequence
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            
            // Phase 1: Violent shaking (1.5 seconds)
            startShaking()
            
            // Elements fade out during shaking
            withAnimation(.easeIn(duration: 1.2)) {
                elementsGroupOpacity = 0
            }
            
            // Phase 2: Explosion (after shaking)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                phase = .complete
                shakeOffset = 0  // Stop shaking
                
                // Play explosion audio
                audioNarrator.playAudioFile(named: "supernova_explosion")
                
                // Shockwave and explosion start immediately (no delay)
                shockwaveOpacity = 1.0
                shockwaveScale = 0.3
                withAnimation(.easeOut(duration: 1.2)) {
                    shockwaveScale = 5.0
                }
                withAnimation(.easeIn(duration: 0.8).delay(0.5)) {
                    shockwaveOpacity = 0
                }
                
                // Main explosion starts immediately
                explosionOpacity = 0.5
                withAnimation(.spring(response: 1.2, dampingFraction: 0.5)) {
                    explosionScale = 1.4
                    explosionOpacity = 1.0
                }
                
                // Sun fades out at the SAME TIME as explosion appears
                withAnimation(.easeOut(duration: 0.6)) {
                    sunOpacity = 0
                }
                
                // Pulsing glow
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    explosionGlow = 1.0
                }
                
                // Settle to final size
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
                        explosionScale = 1.0
                    }
                }
            }
        }
    }
}

// MARK: - Fact Card (Reused from Planets)
struct DeepSpaceFactCard: View {
    let number: Int
    let fact: String
    let color: Color
    let isVisible: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Number badge
            Text("\(number)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(color)
                )
            
            // Fact text
            Text(fact)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            
            // Speaker icon
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(color.opacity(0.8))
                .frame(width: 28, height: 28)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
        .opacity(isVisible ? 1 : 0)
        .offset(x: isVisible ? 0 : -50)
    }
}

#Preview {
    DeepSpaceExploreView()
        .environmentObject(GameProgress())
        .environmentObject(AudioNarrator())
}
