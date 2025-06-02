//
//  ContentView.swift
//  EaglePuffs
//
//  Created by Harpreet Athwal on 6/1/25.
//
import SwiftUI

// MARK: - ContentView

struct ContentView: View {
    @StateObject private var bleManager = BLEManager()
    @State private var textInput: String = ""
    @EnvironmentObject var authVM: AuthViewModel // <--- Added

    var body: some View {
        VStack {
            Button("Sign Out") {
                authVM.signOut()
            }
            .foregroundColor(.red)
            .padding(.bottom)

            NavigationView {
                VStack {
                    if !bleManager.isConnected {
                        List(bleManager.peripherals, id: \.identifier) { peripheral in
                            Button(action: {
                                bleManager.connect(to: peripheral)
                            }) {
                                HStack {
                                    Text(peripheral.name ?? "Unknown Device")
                                    Spacer()
                                    Image(systemName: "dot.radiowaves.left.and.right")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .navigationTitle("Eagle Puffs: Devices")
                        .listStyle(InsetGroupedListStyle())
                    } else {
                        VStack(spacing: 12) {
                            HStack {
                                TextField("Enter ASCII message...", text: $textInput)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .disableAutocorrection(true)
                                Button("Send") {
                                    if !textInput.isEmpty {
                                        bleManager.sendMessage(textInput)
                                        textInput = ""
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding(.horizontal)
                            List(bleManager.messages, id: \.self) { msg in
                                Text(msg)
                            }
                            Button("Disconnect") {
                                bleManager.disconnect()
                            }
                            .foregroundColor(.red)
                            .padding(.top)
                        }
                        .navigationTitle("Connected: \(bleManager.connectedPeripheral?.name ?? "")")
                    }
                }
            }
        }
    }
}
