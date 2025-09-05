//
//  UUIDManager.swift
//  ethwallet
//
//  管理 BLE UUID（使用固定值以便 Web Bluetooth 发现）
//

import Foundation
import CoreBluetooth

class UUIDManager {
    static let shared = UUIDManager()
    
    // MARK: - 固定的 UUID
    // 所有安装此应用的设备都使用相同的 UUID
    // 这样 Web Bluetooth 可以预先知道要扫描的服务
    private let FIXED_SERVICE_UUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"  // 使用 Nordic UART Service 兼容的 UUID
    private let FIXED_READ_UUID = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"     // TX Characteristic (从设备读取)
    private let FIXED_WRITE_UUID = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"    // RX Characteristic (写入设备)
    private let FIXED_NOTIFY_UUID = "6E400004-B5A3-F393-E0A9-E50E24DCCA9E"   // Notify Characteristic
    private let FIXED_READWRITE_UUID = "6E400005-B5A3-F393-E0A9-E50E24DCCA9E" // Read/Write Characteristic
    
    // MARK: - UUID 属性（返回固定值）
    
    var serviceUUID: CBUUID {
        return CBUUID(string: FIXED_SERVICE_UUID)
    }
    
    var readCharacteristicUUID: CBUUID {
        return CBUUID(string: FIXED_READ_UUID)
    }
    
    var writeCharacteristicUUID: CBUUID {
        return CBUUID(string: FIXED_WRITE_UUID)
    }
    
    var notifyCharacteristicUUID: CBUUID {
        return CBUUID(string: FIXED_NOTIFY_UUID)
    }
    
    var readWriteCharacteristicUUID: CBUUID {
        return CBUUID(string: FIXED_READWRITE_UUID)
    }
    
    private init() {
        // 使用固定 UUID，无需初始化
    }
    
    // MARK: - 公共方法
    
    // 重置 UUID（对于固定 UUID 此方法不执行任何操作）
    func resetAllUUIDs() {
        // 固定 UUID 不需要重置
        print("使用固定 UUID，无需重置")
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
    
    // 导出为 JSON 格式
    func exportUUIDsAsJSON() -> String? {
        let uuidDict = [
            "service": serviceUUID.uuidString,
            "read": readCharacteristicUUID.uuidString,
            "write": writeCharacteristicUUID.uuidString,
            "notify": notifyCharacteristicUUID.uuidString,
            "readWrite": readWriteCharacteristicUUID.uuidString
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: uuidDict, options: .prettyPrinted) {
            return String(data: jsonData, encoding: .utf8)
        }
        
        return nil
    }
}