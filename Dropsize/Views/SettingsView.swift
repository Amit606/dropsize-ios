import SwiftUI

struct SettingsView: View {
    @State private var storeManager = StoreManager.shared
    @State private var isPremium = UserDefaultsManager.shared.isPremium
    @State private var stripMetadata = UserDefaultsManager.shared.stripMetadata
    @State private var showPaywall = false
    @State private var alertMessage: String?
    @State private var showAlert = false
    @AppStorage("dropsize_selected_theme") private var selectedTheme = ThemeOption.dark
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                Text("Settings")
                    .font(.title)
                    .fontWeight(.black)
                    .foregroundColor(Theme.primaryText)
                    .padding(.top, 16)
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // Premium Banner
                        if isPremium {
                            GlassmorphicContainer {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Dropsize Premium Active")
                                            .font(.headline)
                                            .foregroundColor(Theme.primaryText)
                                        Text("You have unlimited compression access!")
                                            .font(.subheadline)
                                            .foregroundColor(Theme.secondaryText)
                                    }
                                    Spacer()
                                    Image(systemName: "crown.fill")
                                        .font(.title)
                                        .foregroundColor(.yellow)
                                }
                            }
                            .padding(.horizontal)
                        } else {
                            Button(action: { showPaywall = true }) {
                                GlassmorphicContainer {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Upgrade to Premium")
                                                .font(.headline)
                                                .foregroundColor(Theme.primaryText)
                                            Text("Get unlimited batch modes & widget features.")
                                                .font(.subheadline)
                                                .foregroundColor(Theme.secondaryText)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.headline)
                                            .foregroundColor(Theme.accent)
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                        }
                        
                        // Preferences Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Preferences")
                                .font(.subheadline)
                                .foregroundColor(Theme.secondaryText)
                                .padding(.horizontal)
                            
                            GlassmorphicContainer {
                                VStack(spacing: 16) {
                                    Toggle(isOn: $stripMetadata) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Strip GPS & Exif Metadata")
                                                .font(.headline)
                                                .foregroundColor(Theme.primaryText)
                                            Text("Removes location and camera details to compress files even further.")
                                                .font(.caption)
                                                .foregroundColor(Theme.secondaryText)
                                        }
                                    }
                                    .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                                    .onChange(of: stripMetadata) { _, newValue in
                                        UserDefaultsManager.shared.stripMetadata = newValue
                                    }
                                    
                                    Divider()
                                        .background(Color.white.opacity(0.1))
                                    
                                    // Theme Picker
                                    HStack {
                                        Text("App Theme")
                                            .font(.headline)
                                            .foregroundColor(Theme.primaryText)
                                        Spacer()
                                        Picker("App Theme", selection: $selectedTheme) {
                                            ForEach(ThemeOption.allCases) { option in
                                                Text(option.rawValue).tag(option)
                                            }
                                        }
                                        .pickerStyle(MenuPickerStyle())
                                        .tint(Theme.accent)
                                    }
                                    
                                    Divider()
                                        .background(Color.white.opacity(0.1))
                                    
                                    // Language Row
                                    Button(action: {
                                        if let url = URL(string: UIApplication.openSettingsURLString) {
                                            UIApplication.shared.open(url)
                                        }
                                    }) {
                                        HStack {
                                            Text("App Language")
                                                .font(.headline)
                                                .foregroundColor(Theme.primaryText)
                                            Spacer()
                                            let currentLangCode = Locale.current.language.languageCode?.identifier ?? "en"
                                            let currentLangName = Locale.current.localizedString(forLanguageCode: currentLangCode) ?? "English"
                                            Text(currentLangName)
                                                .font(.subheadline)
                                                .foregroundColor(Theme.secondaryText)
                                            Image(systemName: "arrow.up.forward.square")
                                                .foregroundColor(Theme.secondaryText)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Usage limits section
                        if !isPremium {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Usage")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.secondaryText)
                                    .padding(.horizontal)
                                
                                GlassmorphicContainer {
                                    HStack {
                                        Text("Free Compressions Remaining Today")
                                            .foregroundColor(Theme.primaryText)
                                        Spacer()
                                        Text("\(UserDefaultsManager.shared.remainingFreeCompressions) / 3")
                                            .fontWeight(.bold)
                                            .foregroundColor(Theme.accent)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Restoration Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Store")
                                .font(.subheadline)
                                .foregroundColor(Theme.secondaryText)
                                .padding(.horizontal)
                            
                            GlassmorphicContainer {
                                Button(action: restorePurchases) {
                                    HStack {
                                        Text("Restore Purchases")
                                            .foregroundColor(Theme.primaryText)
                                        Spacer()
                                        Image(systemName: "arrow.clockwise")
                                            .foregroundColor(Theme.accent)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Policy Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Legal")
                                .font(.subheadline)
                                .foregroundColor(Theme.secondaryText)
                                .padding(.horizontal)
                            
                            GlassmorphicContainer {
                                Link(destination: URL(string: "https://amit606.github.io/dropsize-ios/privacy.html")!) {
                                    HStack {
                                        Text("Privacy Policy")
                                            .foregroundColor(Theme.primaryText)
                                        Spacer()
                                        Image(systemName: "arrow.up.forward.square")
                                            .foregroundColor(Theme.secondaryText)
                                    }
                                }
                                
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                    .padding(.vertical, 4)
                                
                                Link(destination: URL(string: "https://amit606.github.io/dropsize-ios/terms.html")!) {
                                    HStack {
                                        Text("Terms of Use")
                                            .foregroundColor(Theme.primaryText)
                                        Spacer()
                                        Image(systemName: "arrow.up.forward.square")
                                            .foregroundColor(Theme.secondaryText)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // App Version Label
                        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
                        let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                        VStack(spacing: 4) {
                            Text("Dropsize — Photo & Video Compressor")
                                .font(.caption2)
                                .foregroundColor(Theme.secondaryText.opacity(0.6))
                            Text("v\(appVersion) (Build \(buildVersion))")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.secondaryText.opacity(0.4))
                        }
                        .padding(.vertical, 16)
                    }
                    .padding(.vertical)
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .onAppear {
            isPremium = storeManager.hasPremiumAccess
        }
        .onChange(of: storeManager.purchasedProductIDs) { _, _ in
            isPremium = storeManager.hasPremiumAccess
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Restore Purchases"), message: Text(alertMessage ?? ""), dismissButton: .default(Text("OK")))
        }
    }
    
    private func restorePurchases() {
        Task {
            do {
                try await storeManager.restorePurchases()
                isPremium = storeManager.hasPremiumAccess
                if isPremium {
                    alertMessage = "Your premium subscription was successfully restored!"
                } else {
                    alertMessage = "No premium subscription was found on this iTunes account."
                }
                showAlert = true
            } catch {
                alertMessage = "Failed to restore: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
}
