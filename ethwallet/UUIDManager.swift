//
//  UUIDManager.swift
//  ethwallet
//
//  管理动态生成的 BLE UUID
//

import Foundation
import CoreBluetooth

class UUIDManager {
    static let shared = UUIDManager()
    
    private let userDefaults = UserDefaults.standard
    
    // UserDefaults keys
    private let serviceUUIDKey = "BLEServiceUUID"
    private let readCharUUIDKey = "BLEReadCharUUID"
    private let writeCharUUIDKey = "BLEWriteCharUUID"
    private let notifyCharUUIDKey = "BLENotifyCharUUID"
    private let readWriteCharUUIDKey = "BLEReadWriteCharUUID"
    private let firstLaunchKey = "BLEFirstLaunch"
    
    // 获取或生成 UUID
    var serviceUUID: CBUUID {
        if let uuidString = userDefaults.string(forKey: serviceUUIDKey) {
            return CBUUID(string: uuidString)
        } else {
            let newUUID = generateAndSaveUUID(for: serviceUUIDKey)
            return CBUUID(string: newUUID)
        }
    }
    
    var readCharacteristicUUID: CBUUID {
        if let uuidString = userDefaults.string(forKey: readCharUUIDKey) {
            return CBUUID(string: uuidString)
        } else {
            let newUUID = generateAndSaveUUID(for: readCharUUIDKey)
            return CBUUID(string: newUUID)
        }
    }
    
    var writeCharacteristicUUID: CBUUID {
        if let uuidString = userDefaults.string(forKey: writeCharUUIDKey) {
            return CBUUID(string: uuidString)
        } else {
            let newUUID = generateAndSaveUUID(for: writeCharUUIDKey)
            return CBUUID(string: newUUID)
        }
    }
    
    var notifyCharacteristicUUID: CBUUID {
        if let uuidString = userDefaults.string(forKey: notifyCharUUIDKey) {
            return CBUUID(string: uuidString)
        } else {
            let newUUID = generateAndSaveUUID(for: notifyCharUUIDKey)
            return CBUUID(string: newUUID)
        }
    }
    
    var readWriteCharacteristicUUID: CBUUID {
        if let uuidString = userDefaults.string(forKey: readWriteCharUUIDKey) {
            return CBUUID(string: uuidString)
        } else {
            let newUUID = generateAndSaveUUID(for: readWriteCharUUIDKey)
            return CBUUID(string: newUUID)
        }
    }
    
    private init() {
        // 首次启动时生成所有 UUID
        if !userDefaults.bool(forKey: firstLaunchKey) {
            generateAllUUIDs()
            userDefaults.set(true, forKey: firstLaunchKey)
        }
    }
    
    private func generateAndSaveUUID(for key: String) -> String {
        let uuid = UUID().uuidString
        userDefaults.set(uuid, forKey: key)
        return uuid
    }
    
    private func generateAllUUIDs() {
        _ = generateAndSaveUUID(for: serviceUUIDKey)
        _ = generateAndSaveUUID(for: readCharUUIDKey)
        _ = generateAndSaveUUID(for: writeCharUUIDKey)
        _ = generateAndSaveUUID(for: notifyCharUUIDKey)
        _ = generateAndSaveUUID(for: readWriteCharUUIDKey)
    }
    
    // 重置所有 UUID
    func resetAllUUIDs() {
        generateAllUUIDs()
    }
    
    // 获取所有 UUID 信息用于显示
    func getAllUUIDs() -> [String: String] {
        return [
            "服务 UUID": serviceUUID.uuidString,
            "读特征 UUID": readCharacteristicUUID.uuidString,
            "写特征 UUID": writeCharacteristicUUID.uuidString,
            "通知特征 UUID": notifyCharacteristicUUID.uuidString,
            "读写特征 UUID": readWriteCharacteristicUUID.uuidString
        ]
    }
    
    // 导出 UUID 配置为 JSON
    func exportUUIDsAsJSON() -> String? {
        let uuids = [
            "service": serviceUUID.uuidString,
            "characteristics": [
                "read": readCharacteristicUUID.uuidString,
                "write": writeCharacteristicUUID.uuidString,
                "notify": notifyCharacteristicUUID.uuidString,
                "readWrite": readWriteCharacteristicUUID.uuidString
            ]
        ] as [String : Any]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: uuids, options: .prettyPrinted) {
            return String(data: jsonData, encoding: .utf8)
        }
        return nil
    }
}