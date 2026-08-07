import SwiftUI

@main
struct DropsizeApp: App {
    @AppStorage("dropsize_onboarding_complete") private var isOnboardingComplete = false
    @State private var storeManager = StoreManager.shared
    @AppStorage("dropsize_selected_theme") private var selectedTheme = ThemeOption.dark
    
    init() {
        // Customize tab bar visual style to match our dark theme
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color(hex: "090A0F"))
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if !isOnboardingComplete {
                    OnboardingView(isOnboardingComplete: $isOnboardingComplete)
                        .transition(.slide)
                } else {
                    TabView {
                        MainCompressView()
                            .tabItem {
                                Label("Compress", systemImage: "arrow.down.right.and.arrow.up.left")
                            }
                        
                        BatchCompressView()
                            .tabItem {
                                Label("Batch", systemImage: "square.grid.3x3.fill")
                            }
                        
                        HistoryView()
                            .tabItem {
                                Label("History", systemImage: "clock.fill")
                            }
                        
                        SettingsView()
                            .tabItem {
                                Label("Settings", systemImage: "gearshape.fill")
                            }
                    }
                    .tint(Theme.accent)
                }
            }
            .preferredColorScheme(selectedTheme.colorScheme)
        }
    }
}
