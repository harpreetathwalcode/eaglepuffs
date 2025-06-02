//
//  AppDelegate.swift
//  EaglePuffs
//
//  Created by Harpreet Athwal on 6/1/25.
//

// UIKit app delegate adapted for SwiftUI.
// Responsibility: Initializes Firebase using FirebaseApp.configure() during app launch.
import UIKit
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}
