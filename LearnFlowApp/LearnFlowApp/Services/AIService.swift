import Foundation

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

    static var claude: AIConfig {
        AIConfig(provider: .claude, apiKey: "", baseURL: "https://api.anthropic.com")
    }

    static var openai: AIConfig {
        AIConfig(provider: .openai, apiKey: "", baseURL: "https://api.openai.com/v1")
    }

    static var deepseek: AIConfig {
        AIConfig(provider: .deepseek, apiKey: "", baseURL: "https://api.deepseek.com")
    }
}

// AI服务
class AIService: ObservableObject {
    @Published var currentConfig: AIConfig

    init() {
        // 从UserDefaults加载配置
        if let data = UserDefaults.standard.data(forKey: "aiConfig"),
           let config = try? JSONDecoder().decode(AIConfig.self, from: data) {
            self.currentConfig = config
        } else {
            self.currentConfig = .claude
        }
    }

    func saveConfig() {
        if let encoded = try? JSONEncoder().encode(currentConfig) {
            UserDefaults.standard.set(encoded, forKey: "aiConfig")
        }
    }

    // 生成工作流
    func generateWorkflow(goal: String, completion: @escaping (Result<Workflow, Error>) -> Void) {
        let prompt = generateWorkflowPrompt(goal: goal)
        callAI(prompt: prompt) { result in
            switch result {
            case .success(let response):
                // 解析AI响应，构建工作流
                if let workflow = self.parseWorkflowFromResponse(response, goal: goal) {
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
                let plans = self.parseTimePlansFromResponse(response, workflow: workflow, availableMinutes: availableMinutes)
                completion(.success(plans))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // AI调用核心方法
    private func callAI(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard !currentConfig.apiKey.isEmpty else {
            completion(.failure(NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "请先配置API Key"])))
            return
        }

        switch currentConfig.provider {
        case .claude:
            callClaude(prompt: prompt, completion: completion)
        case .openai:
            callOpenAI(prompt: prompt, completion: completion)
        case .deepseek:
            callDeepSeek(prompt: prompt, completion: completion)
        }
    }

    // Claude API调用
    private func callClaude(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(currentConfig.baseURL ?? "https://api.anthropic.com")/v1/messages") else {
            completion(.failure(NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的API地址"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(currentConfig.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": "claude-3-5-sonnet-20241022",
            "max_tokens": 4096,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无响应数据"])))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let content = json["content"] as? [[String: Any]],
                   let text = content.first?["text"] as? String {
                    DispatchQueue.main.async {
                        completion(.success(text))
                    }
                } else {
                    completion(.failure(NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "响应格式错误"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // OpenAI API调用
    private func callOpenAI(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(currentConfig.baseURL ?? "https://api.openai.com/v1")/chat/completions") else {
            completion(.failure(NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的API地址"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(currentConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4",
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无响应数据"])))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    DispatchQueue.main.async {
                        completion(.success(content))
                    }
                } else {
                    completion(.failure(NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "响应格式错误"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // DeepSeek API调用
    private func callDeepSeek(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        // DeepSeek使用OpenAI兼容格式
        guard let url = URL(string: "\(currentConfig.baseURL ?? "https://api.deepseek.com")/chat/completions") else {
            completion(.failure(NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的API地址"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(currentConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无响应数据"])))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    DispatchQueue.main.async {
                        completion(.success(content))
                    }
                } else {
                    completion(.failure(NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "响应格式错误"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
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
    private func parseWorkflowFromResponse(_ response: String, goal: String) -> Workflow? {
        // 提取JSON部分
        guard let jsonString = extractJSON(from: response),
              let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let name = json["name"] as? String ?? goal
        let description = json["description"] as? String ?? ""
        let nodesArray = json["nodes"] as? [[String: Any]] ?? []

        let nodes = nodesArray.compactMap { nodeData -> WorkflowNode? in
            guard let name = nodeData["name"] as? String,
                  let minDuration = nodeData["minDuration"] as? Int,
                  let maxDuration = nodeData["maxDuration"] as? Int else {
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

        return Workflow(name: name, description: description, nodes: nodes)
    }

    // 解析时间计划
    private func parseTimePlansFromResponse(_ response: String, workflow: Workflow, availableMinutes: Int) -> [TimePlan] {
        // 提取JSON部分
        guard let jsonString = extractJSON(from: response),
              let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let plansArray = json["plans"] as? [[String: Any]] else {
            return []
        }

        return plansArray.compactMap { planData -> TimePlan? in
            let phasesArray = planData["phases"] as? [[String: Any]] ?? []

            let phases = phasesArray.compactMap { phaseData -> TimePhase? in
                guard let nodeName = phaseData["nodeName"] as? String,
                      let duration = phaseData["duration"] as? Int,
                      let order = phaseData["order"] as? Int else {
                    return nil
                }
                let isTodo = phaseData["isTodo"] as? Bool ?? false
                return TimePhase(nodeName: nodeName, duration: duration, order: order, isTodo: isTodo)
            }

            let totalDuration = planData["totalDuration"] as? Int ?? phases.reduce(0) { $0 + $1.duration }

            return TimePlan(phases: phases, totalDuration: totalDuration)
        }
    }

    // 提取JSON字符串
    private func extractJSON(from text: String) -> String? {
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
           let end = text.lastIndex(of: "}") {
            return String(text[start...end])
        }

        return nil
    }
}
