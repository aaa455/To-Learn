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

    init(id: UUID = UUID(), title: String, content: String = "", goalId: UUID, createdAt: Date = Date(), reviewDates: [Date] = [], completedReviews: [Date] = []) {
        self.id = id
        self.title = title
        self.content = content
        self.goalId = goalId
        self.createdAt = createdAt
        self.reviewDates = reviewDates
        self.completedReviews = completedReviews
    }
}

// 艾宾浩斯遗忘曲线复习计划生成器
class EbbinghausManager {
    // 艾宾浩斯复习间隔（天）：1天、2天、4天、7天、15天
    static let reviewIntervals = [1, 2, 4, 7, 15]

    static func generateReviewDates(from startDate: Date) -> [Date] {
        let calendar = Calendar.current
        return reviewIntervals.compactMap { interval in
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
        let calendar = Calendar.current

        return cards.filter { card in
            if let nextReview = getNextReviewDate(for: card) {
                return calendar.isDate(nextReview, inSameDayAs: today) || nextReview < today
            }
            return false
        }
    }
}
