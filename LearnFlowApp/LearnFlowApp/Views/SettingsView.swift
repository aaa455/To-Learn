import SwiftUI

struct SettingsView: View {
    @StateObject private var aiService = AIService()
    @State private var showingAPIConfig = false

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("AI配置")) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AI提供商")
                                .font(.subheadline)
                            Text(aiService.currentConfig.provider.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if aiService.currentConfig.apiKey.isEmpty {
                            Text("未配置")
                                .font(.caption)
                                .foregroundColor(.red)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingAPIConfig = true
                    }

                    if !aiService.currentConfig.apiKey.isEmpty {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("当前模型")
                                    .font(.subheadline)
                                if let modelId = aiService.currentConfig.model,
                                   let model = aiService.availableModels.first(where: { $0.id == modelId }) {
                                    Text(model.displayName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("未选择")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                    }
                }

                Section(header: Text("关于")) {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("应用名称")
                        Spacer()
                        Text("LearnFlow")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .sheet(isPresented: $showingAPIConfig) {
                AIConfigSheet(aiService: aiService, isPresented: $showingAPIConfig)
            }
        }
    }
}

struct AIConfigSheet: View {
    @ObservedObject var aiService: AIService
    @Binding var isPresented: Bool
    @State private var selectedProvider: AIProvider
    @State private var apiKey: String
    @State private var baseURL: String
    @State private var selectedModel: String
    @State private var showingModelPicker = false

    init(aiService: AIService, isPresented: Binding<Bool>) {
        self.aiService = aiService
        self._isPresented = isPresented
        _selectedProvider = State(initialValue: aiService.currentConfig.provider)
        _apiKey = State(initialValue: aiService.currentConfig.apiKey)
        _baseURL = State(initialValue: aiService.currentConfig.baseURL ?? "")
        _selectedModel = State(initialValue: aiService.currentConfig.model ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("AI提供商")) {
                    Picker("提供商", selection: $selectedProvider) {
                        Text("Claude").tag(AIProvider.claude)
                        Text("OpenAI").tag(AIProvider.openai)
                        Text("DeepSeek").tag(AIProvider.deepseek)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedProvider) { newProvider in
                        // 切换提供商时更新模型列表
                        aiService.currentConfig.provider = newProvider
                        aiService.loadDefaultModels()
                        // 选择默认模型
                        if let firstModel = aiService.availableModels.first {
                            selectedModel = firstModel.id
                        }
                    }
                }

                Section(header: Text("API Key"), footer: Text("你的API Key将安全地存储在本地")) {
                    SecureField("输入API Key", text: $apiKey)
                }

                Section(header: Text("模型选择")) {
                    Button(action: {
                        if !apiKey.isEmpty {
                            fetchModels()
                        }
                        showingModelPicker = true
                    }) {
                        HStack {
                            Text("当前模型")
                            Spacer()
                            if selectedModel.isEmpty {
                                Text("请选择")
                                    .foregroundColor(.secondary)
                            } else {
                                Text(getModelDisplayName(selectedModel))
                                    .foregroundColor(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)

                    if aiService.isLoadingModels {
                        HStack {
                            Spacer()
                            ProgressView()
                            Text("加载模型列表...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }

                Section(header: Text("API地址（可选）"), footer: Text(defaultURLText)) {
                    TextField("自定义API地址", text: $baseURL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                }
            }
            .navigationTitle("AI配置")
            .navigationBarItems(
                leading: Button("取消") {
                    isPresented = false
                },
                trailing: Button("保存") {
                    saveConfig()
                }
                .disabled(apiKey.isEmpty || selectedModel.isEmpty)
            )
            .sheet(isPresented: $showingModelPicker) {
                ModelPickerSheet(
                    models: aiService.availableModels,
                    selectedModel: $selectedModel,
                    isPresented: $showingModelPicker
                )
            }
            .onAppear {
                if selectedModel.isEmpty {
                    if let firstModel = aiService.availableModels.first {
                        selectedModel = firstModel.id
                    }
                }
            }
        }
    }

    private var defaultURLText: String {
        switch selectedProvider {
        case .claude:
            return "默认: https://api.anthropic.com"
        case .openai:
            return "默认: https://api.openai.com/v1"
        case .deepseek:
            return "默认: https://api.deepseek.com"
        }
    }

    private func getModelDisplayName(_ modelId: String) -> String {
        if let model = aiService.availableModels.first(where: { $0.id == modelId }) {
            return model.displayName
        }
        return modelId
    }

    private func fetchModels() {
        // 临时更新配置用于获取模型
        let tempConfig = aiService.currentConfig
        aiService.currentConfig.provider = selectedProvider
        aiService.currentConfig.apiKey = apiKey
        aiService.currentConfig.baseURL = baseURL.isEmpty ? nil : baseURL

        aiService.fetchModels { result in
            switch result {
            case .success(let models):
                if !models.isEmpty && selectedModel.isEmpty {
                    selectedModel = models[0].id
                }
            case .failure:
                // 使用默认模型列表
                break
            }
        }

        // 恢复原配置
        aiService.currentConfig = tempConfig
    }

    private func saveConfig() {
        aiService.currentConfig.provider = selectedProvider
        aiService.currentConfig.apiKey = apiKey
        aiService.currentConfig.baseURL = baseURL.isEmpty ? nil : baseURL
        aiService.currentConfig.model = selectedModel
        aiService.saveConfig()
        isPresented = false
    }
}

struct ModelPickerSheet: View {
    let models: [AIModel]
    @Binding var selectedModel: String
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            List {
                if models.isEmpty {
                    Text("暂无可用模型")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(models) { model in
                        Button(action: {
                            selectedModel = model.id
                            isPresented = false
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(model.displayName)
                                        .font(.headline)
                                    Text(model.id)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if selectedModel == model.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
            }
            .navigationTitle("选择模型")
            .navigationBarItems(trailing: Button("完成") {
                isPresented = false
            })
        }
    }
}
