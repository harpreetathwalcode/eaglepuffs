import SwiftUI
import CoreData

struct ContentView: View {
    @StateObject private var bleManager = BLEManager()
    @State private var textInput: String = ""
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        NavigationView {
            VStack {
                Button("Sign Out") {
                    authVM.signOut()
                }
                .foregroundColor(.red)
                .padding(.bottom)

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
                    Form {
                        Section(header: Text("Send Message")) {
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
                        }

                        Section(header: Text("Navigation")) {
                            NavigationLink("Sensor Data Messages", destination: SensorDataListView())
                            NavigationLink("Puff Charts", destination: PuffChartsViewWrapper())
                        }

                        Section {
                            HStack {
                                Spacer()
                                Button(action: {
                                    SensorDataManager.shared.clearAllSensorData(context: viewContext)
                                }) {
                                    Text("Clear All Messages")
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.red)
                                        .cornerRadius(10)
                                }
                                Spacer()
                            }
                            
                            HStack {
                                Spacer()
                                Button("Disconnect") {
                                    bleManager.disconnect()
                                }
                                .foregroundColor(.red)
                                Spacer()
                            }
                        }
                    }
                    .navigationTitle("Connected: \(bleManager.connectedPeripheral?.name ?? "")")
                }
            }
        }
        .onAppear {
            bleManager.context = viewContext
        }
    }
}

// Helper view to pass fetch results into PuffChartsView
struct PuffChartsViewWrapper: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SensorData.start, ascending: true)],
        animation: .default
    )
    private var sensorDataList: FetchedResults<SensorData>

    var body: some View {
        PuffChartsView(sensorDataList: sensorDataList)
    }
}
