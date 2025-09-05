//
//  DeviceInfo.swift
//  ethwallet
//
//  获取设备信息的辅助类
//

import Foundation
import UIKit

class DeviceInfo {
    
    // 获取设备的名称
    // 注意：从 iOS 16 开始，出于隐私原因，UIDevice.current.name 只返回通用名称（如 "iPhone"）
    // 而不是用户自定义的名称（如 "shelchin's iPhone"）
    static func getFullDeviceName() -> String {
        let deviceName = UIDevice.current.name
        
        // 日志输出，用于调试
        print("========== 设备信息 ==========")
        print("UIDevice.current.name: \(deviceName)")
        print("UIDevice.current.model: \(UIDevice.current.model)")
        print("UIDevice.current.localizedModel: \(UIDevice.current.localizedModel)")
        print("UIDevice.current.systemName: \(UIDevice.current.systemName)")
        print("UIDevice.current.systemVersion: \(UIDevice.current.systemVersion)")
        print("================================")
        
        return deviceName
    }
    
    // 获取蓝牙广播时实际显示的名称
    static func getBluetoothDisplayName() -> String {
        // 重要说明：
        // 1. iOS 蓝牙广播时会自动使用系统设置中的设备名称
        // 2. 这个名称在 "设置 > 通用 > 关于本机 > 名称" 中设置
        // 3. 应用无法通过代码更改这个广播名称
        // 4. Web Bluetooth 看到的将是系统设置的实际名称（如 "shelchin's iPhone"）
        // 5. 但应用内部通过 UIDevice.current.name 只能获取到通用名称（如 "iPhone"）
        
        // 返回提示信息
        return "系统设置的名称"
    }
    
    // 获取设备型号信息
    static func getDeviceModelInfo() -> String {
        let model = UIDevice.current.model
        let systemVersion = UIDevice.current.systemVersion
        return "\(model) (iOS \(systemVersion))"
    }
    
    // 获取提示信息
    static func getNameHint() -> String {
        return "蓝牙将显示您在系统设置中的设备名称"
    }
}