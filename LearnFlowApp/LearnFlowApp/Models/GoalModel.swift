import Foundation

// 学习目标
struct Goal: Identifiable, Codable {
    let id: UUID
    var name: String
    var workflowId: UUID
    var createdAt: Date
    var isActive: Bool

    init(id: UUID = UUID(), name: String, workflowId: UUID, createdAt: Date = Date(), isActive: Bool = true) {
        self.id = id
        self.name = name
        self.workflowId = workflowId
        self.createdAt = createdAt
        self.isActive = isActive
    }
}

// 专注会话
struct FocusSession: Identifiable, Codable {
    let id: UUID
    var goalId: UUID
    var timePlan: TimePlan
    var currentPhaseIndex: Int
    var startTime: Date?
    var endTime: Date?
    var status: SessionStatus
    var pausedAt: Date?
    var totalPausedDuration: Int // 总暂停时长（秒）
    var isAppBlockingEnabled: Bool // 是否启用应用锁定
    var completedPhases: [UUID] // 已完成的阶段ID

    init(id: UUID = UUID(), goalId: UUID, timePlan: TimePlan, currentPhaseIndex: Int = 0, startTime: Date? = nil, endTime: Date? = nil, status: SessionStatus = .pending, pausedAt: Date? = nil, totalPausedDuration: Int = 0, isAppBlockingEnabled: Bool = false, completedPhases: [UUID] = []) {
        self.id = id
        self.goalId = goalId
        self.timePlan = timePlan
        self.currentPhaseIndex = currentPhaseIndex
        self.startTime = startTime
        self.endTime = endTime
        self.status = status
        self.pausedAt = pausedAt
        self.totalPausedDuration = totalPausedDuration
        self.isAppBlockingEnabled = isAppBlockingEnabled
        self.completedPhases = completedPhases
    }
}

enum SessionStatus: String, Codable {
    case pending = "pending"
    case running = "running"
    case paused = "paused"
    case completed = "completed"
}

// 统计数据
struct Statistics: Codable {
    var totalFocusTime: Int // 总专注时间（分钟）
    var sessionsCount: Int // 会话数量
    var dailyStats: [DailyStats]

    init(totalFocusTime: Int = 0, sessionsCount: Int = 0, dailyStats: [DailyStats] = []) {
        self.totalFocusTime = totalFocusTime
        self.sessionsCount = sessionsCount
        self.dailyStats = dailyStats
    }
}

struct DailyStats: Identifiable, Codable {
    let id: UUID
    var date: Date
    var focusTime: Int // 专注时间（分钟）
    var sessionsCount: Int

    init(id: UUID = UUID(), date: Date, focusTime: Int = 0, sessionsCount: Int = 0) {
        self.id = id
        self.date = date
        self.focusTime = focusTime
        self.sessionsCount = sessionsCount
    }
}
