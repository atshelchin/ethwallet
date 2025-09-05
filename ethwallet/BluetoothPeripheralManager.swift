//
//  BluetoothPeripheralManager.swift
//  ethwallet
//
//  蓝牙外设管理器 - 模拟 BLE 设备供 Web Bluetooth 调试
//

import Foundation
import CoreBluetooth
import UIKit
import os.log

// MARK: - 蓝牙服务和特征 UUID 定义
struct BLEConstants {
    // 使用动态生成的 UUID
    static var serviceUUID: CBUUID {
        UUIDManager.shared.serviceUUID
    }
    
    // 特征 UUID
    static var readCharacteristicUUID: CBUUID {
        UUIDManager.shared.readCharacteristicUUID
    }
    static var writeCharacteristicUUID: CBUUID {
        UUIDManager.shared.writeCharacteristicUUID
    }
    static var notifyCharacteristicUUID: CBUUID {
        UUIDManager.shared.notifyCharacteristicUUID
    }
    static var readWriteCharacteristicUUID: CBUUID {
        UUIDManager.shared.readWriteCharacteristicUUID
    }
    
    // 获取完整的设备名称
    static var deviceName: String {
        // 使用 DeviceInfo 获取完整的设备名称
        return DeviceInfo.getFullDeviceName()
    }
}

// MARK: - 数据传输协议
enum BLECommand: String {
    case ping = "PING"
    case echo = "ECHO"
    case getInfo = "GET_INFO"
    case setData = "SET_DATA"
    case getData = "GET_DATA"
    case startStream = "START_STREAM"
    case stopStream = "STOP_STREAM"
    case reset = "RESET"
}

// MARK: - 委托协议
protocol BluetoothPeripheralManagerDelegate: AnyObject {
    func peripheralManagerDidUpdateState(_ state: CBManagerState)
    func peripheralManagerDidStartAdvertising(_ error: Error?)
    func peripheralManagerDidReceiveRead(from central: CBCentral, characteristic: CBCharacteristic)
    func peripheralManagerDidReceiveWrite(from central: CBCentral, characteristic: CBCharacteristic, value: Data)
    func peripheralManagerDidSubscribe(central: CBCentral, characteristic: CBCharacteristic)
    func peripheralManagerDidUnsubscribe(central: CBCentral, characteristic: CBCharacteristic)
    func peripheralManagerDidConnect(central: CBCentral)
    func peripheralManagerDidDisconnect(central: CBCentral)
}

// MARK: - 蓝牙外设管理器
class BluetoothPeripheralManager: NSObject {
    
    // MARK: - 属性
    private var peripheralManager: CBPeripheralManager?
    private var service: CBMutableService?
    
    // 特征
    private var readCharacteristic: CBMutableCharacteristic?
    private var writeCharacteristic: CBMutableCharacteristic?
    private var notifyCharacteristic: CBMutableCharacteristic?
    private var readWriteCharacteristic: CBMutableCharacteristic?
    private var deviceInfoCharacteristic: CBMutableCharacteristic?
    
    // 连接的中心设备
    private var connectedCentrals = Set<CBCentral>()
    private var subscribedCentrals = Set<CBCentral>()
    
    // 数据存储
    private var storedData = Data()
    private var messageCounter = 0
    
    // 流数据定时器
    private var streamTimer: Timer?
    private var isStreaming = false
    
    // 心跳保活定时器
    private var heartbeatTimer: Timer?
    private var isHeartbeatEnabled = true
    private var lastActivityTime = Date()
    private var activityHeartbeatTimer: Timer?
    
    // 委托
    weak var delegate: BluetoothPeripheralManagerDelegate?
    
    // 日志
    private let logger = Logger(subsystem: "com.ethwallet.bluetooth", category: "PeripheralManager")
    
    // MARK: - 初始化
    override init() {
        super.init()
        setupPeripheralManager()
    }
    
    private func setupPeripheralManager() {
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    // MARK: - 公共方法
    
    /// 开始广播
    func startAdvertising() {
        guard let peripheralManager = peripheralManager,
              peripheralManager.state == .poweredOn else {
            logger.warning("无法开始广播：蓝牙未就绪")
            return
        }
        
        // 检查是否已经在广播
        if peripheralManager.isAdvertising {
            logger.info("蓝牙已经在广播中")
            return
        }
        
        // 设置广播数据
        // 虽然 iOS 会覆盖 LocalName，但我们还是设置它
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [BLEConstants.serviceUUID],
            CBAdvertisementDataLocalNameKey: "EthWallet-iOS"  // 尝试设置自定义名称
        ]
        
        peripheralManager.startAdvertising(advertisementData)
        logger.info("开始蓝牙广播，设备名称: \(BLEConstants.deviceName)")
    }
    
    /// 停止广播
    func stopAdvertising() {
        guard let peripheralManager = peripheralManager else { return }
        
        if peripheralManager.isAdvertising {
            peripheralManager.stopAdvertising()
            logger.info("停止蓝牙广播")
        } else {
            logger.info("蓝牙未在广播中")
        }
    }
    
    /// 获取广播状态
    var isAdvertising: Bool {
        return peripheralManager?.isAdvertising ?? false
    }
    
    /// 发送通知数据
    func sendNotification(data: Data) {
        guard let notifyCharacteristic = notifyCharacteristic,
              !subscribedCentrals.isEmpty else {
            logger.warning("无法发送通知：没有订阅的设备")
            return
        }
        
        let success = peripheralManager?.updateValue(
            data,
            for: notifyCharacteristic,
            onSubscribedCentrals: Array(subscribedCentrals)
        ) ?? false
        
        if success {
            logger.info("通知发送成功：\(data.count) 字节")
        } else {
            logger.warning("通知发送失败，数据已排队")
        }
    }
    
    /// 发送测试消息
    func sendTestMessage() {
        messageCounter += 1
        let message = "Test Message #\(messageCounter) at \(Date().timeIntervalSince1970)"
        if let data = message.data(using: .utf8) {
            sendNotification(data: data)
        }
    }
    
    /// 开始流数据
    func startStreamingData(interval: TimeInterval = 1.0) {
        guard !isStreaming else { return }
        
        isStreaming = true
        streamTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.sendStreamData()
        }
        logger.info("开始流数据，间隔：\(interval)秒")
    }
    
    /// 停止流数据
    func stopStreamingData() {
        streamTimer?.invalidate()
        streamTimer = nil
        isStreaming = false
        logger.info("停止流数据")
    }
    
    /// 开始心跳保活
    func startHeartbeat() {
        guard isHeartbeatEnabled else { return }
        
        // 停止现有的心跳
        stopHeartbeat()
        
        // 每10秒发送一次心跳，确保连接不会超时
        // iOS BLE 连接监督超时通常是 20-30 秒，10秒的心跳可以确保连接稳定
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
        
        logger.info("开始心跳保活，间隔：10秒")
    }
    
    /// 停止心跳保活
    func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        logger.info("停止心跳保活")
    }
    
    /// 发送心跳包
    private func sendHeartbeat() {
        guard !subscribedCentrals.isEmpty else { 
            logger.debug("没有订阅的设备，跳过心跳")
            return 
        }
        
        let timestamp = Date().timeIntervalSince1970
        let heartbeatData = "HEARTBEAT:\(timestamp)".data(using: .utf8)!
        
        // 同时通过 notify 和 readWrite 特征发送心跳，增加成功率
        var sent = false
        
        if let notifyCharacteristic = notifyCharacteristic {
            let success = peripheralManager?.updateValue(
                heartbeatData,
                for: notifyCharacteristic,
                onSubscribedCentrals: nil
            ) ?? false
            
            if success {
                logger.debug("心跳包通过 notify 特征发送成功")
                sent = true
            }
        }
        
        if let readWriteCharacteristic = readWriteCharacteristic, !sent {
            let success = peripheralManager?.updateValue(
                heartbeatData,
                for: readWriteCharacteristic,
                onSubscribedCentrals: nil
            ) ?? false
            
            if success {
                logger.debug("心跳包通过 readWrite 特征发送成功")
            } else {
                logger.debug("心跳包已排队")
            }
        }
    }
    
    // MARK: - 私有方法
    
    private func getDeviceInfoJSON() -> String {
        // 创建设备信息 JSON
        let deviceInfo: [String: Any] = [
            "name": "EthWallet iOS Debug",  // 应用自定义名称
            "model": UIDevice.current.model,
            "systemName": UIDevice.current.systemName,
            "systemVersion": UIDevice.current.systemVersion,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            "identifier": UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: deviceInfo, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        return "{\"name\":\"EthWallet iOS\",\"model\":\"\(UIDevice.current.model)\"}"
    }
    
    private func setupService() {
        // 先移除旧服务
        if let oldService = service {
            peripheralManager?.remove(oldService)
        }
        
        // 创建特征
        readCharacteristic = CBMutableCharacteristic(
            type: BLEConstants.readCharacteristicUUID,
            properties: [.read],
            value: nil,
            permissions: [.readable]
        )
        
        writeCharacteristic = CBMutableCharacteristic(
            type: BLEConstants.writeCharacteristicUUID,
            properties: [.write, .writeWithoutResponse],
            value: nil,
            permissions: [.writeable]
        )
        
        notifyCharacteristic = CBMutableCharacteristic(
            type: BLEConstants.notifyCharacteristicUUID,
            properties: [.notify, .indicate],
            value: nil,
            permissions: [.readable]
        )
        
        readWriteCharacteristic = CBMutableCharacteristic(
            type: BLEConstants.readWriteCharacteristicUUID,
            properties: [.read, .write, .notify],
            value: nil,
            permissions: [.readable, .writeable]
        )
        
        // 创建设备信息特征（只读，包含设备名称和型号）
        let deviceInfo = getDeviceInfoJSON()
        deviceInfoCharacteristic = CBMutableCharacteristic(
            type: UUIDManager.shared.deviceInfoCharacteristicUUID,
            properties: [.read],
            value: deviceInfo.data(using: .utf8),
            permissions: [.readable]
        )
        
        // 创建服务
        service = CBMutableService(type: BLEConstants.serviceUUID, primary: true)
        service?.characteristics = [
            readCharacteristic!,
            writeCharacteristic!,
            notifyCharacteristic!,
            readWriteCharacteristic!,
            deviceInfoCharacteristic!
        ]
        
        logger.info("准备添加服务，UUID: \(BLEConstants.serviceUUID)")
        logger.info("服务包含 \(self.service?.characteristics?.count ?? 0) 个特征")
        
        // 添加服务
        peripheralManager?.add(service!)
        logger.info("已请求添加蓝牙服务")
    }
    
    private func sendStreamData() {
        let streamData = createStreamData()
        sendNotification(data: streamData)
    }
    
    private func createStreamData() -> Data {
        // 创建模拟传感器数据
        let timestamp = Date().timeIntervalSince1970
        let temperature = Double.random(in: 20...30)
        let humidity = Double.random(in: 40...60)
        let pressure = Double.random(in: 1000...1020)
        
        let jsonData: [String: Any] = [
            "timestamp": timestamp,
            "temperature": temperature,
            "humidity": humidity,
            "pressure": pressure,
            "counter": messageCounter
        ]
        
        messageCounter += 1
        
        if let data = try? JSONSerialization.data(withJSONObject: jsonData) {
            return data
        }
        
        return Data()
    }
    
    private func processCommand(_ command: String, data: Data?) -> Data {
        guard let cmd = BLECommand(rawValue: command.uppercased()) else {
            return "Unknown command".data(using: .utf8) ?? Data()
        }
        
        switch cmd {
        case .ping:
            return "PONG".data(using: .utf8) ?? Data()
            
        case .echo:
            return data ?? Data()
            
        case .getInfo:
            let info: [String: Any] = [
                "device": BLEConstants.deviceName,
                "version": "1.0.0",
                "connected": connectedCentrals.count,
                "subscribed": subscribedCentrals.count,
                "timestamp": Date().timeIntervalSince1970
            ]
            return (try? JSONSerialization.data(withJSONObject: info)) ?? Data()
            
        case .setData:
            if let data = data {
                storedData = data
                return "OK".data(using: .utf8) ?? Data()
            }
            return "ERROR: No data".data(using: .utf8) ?? Data()
            
        case .getData:
            return storedData
            
        case .startStream:
            startStreamingData()
            return "Stream started".data(using: .utf8) ?? Data()
            
        case .stopStream:
            stopStreamingData()
            return "Stream stopped".data(using: .utf8) ?? Data()
            
        case .reset:
            storedData = Data()
            messageCounter = 0
            return "Reset complete".data(using: .utf8) ?? Data()
        }
    }
}

// MARK: - CBPeripheralManagerDelegate
extension BluetoothPeripheralManager: CBPeripheralManagerDelegate {
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        logger.info("蓝牙状态更新：\(peripheral.state.rawValue)")
        
        switch peripheral.state {
        case .poweredOn:
            setupService()
            // 服务设置后可以开始广播
            logger.info("蓝牙已就绪，可以开始广播")
        case .poweredOff:
            logger.warning("蓝牙已关闭")
        case .unauthorized:
            logger.error("蓝牙未授权")
        case .unsupported:
            logger.error("设备不支持蓝牙")
        default:
            break
        }
        
        delegate?.peripheralManagerDidUpdateState(peripheral.state)
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            logger.error("广播启动失败：\(error.localizedDescription)")
        } else {
            logger.info("广播启动成功")
        }
        delegate?.peripheralManagerDidStartAdvertising(error)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            logger.error("添加服务失败：\(error.localizedDescription)")
            // 重要：如果服务添加失败，需要处理
            delegate?.peripheralManagerDidStartAdvertising(error)
        } else {
            logger.info("服务添加成功：\(service.uuid)")
            logger.info("服务包含 \(service.characteristics?.count ?? 0) 个特征")
            
            // 服务添加成功后自动开始广播
            if !peripheral.isAdvertising {
                startAdvertising()
            } else {
                // 如果已经在广播，通知代理更新状态
                logger.info("服务添加后，广播已自动开启")
                delegate?.peripheralManagerDidStartAdvertising(nil)
            }
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        logger.info("设备订阅特征：\(characteristic.uuid)")
        
        connectedCentrals.insert(central)
        
        if characteristic.uuid == BLEConstants.notifyCharacteristicUUID ||
           characteristic.uuid == BLEConstants.readWriteCharacteristicUUID {
            subscribedCentrals.insert(central)
            
            // 有设备订阅通知特征时，开始心跳保活
            if subscribedCentrals.count == 1 {
                startHeartbeat()
            }
        }
        
        delegate?.peripheralManagerDidSubscribe(central: central, characteristic: characteristic)
        delegate?.peripheralManagerDidConnect(central: central)
        
        // 发送欢迎消息，包含 MTU 信息
        let mtuInfo = "Connected to \(BLEConstants.deviceName) - MTU: \(central.maximumUpdateValueLength)".data(using: .utf8)!
        sendNotification(data: mtuInfo)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        logger.info("设备取消订阅特征：\(characteristic.uuid)")
        
        subscribedCentrals.remove(central)
        
        // 如果没有设备订阅了，停止心跳
        if subscribedCentrals.isEmpty {
            stopHeartbeat()
        }
        
        if !isConnected(central: central) {
            connectedCentrals.remove(central)
            delegate?.peripheralManagerDidDisconnect(central: central)
        }
        
        delegate?.peripheralManagerDidUnsubscribe(central: central, characteristic: characteristic)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        logger.info("收到读取请求：\(request.characteristic.uuid)")
        
        // 更新活动时间
        lastActivityTime = Date()
        
        // 记录连接的设备
        if !connectedCentrals.contains(request.central) {
            connectedCentrals.insert(request.central)
            delegate?.peripheralManagerDidConnect(central: request.central)
        }
        
        if request.characteristic.uuid == BLEConstants.readCharacteristicUUID {
            let responseData = "Read at \(Date())".data(using: .utf8)!
            request.value = responseData
            peripheral.respond(to: request, withResult: .success)
        } else if request.characteristic.uuid == BLEConstants.readWriteCharacteristicUUID {
            request.value = storedData.count > 0 ? storedData : "No data".data(using: .utf8)
            peripheral.respond(to: request, withResult: .success)
        } else if request.characteristic.uuid == UUIDManager.shared.deviceInfoCharacteristicUUID {
            // 返回设备信息
            let deviceInfo = getDeviceInfoJSON()
            request.value = deviceInfo.data(using: .utf8)
            peripheral.respond(to: request, withResult: .success)
        } else {
            peripheral.respond(to: request, withResult: .attributeNotFound)
        }
        
        delegate?.peripheralManagerDidReceiveRead(from: request.central, characteristic: request.characteristic)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            logger.info("收到写入请求：\(request.characteristic.uuid)")
            
            // 更新活动时间
            lastActivityTime = Date()
            
            // 记录连接的设备
            if !connectedCentrals.contains(request.central) {
                connectedCentrals.insert(request.central)
                delegate?.peripheralManagerDidConnect(central: request.central)
            }
            
            if let value = request.value {
                // 处理接收到的数据
                if let string = String(data: value, encoding: .utf8) {
                    logger.info("接收到数据：\(string)")
                    
                    // 解析命令
                    let components = string.components(separatedBy: ":")
                    let command = components.first ?? ""
                    let commandData = components.count > 1 ? components[1].data(using: .utf8) : nil
                    
                    let response = processCommand(command, data: commandData)
                    
                    // 如果是读写特征，更新存储的数据
                    if request.characteristic.uuid == BLEConstants.readWriteCharacteristicUUID {
                        storedData = response
                        // 发送通知
                        sendNotification(data: response)
                    }
                } else {
                    // 二进制数据
                    logger.info("接收到二进制数据：\(value.count) 字节")
                    storedData = value
                }
                
                delegate?.peripheralManagerDidReceiveWrite(
                    from: request.central,
                    characteristic: request.characteristic,
                    value: value
                )
            }
            
            peripheral.respond(to: request, withResult: .success)
        }
    }
    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        // 当之前发送失败的通知可以重试时调用
        logger.info("外设管理器已准备好更新订阅者")
    }
    
    // MARK: - 辅助方法
    
    private func isConnected(central: CBCentral) -> Bool {
        // 检查该中心设备是否还订阅了任何特征
        return subscribedCentrals.contains(central)
    }
}

// MARK: - CBManagerState 扩展
extension CBManagerState {
    var description: String {
        switch self {
        case .unknown:
            return "未知"
        case .resetting:
            return "重置中"
        case .unsupported:
            return "不支持"
        case .unauthorized:
            return "未授权"
        case .poweredOff:
            return "已关闭"
        case .poweredOn:
            return "已开启"
        @unknown default:
            return "未知状态"
        }
    }
}