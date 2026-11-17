import Foundation

// 工作流模型
struct Workflow: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var nodes: [WorkflowNode]
    var createdAt: Date

    init(id: UUID = UUID(), name: String, description: String = "", nodes: [WorkflowNode] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.description = description
        self.nodes = nodes
        self.createdAt = createdAt
    }
}

// 工作流节点
struct WorkflowNode: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var minDuration: Int // 最小时长（分钟）
    var maxDuration: Int // 最大时长（分钟）
    var isRepeatable: Bool // 是否可重复

    init(id: UUID = UUID(), name: String, description: String = "", minDuration: Int, maxDuration: Int, isRepeatable: Bool = false) {
        self.id = id
        self.name = name
        self.description = description
        self.minDuration = minDuration
        self.maxDuration = maxDuration
        self.isRepeatable = isRepeatable
    }
}

// 时间计划方案
struct TimePlan: Identifiable, Codable {
    let id: UUID
    var phases: [TimePhase]
    var totalDuration: Int // 总时长（分钟）

    init(id: UUID = UUID(), phases: [TimePhase] = [], totalDuration: Int = 0) {
        self.id = id
        self.phases = phases
        self.totalDuration = totalDuration
    }

    var todoPhases: [TimePhase] {
        phases.filter { $0.isTodo }
    }

    var activePhases: [TimePhase] {
        phases.filter { !$0.isTodo }
    }
}

// 时间阶段
struct TimePhase: Identifiable, Codable {
    let id: UUID
    var nodeName: String
    var duration: Int // 时长（分钟）
    var order: Int
    var isTodo: Bool // 是否为待办任务

    init(id: UUID = UUID(), nodeName: String, duration: Int, order: Int, isTodo: Bool = false) {
        self.id = id
        self.nodeName = nodeName
        self.duration = duration
        self.order = order
        self.isTodo = isTodo
    }
}

// 待办任务
struct WorkflowTodoTask: Identifiable, Codable {
    let id: UUID
    var nodeName: String
    var duration: Int // 时长（分钟）
    var isCompleted: Bool

    init(id: UUID = UUID(), nodeName: String, duration: Int, isCompleted: Bool = false) {
        self.id = id
        self.nodeName = nodeName
        self.duration = duration
        self.isCompleted = isCompleted
    }
}
