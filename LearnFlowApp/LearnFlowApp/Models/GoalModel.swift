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
    var actualDuration: Int // 实际专注时长（秒）
    var isAppBlockingEnabled: Bool // 是否启用应用锁定
    var completedPhases: [UUID] // 已完成的阶段ID
    var phaseEndTime: Date? // 恢复计时使用的绝对截止时间

    init(id: UUID = UUID(), goalId: UUID, timePlan: TimePlan, currentPhaseIndex: Int = 0, startTime: Date? = nil, endTime: Date? = nil, status: SessionStatus = .pending, pausedAt: Date? = nil, totalPausedDuration: Int = 0, actualDuration: Int = 0, isAppBlockingEnabled: Bool = false, completedPhases: [UUID] = []) {
        self.id = id
        self.goalId = goalId
        self.timePlan = timePlan
        self.currentPhaseIndex = currentPhaseIndex
        self.startTime = startTime
        self.endTime = endTime
        self.status = status
        self.pausedAt = pausedAt
        self.totalPausedDuration = totalPausedDuration
        self.actualDuration = actualDuration
        self.isAppBlockingEnabled = isAppBlockingEnabled
        self.completedPhases = completedPhases
    }

    private enum CodingKeys: String, CodingKey {
        case id, goalId, timePlan, currentPhaseIndex, startTime, endTime, status
        case pausedAt, totalPausedDuration, actualDuration, isAppBlockingEnabled, completedPhases, phaseEndTime
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        goalId = try values.decode(UUID.self, forKey: .goalId)
        timePlan = try values.decode(TimePlan.self, forKey: .timePlan)
        currentPhaseIndex = try values.decodeIfPresent(Int.self, forKey: .currentPhaseIndex) ?? 0
        startTime = try values.decodeIfPresent(Date.self, forKey: .startTime)
        endTime = try values.decodeIfPresent(Date.self, forKey: .endTime)
        status = try values.decode(SessionStatus.self, forKey: .status)
        pausedAt = try values.decodeIfPresent(Date.self, forKey: .pausedAt)
        totalPausedDuration = try values.decodeIfPresent(Int.self, forKey: .totalPausedDuration) ?? 0
        isAppBlockingEnabled = try values.decodeIfPresent(Bool.self, forKey: .isAppBlockingEnabled) ?? false
        completedPhases = try values.decodeIfPresent([UUID].self, forKey: .completedPhases) ?? []
        phaseEndTime = try values.decodeIfPresent(Date.self, forKey: .phaseEndTime)
        if let recorded = try values.decodeIfPresent(Int.self, forKey: .actualDuration) {
            actualDuration = max(0, recorded)
        } else if let start = startTime, let end = endTime {
            actualDuration = max(0, Int(end.timeIntervalSince(start)) - totalPausedDuration)
        } else {
            actualDuration = 0
        }
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
