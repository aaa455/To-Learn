import Foundation

// 任务ID类型
typealias TaskID = UUID
typealias FolderID = UUID

// 任务模型
struct TodoTask: Identifiable, Codable {
    let id: TaskID
    var number: Int // 用户内唯一的短编号
    var folderId: FolderID?
    var title: String
    var description: String
    var doneAt: Date?
    var startDate: Date?
    var startTime: String? // HH:MM
    var dueDate: Date?
    var dueTime: String? // HH:MM
    var remindBefore: Int? // 提前多少分钟提醒
    var sortKey: String
    var createdAt: Date
    var updatedAt: Date

    init(id: TaskID = UUID(), number: Int, folderId: FolderID? = nil, title: String, description: String = "", doneAt: Date? = nil, startDate: Date? = nil, startTime: String? = nil, dueDate: Date? = nil, dueTime: String? = nil, remindBefore: Int? = nil, sortKey: String = "", createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.number = number
        self.folderId = folderId
        self.title = title
        self.description = description
        self.doneAt = doneAt
        self.startDate = startDate
        self.startTime = startTime
        self.dueDate = dueDate
        self.dueTime = dueTime
        self.remindBefore = remindBefore
        self.sortKey = sortKey
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isDone: Bool {
        doneAt != nil
    }

    var isOverdue: Bool {
        guard let dueDate = dueDate, !isDone else { return false }
        return dueDate < Date()
    }
}

// 文件夹模型
struct TodoFolder: Identifiable, Codable {
    let id: FolderID
    var parentId: FolderID?
    var name: String
    var sortKey: String
    var createdAt: Date
    var updatedAt: Date

    init(id: FolderID = UUID(), parentId: FolderID? = nil, name: String, sortKey: String = "", createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.parentId = parentId
        self.name = name
        self.sortKey = sortKey
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// 依赖关系模型
struct TaskDependency: Identifiable, Codable {
    var id: UUID { UUID() } // 临时ID用于列表
    let beforeId: TaskID // 前置任务
    let afterId: TaskID // 后续任务
    var createdAt: Date

    init(beforeId: TaskID, afterId: TaskID, createdAt: Date = Date()) {
        self.beforeId = beforeId
        self.afterId = afterId
        self.createdAt = createdAt
    }
}

// 任务状态枚举
enum TaskStatus {
    case waiting // 等待前置完成
    case ready // 可以开始（前置都已完成）
    case done // 已完成
}

// 任务管理器
class TodoManager: ObservableObject {
    @Published var tasks: [TodoTask] = []
    @Published var folders: [TodoFolder] = []
    @Published var dependencies: [TaskDependency] = []

    private var nextTaskNumber = 1

    init() {
        loadData()
    }

    // MARK: - 数据持久化

    func loadData() {
        if let tasksData = UserDefaults.standard.data(forKey: "todoTasks"),
           let decoded = try? JSONDecoder().decode([TodoTask].self, from: tasksData) {
            tasks = decoded
        }

        if let foldersData = UserDefaults.standard.data(forKey: "todoFolders"),
           let decoded = try? JSONDecoder().decode([TodoFolder].self, from: foldersData) {
            folders = decoded
        }

        if let depsData = UserDefaults.standard.data(forKey: "todoDependencies"),
           let decoded = try? JSONDecoder().decode([TaskDependency].self, from: depsData) {
            dependencies = decoded
        }

        if let number = UserDefaults.standard.object(forKey: "nextTaskNumber") as? Int {
            nextTaskNumber = number
        }
    }

    func saveData() {
        if let encoded = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encoded, forKey: "todoTasks")
        }

        if let encoded = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(encoded, forKey: "todoFolders")
        }

        if let encoded = try? JSONEncoder().encode(dependencies) {
            UserDefaults.standard.set(encoded, forKey: "todoDependencies")
        }

        UserDefaults.standard.set(nextTaskNumber, forKey: "nextTaskNumber")
    }

    // MARK: - 任务操作

    func addTask(title: String, folderId: FolderID? = nil, description: String = "") {
        let task = TodoTask(
            number: nextTaskNumber,
            folderId: folderId,
            title: title,
            description: description
        )
        tasks.append(task)
        nextTaskNumber += 1
        saveData()
    }

    func updateTask(_ task: TodoTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            var updated = task
            updated.updatedAt = Date()
            tasks[index] = updated
            saveData()
        }
    }

    func deleteTask(_ taskId: TaskID) {
        // 删除任务本身
        tasks.removeAll(where: { $0.id == taskId })
        // 删除相关依赖
        dependencies.removeAll(where: { $0.beforeId == taskId || $0.afterId == taskId })
        saveData()
    }

    func toggleTaskDone(_ taskId: TaskID) {
        if let index = tasks.firstIndex(where: { $0.id == taskId }) {
            if tasks[index].doneAt == nil {
                tasks[index].doneAt = Date()
            } else {
                tasks[index].doneAt = nil
            }
            tasks[index].updatedAt = Date()
            saveData()
        }
    }

    // MARK: - 依赖关系操作

    func addDependency(before: TaskID, after: TaskID) -> Bool {
        // 检查是否会形成环
        if wouldCreateCycle(before: before, after: after) {
            return false
        }

        // 检查是否已存在
        if dependencies.contains(where: { $0.beforeId == before && $0.afterId == after }) {
            return false
        }

        let dependency = TaskDependency(beforeId: before, afterId: after)
        dependencies.append(dependency)
        saveData()
        return true
    }

    func removeDependency(before: TaskID, after: TaskID) {
        dependencies.removeAll(where: { $0.beforeId == before && $0.afterId == after })
        saveData()
    }

    // 检测是否会形成环
    private func wouldCreateCycle(before: TaskID, after: TaskID) -> Bool {
        // 使用DFS检测环
        var visited = Set<TaskID>()
        var stack = Set<TaskID>()

        func hasCycle(current: TaskID) -> Bool {
            if stack.contains(current) {
                return true
            }

            if visited.contains(current) {
                return false
            }

            visited.insert(current)
            stack.insert(current)

            // 找到当前任务的所有后续任务
            let nexts = dependencies.filter { $0.beforeId == current }.map { $0.afterId }
            for next in nexts {
                if hasCycle(current: next) {
                    return true
                }
            }

            stack.remove(current)
            return false
        }

        // 临时添加这条边
        let tempDep = TaskDependency(beforeId: before, afterId: after)
        dependencies.append(tempDep)

        let result = hasCycle(current: after)

        // 移除临时边
        dependencies.removeLast()

        return result
    }

    // MARK: - 任务状态查询

    func getTaskStatus(_ taskId: TaskID) -> TaskStatus {
        guard let task = tasks.first(where: { $0.id == taskId }) else {
            return .waiting
        }

        if task.isDone {
            return .done
        }

        // 检查所有前置任务是否完成
        let prerequisites = dependencies.filter { $0.afterId == taskId }.map { $0.beforeId }

        for preId in prerequisites {
            if let preTask = tasks.first(where: { $0.id == preId }), !preTask.isDone {
                return .waiting
            }
        }

        return .ready
    }

    // 获取"接下来"可以开始的任务
    func getReadyTasks() -> [TodoTask] {
        return tasks.filter { !$0.isDone && getTaskStatus($0.id) == .ready }
            .sorted { task1, task2 in
                // 按截止时间排序
                if let due1 = task1.dueDate, let due2 = task2.dueDate {
                    return due1 < due2
                }
                if task1.dueDate != nil {
                    return true
                }
                if task2.dueDate != nil {
                    return false
                }
                return task1.createdAt < task2.createdAt
            }
    }

    // 获取任务的前置任务
    func getPrerequisites(_ taskId: TaskID) -> [TodoTask] {
        let preIds = dependencies.filter { $0.afterId == taskId }.map { $0.beforeId }
        return tasks.filter { preIds.contains($0.id) }
    }

    // 获取任务的后续任务
    func getFollowUps(_ taskId: TaskID) -> [TodoTask] {
        let followIds = dependencies.filter { $0.beforeId == taskId }.map { $0.afterId }
        return tasks.filter { followIds.contains($0.id) }
    }

    // 获取完成该任务后会解锁的任务数量
    func getUnlockCount(_ taskId: TaskID) -> Int {
        let followUps = getFollowUps(taskId)
        return followUps.filter { followUp in
            // 检查这个后续任务除了当前任务外，其他前置是否都完成了
            let otherPres = getPrerequisites(followUp.id).filter { $0.id != taskId }
            return otherPres.allSatisfy { $0.isDone }
        }.count
    }

    // MARK: - 文件夹操作

    func addFolder(name: String, parentId: FolderID? = nil) {
        let folder = TodoFolder(parentId: parentId, name: name)
        folders.append(folder)
        saveData()
    }

    func deleteFolder(_ folderId: FolderID) {
        // 删除文件夹下的所有任务
        let tasksInFolder = tasks.filter { $0.folderId == folderId }
        for task in tasksInFolder {
            deleteTask(task.id)
        }

        // 删除子文件夹
        let subFolders = folders.filter { $0.parentId == folderId }
        for subFolder in subFolders {
            deleteFolder(subFolder.id)
        }

        // 删除文件夹本身
        folders.removeAll(where: { $0.id == folderId })
        saveData()
    }
}
