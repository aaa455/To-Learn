import Foundation
import Combine
import Security

// AI服务配置
enum AIProvider: String, Codable {
    case claude = "Claude"
    case openai = "OpenAI"
    case deepseek = "DeepSeek"
}

struct AIConfig: Codable {
    var provider: AIProvider
    var apiKey: String
    var baseURL: String?
    var model: String? // 选择的模型
    var customBaseURL: Bool // 标记是否是用户自定义的地址

    static var claude: AIConfig {
        AIConfig(provider: .claude, apiKey: "", baseURL: "https://api.anthropic.com", model: "claude-3-5-sonnet-20241022", customBaseURL: false)
    }

    static var openai: AIConfig {
        AIConfig(provider: .openai, apiKey: "", baseURL: "https://api.openai.com/v1", model: "gpt-4", customBaseURL: false)
    }

    static var deepseek: AIConfig {
        AIConfig(provider: .deepseek, apiKey: "", baseURL: "https://api.deepseek.com", model: "deepseek-chat", customBaseURL: false)
    }

    // 获取默认地址
    static func defaultBaseURL(for provider: AIProvider) -> String {
        switch provider {
        case .claude:
            return "https://api.anthropic.com"
        case .openai:
            return "https://api.openai.com/v1"
        case .deepseek:
            return "https://api.deepseek.com"
        }
    }
}

extension AIConfig {
    private enum LegacyKeys: String, CodingKey { case provider, apiKey, baseURL, model, customBaseURL }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: LegacyKeys.self)
        provider = try values.decode(AIProvider.self, forKey: .provider)
        apiKey = try values.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        baseURL = try values.decodeIfPresent(String.self, forKey: .baseURL)
        model = try values.decodeIfPresent(String.self, forKey: .model)
        let defaultURL = Self.defaultBaseURL(for: provider)
        customBaseURL = try values.decodeIfPresent(Bool.self, forKey: .customBaseURL)
            ?? (baseURL.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "/")) != defaultURL } ?? false)
    }

    var withoutAPIKey: AIConfig {
        var copy = self
        copy.apiKey = ""
        return copy
    }
}

private enum APIKeyStore {
    static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.learnflow.app.ai",
         kSecAttrAccount as String: "active-api-key"]
    }

    static func read() throws -> String? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw keychainError(status) }
        return (result as? Data).flatMap { String(data: $0, encoding: .utf8) }
    }

    static func write(_ key: String) throws {
        let attributes: [String: Any] = [kSecValueData as String: Data(key.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw keychainError(status) }
    }

    static func keychainError(_ status: OSStatus) -> Error {
        NSError(domain: NSOSStatusErrorDomain, code: Int(status),
            userInfo: [NSLocalizedDescriptionKey: "无法访问安全存储，请解锁设备后重试（\(status)）。"])
    }
}

// 模型信息
struct AIModel: Identifiable, Codable {
    let id: String
    let name: String
    let provider: AIProvider

    var displayName: String {
        name
    }
}

// AI服务（单例模式，全局共享）
class AIService: ObservableObject {
    static let shared = AIService()

    @Published private(set) var currentConfig: AIConfig = .claude
    @Published private(set) var availableModels: [AIModel] = []
    @Published private(set) var configurationError: String?

    private init() {
        do {
            if let data = UserDefaults.standard.data(forKey: "aiConfig") {
                currentConfig = try JSONDecoder().decode(AIConfig.self, from: data)
            }
            if currentConfig.apiKey.isEmpty {
                currentConfig.apiKey = try APIKeyStore.read() ?? ""
            } else {
                // Retain the legacy configuration if secure storage fails.
                try saveConfig(currentConfig)
            }
        } catch { configurationError = error.localizedDescription }
        availableModels = getDefaultModels(for: currentConfig.provider)
    }

    func saveConfig(_ config: AIConfig) throws {
        let encoded = try JSONEncoder().encode(config.withoutAPIKey)
        try APIKeyStore.write(config.apiKey)
        UserDefaults.standard.set(encoded, forKey: "aiConfig")
        currentConfig = config
        availableModels = getDefaultModels(for: config.provider)
        configurationError = nil
    }

    // 获取默认模型列表
    func getDefaultModels(for provider: AIProvider) -> [AIModel] {
        switch provider {
        case .claude:
            return [
                AIModel(id: "claude-3-5-sonnet-20241022", name: "Claude 3.5 Sonnet", provider: .claude),
                AIModel(id: "claude-3-5-haiku-20241022", name: "Claude 3.5 Haiku", provider: .claude),
                AIModel(id: "claude-3-opus-20240229", name: "Claude 3 Opus", provider: .claude),
                AIModel(id: "claude-3-sonnet-20240229", name: "Claude 3 Sonnet", provider: .claude),
                AIModel(id: "claude-3-haiku-20240307", name: "Claude 3 Haiku", provider: .claude)
            ]
        case .openai:
            return [
                AIModel(id: "gpt-4o", name: "GPT-4o", provider: .openai),
                AIModel(id: "gpt-4o-mini", name: "GPT-4o Mini", provider: .openai),
                AIModel(id: "gpt-4-turbo", name: "GPT-4 Turbo", provider: .openai),
                AIModel(id: "gpt-4", name: "GPT-4", provider: .openai),
                AIModel(id: "gpt-3.5-turbo", name: "GPT-3.5 Turbo", provider: .openai)
            ]
        case .deepseek:
            return [
                AIModel(id: "deepseek-chat", name: "DeepSeek Chat", provider: .deepseek),
                AIModel(id: "deepseek-coder", name: "DeepSeek Coder", provider: .deepseek)
            ]
        }
    }

    // Draft requests never modify the saved or live configuration.
    func fetchModels(config: AIConfig, completion: @escaping (Result<[AIModel], Error>) -> Void) {
        guard !config.apiKey.isEmpty else {
            completion(.failure(Self.error("请先配置API Key")))
            return
        }
        guard config.provider == .openai else {
            completion(.success(getDefaultModels(for: config.provider)))
            return
        }
        guard let url = Self.endpoint(config: config, path: "models") else {
            completion(.failure(Self.error("请输入有效的 HTTPS API 地址")))
            return
        }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        Self.send(request) { result in
            completion(result.flatMap { data in
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let list = json["data"] as? [[String: Any]] else {
                    return .failure(Self.error("模型列表响应格式错误"))
                }
                let models = list.compactMap { item -> AIModel? in
                    guard let id = item["id"] as? String, !id.isEmpty else { return nil }
                    return AIModel(id: id, name: id, provider: config.provider)
                }
                return .success(models)
            })
        }
    }

    // 生成工作流
    func generateWorkflow(goal: String, completion: @escaping (Result<Workflow, Error>) -> Void) {
        let prompt = generateWorkflowPrompt(goal: goal)
        callAI(prompt: prompt) { result in
            switch result {
            case .success(let response):
                // 解析AI响应，构建工作流
                if let workflow = Self.parseWorkflowFromResponse(response, goal: goal) {
                    completion(.success(workflow))
                } else {
                    completion(.failure(NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析工作流"])))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // 生成时间计划
    func generateTimePlan(workflow: Workflow, availableMinutes: Int, completion: @escaping (Result<[TimePlan], Error>) -> Void) {
        let prompt = generateTimePlanPrompt(workflow: workflow, availableMinutes: availableMinutes)
        callAI(prompt: prompt) { result in
            switch result {
            case .success(let response):
                // 解析AI响应，生成多个时间方案
                let plans = Self.parseTimePlansFromResponse(response, workflow: workflow, availableMinutes: availableMinutes)
                if plans.isEmpty {
                    completion(.failure(Self.error("AI 返回的方案无效，请重新生成。")))
                } else {
                    completion(.success(plans))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private static func error(_ message: String) -> Error {
        NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    static func endpoint(config: AIConfig, path: String) -> URL? {
        let base = (config.baseURL ?? AIConfig.defaultBaseURL(for: config.provider))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard var url = URL(string: base), url.scheme?.lowercased() == "https",
              url.host != nil, url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil else { return nil }
        for part in path.split(separator: "/") { url.appendPathComponent(String(part)) }
        return url
    }

    private static func send(_ request: URLRequest, completion: @escaping (Result<Data, Error>) -> Void) {
        URLSession.shared.dataTask(with: request) { data, response, error in
            let result: Result<Data, Error>
            if let error = error { result = .failure(error) }
            else if let response = response as? HTTPURLResponse, !(200...299).contains(response.statusCode) {
                result = .failure(Self.error("API 请求失败（HTTP \(response.statusCode)），请检查地址、Key 和模型。"))
            } else if let data = data { result = .success(data) }
            else { result = .failure(Self.error("无响应数据")) }
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }

    private func callAI(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        let config = currentConfig
        guard !config.apiKey.isEmpty else {
            completion(.failure(Self.error("请先配置API Key")))
            return
        }
        let isClaude = config.provider == .claude
        guard let url = Self.endpoint(config: config, path: isClaude ? "v1/messages" : "chat/completions") else {
            completion(.failure(Self.error("请输入有效的 HTTPS API 地址")))
            return
        }
        var request = URLRequest(url: url, timeoutInterval: 90)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if isClaude {
            request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        } else { request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization") }
        let defaultModel = getDefaultModels(for: config.provider).first?.id ?? ""
        var body: [String: Any] = ["model": config.model ?? defaultModel,
            "messages": [["role": "user", "content": prompt]]]
        if isClaude { body["max_tokens"] = 4096 }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        Self.send(request) { result in
            completion(result.flatMap { data in
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return .failure(Self.error("响应格式错误"))
                }
                let text: String?
                if isClaude {
                    text = (json["content"] as? [[String: Any]])?.compactMap { $0["text"] as? String }.joined(separator: "\n")
                } else {
                    text = ((json["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any])?["content"] as? String
                }
                guard let text = text, !text.isEmpty else { return .failure(Self.error("AI 返回了空内容")) }
                return .success(text)
            })
        }
    }

    // 生成工作流提示词
    private func generateWorkflowPrompt(goal: String) -> String {
        return """
        你是一位专业的学习方法专家。请为以下学习目标设计一个科学、可执行的学习工作流。

        学习目标：\(goal)

        要求：
        1. 工作流应该包含3-7个学习节点
        2. 工作流整体描述要说明学习方法的科学依据和预期效果
        3. 每个节点需要：
           - 明确的名称
           - 详细的描述（说明该节点的具体操作方法和目的）
           - 时间范围（最小和最大分钟数）
           - 标注是否可重复
        4. 节点应基于科学的学习理论（如费曼学习法、番茄工作法、艾宾浩斯遗忘曲线等）
        5. 包含自我检测学习质量的方法

        请以JSON格式返回，格式如下：
        {
          "name": "工作流名称",
          "description": "工作流整体描述，说明学习方法原理和预期效果",
          "nodes": [
            {
              "name": "节点名称",
              "description": "详细描述该节点的具体操作方法、为什么这样做、达到什么效果",
              "minDuration": 最小时长(分钟),
              "maxDuration": 最大时长(分钟),
              "isRepeatable": true/false
            }
          ]
        }
        """
    }

    // 生成时间计划提示词
    private func generateTimePlanPrompt(workflow: Workflow, availableMinutes: Int) -> String {
        let workflowDesc = """
        工作流名称：\(workflow.name)
        工作流描述：\(workflow.description)
        """

        let nodesDesc = workflow.nodes.map { node in
            """
            节点：\(node.name)
            描述：\(node.description)
            时长范围：\(node.minDuration)-\(node.maxDuration)分钟
            可重复：\(node.isRepeatable ? "是" : "否")
            """
        }.joined(separator: "\n\n")

        return """
        请为以下学习工作流生成2-3种时间安排方案。

        \(workflowDesc)

        工作流节点详情：
        \(nodesDesc)

        可用时间：\(availableMinutes)分钟

        要求：
        1. 根据工作流整体描述和各节点描述，理解学习方法的原理
        2. 根据节点描述的具体操作方法，合理分配每个节点的时间
        3. 总时间不超过可用时间
        4. 待办任务也作为一种阶段类型参与时间划分：如果时间不足以完成所有节点，将优先级较低的节点作为待办阶段（isTodo: true）安排在计时中
        5. 待办阶段用户可以选择跳过或稍后完成
        6. 可重复节点可以安排多次
        7. 生成2-3种不同的方案供用户选择

        请以JSON格式返回，格式如下：
        {
          "plans": [
            {
              "phases": [
                {
                  "nodeName": "节点名称",
                  "duration": 时长(分钟),
                  "order": 顺序(从0开始),
                  "isTodo": false
                },
                {
                  "nodeName": "待办节点名称",
                  "duration": 建议时长(分钟),
                  "order": 顺序,
                  "isTodo": true
                }
              ],
              "totalDuration": 总时长(分钟)
            }
          ]
        }

        注意：
        - isTodo为true的阶段表示这是一个待办任务，用户在计时时可以选择跳过
        - 根据节点描述的重要性和依赖关系，决定哪些节点应该作为待办任务
        - order从0开始递增，表示执行顺序
        """
    }

    // 解析工作流
    static func parseWorkflowFromResponse(_ response: String, goal: String) -> Workflow? {
        // 提取JSON部分
        guard let jsonString = extractJSON(from: response),
              let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let name = json["name"] as? String ?? goal
        let description = json["description"] as? String ?? ""
        let nodesArray = json["nodes"] as? [[String: Any]] ?? []

        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              (1...64).contains(nodesArray.count) else { return nil }
        let nodes = nodesArray.compactMap { nodeData -> WorkflowNode? in
            guard let name = nodeData["name"] as? String,
                  let minDuration = nodeData["minDuration"] as? Int,
                  let maxDuration = nodeData["maxDuration"] as? Int,
                  !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  (1...120).contains(minDuration), (minDuration...180).contains(maxDuration) else {
                return nil
            }

            return WorkflowNode(
                name: name,
                description: nodeData["description"] as? String ?? "",
                minDuration: minDuration,
                maxDuration: maxDuration,
                isRepeatable: nodeData["isRepeatable"] as? Bool ?? false
            )
        }

        guard nodes.count == nodesArray.count,
              Set(nodes.map(\.name)).count == nodes.count else { return nil }
        return Workflow(name: name, description: description, nodes: nodes)
    }

    // 解析时间计划
    static func parseTimePlansFromResponse(_ response: String, workflow: Workflow, availableMinutes: Int) -> [TimePlan] {
        // 提取JSON部分
        guard let jsonString = extractJSON(from: response),
              let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let plansArray = json["plans"] as? [[String: Any]] else {
            return []
        }

        return plansArray.compactMap { planData -> TimePlan? in
            let phasesArray = planData["phases"] as? [[String: Any]] ?? []

            guard (1...64).contains(phasesArray.count) else { return nil }
            let phases = phasesArray.compactMap { phaseData -> TimePhase? in
                guard let nodeName = phaseData["nodeName"] as? String,
                      let duration = phaseData["duration"] as? Int,
                      let order = phaseData["order"] as? Int,
                      (1...180).contains(duration), order >= 0,
                      let node = workflow.nodes.first(where: { $0.name == nodeName }),
                      duration >= node.minDuration, duration <= node.maxDuration else {
                    return nil
                }
                let isTodo = phaseData["isTodo"] as? Bool ?? false
                return TimePhase(nodeName: nodeName, duration: duration, order: order, isTodo: isTodo)
            }

            guard phases.count == phasesArray.count else { return nil }
            let totalDuration = phases.reduce(0) { $0 + $1.duration }
            guard totalDuration <= availableMinutes,
                  (planData["totalDuration"] as? Int ?? totalDuration) == totalDuration else { return nil }
            for node in workflow.nodes where !node.isRepeatable {
                guard phases.filter({ $0.nodeName == node.name }).count <= 1 else { return nil }
            }
            let plan = TimePlan(phases: phases.sorted { $0.order < $1.order }, totalDuration: totalDuration)
            return plan.isExecutable ? plan : nil
        }
    }

    // 提取JSON字符串
    private static func extractJSON(from text: String) -> String? {
        // 尝试提取```json```代码块
        if let range = text.range(of: "```json\\s*(.+?)```", options: .regularExpression) {
            let jsonText = text[range]
            return String(jsonText)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 尝试直接查找JSON对象
        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}"), start <= end {
            return String(text[start...end])
        }

        return nil
    }
}
