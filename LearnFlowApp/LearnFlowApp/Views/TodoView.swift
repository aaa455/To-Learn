import SwiftUI

struct TodoView: View {
    @StateObject private var todoManager = TodoManager()
    @State private var selectedTab = 0
    @State private var showingAddTask = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部标签栏
                Picker("视图", selection: $selectedTab) {
                    Text("接下来").tag(0)
                    Text("全部").tag(1)
                    Text("文件夹").tag(2)
                    Text("关系图").tag(3)
                }
                .pickerStyle(.segmented)
                .padding()

                // 内容区域
                if selectedTab == 0 {
                    NextTasksView(todoManager: todoManager)
                } else if selectedTab == 1 {
                    AllTasksView(todoManager: todoManager)
                } else if selectedTab == 2 {
                    FoldersView(todoManager: todoManager)
                } else {
                    TaskGraphView(todoManager: todoManager, folderId: nil)
                }
            }
            .navigationTitle("待办")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddTask = true }) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskSheet(todoManager: todoManager, isPresented: $showingAddTask)
            }
        }
    }
}

// "接下来"视图 - 显示可以开始的任务
struct NextTasksView: View {
    @ObservedObject var todoManager: TodoManager

    var readyTasks: [TodoTask] {
        todoManager.getReadyTasks()
    }

    var body: some View {
        if readyTasks.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 64))
                    .foregroundColor(.green.opacity(0.5))

                Text("太棒了！")
                    .font(.title2)
                    .fontWeight(.medium)

                Text("当前没有可以开始的任务")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(readyTasks) { task in
                    NavigationLink(destination: TaskDetailView(task: task, todoManager: todoManager)) {
                        TaskRowView(task: task, todoManager: todoManager)
                    }
                }
            }
        }
    }
}

// 全部任务视图
struct AllTasksView: View {
    @ObservedObject var todoManager: TodoManager
    @State private var showCompleted = false

    var displayTasks: [TodoTask] {
        if showCompleted {
            return todoManager.tasks
        } else {
            return todoManager.tasks.filter { !$0.isDone }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Toggle("显示已完成", isOn: $showCompleted)
                .padding()

            List {
                ForEach(displayTasks) { task in
                    NavigationLink(destination: TaskDetailView(task: task, todoManager: todoManager)) {
                        TaskRowView(task: task, todoManager: todoManager)
                    }
                }
                .onDelete(perform: deleteTasks)
            }
        }
    }

    private func deleteTasks(at offsets: IndexSet) {
        for index in offsets {
            todoManager.deleteTask(displayTasks[index].id)
        }
    }
}

// 文件夹视图
struct FoldersView: View {
    @ObservedObject var todoManager: TodoManager
    @State private var showingAddFolder = false

    var rootFolders: [TodoFolder] {
        todoManager.folders.filter { $0.parentId == nil }
    }

    var body: some View {
        List {
            ForEach(rootFolders) { folder in
                NavigationLink(destination: FolderDetailView(folder: folder, todoManager: todoManager)) {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.blue)
                        Text(folder.name)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddFolder = true }) {
                    Image(systemName: "folder.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showingAddFolder) {
            AddFolderSheet(todoManager: todoManager, isPresented: $showingAddFolder)
        }
    }
}

// 任务行视图
struct TaskRowView: View {
    let task: TodoTask
    @ObservedObject var todoManager: TodoManager

    var taskStatus: TaskStatus {
        todoManager.getTaskStatus(task.id)
    }

    var unlockCount: Int {
        todoManager.getUnlockCount(task.id)
    }

    var body: some View {
        HStack(spacing: 12) {
            // 完成按钮
            Button(action: {
                todoManager.toggleTaskDone(task.id)
            }) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(task.isDone ? .green : .gray)
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 4) {
                // 标题
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.isDone)
                    .foregroundColor(task.isDone ? .secondary : .primary)

                // 状态和信息
                HStack(spacing: 8) {
                    // 状态标记
                    if taskStatus == .waiting {
                        Text("等待中")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }

                    // 截止时间
                    if let dueDate = task.dueDate {
                        HStack(spacing: 2) {
                            Image(systemName: task.isOverdue ? "exclamationmark.triangle.fill" : "calendar")
                                .font(.caption2)
                            Text(formatDate(dueDate))
                                .font(.caption)
                        }
                        .foregroundColor(task.isOverdue ? .red : .secondary)
                    }

                    // 解锁数量
                    if !task.isDone && unlockCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "lock.open")
                                .font(.caption2)
                            Text("\(unlockCount)")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

// 添加任务弹窗
struct AddTaskSheet: View {
    @ObservedObject var todoManager: TodoManager
    @Binding var isPresented: Bool
    @State private var title = ""
    @State private var description = ""
    @State private var selectedFolderId: UUID?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("任务标题")) {
                    TextField("例如：完成报告", text: $title)
                }

                Section(header: Text("描述（可选）")) {
                    TextEditor(text: $description)
                        .frame(minHeight: 80)
                }

                Section(header: Text("文件夹（可选）")) {
                    Picker("文件夹", selection: $selectedFolderId) {
                        Text("无").tag(nil as UUID?)
                        ForEach(todoManager.folders) { folder in
                            Text(folder.name).tag(folder.id as UUID?)
                        }
                    }
                }
            }
            .navigationTitle("添加任务")
            .navigationBarItems(
                leading: Button("取消") { isPresented = false },
                trailing: Button("保存") {
                    todoManager.addTask(title: title, folderId: selectedFolderId, description: description)
                    isPresented = false
                }
                .disabled(title.isEmpty)
            )
        }
    }
}

// 添加文件夹弹窗
struct AddFolderSheet: View {
    @ObservedObject var todoManager: TodoManager
    @Binding var isPresented: Bool
    @State private var name = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("文件夹名称")) {
                    TextField("例如：工作", text: $name)
                }
            }
            .navigationTitle("添加文件夹")
            .navigationBarItems(
                leading: Button("取消") { isPresented = false },
                trailing: Button("保存") {
                    todoManager.addFolder(name: name)
                    isPresented = false
                }
                .disabled(name.isEmpty)
            )
        }
    }
}
