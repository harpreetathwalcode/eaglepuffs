//
//  AuthView.swift
//  EaglePuffs
//
//  Created by Harpreet Athwal on 6/1/25.
//

//Presents the user interface for login, sign-up, and password reset.
//Includes a "Remember Me" toggle to optionally save credentials.
//Binds to AuthViewModel for authentication actions.

import SwiftUI
import LocalAuthentication

struct AuthView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var rememberMe = false
    @State private var isBiometricLoginAvailable = false
    @State private var showResetAlert = false

    var body: some View {
        VStack(spacing: 20) {
            Text(isSignUp ? "Sign Up" : "Sign In")
                .font(.largeTitle)
                .padding(.top)

            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textContentType(.username)

            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textContentType(.password)

            Toggle("Remember Me (Face ID/Touch ID)", isOn: $rememberMe)
                .disabled(authVM.isLoading)
                .padding(.vertical, 2)

            if !isSignUp && isBiometricLoginAvailable {
                Button("Sign in with Face ID / Touch ID") {
                    let context = LAContext()
                    context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock stored credentials") { success, error in
                        if success {
                            retrieveCredentialsFromKeychain { emailStored, passwordStored in
                                DispatchQueue.main.async {
                                    if let emailStored = emailStored, let passwordStored = passwordStored,
                                       !emailStored.isEmpty, !passwordStored.isEmpty {
                                        email = emailStored
                                        password = passwordStored
                                        authVM.signIn(email: emailStored, password: passwordStored, rememberMe: rememberMe)
                                    } else {
                                        // Show an alert or error message to user!
                                        authVM.errorMessage = "No credentials stored. Please sign in and enable 'Remember Me' first."
                                    }
                                }
                            }
                        } else {
                            // Optionally handle authentication failure (Face ID did not match, etc)
                            DispatchQueue.main.async {
                                authVM.errorMessage = "Biometric authentication failed."
                            }
                        }
                    }
                }
                .padding(.top, 2)
            }


            if let error = authVM.errorMessage {
                Text(error)
                    .foregroundColor(error.contains("sent") ? .green : .red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }

            if authVM.isLoading {
                ProgressView()
            }

            Button(isSignUp ? "Sign Up" : "Sign In") {
                if isSignUp {
                    authVM.signUp(email: email, password: password, rememberMe: rememberMe)
                } else {
                    authVM.signIn(email: email, password: password, rememberMe: rememberMe)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || password.isEmpty)

            Button(isSignUp ? "Have an account? Sign In" : "No account? Sign Up") {
                isSignUp.toggle()
            }
            .font(.footnote)
            .padding(.top)

            // Forgot Password Button
            if !isSignUp {
                Button("Forgot your password?") {
                    authVM.resetPassword(email: email)
                    showResetAlert = true
                }
                .font(.footnote)
                .foregroundColor(.blue)
                .padding(.top, 4)
            }

            Spacer()
        }
        .padding()
        .alert(isPresented: $showResetAlert) {
            Alert(
                title: Text("Password Reset"),
                message: Text(authVM.errorMessage ?? "If an account exists for that email, a reset link was sent."),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            let context = LAContext()
            var error: NSError?
            isBiometricLoginAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        }
    }
}

