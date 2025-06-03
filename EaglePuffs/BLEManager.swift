//
//  BLEManager.swift
//  EaglePuffs
//
//  Created by Harpreet Athwal on 6/1/25.
//


import Foundation
import CoreBluetooth

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var peripherals: [CBPeripheral] = []
    @Published var connectedPeripheral: CBPeripheral?
    @Published var messages: [String] = []
    @Published var isConnected = false

    private var centralManager: CBCentralManager!
    private var dataCharacteristic: CBCharacteristic?
    private let serviceUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef0")
    private let characteristicUUID = CBUUID(string: "87654321-4321-6789-4321-0fedcba98765")
    var context = PersistenceController.shared.container.viewContext

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
        print(characteristic.isNotifying ? "Notification enabled." : "Notification disabled.")
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
           guard let value = characteristic.value,
                 let str = String(data: value, encoding: .ascii),
                 !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
               return
           }

           DispatchQueue.main.async {
               self.messages.append("Device: \(str)")
               self.parseAndStoreSensorData(from: str)
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
