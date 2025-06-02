import SwiftUI

@main
struct EaglePuffsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authVM = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if authVM.isSignedIn {
                    ContentView().environmentObject(authVM)
                } else {
                    AuthView().environmentObject(authVM)
                }
            }
            .onAppear { authVM.checkSignIn() }
        }
    }
}
    
