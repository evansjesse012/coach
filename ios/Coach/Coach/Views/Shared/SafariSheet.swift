import SwiftUI
import SafariServices

/// SwiftUI wrapper around SFSafariViewController so in-app links open
/// without kicking the user out to Safari.
struct SafariSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.preferredControlTintColor = UIColor(CoachColors.accent)
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) { }
}
