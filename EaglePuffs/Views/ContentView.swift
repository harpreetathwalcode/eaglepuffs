import SwiftUI
import CoreData

struct ContentView: View {
    @StateObject private var bleManager = BLEManager()
    @State private var textInput: String = ""
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SensorData.start, ascending: true)],
        animation: .default
    )
    private var sensorDataList: FetchedResults<SensorData>

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

                            List(sensorDataList, id: \.self) { data in
                                VStack(alignment: .leading) {
                                    Text("Start: \(data.start)")
                                    Text("Duration: \(data.duration)")
                                    if let timestamp = data.timestamp {
                                        Text("Received Timestamp: \(timestamp)")
                                    } else {
                                        Text("Received Timestamp: Unknown")
                                    }
                                    Text("Synced: \(data.isSynced ? "Yes" : "No")")
                                        .foregroundColor(data.isSynced ? .green : .red)
                                }
                            }

                            PuffChartsView(sensorDataList: sensorDataList)

                            Button(action: {
                                SensorDataManager.shared.clearAllSensorData(context: viewContext)
                            }) {
                                Text("Clear All Messages")
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.red)
                                    .cornerRadius(10)
                            }
                            .padding()

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
        .onAppear {
            bleManager.context = viewContext
        }
    }
}
