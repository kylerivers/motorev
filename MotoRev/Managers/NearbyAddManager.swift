import Foundation
import CoreBluetooth
import Combine

final class NearbyAddManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralManagerDelegate {
    static let shared = NearbyAddManager()
    @Published var nearbyUsernames: [String] = []
    private var central: CBCentralManager!
    private var peripheral: CBPeripheralManager!
    private let serviceUUID = CBUUID(string: "F3D1C2AB-1234-5678-90AB-FFEEDDCCBBAA")
    private let characteristicUUID = CBUUID(string: "8F1A2B3C-4D5E-6789-ABCD-001122334455")
    private var advertisedData: [String: Any] = [:]
    
    private override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
        peripheral = CBPeripheralManager(delegate: self, queue: .main)
    }
    
    func start(username: String) {
        if peripheral.state == .poweredOn {
            let data = username.data(using: .utf8) ?? Data()
            let characteristic = CBMutableCharacteristic(type: characteristicUUID, properties: [.read], value: data, permissions: [.readable])
            let service = CBMutableService(type: serviceUUID, primary: true)
            service.characteristics = [characteristic]
            peripheral.add(service)
            advertisedData = [CBAdvertisementDataServiceUUIDsKey: [serviceUUID]]
            peripheral.startAdvertising(advertisedData)
        }
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: [serviceUUID])
        }
    }
    
    func stop() {
        central.stopScan()
        peripheral.stopAdvertising()
        nearbyUsernames.removeAll()
    }
    
    // MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // handle state changes if needed
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Username exposed via characteristic requires connect; for demo, show placeholder
        if let uuids = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID], uuids.contains(serviceUUID) {
            let name = peripheral.name ?? "Rider"
            if !nearbyUsernames.contains(name) { nearbyUsernames.append(name) }
        }
    }
    
    // MARK: - CBPeripheralManagerDelegate
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        // handle state
    }
} 