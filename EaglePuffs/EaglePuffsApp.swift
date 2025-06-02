import SwiftUI
import CoreBluetooth
import FirebaseCore
import FirebaseAuth
import LocalAuthentication
import Security

// MARK: - BLE Manager

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var peripherals: [CBPeripheral] = []
    @Published var connectedPeripheral: CBPeripheral?
    @Published var messages: [String] = []
    @Published var isConnected = false

    private var centralManager: CBCentralManager!
    private var dataCharacteristic: CBCharacteristic?
    private let serviceUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef0")
    private let characteristicUUID = CBUUID(string: "87654321-4321-6789-4321-0fedcba98765")

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        print("BLE Manager initialized.")
    }

    // MARK: CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: [serviceUUID])
            print("Scanning for peripherals...")
        } else {
            print("Central Manager state: \(central.state.rawValue)")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                       advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if !peripherals.contains(peripheral) {
            peripherals.append(peripheral)
            print("Discovered peripheral: \(peripheral.name ?? "Unknown")")
        }
    }

    func connect(to peripheral: CBPeripheral) {
        print("Attempting to connect to \(peripheral.name ?? "Unknown")")
        centralManager.stopScan()
        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        print("Connected to peripheral: \(peripheral.name ?? "Unnamed")")
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        connectedPeripheral = nil
        dataCharacteristic = nil
        peripherals.removeAll()
        messages.removeAll()
        print("Disconnected.")
        centralManager.scanForPeripherals(withServices: [serviceUUID])
    }

    // MARK: CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services where service.uuid == serviceUUID {
                print("Discovered service: \(service.uuid)")
                peripheral.discoverCharacteristics([characteristicUUID], for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics where characteristic.uuid == characteristicUUID {
            dataCharacteristic = characteristic
            print("Discovered characteristic: \(characteristic.uuid)")

            // Subscribe to notifications!
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
                print("Subscribed to notifications for characteristic: \(characteristic.uuid)")
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.isNotifying {
            print("Notification enabled for characteristic: \(characteristic.uuid)")
        } else {
            print("Notification disabled for characteristic: \(characteristic.uuid)")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let value = characteristic.value,
              let str = String(data: value, encoding: .ascii) else { return }
        DispatchQueue.main.async {
            self.messages.append("Device: \(str)")
        }
        print("Received from device: \(str)")
    }

    // MARK: Send message

    func sendMessage(_ msg: String) {
        guard let characteristic = dataCharacteristic,
              let peripheral = connectedPeripheral,
              (characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse))
        else {
            print("Characteristic not ready for write.")
            return
        }
        if let data = msg.data(using: .ascii) {
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
            DispatchQueue.main.async {
                self.messages.append("You: \(msg)")
            }
            print("Sent: \(msg)")
        }
    }

    // MARK: Disconnect

    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
            print("Disconnect requested.")
        }
    }
}

func saveCredentialsToKeychain(email: String, password: String) {
    let credentials = "\(email):\(password)"
    let credentialsData = credentials.data(using: .utf8)!
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.yourapp.eaglepuffs",
        kSecAttrAccount as String: "userCredentials",
        kSecValueData as String: credentialsData,
        kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
    ]
    SecItemDelete(query as CFDictionary) // Remove any old value
    SecItemAdd(query as CFDictionary, nil)
}

func retrieveCredentialsFromKeychain(completion: @escaping (String?, String?) -> Void) {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.yourapp.eaglepuffs",
        kSecAttrAccount as String: "userCredentials",
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecSuccess, let data = item as? Data,
       let credentials = String(data: data, encoding: .utf8),
       let separatorIndex = credentials.firstIndex(of: ":") {
        let email = String(credentials[..<separatorIndex])
        let password = String(credentials[credentials.index(after: separatorIndex)...])
        completion(email, password)
    } else {
        completion(nil, nil)
    }
}

// MARK: - Auth ViewModel

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
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
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
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
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
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.errorMessage = "Password reset email sent! Check your inbox."
                }
            }
        }
    }
}


// MARK: - AuthView

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

// Firebase initialization
class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
}

// MARK: - Main App

@main
struct EaglePuffsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authVM = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if authVM.isSignedIn {
                    ContentView()
                        .environmentObject(authVM)
                } else {
                    AuthView()
                        .environmentObject(authVM)
                }
            }
            .onAppear { authVM.checkSignIn() }
        }
    }
}
