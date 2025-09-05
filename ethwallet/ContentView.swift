//
//  ContentView.swift
//  ethwallet
//
//  Created by shelchin on 2025/9/5.
//

import SwiftUI
import CoreBluetooth

struct ContentView: View {
    @StateObject private var viewModel = BluetoothViewModel()
    @State private var selectedTab = 0
    @State private var customMessage = ""
    @State private var hexData = ""
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 主控制面板
            NavigationView {
                MainControlView(viewModel: viewModel)
                    .navigationTitle("🔷 蓝牙外设模拟器")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("控制", systemImage: "antenna.radiowaves.left.and.right")
            }
            .tag(0)
            
            // 消息日志
            NavigationView {
                MessageLogView(viewModel: viewModel)
                    .navigationTitle("📝 消息日志")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("日志", systemImage: "text.bubble")
            }
            .tag(1)
            
            // 数据发送
            NavigationView {
                DataSendView(viewModel: viewModel, customMessage: $customMessage, hexData: $hexData)
                    .navigationTitle("📤 数据发送")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("发送", systemImage: "paperplane")
            }
            .tag(2)
            
            // 统计信息
            NavigationView {
                StatisticsView(viewModel: viewModel)
                    .navigationTitle("📊 统计信息")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("统计", systemImage: "chart.bar")
            }
            .tag(3)
        }
        .alert("提示", isPresented: $viewModel.showAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage)
        }
    }
}

// MARK: - 主控制视图
struct MainControlView: View {
    @ObservedObject var viewModel: BluetoothViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 蓝牙状态卡片
                BluetoothStatusCard(viewModel: viewModel)
                
                // 广播控制
                AdvertisingControlCard(viewModel: viewModel)
                
                // 连接设备列表
                ConnectedDevicesCard(viewModel: viewModel)
                
                // 流数据控制
                StreamControlCard(viewModel: viewModel)
            }
            .padding()
        }
    }
}

// MARK: - 蓝牙状态卡片
struct BluetoothStatusCard: View {
    @ObservedObject var viewModel: BluetoothViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.title2)
                    .foregroundColor(viewModel.bluetoothStatusColor)
                
                Text("蓝牙状态")
                    .font(.headline)
                
                Spacer()
                
                Text(viewModel.bluetoothStatusText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("设备信息", systemImage: "iphone")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text(DeviceInfo.getDeviceModelInfo())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("蓝牙广播名称")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                    
                    Text("使用系统设置中的设备名称")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    
                    Text("(设置 > 通用 > 关于本机 > 名称)")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                        .italic()
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("服务 UUID", systemImage: "qrcode")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .onTapGesture {
                            UIPasteboard.general.string = UUIDManager.shared.serviceUUID.uuidString
                            viewModel.showAlert = true
                            viewModel.alertMessage = "服务 UUID 已复制到剪贴板"
                        }
                }
                
                Text(UUIDManager.shared.serviceUUID.uuidString)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 2)
    }
}

// MARK: - 广播控制卡片
struct AdvertisingControlCard: View {
    @ObservedObject var viewModel: BluetoothViewModel
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: viewModel.isAdvertising ? "antenna.radiowaves.left.and.right.circle.fill" : "antenna.radiowaves.left.and.right.circle")
                    .font(.title2)
                    .foregroundColor(viewModel.isAdvertising ? .green : .gray)
                
                Text("广播控制")
                    .font(.headline)
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { viewModel.isAdvertising },
                    set: { _ in viewModel.toggleAdvertising() }
                ))
                .disabled(!viewModel.isBluetoothReady)
            }
            
            if viewModel.isAdvertising {
                Text("正在广播蓝牙服务...")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 2)
    }
}

// MARK: - 连接设备卡片
struct ConnectedDevicesCard: View {
    @ObservedObject var viewModel: BluetoothViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "link.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("连接设备")
                    .font(.headline)
                
                Spacer()
                
                Text("\(viewModel.connectedDevices.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
            }
            
            if viewModel.connectedDevices.isEmpty {
                Text("暂无连接设备")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 10)
            } else {
                ForEach(viewModel.connectedDevices) { device in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(device.name)
                                .font(.caption)
                                .lineLimit(1)
                            
                            Text("订阅: \(device.subscribedCharacteristics.count) 个特征")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.disconnectDevice(device)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red.opacity(0.7))
                        }
                    }
                    .padding(.vertical, 5)
                    
                    if device.id != viewModel.connectedDevices.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 2)
    }
}

// MARK: - 流控制卡片
struct StreamControlCard: View {
    @ObservedObject var viewModel: BluetoothViewModel
    @State private var tempInterval: Double = 1.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.title2)
                    .foregroundColor(viewModel.isStreaming ? .orange : .gray)
                
                Text("流数据控制")
                    .font(.headline)
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { viewModel.isStreaming },
                    set: { _ in viewModel.toggleStreaming() }
                ))
            }
            
            VStack(alignment: .leading) {
                Text("发送间隔: \(String(format: "%.1f", tempInterval)) 秒")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Slider(value: $tempInterval, in: 0.1...5.0, step: 0.1)
                    .disabled(viewModel.isStreaming)
                    .onChange(of: tempInterval) { newValue in
                        viewModel.streamInterval = newValue
                    }
            }
            
            Button(action: {
                viewModel.sendTestMessage()
            }) {
                Label("发送测试消息", systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.connectedDevices.isEmpty)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 2)
        .onAppear {
            tempInterval = viewModel.streamInterval
        }
    }
}

// MARK: - 消息日志视图
struct MessageLogView: View {
    @ObservedObject var viewModel: BluetoothViewModel
    
    var body: some View {
        VStack {
            if viewModel.messages.isEmpty {
                ContentUnavailableView(
                    "暂无消息",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("蓝牙通信消息将在这里显示")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.messages) { message in
                            MessageRow(message: message)
                            Divider()
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("清空") {
                    viewModel.clearMessages()
                }
                .disabled(viewModel.messages.isEmpty)
            }
        }
    }
}

// MARK: - 消息行
struct MessageRow: View {
    let message: BLEMessage
    
    var iconName: String {
        switch message.type {
        case .text: return "text.bubble"
        case .binary: return "01.square"
        case .command: return "terminal"
        case .notification: return "bell"
        case .error: return "exclamationmark.triangle"
        }
    }
    
    var iconColor: Color {
        switch message.type {
        case .error: return .red
        case .notification: return .orange
        case .command: return .blue
        default: return message.direction == .sent ? .green : .purple
        }
    }
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(3)
                
                HStack {
                    Text(message.timestamp, format: .dateTime.hour().minute().second())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if message.dataSize > 0 {
                        Text("• \(message.dataSize) bytes")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("• \(message.direction == .sent ? "发送" : "接收")")
                        .font(.caption2)
                        .foregroundColor(message.direction == .sent ? .green : .purple)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 数据发送视图
struct DataSendView: View {
    @ObservedObject var viewModel: BluetoothViewModel
    @Binding var customMessage: String
    @Binding var hexData: String
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 文本消息
                VStack(alignment: .leading, spacing: 10) {
                    Label("文本消息", systemImage: "text.quote")
                        .font(.headline)
                    
                    TextField("输入要发送的消息...", text: $customMessage, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                        .focused($isTextFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            isTextFieldFocused = false
                        }
                    
                    Button(action: {
                        isTextFieldFocused = false
                        viewModel.sendCustomMessage(customMessage)
                        customMessage = ""
                    }) {
                        Label("发送文本", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(customMessage.isEmpty || viewModel.connectedDevices.isEmpty)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(15)
                .shadow(radius: 2)
                
                // 十六进制数据
                VStack(alignment: .leading, spacing: 10) {
                    Label("十六进制数据", systemImage: "01.square")
                        .font(.headline)
                    
                    TextField("输入十六进制 (例: 48 65 6C 6C 6F)", text: $hexData)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .focused($isTextFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            isTextFieldFocused = false
                        }
                    
                    Button(action: {
                        isTextFieldFocused = false
                        viewModel.sendBinaryData(hexData)
                        hexData = ""
                    }) {
                        Label("发送二进制", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(hexData.isEmpty || viewModel.connectedDevices.isEmpty)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(15)
                .shadow(radius: 2)
                
                // 预设命令
                VStack(alignment: .leading, spacing: 10) {
                    Label("预设命令", systemImage: "command")
                        .font(.headline)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        Button("PING") {
                            viewModel.sendCustomMessage("PING")
                        }
                        .buttonStyle(.bordered)
                        
                        Button("GET_INFO") {
                            viewModel.sendCustomMessage("GET_INFO")
                        }
                        .buttonStyle(.bordered)
                        
                        Button("RESET") {
                            viewModel.sendCustomMessage("RESET")
                        }
                        .buttonStyle(.bordered)
                        
                        Button("START_STREAM") {
                            viewModel.sendCustomMessage("START_STREAM")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(15)
                .shadow(radius: 2)
            }
            .padding()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    isTextFieldFocused = false
                }
            }
        }
        .onTapGesture {
            isTextFieldFocused = false
        }
    }
}

// MARK: - 统计视图
struct StatisticsView: View {
    @ObservedObject var viewModel: BluetoothViewModel
    @State private var showingUUIDDetails = false
    @State private var showingResetConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 数据统计
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                    StatCard(
                        title: "发送字节",
                        value: "\(viewModel.bytesSent)",
                        icon: "arrow.up.circle.fill",
                        color: .green
                    )
                    
                    StatCard(
                        title: "接收字节",
                        value: "\(viewModel.bytesReceived)",
                        icon: "arrow.down.circle.fill",
                        color: .blue
                    )
                    
                    StatCard(
                        title: "通知数",
                        value: "\(viewModel.notificationsSent)",
                        icon: "bell.circle.fill",
                        color: .orange
                    )
                    
                    StatCard(
                        title: "命令数",
                        value: "\(viewModel.commandsProcessed)",
                        icon: "terminal.fill",
                        color: .purple
                    )
                }
                
                // 重置按钮
                Button(action: {
                    viewModel.resetStats()
                }) {
                    Label("重置统计", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.top)
                
                Divider()
                
                // UUID 配置
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Image(systemName: "key.fill")
                            .font(.title2)
                            .foregroundColor(.indigo)
                        
                        Text("UUID 配置")
                            .font(.headline)
                        
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("当前 UUID 概览")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            // 服务 UUID
                            HStack {
                                Text("服务:")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .frame(width: 40, alignment: .leading)
                                
                                Text(String(UUIDManager.shared.serviceUUID.uuidString.prefix(20)) + "...")
                                    .font(.system(.caption2, design: .monospaced))
                                    .lineLimit(1)
                                    .onTapGesture {
                                        UIPasteboard.general.string = UUIDManager.shared.serviceUUID.uuidString
                                        viewModel.showAlert = true
                                        viewModel.alertMessage = "服务 UUID 已复制"
                                    }
                            }
                            
                            // 显示特征数量
                            Text("4 个特征 UUID")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    HStack(spacing: 10) {
                        Button(action: {
                            showingUUIDDetails = true
                        }) {
                            Label("查看所有", systemImage: "eye")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: {
                            showingResetConfirmation = true
                        }) {
                            Label("重置 UUID", systemImage: "arrow.triangle.2.circlepath")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.orange)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(15)
                .shadow(radius: 2)
            }
            .padding()
        }
        .sheet(isPresented: $showingUUIDDetails) {
            UUIDDetailsView()
        }
        .alert("重置 UUID", isPresented: $showingResetConfirmation) {
            Button("取消", role: .cancel) {}
            Button("重置", role: .destructive) {
                viewModel.resetUUIDs()
            }
        } message: {
            Text("重置后将生成新的 UUID，需要重新配对设备。确定要继续吗？")
        }
    }
}

// MARK: - UUID 详情视图
struct UUIDDetailsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var copiedUUID = ""
    @State private var showingCopyAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(Array(UUIDManager.shared.getAllUUIDs().sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(key)
                                .font(.headline)
                            
                            Text(value)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .onTapGesture {
                                    UIPasteboard.general.string = value
                                    copiedUUID = key
                                    showingCopyAlert = true
                                }
                            
                            Divider()
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("JSON 格式")
                            .font(.headline)
                        
                        if let jsonString = UUIDManager.shared.exportUUIDsAsJSON() {
                            Text(jsonString)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .onTapGesture {
                                    UIPasteboard.general.string = jsonString
                                    copiedUUID = "JSON 配置"
                                    showingCopyAlert = true
                                }
                        }
                    }
                    
                    Text("💡 点击任意 UUID 复制到剪贴板")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top)
                }
                .padding()
            }
            .navigationTitle("UUID 详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .alert("已复制", isPresented: $showingCopyAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("\(copiedUUID) 已复制到剪贴板")
        }
    }
}

// MARK: - 统计卡片
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .bold()
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 2)
    }
}

#Preview {
    ContentView()
}
