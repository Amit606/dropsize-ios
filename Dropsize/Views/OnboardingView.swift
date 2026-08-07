import SwiftUI

struct OnboardStep {
    let title: String
    let description: String
    let icon: String
    let iconColor: Color
}

struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    @State private var currentStepIndex = 0
    
    private let steps = [
        OnboardStep(
            title: "Smart Compression",
            description: "Reduce photo & video files to your exact target size without visible quality loss.",
            icon: "square.dashed.inset.filled",
            iconColor: Color(hex: "8A3FFC")
        ),
        OnboardStep(
            title: "System-wide Extension",
            description: "Compress media directly from Photos, Messages, or Mail without opening the app.",
            icon: "square.and.arrow.up",
            iconColor: Color(hex: "F43F5E")
        ),
        OnboardStep(
            title: "Efficient Batch Mode",
            description: "Select and compress multiple photos or videos at once, saving you time.",
            icon: "square.grid.3x3.square.badge.recorded.button",
            iconColor: Color(hex: "10B981")
        )
    ]
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack {
                HStack {
                    Spacer()
                    Button("Skip") {
                        withAnimation {
                            isOnboardingComplete = true
                        }
                    }
                    .foregroundColor(Theme.secondaryText)
                    .padding()
                }
                
                Spacer()
                
                TabView(selection: $currentStepIndex) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        let step = steps[index]
                        VStack(spacing: 24) {
                            ZStack {
                                Circle()
                                    .fill(step.iconColor.opacity(0.15))
                                    .frame(width: 140, height: 140)
                                
                                Image(systemName: step.icon)
                                    .font(.system(size: 64))
                                    .foregroundColor(step.iconColor)
                            }
                            
                            VStack(spacing: 16) {
                                Text(step.title)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                
                                Text(step.description)
                                    .font(.body)
                                    .foregroundColor(Theme.secondaryText)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                .frame(maxHeight: 450)
                
                Spacer()
                
                VStack(spacing: 16) {
                    PremiumButton(
                        title: currentStepIndex == steps.count - 1 ? "Get Started" : "Continue",
                        action: {
                            if currentStepIndex < steps.count - 1 {
                                withAnimation {
                                    currentStepIndex += 1
                                }
                            } else {
                                withAnimation {
                                    isOnboardingComplete = true
                                }
                            }
                        }
                    )
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 32)
            }
        }
    }
}
