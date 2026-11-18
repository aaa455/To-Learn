import SwiftUI

struct SettingsView: View {
    @ObservedObject var aiService = AIService.shared
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
                                    Text(aiService.currentConfig.model ?? "未选择")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                    }
                }

                if let error = aiService.configurationError {
                    Section { Text(error).foregroundColor(.red) }
                }

                Section(header: Text("关于")) {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.1")
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
    @State private var isCustomURL: Bool
    @State private var models: [AIModel] = []
    @State private var isLoadingModels = false
    @State private var errorMessage = ""
    @State private var modelRequestID = UUID()

    init(aiService: AIService, isPresented: Binding<Bool>) {
        self.aiService = aiService
        self._isPresented = isPresented
        _selectedProvider = State(initialValue: aiService.currentConfig.provider)
        _apiKey = State(initialValue: aiService.currentConfig.apiKey)
        // 不自动填充baseURL，只在customBaseURL为true时填充
        _baseURL = State(initialValue: aiService.currentConfig.customBaseURL ? (aiService.currentConfig.baseURL ?? "") : "")
        _selectedModel = State(initialValue: aiService.currentConfig.model ?? "")
        _isCustomURL = State(initialValue: aiService.currentConfig.customBaseURL)
    }

    var body: some View {
        NavigationView {
            Form {
                if !errorMessage.isEmpty {
                    Section { Text(errorMessage).foregroundColor(.red) }
                }
                Section(header: Text("AI提供商")) {
                    Picker("提供商", selection: $selectedProvider) {
                        Text("Claude").tag(AIProvider.claude)
                        Text("OpenAI").tag(AIProvider.openai)
                        Text("DeepSeek").tag(AIProvider.deepseek)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedProvider) { newProvider in
                        // 切换提供商时更新默认地址（如果不是自定义地址）
                        if !isCustomURL {
                            baseURL = ""
                        }
                        modelRequestID = UUID()
                        isLoadingModels = false
                        models = aiService.getDefaultModels(for: newProvider)
                        selectedModel = models.first?.id ?? ""
                    }
                }

                Section(header: Text("API Key"), footer: Text("API Key 保存在本机钥匙串中")) {
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

                    if isLoadingModels {
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
                    Toggle("使用自定义地址", isOn: $isCustomURL)

                    if isCustomURL {
                        TextField("自定义API地址", text: $baseURL)
                            .autocapitalization(.none)
                            .keyboardType(.URL)
                    }
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
                    models: models,
                    selectedModel: $selectedModel,
                    isPresented: $showingModelPicker
                )
            }
            .onDisappear { modelRequestID = UUID() }
            .onAppear {
                models = aiService.getDefaultModels(for: selectedProvider)
                if selectedModel.isEmpty {
                    if let firstModel = models.first {
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
        if let model = models.first(where: { $0.id == modelId }) {
            return model.displayName
        }
        return modelId
    }

    private var draftConfig: AIConfig {
        AIConfig(provider: selectedProvider, apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            baseURL: isCustomURL ? baseURL.trimmingCharacters(in: .whitespacesAndNewlines) : AIConfig.defaultBaseURL(for: selectedProvider),
            model: selectedModel, customBaseURL: isCustomURL)
    }

    private func fetchModels() {
        let requestID = UUID()
        modelRequestID = requestID
        isLoadingModels = true
        errorMessage = ""
        aiService.fetchModels(config: draftConfig) { result in
            guard modelRequestID == requestID else { return }
            isLoadingModels = false
            switch result {
            case .success(let fetched):
                if !fetched.isEmpty { models = fetched }
                if selectedModel.isEmpty { selectedModel = models.first?.id ?? "" }
            case .failure(let error): errorMessage = error.localizedDescription
            }
        }
    }

    private func saveConfig() {
        let config = draftConfig
        guard !config.apiKey.isEmpty,
              AIService.endpoint(config: config, path: "models") != nil else {
            errorMessage = "请填写 API Key 和有效的 HTTPS API 地址。"
            return
        }
        do {
            try aiService.saveConfig(config)
            modelRequestID = UUID()
            isPresented = false
        } catch { errorMessage = error.localizedDescription }
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
