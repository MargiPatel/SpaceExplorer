import SwiftUI
import Lottie

struct ExploreView: View {
    @EnvironmentObject var gameProgress: GameProgress
    @EnvironmentObject var audioNarrator: AudioNarrator
    @EnvironmentObject var profileManager: UserProfileManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var highlightedCardIndex: Int? = nil
    @State private var highlightTask: Task<Void, Never>? = nil
    
    // Static property to track if welcome narration has played this app launch
    private static var hasPlayedWelcomeNarration = false
    // Static property to track if card highlight cycle has run this app launch
    private static var hasRunCardHighlightCycle = false
    
    // No astronaut animation states needed
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geo in
              ZStack {
                // Background image — sized to full screen including safe areas
                Image("space_background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                if isIPad {
                    // iPad Layout - More spacious with horizontal cards
                    iPadLayout
                } else {
                    // iPhone Layout - Original vertical layout
                    iPhoneLayout
                }
              }
              .frame(width: geo.size.width, height: geo.size.height)
            }
            .ignoresSafeArea()
            .navigationBarHidden(true)
        }
        .task {
            // Only run card highlight cycle once per app launch
            if !Self.hasRunCardHighlightCycle {
                Self.hasRunCardHighlightCycle = true
                highlightTask = Task {
                    await startCardHighlightCycle()
                }
            }
        }
        .onAppear {
            playWelcomeNarration()
            
            // Ensure tab bar is visible (in case coming back from child view)
            print("🔄 ExploreView appeared")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                for scene in UIApplication.shared.connectedScenes {
                    if let windowScene = scene as? UIWindowScene {
                        for window in windowScene.windows {
                            if let tabBarController = window.rootViewController as? UITabBarController {
                                print("✅ Showing tab bar")
                                tabBarController.tabBar.isHidden = false
                                return
                            }
                        }
                    }
                }
                print("❌ Could not find tab bar in ExploreView")
            }
        }
        .onDisappear {
            highlightedCardIndex = nil
            
            // Cancel the card highlight cycle task
            highlightTask?.cancel()
            highlightTask = nil
            
            // Stop audio narration when leaving ExploreView (tab switch)
            print("🚪 ExploreView disappeared - stopping audio")
            audioNarrator.stop()
        }
        .onChange(of: scenePhase) { newPhase in
            // Stop audio if app goes to background
            if newPhase == .background || newPhase == .inactive {
                print("📱 App went to background - stopping audio")
                audioNarrator.stop()
            }
        }
        .toolbar(.visible, for: .tabBar)
    }

    // MARK: - iPad Layout
    
    private var iPadLayout: some View {
        VStack(spacing: 0) {
            // Home button in top-right corner
            HStack {
                Spacer()
                
                Button(action: {
                    audioNarrator.playTapSound()
                    audioNarrator.stop()
                    profileManager.signOut()
                }) {
                    homeButton
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 30)
            
            Spacer()
            
            // Welcome message - centered
            VStack(spacing: 16) {
                // Astronaut Lottie Animation
                DelayedLottieView(
                    animationName: "Astronaut Illustration",
                    width: 200,
                    height: 200,
                    playDelay: 4.0,
                    contentMode: .scaleAspectFit,
                    loopMode: .loop
                )
                .shadow(color: .white.opacity(0.3), radius: 20)
                
                Text("Hi, Space Explorer!")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 5)
                
                Text("Get ready to blast off!")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.5), radius: 3)
            }
            
            Spacer()
            
            // Exploration options - Horizontal layout for iPad
            HStack(spacing: 24) {
                // Earth's Atmosphere
                NavigationLink(destination: AtmosphereExploreView()) {
                    ExploreOptionCard(
                        title: "Earth's Atmosphere",
                        subtitle: "5 amazing layers",
                        imageName: "earth_planet",
                        color: Color(hex: "#4A90E2"),
                        isHighlighted: highlightedCardIndex == 0,
                        index: 0,
                        isIPad: true
                    )
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded {
                    print("🚪 Navigating to Earth's Atmosphere - stopping audio")
                    audioNarrator.stop()
                })
                
                // Planets
                NavigationLink(destination: PlanetsExploreView()) {
                    ExploreOptionCard(
                        title: "Planets",
                        subtitle: "8 incredible worlds",
                        imageName: "Planets",
                        color: Color(hex: "#9D7CBF"),
                        isHighlighted: highlightedCardIndex == 1,
                        index: 1,
                        isIPad: true
                    )
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded {
                    print("🚪 Navigating to Planets - stopping audio")
                    audioNarrator.stop()
                })
                
                // Deep Space
                NavigationLink(destination: DeepSpaceExploreView()) {
                    ExploreOptionCard(
                        title: "Deep Space",
                        subtitle: "Stars & black holes",
                        imageName: "Galaxy",
                        color: Color(hex: "#2D3748"),
                        isHighlighted: highlightedCardIndex == 2,
                        index: 2,
                        isIPad: true
                    )
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded {
                    print("🚪 Navigating to Deep Space - stopping audio")
                    audioNarrator.stop()
                })
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    // MARK: - iPhone Layout
    
    private var iPhoneLayout: some View {
        VStack(spacing: 30) {
            // Home button in top-right corner
            HStack {
                Spacer()
                
                Button(action: {
                    audioNarrator.playTapSound()
                    audioNarrator.stop()
                    profileManager.signOut()
                }) {
                    homeButton
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 50)
            
            // Welcome message
            VStack(spacing: 12) {
                // Astronaut Lottie Animation (plays once after 4 seconds)
                DelayedLottieView(
                    animationName: "Astronaut Illustration",
                    width: 150,
                    height: 150,
                    playDelay: 4.0,
                    contentMode: .scaleAspectFit,
                    loopMode: .loop
                )
                .shadow(color: .white.opacity(0.3), radius: 20)
                
                Text("Hi, Space Explorer!")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 5)
                
                Text("Get ready to blast off!")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.5), radius: 3)
            }
            .padding(.top, 10)
            
            // Exploration options - Vertical layout for iPhone
            VStack(spacing: 14) {
                // Earth's Atmosphere
                NavigationLink(destination: AtmosphereExploreView()) {
                    ExploreOptionCard(
                        title: "Earth's Atmosphere",
                        subtitle: "5 amazing layers",
                        imageName: "earth_planet",
                        color: Color(hex: "#4A90E2"),
                        isHighlighted: highlightedCardIndex == 0,
                        index: 0,
                        isIPad: false
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .simultaneousGesture(TapGesture().onEnded {
                    print("🚪 Navigating to Earth's Atmosphere - stopping audio")
                    audioNarrator.stop()
                })
                
                // Planets
                NavigationLink(destination: PlanetsExploreView()) {
                    ExploreOptionCard(
                        title: "Planets",
                        subtitle: "8 incredible worlds",
                        imageName: "Planets",
                        color: Color(hex: "#9D7CBF"),
                        isHighlighted: highlightedCardIndex == 1,
                        index: 1,
                        isIPad: false
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .simultaneousGesture(TapGesture().onEnded {
                    print("🚪 Navigating to Planets - stopping audio")
                    audioNarrator.stop()
                })
                
                // Deep Space
                NavigationLink(destination: DeepSpaceExploreView()) {
                    ExploreOptionCard(
                        title: "Deep Space",
                        subtitle: "Stars & black holes",
                        imageName: "Galaxy",
                        color: Color(hex: "#2D3748"),
                        isHighlighted: highlightedCardIndex == 2,
                        index: 2,
                        isIPad: false
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .simultaneousGesture(TapGesture().onEnded {
                    print("🚪 Navigating to Deep Space - stopping audio")
                    audioNarrator.stop()
                })
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
    
    // MARK: - Shared Home Button
    
    private var homeButton: some View {
        ZStack {
            // Gradient background
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.8),
                            Color.blue.opacity(0.6),
                            Color.cyan.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: isIPad ? 60 : 50, height: isIPad ? 60 : 50)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.6),
                                    Color.cyan.opacity(0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
            
            Image(systemName: "house.fill")
                .font(.system(size: isIPad ? 28 : 22))
                .foregroundColor(.white)
        }
        .shadow(color: .purple.opacity(0.5), radius: 10)
        .shadow(color: .blue.opacity(0.3), radius: 5)
    }


    /// Highlights each card one-by-one with a glow every 3 seconds.
    private func startCardHighlightCycle() async {
        
        // Wait until 6 seconds after the view appears
        try? await Task.sleep(nanoseconds: 9_000_000_000)
        if Task.isCancelled { return }

        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.30)) {
                highlightedCardIndex = 0
            }
        }

        // 7th second
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        if Task.isCancelled { return }

        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.40)) {
                highlightedCardIndex = 1
            }
        }

        // 8th second
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        if Task.isCancelled { return }

        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.40)) {
                highlightedCardIndex = 2
            }
        }

        // Turn off after a brief glow
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        if Task.isCancelled { return }

        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.30)) {
                highlightedCardIndex = nil
            }
        }
        
    }

    private func playWelcomeNarration() {
        if Self.hasPlayedWelcomeNarration { return }
        Self.hasPlayedWelcomeNarration = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            audioNarrator.playAudioFile(named: "welcome_narration")
        }
    }
}

// MARK: - Animated Stars Background

struct AnimatedStarsBackground: View {
    var body: some View {
        ZStack {
            ForEach(0..<200, id: \.self) { index in
                TwinklingStarView(index: index)
            }
        }
    }
}

struct TwinklingStarView: View {
    let index: Int
    @State private var opacity: Double = 0.3
    @State private var scale: CGFloat = 0.8
    
    // Random properties (constant per star)
    private let xPercent: CGFloat
    private let yPercent: CGFloat
    private let size: CGFloat
    private let delay: Double
    private let duration: Double
    
    init(index: Int) {
        self.index = index
        // Use index as seed for consistent random values
        var generator = SeededRandomNumberGenerator(seed: UInt64(index))
        self.xPercent = CGFloat.random(in: 0...1, using: &generator)
        self.yPercent = CGFloat.random(in: 0...1, using: &generator)
        self.size = CGFloat.random(in: 3...10, using: &generator)
        self.delay = Double(index) * 0.03
        self.duration = Double.random(in: 1.2...2.5, using: &generator)
    }
    
    var body: some View {
        GeometryReader { geometry in
            StarShape()
                .fill(Color.white)
                .frame(width: size, height: size)
                .opacity(opacity)
                .scaleEffect(scale)
                .shadow(color: .white.opacity(0.9), radius: size * 3)
                .shadow(color: .cyan.opacity(0.5), radius: size * 2)
                .position(
                    x: xPercent * geometry.size.width,
                    y: yPercent * geometry.size.height
                )
                .onAppear {
                    startTwinkling()
                }
        }
    }
    
    private func startTwinkling() {
        // Opacity animation
        withAnimation(
            .easeInOut(duration: duration)
                .repeatForever(autoreverses: true)
                .delay(delay)
        ) {
            opacity = Double.random(in: 0.7...1.0)
        }
        
        // Scale animation for extra twinkle effect
        withAnimation(
            .easeInOut(duration: duration * 0.8)
                .repeatForever(autoreverses: true)
                .delay(delay)
        ) {
            scale = CGFloat.random(in: 1.0...1.5)
        }
    }
}

// Seeded random number generator for consistent star positions
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        state = seed
    }
    
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

// MARK: - Periodic GIF View

struct PeriodicGIFView: View {
    let gifName: String
    let width: CGFloat
    let height: CGFloat
    let playInterval: Double
    
    @State private var isPlaying = false
    @State private var gifData: Data?
    @State private var lastFrameImage: UIImage?
    @State private var hasPlayed = false  // Track if GIF has played once
    
    var body: some View {
        ZStack {
            // Fixed-size container (prevents expansion)
            Color.clear
                .frame(width: width, height: height)
            
            // Content overlaid on top
            Group {
                if let data = gifData {
                    if isPlaying {
                        // Play GIF animation (fixed size, scaleAspectFit)
                        AnimatedGIFImageView(data: data)
                            .frame(width: width, height: height)
                            .clipped()
                    } else {
                        // Show last frame as static image (same scale as GIF)
                        if let lastFrame = lastFrameImage {
                            Image(uiImage: lastFrame)
                                .resizable()
                                .scaledToFit()  // Match GIF's scaleAspectFit
                                .frame(width: width, height: height)
                                .clipped()
                        }
                    }
                }
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .onAppear {
            loadGIF()
            scheduleOneTimePlayback()  // Changed from startPeriodicPlayback
        }
        .onDisappear {
            // Reset so GIF plays again next time view appears
            hasPlayed = false
            isPlaying = false
        }
    }
    
    private func loadGIF() {
        // Try loading from Assets first
        if let asset = NSDataAsset(name: gifName) {
            gifData = asset.data
            extractLastFrame(from: asset.data)  // Changed from extractFirstFrame
        }
        // Fallback: try loading from Bundle
        else if let url = Bundle.main.url(forResource: gifName, withExtension: "gif"),
                let data = try? Data(contentsOf: url) {
            gifData = data
            extractLastFrame(from: data)  // Changed from extractFirstFrame
        } else {
            print("❌ GIF file not found: \(gifName).gif")
        }
    }
    
    private func extractLastFrame(from data: Data) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return
        }
        
        // Get the last frame index
        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0 else { return }
        
        let lastFrameIndex = frameCount - 1  // Last frame
        
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, lastFrameIndex, nil) else {
            return
        }
        
        lastFrameImage = UIImage(cgImage: cgImage)
        print("✅ Extracted last frame (frame \(lastFrameIndex + 1) of \(frameCount))")
    }
    
    private func scheduleOneTimePlayback() {
        // Play GIF once after 4 seconds delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            if !hasPlayed {
                playGIFOnce()
            }
        }
    }
    
    private func playGIFOnce() {
        guard let data = gifData,
              let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return
        }
        
        // Calculate total GIF duration
        let frameCount = CGImageSourceGetCount(source)
        var totalDuration: Double = 0
        
        for i in 0..<frameCount {
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
               let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any],
               let frameDuration = gifProperties[kCGImagePropertyGIFDelayTime as String] as? Double {
                totalDuration += frameDuration
            } else {
                totalDuration += 0.1
            }
        }
        
        // Add small buffer to ensure GIF completes
        let bufferTime = 0.1
        
        // Play GIF
        withAnimation(.linear(duration: 0)) {
            isPlaying = true
            hasPlayed = true  // Mark as played
        }
        
        print("🎬 Playing astronaut GIF once (duration: \(totalDuration)s)")
        
        // Stop after GIF completes (with buffer)
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration + bufferTime) {
            withAnimation(.linear(duration: 0)) {
                isPlaying = false
            }
            print("✅ Astronaut GIF completed - staying on last frame forever")
        }
    }
}

// MARK: - Animated GIF Image View (for periodic playback)

struct AnimatedGIFImageView: UIViewRepresentable {
    let data: Data
    
    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit  // Keep consistent scale
        imageView.clipsToBounds = true
        
        // Create animated image from GIF data
        if let source = CGImageSourceCreateWithData(data as CFData, nil) {
            let frameCount = CGImageSourceGetCount(source)
            var images: [UIImage] = []
            var duration: Double = 0
            
            for i in 0..<frameCount {
                if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                    // Get frame duration
                    if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                       let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any],
                       let frameDuration = gifProperties[kCGImagePropertyGIFDelayTime as String] as? Double {
                        duration += frameDuration
                    } else {
                        duration += 0.1
                    }
                    images.append(UIImage(cgImage: cgImage))
                }
            }
            
            imageView.animationImages = images
            imageView.animationDuration = duration
            imageView.animationRepeatCount = 1 // Play once
            imageView.image = images.last // Set last frame as default image
            imageView.startAnimating()
        }
        
        return imageView
    }
    
    func updateUIView(_ uiView: UIImageView, context: Context) {
        // Don't restart if already animating (prevents blinking)
        // Only ensure contentMode stays consistent
        uiView.contentMode = .scaleAspectFit
    }
}

// MARK: - Star Shape

struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let innerRadius = radius * 0.4
        
        let numberOfPoints = 5
        let angleIncrement = CGFloat.pi * 2 / CGFloat(numberOfPoints * 2)
        var currentAngle: CGFloat = -CGFloat.pi / 2 // Start from top
        
        // Create star points
        for i in 0..<(numberOfPoints * 2) {
            let currentRadius = i % 2 == 0 ? radius : innerRadius
            let x = center.x + cos(currentAngle) * currentRadius
            let y = center.y + sin(currentAngle) * currentRadius
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            currentAngle += angleIncrement
        }
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Explore Option Card

struct ExploreOptionCard: View {
    let title: String
    let subtitle: String
    /// Name of an asset image to show in the icon circle (e.g. "earth_icon").
    let imageName: String
    let color: Color
    var isHighlighted: Bool = false
    let index: Int
    var isIPad: Bool = false

    @State private var glowAnimation = false

    var body: some View {
        if isIPad {
            // Vertical card layout for iPad
            iPadCardLayout
        } else {
            // Horizontal card layout for iPhone
            iPhoneCardLayout
        }
    }
    
    // MARK: - iPad Card (Vertical)
    
    private var iPadCardLayout: some View {
        VStack(spacing: 20) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(color.opacity(0.30))
                    .frame(width: 100, height: 100)

                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 75, height: 75)
                    .clipShape(Circle())
            }
            .frame(width: 100, height: 100)
            
            // Labels
            VStack(alignment: .center, spacing: 8) {
                Text(title)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            
            // Chevron
            Image(systemName: "chevron.right.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cardBackground)
        .contentShape(RoundedRectangle(cornerRadius: 24))
        .overlay(highlightOverlay(cornerRadius: 24))
        .scaleEffect(isHighlighted ? 1.04 : 1.0)
        .shadow(
            color: isHighlighted ? color.opacity(0.8) : .clear,
            radius: isHighlighted ? 28 : 0,
            x: 0, y: 0
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isHighlighted)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.15) {
                glowAnimation = true
            }
        }
    }
    
    // MARK: - iPhone Card (Horizontal)
    
    private var iPhoneCardLayout: some View {
        HStack(spacing: 16) {

            // ── Icon circle ───────────────────────────────────────────────
            ZStack {
                Circle()
                    .fill(color.opacity(0.30))
                    .frame(width: 72, height: 72)

                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .clipShape(Circle())
            }
            .frame(width: 72, height: 72)   // hard-pin so it never expands

            // ── Labels ────────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // ── Chevron ───────────────────────────────────────────────────
            Image(systemName: "chevron.right.circle.fill")
                .font(.system(size: 26))
                .foregroundColor(.white.opacity(0.85))
                .fixedSize()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(cardBackground)
        .frame(maxWidth: .infinity)
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .overlay(highlightOverlay(cornerRadius: 20))
        .scaleEffect(isHighlighted ? 1.04 : 1.0)
        .shadow(
            color: isHighlighted ? color.opacity(0.8) : .clear,
            radius: isHighlighted ? 28 : 0,
            x: 0, y: 0
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isHighlighted)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.15) {
                glowAnimation = true
            }
        }
    }
    
    // MARK: - Shared Components
    
    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: isIPad ? 24 : 20)
                .fill(
                    LinearGradient(
                        colors: cardGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Shimmer overlay
            RoundedRectangle(cornerRadius: isIPad ? 24 : 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(glowAnimation ? 0.22 : 0.08),
                            Color.clear,
                            Color.white.opacity(glowAnimation ? 0.14 : 0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .animation(
                    .easeInOut(duration: 3.0).repeatForever(autoreverses: true),
                    value: glowAnimation
                )

            // Border
            RoundedRectangle(cornerRadius: isIPad ? 24 : 20)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.55), Color.white.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        }
        .shadow(color: color.opacity(0.45), radius: 14, x: 0, y: 8)
    }
    
    private func highlightOverlay(cornerRadius: CGFloat) -> some View {
        ZStack {
            // Outer glow ring
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    color.opacity(isHighlighted ? 1.0 : 0),
                    lineWidth: isHighlighted ? 3.5 : 0
                )
                .shadow(color: color, radius: isHighlighted ? 20 : 0)
                .shadow(color: color.opacity(0.6), radius: isHighlighted ? 40 : 0)

            // Inner white shimmer edge
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    Color.white.opacity(isHighlighted ? 0.75 : 0),
                    lineWidth: isHighlighted ? 1.5 : 0
                )
                .blur(radius: isHighlighted ? 1 : 0)

            // Full-card color wash
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(color.opacity(isHighlighted ? 0.18 : 0))
        }
    }

    private var cardGradient: [Color] {
        switch title {
        case "Earth's Atmosphere":
            return [Color(hex: "#3A7BD5").opacity(0.85), Color(hex: "#5BA4F5").opacity(0.6)]
        case "Planets":
            return [Color(hex: "#8B5CF6").opacity(0.85), Color(hex: "#C084FC").opacity(0.6)]
        case "Deep Space":
            return [Color(hex: "#1E2A3A").opacity(0.92), Color(hex: "#374151").opacity(0.75)]
        default:
            return [color.opacity(0.7), color.opacity(0.4)]
        }
    }
}

// MARK: - 3D Rotating Sphere

struct Rotating3DSphere: View {
    let emoji: String
    let color: Color
    let rotation: Double
    
    var body: some View {
        ZStack {
            // Check which card this is and use appropriate GIF
            if emoji == "🌍" {
                // Use Earth GIF for Atmosphere card
                RotatingPlanetGIF(
                    gifName: "earth_spin",
                    fallbackImage: "earth_icon",
                    color: color,
                    animationSpeed: 0.5  // Slower Earth rotation
                )
            } else if emoji == "🪐" {
                // Use Saturn GIF for Planets card
                RotatingPlanetGIF(
                    gifName: "saturn_spin",
                    fallbackImage: "saturn_icon",
                    color: color,
                    animationSpeed: 0.4  // Even slower Saturn rotation (majestic!)
                )
            } else {
                // Use emoji-based sphere for other cards
                EmojiSphere(emoji: emoji, color: color, rotation: rotation)
            }
        }
    }
}

// MARK: - Rotating Planet GIF

struct RotatingPlanetGIF: View {
    let gifName: String
    let fallbackImage: String
    let color: Color
    let animationSpeed: Double  // Speed multiplier (0.5 = half speed, 1.0 = normal)
    
    var body: some View {
        ZStack {
            // Shadow/glow behind planet
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            color.opacity(0.6),
                            color.opacity(0.3),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: 35
                    )
                )
                .frame(width: 70, height: 70)
            
            // Animated GIF Planet
            AnimatedPlanetGIF(
                gifName: gifName,
                fallbackImage: fallbackImage,
                color: color,
                animationSpeed: animationSpeed
            )
            .frame(width: 60, height: 60)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.4), radius: 8, x: 3, y: 3)
            .shadow(color: color.opacity(0.6), radius: 15)
            
            // Atmospheric glow overlay (different colors per planet)
            Circle()
                .stroke(
                    LinearGradient(
                        colors: getGlowColors(),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 62, height: 62)
                .blur(radius: 1)
        }
    }
    
    private func getGlowColors() -> [Color] {
        switch gifName {
        case "earth_spin":
            return [
                Color.cyan.opacity(0.4),
                Color.blue.opacity(0.2),
                Color.clear
            ]
        case "saturn_spin":
            return [
                Color.yellow.opacity(0.4),
                Color.orange.opacity(0.2),
                Color.clear
            ]
        default:
            return [
                Color.white.opacity(0.3),
                Color.white.opacity(0.1),
                Color.clear
            ]
        }
    }
}

// MARK: - Animated Planet GIF

struct AnimatedPlanetGIF: View {
    let gifName: String
    let fallbackImage: String
    let color: Color
    let animationSpeed: Double
    
    @State private var gifData: Data?
    
    var body: some View {
        Group {
            if let data = gifData {
                // Display animated GIF with speed control
                GIFImageView(
                    data: data,
                    animationSpeed: animationSpeed,
                    contentMode: gifName == "saturn_spin" ? .scaleAspectFit : .scaleAspectFill
                )
            } else {
                // Fallback: show static image while loading
                Image(fallbackImage)
                    .resizable()
                    .aspectRatio(contentMode: gifName == "saturn_spin" ? .fit : .fill)
            }
        }
        .onAppear {
            loadGIF()
        }
    }
    
    private func loadGIF() {
        // Try loading from Assets first
        if let asset = NSDataAsset(name: gifName) {
            gifData = asset.data
        }
        // Fallback: try loading from Bundle
        else if let url = Bundle.main.url(forResource: gifName, withExtension: "gif"),
                let data = try? Data(contentsOf: url) {
            gifData = data
        }
    }
}

// MARK: - GIF Image View (UIKit wrapper with speed control)

struct GIFImageView: UIViewRepresentable {
    let data: Data
    var animationSpeed: Double = 1.0  // 1.0 = normal, 0.5 = half speed, 2.0 = double speed
    var contentMode: UIView.ContentMode = .scaleAspectFill  // Default to fill
    
    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = contentMode
        imageView.clipsToBounds = true
        
        // Create animated image from GIF data
        if let source = CGImageSourceCreateWithData(data as CFData, nil) {
            let frameCount = CGImageSourceGetCount(source)
            var images: [UIImage] = []
            var duration: Double = 0
            
            for i in 0..<frameCount {
                if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                    // Get frame duration
                    if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                       let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any],
                       let frameDuration = gifProperties[kCGImagePropertyGIFDelayTime as String] as? Double {
                        duration += frameDuration
                    } else {
                        duration += 0.1 // Default frame duration
                    }
                    images.append(UIImage(cgImage: cgImage))
                }
            }
            
            // Apply speed multiplier (slower speed = longer duration)
            let adjustedDuration = duration / animationSpeed
            
            imageView.animationImages = images
            imageView.animationDuration = adjustedDuration
            imageView.animationRepeatCount = 0 // Loop forever
            imageView.startAnimating()
        }
        
        return imageView
    }
    
    func updateUIView(_ uiView: UIImageView, context: Context) {
        // Update content mode if changed
        uiView.contentMode = contentMode
    }
}

// MARK: - Emoji-based Sphere

struct EmojiSphere: View {
    let emoji: String
    let color: Color
    let rotation: Double
    
    var body: some View {
        ZStack {
            // Base sphere with 3D gradient
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            color.opacity(0.8),
                            color.opacity(0.5),
                            color.opacity(0.3)
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: 30
                    )
                )
            
            // Highlight (creates 3D effect)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.6),
                            Color.white.opacity(0.2),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.35, y: 0.35),
                        startRadius: 1,
                        endRadius: 20
                    )
                )
            
            // Shadow side (creates depth)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            Color.black.opacity(0.3),
                            Color.black.opacity(0.5)
                        ],
                        center: UnitPoint(x: 0.7, y: 0.7),
                        startRadius: 5,
                        endRadius: 25
                    )
                )
            
            // Rotating emoji with perspective
            Text(emoji)
                .font(.system(size: 35))
                .rotation3DEffect(
                    .degrees(rotation),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )
                .opacity(0.9)
            
            // Rotating overlay stripes for extra 3D effect
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 60, height: 3)
                    .offset(y: CGFloat(index - 1) * 15)
                    .rotation3DEffect(
                        .degrees(rotation + Double(index * 30)),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.5
                    )
            }
        }
        .shadow(color: color.opacity(0.5), radius: 15)
        .shadow(color: .black.opacity(0.3), radius: 5, x: 3, y: 3)
    }
}

#Preview {
    ExploreView()
        .environmentObject(GameProgress())
        .environmentObject(AudioNarrator())
}

