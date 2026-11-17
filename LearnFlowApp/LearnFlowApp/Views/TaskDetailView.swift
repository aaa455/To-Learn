import SwiftUI

struct TaskDetailView: View {
    let task: TodoTask
    @ObservedObject var todoManager: TodoManager
    @State private var isEditing = false
    @State private var showingAddDependency = false
    @Environment(\.dismiss) private var dismiss

    var taskStatus: TaskStatus {
        todoManager.getTaskStatus(task.id)
    }

    var prerequisites: [TodoTask] {
        todoManager.getPrerequisites(task.id)
    }

    var followUps: [TodoTask] {
        todoManager.getFollowUps(task.id)
    }

    var body: some View {
        List {
            // 任务标题和状态
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(task.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    HStack {
                        StatusBadge(status: taskStatus)

                        if task.isDone, let doneAt = task.doneAt {
                            Text("完成于 \(formatDateTime(doneAt))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            // 描述
            if !task.description.isEmpty {
                Section(header: Text("描述")) {
                    Text(task.description)
                        .font(.body)
                }
            }

            // 时间信息
            Section(header: Text("时间")) {
                if let startDate = task.startDate {
                    HStack {
                        Label("开始", systemImage: "play.circle")
                        Spacer()
                        Text(formatDate(startDate))
                            .foregroundColor(.secondary)
                    }
                }

                if let dueDate = task.dueDate {
                    HStack {
                        Label("截止", systemImage: "calendar")
                        Spacer()
                        Text(formatDate(dueDate))
                            .foregroundColor(task.isOverdue ? .red : .secondary)
                    }
                }

                if task.startDate == nil && task.dueDate == nil {
                    Text("未设置时间")
                        .foregroundColor(.secondary)
                }
            }

            // 前置任务
            Section(header: HStack {
                Text("前置任务")
                Spacer()
                Button(action: { showingAddDependency = true }) {
                    Image(systemName: "plus.circle")
                }
            }) {
                if prerequisites.isEmpty {
                    Text("无前置任务")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(prerequisites) { preTask in
                        DependencyRowView(task: preTask, todoManager: todoManager, onRemove: {
                            todoManager.removeDependency(before: preTask.id, after: task.id)
                        })
                    }
                }
            }

            // 后续任务
            Section(header: Text("后续任务（解锁）")) {
                if followUps.isEmpty {
                    Text("无后续任务")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(followUps) { followTask in
                        DependencyRowView(task: followTask, todoManager: todoManager, onRemove: {
                            todoManager.removeDependency(before: task.id, after: followTask.id)
                        })
                    }
                }
            }

            // 操作按钮
            Section {
                Button(action: {
                    todoManager.toggleTaskDone(task.id)
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: task.isDone ? "arrow.uturn.backward.circle" : "checkmark.circle.fill")
                        Text(task.isDone ? "标记为未完成" : "标记为完成")
                    }
                    .foregroundColor(task.isDone ? .orange : .green)
                }

                Button(role: .destructive, action: {
                    todoManager.deleteTask(task.id)
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("删除任务")
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("编辑") {
                    isEditing = true
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            EditTaskSheet(task: task, todoManager: todoManager, isPresented: $isEditing)
        }
        .sheet(isPresented: $showingAddDependency) {
            AddDependencySheet(
                task: task,
                todoManager: todoManager,
                isPresented: $showingAddDependency
            )
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct StatusBadge: View {
    let status: TaskStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .font(.caption)
            Text(statusText)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.2))
        .foregroundColor(statusColor)
        .cornerRadius(6)
    }

    var statusIcon: String {
        switch status {
        case .waiting: return "clock"
        case .ready: return "play.circle"
        case .done: return "checkmark.circle"
        }
    }

    var statusText: String {
        switch status {
        case .waiting: return "等待中"
        case .ready: return "可开始"
        case .done: return "已完成"
        }
    }

    var statusColor: Color {
        switch status {
        case .waiting: return .orange
        case .ready: return .green
        case .done: return .blue
        }
    }
}

struct DependencyRowView: View {
    let task: TodoTask
    @ObservedObject var todoManager: TodoManager
    let onRemove: () -> Void

    var body: some View {
        HStack {
            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                .foregroundColor(task.isDone ? .green : .gray)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .strikethrough(task.isDone)

                if let dueDate = task.dueDate {
                    Text(formatDate(dueDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

// 编辑任务弹窗
struct EditTaskSheet: View {
    var task: TodoTask
    @ObservedObject var todoManager: TodoManager
    @Binding var isPresented: Bool

    @State private var title: String
    @State private var description: String
    @State private var hasStartDate: Bool
    @State private var startDate: Date
    @State private var hasDueDate: Bool
    @State private var dueDate: Date

    init(task: TodoTask, todoManager: TodoManager, isPresented: Binding<Bool>) {
        self.task = task
        self.todoManager = todoManager
        self._isPresented = isPresented

        _title = State(initialValue: task.title)
        _description = State(initialValue: task.description)
        _hasStartDate = State(initialValue: task.startDate != nil)
        _startDate = State(initialValue: task.startDate ?? Date())
        _hasDueDate = State(initialValue: task.dueDate != nil)
        _dueDate = State(initialValue: task.dueDate ?? Date())
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("标题")) {
                    TextField("任务标题", text: $title)
                }

                Section(header: Text("描述")) {
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                }

                Section(header: Text("开始时间")) {
                    Toggle("设置开始时间", isOn: $hasStartDate)
                    if hasStartDate {
                        DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                    }
                }

                Section(header: Text("截止时间")) {
                    Toggle("设置截止时间", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("截止日期", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle("编辑任务")
            .navigationBarItems(
                leading: Button("取消") { isPresented = false },
                trailing: Button("保存") {
                    var updatedTask = task
                    updatedTask.title = title
                    updatedTask.description = description
                    updatedTask.startDate = hasStartDate ? startDate : nil
                    updatedTask.dueDate = hasDueDate ? dueDate : nil
                    todoManager.updateTask(updatedTask)
                    isPresented = false
                }
                .disabled(title.isEmpty)
            )
        }
    }
}

// 添加依赖关系弹窗
struct AddDependencySheet: View {
    let task: TodoTask
    @ObservedObject var todoManager: TodoManager
    @Binding var isPresented: Bool
    @State private var selectedTaskId: UUID?
    @State private var showError = false
    @State private var errorMessage = ""

    var availableTasks: [TodoTask] {
        // 排除自己和已经是前置的任务
        let existingPreIds = todoManager.getPrerequisites(task.id).map { $0.id }
        return todoManager.tasks.filter { $0.id != task.id && !existingPreIds.contains($0.id) }
    }

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("选择前置任务")) {
                    ForEach(availableTasks) { availableTask in
                        Button(action: {
                            selectedTaskId = availableTask.id
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(availableTask.title)
                                        .foregroundColor(.primary)

                                    if let dueDate = availableTask.dueDate {
                                        Text(formatDate(dueDate))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                if selectedTaskId == availableTask.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("添加前置任务")
            .navigationBarItems(
                leading: Button("取消") { isPresented = false },
                trailing: Button("添加") {
                    guard let selectedId = selectedTaskId else { return }

                    let success = todoManager.addDependency(before: selectedId, after: task.id)
                    if success {
                        isPresented = false
                    } else {
                        errorMessage = "添加失败：会形成循环依赖"
                        showError = true
                    }
                }
                .disabled(selectedTaskId == nil)
            )
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
