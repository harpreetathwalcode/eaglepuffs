//
//  AuthViewModel.swift
//  EaglePuffs
//
//  Created by Harpreet Athwal on 6/1/25.
//

//Handles Firebase authentication actions: sign-in, sign-up, sign-out, password reset.
//Manages isSignedIn, error messages, and loading states.
//Optionally saves credentials to Keychain for auto-login.

import Foundation
import FirebaseAuth

class AuthViewModel: ObservableObject {
    @Published var isSignedIn = false
    @Published var errorMessage: String?
    @Published var isLoading = false

    func checkSignIn() {
        isSignedIn = Auth.auth().currentUser != nil
    }

    func signIn(email: String, password: String, rememberMe: Bool) {
        isLoading = true
        errorMessage = nil
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] _, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.isSignedIn = true
                    if rememberMe {
                        saveCredentialsToKeychain(email: email, password: password)
                    }
                }
            }
        }
    }

    func signUp(email: String, password: String, rememberMe: Bool) {
        isLoading = true
        errorMessage = nil
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] _, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.isSignedIn = true
                    if rememberMe {
                        saveCredentialsToKeychain(email: email, password: password)
                    }
                }
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            isSignedIn = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetPassword(email: String) {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email to reset your password."
            return
        }
        isLoading = true
        errorMessage = nil
        Auth.auth().sendPasswordReset(withEmail: email) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.errorMessage = error?.localizedDescription ?? "Password reset email sent! Check your inbox."
            }
        }
    }
}
