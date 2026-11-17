import SwiftUI

struct GoalView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingCreateSheet = false

    var body: some View {
        NavigationView {
            List {
                ForEach(dataManager.goals.filter { $0.isActive }) { goal in
                    NavigationLink(destination: GoalDetailView(goal: goal)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(goal.name)
                                .font(.headline)
                            if let workflow = dataManager.workflows.first(where: { $0.id == goal.workflowId }) {
                                Text(workflow.name)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: deleteGoals)
            }
            .navigationTitle("我的目标")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateGoalSheet(isPresented: $showingCreateSheet)
            }
        }
    }

    private func deleteGoals(at offsets: IndexSet) {
        for index in offsets {
            dataManager.goals[index].isActive = false
        }
        dataManager.saveData()
    }
}

struct GoalDetailView: View {
    let goal: Goal
    @EnvironmentObject var dataManager: DataManager
    @State private var showingFocusView = false

    var workflow: Workflow? {
        dataManager.workflows.first(where: { $0.id == goal.workflowId })
    }

    var body: some View {
        List {
            Section(header: Text("工作流")) {
                if let workflow = workflow {
                    Text(workflow.name)
                    Text(workflow.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("未设置工作流")
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Button(action: { showingFocusView = true }) {
                    HStack {
                        Image(systemName: "timer")
                        Text("开始专注")
                        Spacer()
                    }
                }
                .disabled(workflow == nil)
            }
        }
        .navigationTitle(goal.name)
        .sheet(isPresented: $showingFocusView) {
            if let workflow = workflow {
                TimePlanSheet(goal: goal, workflow: workflow, isPresented: $showingFocusView)
            }
        }
    }
}

struct CreateGoalSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var dataManager: DataManager
    @State private var name = ""
    @State private var selectedWorkflowId: UUID?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("目标名称")) {
                    TextField("例如：学习Swift编程", text: $name)
                }

                Section(header: Text("选择工作流")) {
                    if dataManager.workflows.isEmpty {
                        Text("暂无工作流，请先创建")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("工作流", selection: $selectedWorkflowId) {
                            Text("请选择").tag(nil as UUID?)
                            ForEach(dataManager.workflows) { workflow in
                                Text(workflow.name).tag(workflow.id as UUID?)
                            }
                        }
                    }
                }
            }
            .navigationTitle("创建目标")
            .navigationBarItems(
                leading: Button("取消") { isPresented = false },
                trailing: Button("保存") {
                    if let workflowId = selectedWorkflowId {
                        let goal = Goal(name: name, workflowId: workflowId)
                        dataManager.goals.append(goal)
                        dataManager.saveData()
                        isPresented = false
                    }
                }
                .disabled(name.isEmpty || selectedWorkflowId == nil)
            )
        }
    }
}

struct TimePlanSheet: View {
    let goal: Goal
    let workflow: Workflow
    @Binding var isPresented: Bool
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var aiService = AIService()
    @State private var availableMinutes = 60
    @State private var timePlans: [TimePlan] = []
    @State private var isGenerating = false
    @State private var errorMessage = ""
    @State private var selectedPlanId: UUID?
    @State private var enableAppBlocking = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("可用时间")) {
                    Stepper("\(availableMinutes) 分钟", value: $availableMinutes, in: 10...300, step: 5)
                }

                Section(header: Text("专注设置")) {
                    Toggle("启用应用锁定", isOn: $enableAppBlocking)
                    if enableAppBlocking {
                        Text("专注期间将限制使用其他应用")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if isGenerating {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Text("生成方案中...")
                            Spacer()
                        }
                    }
                }

                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }

                if !timePlans.isEmpty {
                    Section(header: Text("选择方案")) {
                        ForEach(timePlans) { plan in
                            Button(action: { selectedPlanId = plan.id }) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("方案 \(timePlans.firstIndex(where: { $0.id == plan.id })! + 1)")
                                            .font(.headline)
                                        Spacer()
                                        if selectedPlanId == plan.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                        }
                                    }

                                    ForEach(plan.phases) { phase in
                                        HStack {
                                            Text("\(phase.order + 1).")
                                            Text(phase.nodeName)
                                            Spacer()
                                            Text("\(phase.duration)分")
                                                .foregroundColor(.secondary)
                                        }
                                        .font(.caption)
                                    }

                                    if !plan.todoPhases.isEmpty {
                                        Text("今日待办:")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                        ForEach(plan.todoPhases) { todo in
                                            HStack {
                                                Text("• \(todo.nodeName)")
                                                Spacer()
                                                Text("\(todo.duration)分")
                                            }
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
            }
            .navigationTitle("时间规划")
            .navigationBarItems(
                leading: Button("取消") { isPresented = false },
                trailing: Button(timePlans.isEmpty ? "生成方案" : "开始专注") {
                    if timePlans.isEmpty {
                        generatePlans()
                    } else if let planId = selectedPlanId,
                              let plan = timePlans.first(where: { $0.id == planId }) {
                        startFocus(with: plan)
                    }
                }
                .disabled(isGenerating || (!timePlans.isEmpty && selectedPlanId == nil))
            )
        }
    }

    private func generatePlans() {
        isGenerating = true
        errorMessage = ""

        aiService.generateTimePlan(workflow: workflow, availableMinutes: availableMinutes) { result in
            isGenerating = false
            switch result {
            case .success(let plans):
                timePlans = plans
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }

    private func startFocus(with plan: TimePlan) {
        var session = FocusSession(goalId: goal.id, timePlan: plan)
        session.isAppBlockingEnabled = enableAppBlocking

        // 如果启用应用锁定，请求授权
        if enableAppBlocking {
            if #available(iOS 16.0, *) {
                Task {
                    do {
                        try await ScreenTimeManager.shared.requestAuthorization()
                        DispatchQueue.main.async {
                            self.completeSessionStart(session)
                        }
                    } catch {
                        errorMessage = "无法获取屏幕使用时间授权: \(error.localizedDescription)"
                    }
                }
            } else {
                completeSessionStart(session)
            }
        } else {
            completeSessionStart(session)
        }
    }

    private func completeSessionStart(_ session: FocusSession) {
        dataManager.focusSessions.append(session)
        dataManager.saveData()
        isPresented = false

        // 导航到专注视图
        NotificationCenter.default.post(name: NSNotification.Name("StartFocusSession"), object: session)
    }
}
