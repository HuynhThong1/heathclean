import SwiftUI
import UIKit

/// SwiftUI's `navigationTitle` always renders in the system face — the only way
/// to put the brand typeface there is the UIKit appearance proxy. Called once
/// at launch.
enum DSAppearance {
    static func apply() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()

        if let large = UIFont(name: DSFontName.bold, size: 34) {
            appearance.largeTitleTextAttributes = [
                .font: large,
                .foregroundColor: UIColor(DSColor.textStrong)
            ]
        }
        if let inline = UIFont(name: DSFontName.semibold, size: 17) {
            appearance.titleTextAttributes = [
                .font: inline,
                .foregroundColor: UIColor(DSColor.textStrong)
            ]
        }

        let bar = UINavigationBar.appearance()
        bar.standardAppearance = appearance
        bar.compactAppearance = appearance
        bar.scrollEdgeAppearance = appearance
    }
}
