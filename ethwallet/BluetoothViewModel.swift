//
//  BluetoothViewModel.swift
//  ethwallet
//
//  视图模型 - 管理蓝牙状态和数据
//

import Foundation
import SwiftUI
import CoreBluetooth
import Combine

// MARK: - 消息模型
struct BLEMessage: Identifiable {
    let id = UUID()
    let timestamp: Date
    let direction: MessageDirection
    let content: String
    let dataSize: Int
    let type: MessageType
    
    enum MessageDirection {
        case sent
        case received
    }
    
    enum MessageType {
        case text
        case binary
        case command
        case notification
        case error
    }
}

// MARK: - 连接设备模型
struct ConnectedDevice: Identifiable {
    let id = UUID()
    let central: CBCentral
    let connectedAt: Date
    var subscribedCharacteristics: Set<String> = []
    
    var name: String {
        central.identifier.uuidString
    }
}

// MARK: - 视图模型
@MainActor
class BluetoothViewModel: ObservableObject {
    // MARK: - 发布的属性
    @Published var isAdvertising = false
    @Published var bluetoothState: CBManagerState = .unknown
    @Published var connectedDevices: [ConnectedDevice] = []
    @Published var messages: [BLEMessage] = []
    @Published var isStreaming = false
    @Published var streamInterval: TimeInterval = 1.0
    @Published var showAlert = false
    @Published var alertMessage = ""
    
    // 统计数据
    @Published var bytesSent = 0
    @Published var bytesReceived = 0
    @Published var notificationsSent = 0
    @Published var commandsProcessed = 0
    
    // MARK: - 私有属性
    private let peripheralManager: BluetoothPeripheralManager
    private var cancellables = Set<AnyCancellable>()
    private var lastSendTime = Date()
    private let minSendInterval: TimeInterval = 0.05  // 50ms 防抖动
    
    // MARK: - 计算属性
    var bluetoothStatusText: String {
        bluetoothState.description
    }
    
    var bluetoothStatusColor: Color {
        switch bluetoothState {
        case .poweredOn:
            return .green
        case .poweredOff:
            return .red
        case .unauthorized:
            return .orange
        default:
            return .gray
        }
    }
    
    var isBluetoothReady: Bool {
        bluetoothState == .poweredOn
    }
    
    // MARK: - 初始化
    init() {
        self.peripheralManager = BluetoothPeripheralManager()
        setupPeripheralManager()
    }
    
    private func setupPeripheralManager() {
        peripheralManager.delegate = self
    }
    
    // MARK: - 公共方法
    
    func toggleAdvertising() {
        if isAdvertising {
            stopAdvertising()
        } else {
            startAdvertising()
        }
    }
    
    func startAdvertising() {
        guard isBluetoothReady else {
            showError("蓝牙未就绪")
            return
        }
        
        // 检查实际广播状态
        if peripheralManager.isAdvertising {
            isAdvertising = true
            addMessage("蓝牙已在广播中", type: .command)
            return
        }
        
        peripheralManager.startAdvertising()
        isAdvertising = true
        addMessage("开始广播蓝牙服务", type: .command)
    }
    
    func stopAdvertising() {
        peripheralManager.stopAdvertising()
        isAdvertising = false
        addMessage("停止广播蓝牙服务", type: .command)
    }
    
    func sendTestMessage() {
        // 防止过快发送
        guard Date().timeIntervalSince(lastSendTime) >= minSendInterval else { return }
        lastSendTime = Date()
        
        let testData = "Test Message at \(Date())".data(using: .utf8)!
        peripheralManager.sendNotification(data: testData)
        bytesSent += testData.count
        notificationsSent += 1
        addMessage("发送测试消息", type: .notification, direction: .sent, dataSize: testData.count)
    }
    
    func sendCustomMessage(_ text: String) {
        guard !text.isEmpty else { return }
        
        // 防止过快发送
        guard Date().timeIntervalSince(lastSendTime) >= minSendInterval else { return }
        lastSendTime = Date()
        
        if let data = text.data(using: .utf8) {
            peripheralManager.sendNotification(data: data)
            bytesSent += data.count
            notificationsSent += 1
            addMessage(text, type: .text, direction: .sent, dataSize: data.count)
        }
    }
    
    func sendBinaryData(_ hexString: String) {
        let hex = hexString.replacingOccurrences(of: " ", with: "")
        guard !hex.isEmpty, hex.count % 2 == 0 else {
            showError("无效的十六进制数据")
            return
        }
        
        // 防止过快发送
        guard Date().timeIntervalSince(lastSendTime) >= minSendInterval else { return }
        lastSendTime = Date()
        
        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            if let byte = UInt8(hex[index..<nextIndex], radix: 16) {
                data.append(byte)
            }
            index = nextIndex
        }
        
        peripheralManager.sendNotification(data: data)
        bytesSent += data.count
        notificationsSent += 1
        addMessage("HEX: \(hexString)", type: .binary, direction: .sent, dataSize: data.count)
    }
    
    func toggleStreaming() {
        if isStreaming {
            stopStreaming()
        } else {
            startStreaming()
        }
    }
    
    func startStreaming() {
        peripheralManager.startStreamingData(interval: streamInterval)
        isStreaming = true
        addMessage("开始流数据传输 (间隔: \(streamInterval)s)", type: .command)
    }
    
    func stopStreaming() {
        peripheralManager.stopStreamingData()
        isStreaming = false
        addMessage("停止流数据传输", type: .command)
    }
    
    func clearMessages() {
        messages.removeAll()
        addMessage("消息记录已清空", type: .command)
    }
    
    func resetStats() {
        bytesSent = 0
        bytesReceived = 0
        notificationsSent = 0
        commandsProcessed = 0
        addMessage("统计数据已重置", type: .command)
    }
    
    func getCurrentUUIDs() -> String {
        return UUIDManager.shared.exportUUIDsAsJSON() ?? "{}"
    }
    
    func disconnectDevice(_ device: ConnectedDevice) {
        // 实际断开逻辑需要在 PeripheralManager 中实现
        if let index = connectedDevices.firstIndex(where: { $0.id == device.id }) {
            connectedDevices.remove(at: index)
            addMessage("设备断开连接: \(device.name)", type: .command)
        }
    }
    
    // MARK: - 私有方法
    
    private func addMessage(
        _ content: String,
        type: BLEMessage.MessageType,
        direction: BLEMessage.MessageDirection = .sent,
        dataSize: Int = 0
    ) {
        Task { @MainActor in
            let message = BLEMessage(
                timestamp: Date(),
                direction: direction,
                content: content,
                dataSize: dataSize,
                type: type
            )
            
            messages.insert(message, at: 0)
            
            // 限制消息数量，保持较小的列表以提升性能
            if messages.count > 50 {
                messages.removeLast(messages.count - 50)
            }
        }
    }
    
    private func showError(_ message: String) {
        alertMessage = message
        showAlert = true
        addMessage("错误: \(message)", type: .error)
    }
    
    private func updateConnectedDevice(central: CBCentral, subscribedCharacteristic: String? = nil) {
        if let index = connectedDevices.firstIndex(where: { $0.central === central }) {
            if let characteristic = subscribedCharacteristic {
                connectedDevices[index].subscribedCharacteristics.insert(characteristic)
            }
        } else {
            var device = ConnectedDevice(central: central, connectedAt: Date())
            if let characteristic = subscribedCharacteristic {
                device.subscribedCharacteristics.insert(characteristic)
            }
            connectedDevices.append(device)
        }
    }
}

// MARK: - BluetoothPeripheralManagerDelegate
extension BluetoothViewModel: BluetoothPeripheralManagerDelegate {
    
    nonisolated func peripheralManagerDidUpdateState(_ state: CBManagerState) {
        Task { @MainActor in
            self.bluetoothState = state
            
            if state == .poweredOn {
                // 同步广播状态 - 延迟一点以确保状态正确
                Task {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                    await MainActor.run {
                        self.isAdvertising = self.peripheralManager.isAdvertising
                        if self.isAdvertising {
                            addMessage("蓝牙已就绪，广播已自动开启", type: .command)
                        } else {
                            addMessage("蓝牙已就绪", type: .command)
                        }
                        // 显示当前服务 UUID
                        let serviceUUID = UUIDManager.shared.serviceUUID.uuidString
                        addMessage("服务UUID: \(serviceUUID)", type: .command)
                    }
                }
            } else if state != .poweredOn && isAdvertising {
                isAdvertising = false
                addMessage("蓝牙状态变更: \(state.description)", type: .command)
            }
        }
    }
    
    nonisolated func peripheralManagerDidStartAdvertising(_ error: Error?) {
        Task { @MainActor in
            if let error = error {
                showError("广播启动失败: \(error.localizedDescription)")
                isAdvertising = false
                addMessage("错误详情: \(error)", type: .error)
            } else {
                // 同步广播状态
                isAdvertising = true
                addMessage("广播启动成功", type: .command)
                // 显示当前动态服务 UUID
                let serviceUUID = UUIDManager.shared.serviceUUID.uuidString
                addMessage("服务UUID: \(serviceUUID)", type: .command)
            }
        }
    }
    
    nonisolated func peripheralManagerDidReceiveRead(from central: CBCentral, characteristic: CBCharacteristic) {
        Task { @MainActor in
            addMessage("读取请求: \(characteristic.uuid.uuidString)", type: .command, direction: .received)
            commandsProcessed += 1
        }
    }
    
    nonisolated func peripheralManagerDidReceiveWrite(from central: CBCentral, characteristic: CBCharacteristic, value: Data) {
        Task { @MainActor in
            bytesReceived += value.count
            commandsProcessed += 1
            
            if let text = String(data: value, encoding: .utf8) {
                addMessage("收到: \(text)", type: .text, direction: .received, dataSize: value.count)
            } else {
                let hex = value.map { String(format: "%02X", $0) }.joined(separator: " ")
                addMessage("收到 HEX: \(hex)", type: .binary, direction: .received, dataSize: value.count)
            }
        }
    }
    
    nonisolated func peripheralManagerDidSubscribe(central: CBCentral, characteristic: CBCharacteristic) {
        Task { @MainActor in
            updateConnectedDevice(central: central, subscribedCharacteristic: characteristic.uuid.uuidString)
            addMessage("设备订阅: \(characteristic.uuid.uuidString)", type: .command, direction: .received)
        }
    }
    
    nonisolated func peripheralManagerDidUnsubscribe(central: CBCentral, characteristic: CBCharacteristic) {
        Task { @MainActor in
            addMessage("设备取消订阅: \(characteristic.uuid.uuidString)", type: .command, direction: .received)
        }
    }
    
    nonisolated func peripheralManagerDidConnect(central: CBCentral) {
        Task { @MainActor in
            updateConnectedDevice(central: central)
            addMessage("新设备连接", type: .command, direction: .received)
        }
    }
    
    nonisolated func peripheralManagerDidDisconnect(central: CBCentral) {
        Task { @MainActor in
            if let index = connectedDevices.firstIndex(where: { $0.central === central }) {
                let device = connectedDevices[index]
                connectedDevices.remove(at: index)
                addMessage("设备断开: \(device.name)", type: .command)
            }
        }
    }
}