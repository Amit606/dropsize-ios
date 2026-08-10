import SwiftUI

extension View {
    @MainActor
    public func presentShareSheet(activityItems: [Any]) {
        // Find the active foreground window scene and key window
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootViewController = window.rootViewController else {
            return
        }
        
        var topViewController = rootViewController
        while let presentedViewController = topViewController.presentedViewController {
            topViewController = presentedViewController
        }
        
        let activityViewController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        
        // iPad popover presentation configuration to prevent crashes on iPad devices
        if let popoverController = activityViewController.popoverPresentationController {
            popoverController.sourceView = topViewController.view
            popoverController.sourceRect = CGRect(
                x: topViewController.view.bounds.midX,
                y: topViewController.view.bounds.midY,
                width: 0,
                height: 0
            )
            popoverController.permittedArrowDirections = []
        }
        
        // Wrap presentation in async block to let any pending SwiftUI layouts/animations finish first
        DispatchQueue.main.async {
            topViewController.present(activityViewController, animated: true, completion: nil)
        }
    }
}
