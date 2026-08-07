import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @State private var storeManager = StoreManager.shared
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            // Subtle glowing background spots
            VStack {
                HStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.15))
                        .frame(width: 250, height: 250)
                        .blur(radius: 50)
                        .offset(x: -50, y: -50)
                    Spacer()
                }
                Spacer()
            }
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Close button
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Header
                    VStack(spacing: 8) {
                        Text("Dropsize Premium")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(Theme.primaryGradient)
                        
                        Text("Unlock unlimited on-device compression")
                            .font(.subheadline)
                            .foregroundColor(Theme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 10)
                    
                    // Features Grid
                    VStack(spacing: 16) {
                        FeatureRow(icon: "infinity", title: "Unlimited Compressions", description: "No daily limits, compress as many files as you like.")
                        FeatureRow(icon: "square.grid.3x3.fill", title: "Batch Mode", description: "Compress multiple photos & videos simultaneously.")
                        FeatureRow(icon: "bolt.fill", title: "Superfast Processing", description: "Highest priority core execution for faster transcoding.")
                        FeatureRow(icon: "sparkles", title: "Metadata Stripping", description: "Remove location data and camera info to shrink files further.")
                    }
                    .padding(.horizontal)
                    
                    // Product selection
                    VStack(spacing: 16) {
                        if storeManager.products.isEmpty {
                            ProgressView()
                                .tint(.white)
                                .padding()
                        } else {
                            ForEach(storeManager.products, id: \.id) { product in
                                let isSelected = selectedProduct?.id == product.id
                                Button(action: { selectedProduct = product }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(product.displayName)
                                                .font(.headline)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                            Text(product.description)
                                                .font(.subheadline)
                                                .foregroundColor(Theme.secondaryText)
                                                .multilineTextAlignment(.leading)
                                        }
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text(product.displayPrice)
                                                .font(.title3)
                                                .fontWeight(.black)
                                                .foregroundColor(.white)
                                            
                                            if product.id.contains("yearly") {
                                                Text("7 Days Free")
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.green)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 2)
                                                    .background(Color.green.opacity(0.15))
                                                    .cornerRadius(4)
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(isSelected ? Theme.accent.opacity(0.15) : Color.white.opacity(0.03))
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(isSelected ? Theme.accent : Color.white.opacity(0.1), lineWidth: 2)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // CTAs & Actions
                    VStack(spacing: 16) {
                        if let error = errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        PremiumButton(
                            title: isPurchasing ? "Purchasing..." : (selectedProduct?.id.contains("yearly") == true ? "Start 7-Day Trial" : "Subscribe Now"),
                            action: {
                                handlePurchase()
                            }
                        )
                        .disabled(selectedProduct == nil || isPurchasing)
                        .padding(.horizontal)
                        
                        Button("Restore Purchases") {
                            handleRestore()
                        }
                        .font(.footnote)
                        .foregroundColor(Theme.secondaryText)
                    }
                    
                    // Disclaimer
                    Text("Subscriptions auto-renew at the price selected above unless cancelled. You can manage or cancel your subscription in your iTunes Account Settings.")
                        .font(.caption2)
                        .foregroundColor(Theme.secondaryText.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            if selectedProduct == nil && !storeManager.products.isEmpty {
                // Pre-select yearly if available, else first
                selectedProduct = storeManager.products.first(where: { $0.id.contains("yearly") }) ?? storeManager.products.first
            }
        }
        .onChange(of: storeManager.products) { _, newProducts in
            if selectedProduct == nil && !newProducts.isEmpty {
                selectedProduct = newProducts.first(where: { $0.id.contains("yearly") }) ?? newProducts.first
            }
        }
    }
    
    private func handlePurchase() {
        guard let product = selectedProduct else { return }
        isPurchasing = true
        errorMessage = nil
        
        Task {
            do {
                let transaction = try await storeManager.purchase(product)
                isPurchasing = false
                if transaction != nil {
                    // Success!
                    dismiss()
                }
            } catch {
                isPurchasing = false
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func handleRestore() {
        isPurchasing = true
        errorMessage = nil
        Task {
            do {
                try await storeManager.restorePurchases()
                isPurchasing = false
                if storeManager.hasPremiumAccess {
                    dismiss()
                } else {
                    errorMessage = "No active subscription found to restore."
                }
            } catch {
                isPurchasing = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.05))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(Theme.accent)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(Theme.secondaryText)
                    .lineLimit(2)
            }
            
            Spacer()
        }
    }
}
