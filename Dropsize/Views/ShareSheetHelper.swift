import SwiftUI

extension View {
    public func presentShareSheet(activityItems: [Any]) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
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
        
        topViewController.present(activityViewController, animated: true, completion: nil)
    }
}
