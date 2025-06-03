import SwiftUI

@main
struct EaglePuffsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authVM = AuthViewModel()
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if authVM.isSignedIn {
                    ContentView().environmentObject(authVM)
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                } else {
                    AuthView().environmentObject(authVM)
                }
            }
            .onAppear { authVM.checkSignIn() }
        }
    }
}
    
