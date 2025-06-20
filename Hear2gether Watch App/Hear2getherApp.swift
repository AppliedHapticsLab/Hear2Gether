
import SwiftUI

@main
struct Hear2gether_Watch_AppApp: App {
    @WKApplicationDelegateAdaptor private var extensionDelegate: ExtensionDelegate
    
    // LoginConnector のインスタンスを作成
    @StateObject private var loginConnector = LoginConnector()

    @SceneBuilder var body: some Scene {
        WindowGroup {
            NavigationView {
                QRLoginView()
                    .environmentObject(extensionDelegate)
                    .environmentObject(loginConnector)
            }
        }

    }
}

