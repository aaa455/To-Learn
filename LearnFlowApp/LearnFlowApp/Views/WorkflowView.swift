import SwiftUI

struct WorkflowView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var aiService = AIService()
    @State private var showingCreateSheet = false
    @State private var showingAISheet = false
    @State private var newWorkflowName = ""
    @State private var newWorkflowDescription = ""
    @State private var aiGoal = ""
    @State private var isGenerating = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            List {
                ForEach(dataManager.workflows) { workflow in
                    NavigationLink(destination: WorkflowDetailView(workflow: workflow)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(workflow.name)
                                .font(.headline)
                            Text(workflow.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(workflow.nodes.count) 个节点")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: deleteWorkflows)
            }
            .navigationTitle("工作流")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingCreateSheet = true }) {
                            Label("手动创建", systemImage: "plus")
                        }
                        Button(action: { showingAISheet = true }) {
                            Label("AI生成", systemImage: "sparkles")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateWorkflowSheet(isPresented: $showingCreateSheet)
            }
            .sheet(isPresented: $showingAISheet) {
                AIGenerateWorkflowSheet(
                    isPresented: $showingAISheet,
                    aiService: aiService
                )
            }
        }
    }

    private func deleteWorkflows(at offsets: IndexSet) {
        dataManager.workflows.remove(atOffsets: offsets)
        dataManager.saveData()
    }
}

struct WorkflowDetailView: View {
    let workflow: Workflow
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        List {
            Section(header: Text("描述")) {
                Text(workflow.description)
            }

            Section(header: Text("节点")) {
                ForEach(workflow.nodes) { node in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(node.name)
                                .font(.headline)
                            Spacer()
                            if node.isRepeatable {
                                Text("可重复")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                        Text(node.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("时长: \(node.minDuration)-\(node.maxDuration) 分钟")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(workflow.name)
    }
}

struct CreateWorkflowSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var dataManager: DataManager
    @State private var name = ""
    @State private var description = ""
    @State private var nodes: [WorkflowNode] = []

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("名称", text: $name)
                    TextField("描述", text: $description)
                }

                Section(header: Text("节点")) {
                    ForEach(nodes) { node in
                        Text(node.name)
                    }
                    Button("添加节点") {
                        nodes.append(WorkflowNode(name: "新节点", minDuration: 10, maxDuration: 30))
                    }
                }
            }
            .navigationTitle("创建工作流")
            .navigationBarItems(
                leading: Button("取消") { isPresented = false },
                trailing: Button("保存") {
                    let workflow = Workflow(name: name, description: description, nodes: nodes)
                    dataManager.workflows.append(workflow)
                    dataManager.saveData()
                    isPresented = false
                }
                .disabled(name.isEmpty)
            )
        }
    }
}

struct AIGenerateWorkflowSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject var aiService: AIService
    @EnvironmentObject var dataManager: DataManager
    @State private var goal = ""
    @State private var isGenerating = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("AI配置")) {
                    Picker("提供商", selection: $aiService.currentConfig.provider) {
                        Text("Claude").tag(AIProvider.claude)
                        Text("OpenAI").tag(AIProvider.openai)
                        Text("DeepSeek").tag(AIProvider.deepseek)
                    }

                    SecureField("API Key", text: $aiService.currentConfig.apiKey)
                }

                Section(header: Text("学习目标")) {
                    TextEditor(text: $goal)
                        .frame(height: 100)
                }

                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }

                if isGenerating {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Text("生成中...")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("AI生成工作流")
            .navigationBarItems(
                leading: Button("取消") { isPresented = false },
                trailing: Button("生成") {
                    generateWorkflow()
                }
                .disabled(goal.isEmpty || aiService.currentConfig.apiKey.isEmpty || isGenerating)
            )
        }
    }

    private func generateWorkflow() {
        isGenerating = true
        errorMessage = ""
        aiService.saveConfig()

        aiService.generateWorkflow(goal: goal) { result in
            isGenerating = false
            switch result {
            case .success(let workflow):
                dataManager.workflows.append(workflow)
                dataManager.saveData()
                isPresented = false
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
}
