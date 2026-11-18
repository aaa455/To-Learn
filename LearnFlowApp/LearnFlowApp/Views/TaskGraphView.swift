import SwiftUI

struct TaskGraphView: View {
    @ObservedObject var todoManager: TodoManager
    let folderId: UUID?
    var showAllTasks: Bool = false

    var tasksInFolder: [TodoTask] {
        if showAllTasks {
            return todoManager.tasks
        } else if let folderId = folderId {
            return todoManager.tasks.filter { $0.folderId == folderId }
        } else {
            return todoManager.tasks.filter { $0.folderId == nil }
        }
    }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 40) {
                ForEach(tasksInFolder) { task in
                    TaskNodeView(task: task, todoManager: todoManager)
                }
            }
            .padding(40)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("关系图")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TaskNodeView: View {
    let task: TodoTask
    @ObservedObject var todoManager: TodoManager

    var prerequisites: [TodoTask] {
        todoManager.getPrerequisites(task.id)
    }

    var body: some View {
        VStack(spacing: 8) {
            // 前置任务
            if !prerequisites.isEmpty {
                HStack(spacing: 12) {
                    ForEach(prerequisites) { preTask in
                        MiniTaskCard(task: preTask)
                    }
                }

                Image(systemName: "arrow.down")
                    .foregroundColor(.gray)
            }

            // 当前任务
            NavigationLink(destination: TaskDetailView(task: task, todoManager: todoManager)) {
                TaskCard(task: task, todoManager: todoManager)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct TaskCard: View {
    let task: TodoTask
    @ObservedObject var todoManager: TodoManager

    var taskStatus: TaskStatus {
        todoManager.getTaskStatus(task.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isDone ? .green : statusColor)

                Text(task.title)
                    .font(.headline)
                    .strikethrough(task.isDone)

                Spacer()
            }

            if let dueDate = task.dueDate {
                Text(formatDate(dueDate))
                    .font(.caption)
                    .foregroundColor(task.isOverdue ? .red : .secondary)
            }

            HStack {
                StatusBadge(status: taskStatus)

                let unlockCount = todoManager.getUnlockCount(task.id)
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
        .padding()
        .frame(width: 200)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    var statusColor: Color {
        switch taskStatus {
        case .waiting: return .orange
        case .ready: return .green
        case .done: return .blue
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

struct MiniTaskCard: View {
    let task: TodoTask

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isDone ? .green : .gray)
                    .font(.caption)

                Text(task.title)
                    .font(.caption)
                    .strikethrough(task.isDone)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .frame(width: 120)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}
