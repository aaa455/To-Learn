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
    @State private var workflow: Workflow
    @EnvironmentObject var dataManager: DataManager
    @State private var isEditing = false
    @State private var editingWorkflowName: String
    @State private var editingWorkflowDescription: String
    @State private var showingAddNode = false
    @State private var editingNode: WorkflowNode?

    init(workflow: Workflow) {
        _workflow = State(initialValue: workflow)
        _editingWorkflowName = State(initialValue: workflow.name)
        _editingWorkflowDescription = State(initialValue: workflow.description)
    }

    var body: some View {
        List {
            Section(header: Text("基本信息")) {
                if isEditing {
                    TextField("名称", text: $editingWorkflowName)
                    TextEditor(text: $editingWorkflowDescription)
                        .frame(height: 60)
                } else {
                    Text(workflow.name)
                        .font(.headline)
                    Text(workflow.description)
                        .foregroundColor(.secondary)
                }
            }

            Section(header: HStack {
                Text("节点")
                Spacer()
                if isEditing {
                    Button(action: { showingAddNode = true }) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }) {
                ForEach(workflow.nodes) { node in
                    Button(action: {
                        if isEditing {
                            editingNode = node
                        }
                    }) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(node.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
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
                            if !node.description.isEmpty {
                                Text(node.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text("时长: \(node.minDuration)-\(node.maxDuration) 分钟")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: isEditing ? deleteNodes : nil)
            }
        }
        .navigationTitle("工作流详情")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "完成" : "编辑") {
                    if isEditing {
                        saveChanges()
                    }
                    isEditing.toggle()
                }
            }
        }
        .sheet(isPresented: $showingAddNode) {
            EditNodeSheet(
                node: nil,
                workflowId: workflow.id,
                isPresented: $showingAddNode,
                onSave: { newNode in
                    workflow.nodes.append(newNode)
                }
            )
        }
        .sheet(item: $editingNode) { node in
            if let index = workflow.nodes.firstIndex(where: { $0.id == node.id }) {
                EditNodeSheet(
                    node: workflow.nodes[index],
                    workflowId: workflow.id,
                    isPresented: Binding(
                        get: { editingNode != nil },
                        set: { if !$0 { editingNode = nil } }
                    ),
                    onSave: { updatedNode in
                        workflow.nodes[index] = updatedNode
                    }
                )
            }
        }
    }

    private func saveChanges() {
        workflow.name = editingWorkflowName
        workflow.description = editingWorkflowDescription

        if let index = dataManager.workflows.firstIndex(where: { $0.id == workflow.id }) {
            dataManager.workflows[index] = workflow
            dataManager.saveData()
        }
    }

    private func deleteNodes(at offsets: IndexSet) {
        workflow.nodes.remove(atOffsets: offsets)
    }
}

struct EditNodeSheet: View {
    let node: WorkflowNode?
    let workflowId: UUID
    @Binding var isPresented: Bool
    let onSave: (WorkflowNode) -> Void

    @State private var name: String
    @State private var description: String
    @State private var minDuration: Int
    @State private var maxDuration: Int
    @State private var isRepeatable: Bool

    init(node: WorkflowNode?, workflowId: UUID, isPresented: Binding<Bool>, onSave: @escaping (WorkflowNode) -> Void) {
        self.node = node
        self.workflowId = workflowId
        self._isPresented = isPresented
        self.onSave = onSave

        _name = State(initialValue: node?.name ?? "")
        _description = State(initialValue: node?.description ?? "")
        _minDuration = State(initialValue: node?.minDuration ?? 10)
        _maxDuration = State(initialValue: node?.maxDuration ?? 30)
        _isRepeatable = State(initialValue: node?.isRepeatable ?? false)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("节点名称")) {
                    TextField("例如：预扫描", text: $name)
                }

                Section(header: Text("节点描述")) {
                    TextEditor(text: $description)
                        .frame(height: 100)
                }

                Section(header: Text("时长范围（分钟）")) {
                    Stepper("最小: \(minDuration) 分钟", value: $minDuration, in: 1...120, step: 5)
                    Stepper("最大: \(maxDuration) 分钟", value: $maxDuration, in: minDuration...180, step: 5)
                }

                Section {
                    Toggle("可重复执行", isOn: $isRepeatable)
                }
            }
            .navigationTitle(node == nil ? "添加节点" : "编辑节点")
            .navigationBarItems(
                leading: Button("取消") { isPresented = false },
                trailing: Button("保存") {
                    let updatedNode = WorkflowNode(
                        id: node?.id ?? UUID(),
                        name: name,
                        description: description,
                        minDuration: minDuration,
                        maxDuration: maxDuration,
                        isRepeatable: isRepeatable
                    )
                    onSave(updatedNode)
                    isPresented = false
                }
                .disabled(name.isEmpty)
            )
        }
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
