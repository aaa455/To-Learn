import Foundation

// 复习卡片
struct ReviewCard: Identifiable, Codable {
    let id: UUID
    var title: String
    var content: String
    var goalId: UUID
    var createdAt: Date
    var reviewDates: [Date] // 艾宾浩斯复习时间点
    var completedReviews: [Date] // 已完成的复习
    var reviewCompletionTimes: [String: Date]? // 计划日期对应的实际完成时间，兼容旧记录

    init(id: UUID = UUID(), title: String, content: String = "", goalId: UUID, createdAt: Date = Date(), reviewDates: [Date] = [], completedReviews: [Date] = []) {
        self.id = id
        self.title = title
        self.content = content
        self.goalId = goalId
        self.createdAt = createdAt
        self.reviewDates = reviewDates
        self.completedReviews = completedReviews
    }

    @discardableResult
    mutating func completeNextReview(at now: Date = Date()) -> Bool {
        guard let scheduled = EbbinghausManager.getNextReviewDate(for: self),
              EbbinghausManager.isDue(scheduled, at: now) else { return false }
        // Completion identifies the scheduled occurrence, even when reviewed late.
        completedReviews.append(scheduled)
        var times = reviewCompletionTimes ?? [:]
        times[String(scheduled.timeIntervalSinceReferenceDate)] = now
        reviewCompletionTimes = times
        return true
    }
}

// 艾宾浩斯遗忘曲线复习计划生成器
class EbbinghausManager {
    static func isDue(_ scheduled: Date, at now: Date = Date()) -> Bool {
        Calendar.current.startOfDay(for: scheduled) <= Calendar.current.startOfDay(for: now)
    }
    // 艾宾浩斯复习间隔（天）：1天、2天、4天、7天、15天
    static let reviewDays = [1, 2, 4, 7, 15]

    static let reviewIntervals = reviewDays // 保持兼容

    static func generateReviewDates(from startDate: Date) -> [Date] {
        let calendar = Calendar.current
        return reviewDays.compactMap { interval in
            calendar.date(byAdding: .day, value: interval, to: startDate)
        }
    }

    static func getNextReviewDate(for card: ReviewCard) -> Date? {
        let pendingDates = card.reviewDates.filter { date in
            !card.completedReviews.contains(where: { completed in
                Calendar.current.isDate(completed, inSameDayAs: date)
            })
        }

        return pendingDates.sorted().first
    }

    static func getTodayReviewCards(from cards: [ReviewCard]) -> [ReviewCard] {
        let today = Date()

        return cards.filter { card in
            if let nextReview = getNextReviewDate(for: card) {
                // 包括今日和逾期的复习
                return isDue(nextReview, at: today)
            }
            return false
        }
    }
}
