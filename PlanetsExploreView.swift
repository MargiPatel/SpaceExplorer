import SwiftUI
import UIKit

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
            print(hidden ? "✅ Hiding tab bar (Planets)" : "✅ Showing tab bar (Planets)")
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


struct PlanetsExploreView: View {
    @EnvironmentObject var gameProgress: GameProgress
    @EnvironmentObject var audioNarrator: AudioNarrator
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var selectedPlanet: Planet?
    @State private var showQuiz = false
    
    private let planets: [Planet]
    private let sun: Planet
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    init() {
        let dataManager = SpaceDataManager()
        self.planets = dataManager.getAllPlanets()
        self.sun = dataManager.getSun()
    }
    
    var body: some View {
        ZStack {
            // Background layer (ignores safe area)
            ZStack {
                // Space background image
                Image("space_background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea(.all)
                
                // Twinkling stars overlay
                ForEach(0..<50, id: \.self) { _ in
                    Circle()
                        .fill(Color.white.opacity(Double.random(in: 0.3...0.9)))
                        .frame(width: CGFloat.random(in: 1...3))
                        .position(
                            x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                            y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                        )
                        .opacity(Double.random(in: 0.5...1.0))
                }
            }
            
            VStack(spacing: 0) {
                // Header with back button at top
                ZStack {
                    // Title in center
                    VStack(spacing: 4) {
                        Text("🌌 Solar System")
                            .font(.system(size: isIPad ? 32 : 24, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .purple.opacity(0.8), radius: 8)
                            .shadow(color: .black.opacity(0.7), radius: 3)
                        
                        Text("Tap any planet to explore")
                            .font(.system(size: isIPad ? 18 : 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.yellow)
                            .shadow(color: .black.opacity(0.7), radius: 3)
                    }
                    
                    // Back button on left (aligned to leading edge)
                    HStack {
                        BackButton {
                            audioNarrator.playTapSound()
                            dismiss()
                        }
                        
                        Spacer()
                        
                        // Quiz button on right
                        QuizButton(topic: .planets)
                    }
                    .padding(.horizontal, isIPad ? 60 : 40)
                }
                .padding(.top, isIPad ? 20 : 30)
                .padding(.bottom, 20)
                
                // Solar System View
                GeometryReader { geometry in
                    SolarSystemOrbitalView(
                        planets: planets,
                        sun: sun,
                        size: geometry.size,
                        onPlanetTapped: { planet in
                            selectedPlanet = planet
                            audioNarrator.playTapSound()
                        },
                        isIPad: isIPad
                    )
                }
            }
        }
        .sheet(item: $selectedPlanet) { planet in
            PlanetDetailView(planet: planet)
        }
        .sheet(isPresented: $showQuiz) {
            QuizGameView(topic: .planets)
                .environmentObject(gameProgress)
                .environmentObject(audioNarrator)
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            // Force hide tab bar
            print("🔄 PlanetsExploreView appeared")
            setTabBarHidden(true)
            
            // Play planets intro audio
            audioNarrator.playAudioFile(named: "Planets_audio")
        }
        .onDisappear {
            // Stop audio and restore tab bar when leaving
            print("🔄 PlanetsExploreView disappeared")
            audioNarrator.stop()
            setTabBarHidden(false)
        }
    }
}

// MARK: - Solar System Orbital View

struct SolarSystemOrbitalView: View {
    let planets: [Planet]
    let sun: Planet
    let size: CGSize
    let onPlanetTapped: (Planet) -> Void
    var isIPad: Bool = false
    
    @State private var rotationAngles: [Double] = [0, 0, 0, 0, 0, 0, 0, 0]
    
    // Orbital parameters for each planet - scaled for iPad
    private var orbitalParameters: [(major: CGFloat, minor: CGFloat)] {
        let scale: CGFloat = isIPad ? 1.4 : 1.0
        return [
            (50 * scale, 50 * scale),    // Mercury - circular orbit
            (75 * scale, 75 * scale),    // Venus
            (100 * scale, 100 * scale),  // Earth
            (125 * scale, 125 * scale),  // Mars
            (160 * scale, 160 * scale),  // Jupiter
            (190 * scale, 190 * scale),  // Saturn
            (215 * scale, 215 * scale),  // Uranus
            (240 * scale, 240 * scale)   // Neptune
        ]
    }
    
    // Orbital speeds - proportional to real orbital periods (scaled for visibility)
    // Real periods: Mercury=88d, Venus=225d, Earth=365d, Mars=687d, 
    //               Jupiter=4333d, Saturn=10759d, Uranus=30687d, Neptune=60190d
    // Speed = 1/period (relative to Earth), then scaled up 5× for best visibility
    private let orbitalSpeeds: [Double] = [
        20.70,  // Mercury: 88 days (365/88 = 4.14 × 5 for visibility)
        8.10,   // Venus: 225 days (365/225 = 1.62 × 5)
        5.00,   // Earth: 365 days (baseline × 5)
        2.65,   // Mars: 687 days (365/687 = 0.53 × 5)
        0.42,   // Jupiter: 4,333 days (365/4333 = 0.084 × 5)
        0.17,   // Saturn: 10,759 days (365/10759 = 0.034 × 5)
        0.060,  // Uranus: 30,687 days (365/30687 = 0.012 × 5)
        0.030   // Neptune: 60,190 days (365/60190 = 0.006 × 5)
    ]
    
    var body: some View {
        ZStack {
            // Central Sun - ROTATING WITH SCENEKIT (Tappable)
            Button(action: {
                onPlanetTapped(sun)
            }) {
                ZStack {
                    let sunSize: CGFloat = isIPad ? 90 : 70
                    let glowSize1: CGFloat = isIPad ? 200 : 160
                    let glowSize2: CGFloat = isIPad ? 130 : 100
                    
                    // Outer glow (largest)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.yellow.opacity(0.6),
                                    Color.orange.opacity(0.4),
                                    Color.red.opacity(0.2),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 80
                            )
                        )
                        .frame(width: glowSize1, height: glowSize1)
                        .blur(radius: 25)
                    
                    // Middle glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.yellow.opacity(0.8),
                                    Color.orange.opacity(0.5),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 15,
                                endRadius: 50
                            )
                        )
                        .frame(width: glowSize2, height: glowSize2)
                        .blur(radius: 15)
                    
                    // Rotating Sun with SceneKit
                    PlanetSceneView(planetName: "Sun", planetColor: "#FDB813")
                        .frame(width: sunSize, height: sunSize)
                        .clipShape(Circle())
                        .shadow(color: .yellow.opacity(0.9), radius: 35)
                        .shadow(color: .orange.opacity(0.7), radius: 25)
                        .allowsHitTesting(false)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .position(x: size.width / 2, y: size.height / 2)
            
            // Elliptical orbital rings and planets
            ForEach(Array(planets.enumerated()), id: \.offset) { index, planet in
                let params = orbitalParameters[index]
                
                // Circular orbital ring
                Ellipse()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: planet.color).opacity(0.3),
                                Color(hex: planet.color).opacity(0.15),
                                Color(hex: planet.color).opacity(0.3)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 1.5, dash: [5, 5])
                    )
                    .frame(width: params.major * 2, height: params.minor * 2)
                    .position(x: size.width / 2, y: size.height / 2)
                
                // Planet on circular orbit - moves along the orbit path
                // Each planet has its own angle that updates independently
                let angleInRadians = rotationAngles[index] * .pi / 180.0
                
                // Calculate position on circle using parametric equations
                let x = size.width / 2 + CGFloat(cos(angleInRadians)) * params.major
                let y = size.height / 2 + CGFloat(sin(angleInRadians)) * params.minor
                
                Button(action: {
                    onPlanetTapped(planet)
                }) {
                    ZStack {
                        // Planet glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(hex: planet.color).opacity(0.6),
                                        Color(hex: planet.color).opacity(0.3),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 8,
                                    endRadius: 30
                                )
                            )
                            .frame(width: 60, height: 60)
                            .blur(radius: 8)
                        
                        // Planet SceneKit view (larger sizes)
                        PlanetSceneView(planetName: planet.name, planetColor: planet.color)
                            .frame(width: getPlanetSize(index: index), height: getPlanetSize(index: index))
                            .clipShape(Circle())
                            .shadow(color: Color(hex: planet.color).opacity(0.7), radius: 12)
                        
                        // Planet name label
                        VStack {
                            Spacer()
                            Text(planet.name)
                                .font(.system(size: isIPad ? 14 : 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, isIPad ? 10 : 8)
                                .padding(.vertical, isIPad ? 4 : 3)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.75))
                                        .overlay(
                                            Capsule()
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [
                                                            Color(hex: planet.color),
                                                            Color(hex: planet.color).opacity(0.5)
                                                        ],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    ),
                                                    lineWidth: 1.5
                                                )
                                        )
                                )
                                .shadow(color: .black.opacity(0.8), radius: 5)
                        }
                        .frame(width: 80, height: getPlanetSize(index: index) + 25)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .position(x: x, y: y)
            }
        }
        .onAppear {
            startOrbitalAnimation()
        }
    }
    
    private func getPlanetSize(index: Int) -> CGFloat {
        // Larger planet sizes with more variation - scaled for iPad
        let baseSizes: [CGFloat] = [28, 35, 38, 32, 50, 48, 42, 40]
        let scale: CGFloat = isIPad ? 1.3 : 1.0
        return baseSizes[index] * scale
    }
    
    private func startOrbitalAnimation() {
        // Start each planet at a different position
        rotationAngles = [0, 45, 90, 135, 180, 225, 270, 315]
        
        // Animate each planet independently using a timer
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            withAnimation(.linear(duration: 0.016)) {
                for i in 0..<rotationAngles.count {
                    // Increment each planet's angle by its speed
                    rotationAngles[i] += orbitalSpeeds[i] * 0.016
                    
                    // Keep angles in 0-360 range
                    if rotationAngles[i] >= 360 {
                        rotationAngles[i] -= 360
                    }
                }
            }
        }
    }
}

// MARK: - Planet Card

struct PlanetCard: View {
    let planet: Planet
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                action()
            }
        }) {
            VStack(spacing: 12) {
                // Planet with 3D SceneKit view
                ZStack {
                    // Glow effect based on planet color
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: planet.color).opacity(0.3),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 25,
                                endRadius: 55
                            )
                        )
                        .frame(width: 110, height: 110)
                        .blur(radius: 10)
                    
                    // Use SceneKit for all planets
                    PlanetSceneView(planetName: planet.name, planetColor: planet.color)
                        .frame(width: 90, height: 90)
                        .clipShape(Circle())
                        .shadow(color: Color(hex: planet.color).opacity(0.6), radius: 20)
                        .allowsHitTesting(false)
                }
                
                Text(planet.name)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: planet.color).opacity(0.3),
                                Color(hex: planet.color).opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(hex: planet.color).opacity(0.5), lineWidth: 2)
                    )
            )
            .shadow(color: Color(hex: planet.color).opacity(0.3), radius: 10)
        }
        .scaleEffect(isPressed ? 0.92 : 1.0)
    }
}

// MARK: - Planet Detail View

struct PlanetDetailView: View {
    let planet: Planet
    @EnvironmentObject var gameProgress: GameProgress
    @EnvironmentObject var audioNarrator: AudioNarrator
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var currentFactIndex = 0
    @State private var showingFact = false
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(hex: planet.color).opacity(0.4),
                    Color(hex: "#0F1419")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Close button - positioned at top right with consistent spacing
            VStack {
                HStack {
                    Spacer()
                    CloseButton {
                        audioNarrator.playTapSound()
                        dismiss()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 70)  // Consistent with all planets including Sun
                }
                Spacer()
            }
            .zIndex(1)  // Keep button on top
            
            // Scrollable content
            ScrollView {
                VStack(spacing: 0) {
                    // Top spacing
                    Spacer()
                        .frame(height: 80)
                    
                    // Rotating planet with 3D SceneKit
                    ZStack {
                        let planetSize: CGFloat = (planet.name == "Saturn" || planet.name == "Uranus") 
                            ? (isIPad ? 380 : 300) 
                            : (isIPad ? 350 : 280)
                        let glowSize: CGFloat = (planet.name == "Saturn" || planet.name == "Uranus")
                            ? (isIPad ? 400 : 320)
                            : (isIPad ? 375 : 300)
                        
                        // Glow effect based on planet color (slightly larger for Saturn and Uranus)
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(hex: planet.color).opacity(0.4),
                                        Color(hex: planet.color).opacity(0.2),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: (planet.name == "Saturn" || planet.name == "Uranus") ? 90 : 80,
                                    endRadius: (planet.name == "Saturn" || planet.name == "Uranus") ? 170 : 160
                                )
                            )
                            .frame(width: glowSize, height: glowSize)
                            .blur(radius: 20)
                        
                        // Use SceneKit 3D view for all planets (slightly larger for Saturn and Uranus to show rings)
                        PlanetSceneView(planetName: planet.name, planetColor: planet.color)
                            .frame(width: planetSize, height: planetSize)
                            .clipShape((planet.name == "Saturn" || planet.name == "Uranus") ? AnyShape(Rectangle()) : AnyShape(Circle()))
                            .shadow(color: Color(hex: planet.color).opacity(0.6), radius: 30)
                    }
                    .padding(.vertical, isIPad ? 30 : 20)
                    
                    // Planet name
                    Text(planet.name)
                        .font(.system(size: isIPad ? 52 : 42, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(radius: 10)
                        .padding(.top, 10)
                    
                    // Instructions for all planets (all use SceneKit now)
                    Text("Drag to rotate")
                        .font(.system(size: isIPad ? 18 : 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.bottom, isIPad ? 40 : 30)
                    
                    // Facts section
                    VStack(spacing: isIPad ? 20 : 16) {
                        ForEach(Array(planet.facts.enumerated()), id: \.offset) { index, fact in
                            FactCard(
                                number: index + 1,
                                fact: fact,
                                color: Color(hex: planet.color),
                                isVisible: showingFact && currentFactIndex >= index,
                                isIPad: isIPad
                            )
                            .onTapGesture {
                           //     audioNarrator.narrate(fact)
                            }
                        }
                    }
                    .padding(.horizontal, isIPad ? 40 : 24)
                    .padding(.bottom, isIPad ? 60 : 40)  // Bottom padding for scroll
                }
            }
        }
        .onAppear {
            gameProgress.explorePlanet(planet.id)
            
            // Play planet-specific audio file (e.g., "Earth_audio.mp4", "Sun_audio.mp4")
            audioNarrator.playAudioFile(named: "\(planet.name)_audio")
            
            // Auto-reveal facts after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                revealFacts()
            }
        }
        .onDisappear {
            // Stop audio when closing detail view
            audioNarrator.stop()
        }
    }
    
    private func revealFacts() {
        showingFact = true
        audioNarrator.playSuccessSound()
        
        // Reveal facts one by one
        for index in 0..<planet.facts.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.3) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    currentFactIndex = index
                }
            }
        }
        
        // Don't narrate facts - audio file already playing
        
        // Award star
        let activityName = "planet_\(planet.name)"
        if !gameProgress.hasActivityBeenCompleted(activityName) {
            gameProgress.completeActivity(activityName)
        }
    }
}

// MARK: - Fact Card

struct FactCard: View {
    let number: Int
    let fact: String
    let color: Color
    let isVisible: Bool
    var isIPad: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: isIPad ? 16 : 12) {
            // Number badge
            Text("\(number)")
                .font(.system(size: isIPad ? 22 : 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: isIPad ? 40 : 32, height: isIPad ? 40 : 32)
                .background(
                    Circle()
                        .fill(color)
                )
            
            // Fact text
            Text(fact)
                .font(.system(size: isIPad ? 20 : 16, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            
            // Speaker icon
          //  Image(systemName: "speaker.wave.2.fill")
          //      .font(.system(size: 16))
          //      .foregroundColor(color)
        }
        .padding(isIPad ? 20 : 16)
        .background(
            RoundedRectangle(cornerRadius: isIPad ? 20 : 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: isIPad ? 20 : 16)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
        .opacity(isVisible ? 1 : 0)
        .offset(x: isVisible ? 0 : -50)
    }
}

// MARK: - AnyShape Helper
struct AnyShape: Shape {
    private let _path: (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        _path = { rect in
            shape.path(in: rect)
        }
    }
    
    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

#Preview {
    PlanetsExploreView()
        .environmentObject(GameProgress())
        .environmentObject(AudioNarrator())
}
