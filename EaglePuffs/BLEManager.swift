//
//  BLEManager.swift
//  EaglePuffs
//
//  Created by Harpreet Athwal on 6/1/25.
//


import Foundation
import CoreBluetooth
import FirebaseFirestore
import FirebaseAuth

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var peripherals: [CBPeripheral] = []
    @Published var connectedPeripheral: CBPeripheral?
    @Published var messages: [String] = []
    @Published var isConnected = false
    @Published var isSubscribed = false
    @Published var lastSuccessfulMessage: String = ""
    private var pendingMessage: String?


    
    // BLE Vars
    private var centralManager: CBCentralManager!
    private var dataCharacteristic: CBCharacteristic?
    private let serviceUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef0")
    private let characteristicUUID = CBUUID(string: "87654321-4321-6789-4321-0fedcba98765")
    var context = PersistenceController.shared.container.viewContext
    // Timer Sync to Firebase vars
    private var syncTimer: Timer?
    private let syncInterval: TimeInterval = 10 // seconds, adjust as you wish
    private let firestore = Firestore.firestore()

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)

        // Restore previously connected peripheral if available
        if let uuidString = UserDefaults.standard.string(forKey: "lastConnectedPeripheralUUID"),
           let uuid = UUID(uuidString: uuidString) {
            let restoredPeripherals = centralManager.retrievePeripherals(withIdentifiers: [uuid])
            if let peripheral = restoredPeripherals.first {
                print("Restoring connection to previously connected peripheral: \(peripheral.name ?? "Unknown")")
                connectedPeripheral = peripheral
                peripheral.delegate = self
                centralManager.connect(peripheral)
            }
        }

        print("BLE Manager initialized.")
        // Start periodic sync timer
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            self?.syncUnsyncedSensorData()
        }
    }

    private func syncUnsyncedSensorData() {
        let fetchRequest = SensorData.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isSynced == NO")

        do {
            let unsynced = try context.fetch(fetchRequest)
            guard !unsynced.isEmpty else { return }

            let userEmail = Auth.auth().currentUser?.email ?? "unknown"

            for data in unsynced {
                let dict: [String: Any] = [
                    "start": data.start,
                    "duration": data.duration,
                    "centralTimestamp": data.timestamp ?? Date(),
                    "sendTimestamp": Date(),
                    "userEmail": userEmail,
                    "serviceUUID": serviceUUID.uuidString,
                    "characteristicUUID": characteristicUUID.uuidString
                ]
                // Optionally, use the objectID as a unique ID
                let rawID = data.objectID.uriRepresentation().absoluteString
                let nanoseconds = DispatchTime.now().uptimeNanoseconds  // Preferred for uniqueness
                let combinedID = "\(nanoseconds)_\(rawID)"
                let docID = combinedID.replacingOccurrences(of: "[^A-Za-z0-9_]", with: "_", options: .regularExpression)

                firestore.collection("SensorData").document(docID).setData(dict) { [weak self] error in
                    guard let self = self else { return }
                    if error == nil {
                        // Mark as synced only if successful
                        data.isSynced = true
                        do {
                            try self.context.save()
                        } catch {
                            print("CoreData save error after sync: \(error)")
                        }
                    } else {
                        print("Failed to sync SensorData: \(error!)")
                    }
                }
            }
        } catch {
            print("Failed to fetch unsynced SensorData: \(error)")
        }
    }
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

            // Auto-reconnect if UUID matches whats stored for last connection
            if let uuidString = UserDefaults.standard.string(forKey: "lastConnectedPeripheralUUID"),
               peripheral.identifier.uuidString == uuidString {
                connect(to: peripheral)
            }
        }
    }

    func connect(to peripheral: CBPeripheral) {
        print("Attempting to connect to \(peripheral.name ?? "Unknown")")
        centralManager.stopScan()
        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral)

        // Save identifier to UserDefaults
        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: "lastConnectedPeripheralUUID")
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        print("Connected to peripheral: \(peripheral.name ?? "Unnamed")")
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        isSubscribed = false
        connectedPeripheral = nil
        dataCharacteristic = nil
        peripherals.removeAll()
        messages.removeAll()
        print("Disconnected.")
        centralManager.scanForPeripherals(withServices: [serviceUUID])
    }

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
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
                print("Subscribed to notifications.")
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == characteristicUUID {
            if characteristic.isNotifying {
                print("✅ Notification enabled for characteristic: \(characteristic.uuid)")
                DispatchQueue.main.async {
                    self.isSubscribed = true
                }
                sendMessage("subscribed")
            } else {
                print("❌ Notification disabled for characteristic: \(characteristic.uuid)")
                DispatchQueue.main.async {
                    self.isSubscribed = false
                }
            }
        }
    }


    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
           guard let value = characteristic.value,
                 let str = String(data: value, encoding: .ascii),
                 !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
               return
           }
        
           let trimmedStr = str.trimmingCharacters(in: .whitespacesAndNewlines)
        
           DispatchQueue.main.async {
               self.messages.append("Device: \(str)")
               
               // ✅ If the device sent the expected ACK, store the pending message
               // Else process the message as new data
               if trimmedStr == "ACKNOWLEDGE_PUFF_SETTINGS", let pending = self.pendingMessage {
                   self.lastSuccessfulMessage = pending
                   print("✅ LastSuccessfulMessage set to: \(pending)")
                   self.pendingMessage = nil  // Clear after success
               } else {
                   self.parseAndStoreSensorData(from: str)
               }
           }

           print("Received from device: \(str)")
           
       }

       private func parseAndStoreSensorData(from input: String) {
           let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)

           if trimmedInput.contains("|") {
               let entries = trimmedInput.split(separator: "|")
               for entry in entries {
                   processSensorEntry(String(entry))
               }
           } else {
               processSensorEntry(trimmedInput)
           }

           try? context.save()
       }

       private func processSensorEntry(_ entry: String) {
           let parts = entry.split(separator: ",")
           guard parts.count == 2,
                 let start = Int64(parts[0]),
                 let duration = Int64(parts[1]) else {
               print("Invalid entry: \(entry)")
               return
           }

           let sensorData = SensorData(context: context)
           sensorData.start = start
           sensorData.duration = duration
           sensorData.timestamp = Date()
           sensorData.isSynced = false
       }

    func sendMessage(_ msg: String) {
        guard let characteristic = dataCharacteristic,
              let peripheral = connectedPeripheral,
              (characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse))
        else {
            print("Characteristic not ready for write.")
            return
        }
        if let data = msg.data(using: .ascii) {
            pendingMessage = msg  // Track this message as pending!

            peripheral.writeValue(data, for: characteristic, type: .withResponse)
            DispatchQueue.main.async {
                self.messages.append("You: \(msg)")
            }
            print("Sent: \(msg)")
        }
    }

    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
            print("Disconnect requested.")
            UserDefaults.standard.removeObject(forKey: "lastConnectedPeripheralUUID")
        }
    }
}
