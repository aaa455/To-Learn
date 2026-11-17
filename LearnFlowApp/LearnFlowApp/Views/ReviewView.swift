import SwiftUI

struct ReviewView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingCreateSheet = false

    var todayReviews: [ReviewCard] {
        EbbinghausManager.getTodayReviewCards(from: dataManager.reviewCards)
    }

    var upcomingReviews: [ReviewCard] {
        dataManager.reviewCards.filter { card in
            if let nextDate = EbbinghausManager.getNextReviewDate(for: card) {
                return nextDate > Date()
            }
            return false
        }
    }

    var body: some View {
        NavigationView {
            List {
                if !todayReviews.isEmpty {
                    Section(header: Text("今日复习")) {
                        ForEach(todayReviews) { card in
                            ReviewCardRow(card: card, isToday: true)
                        }
                    }
                }

                Section(header: Text("即将复习")) {
                    if upcomingReviews.isEmpty {
                        Text("暂无复习计划")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(upcomingReviews) { card in
                            ReviewCardRow(card: card, isToday: false)
                        }
                    }
                }
            }
            .navigationTitle("复习")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateReviewCardSheet(isPresented: $showingCreateSheet)
            }
        }
    }
}

struct ReviewCardRow: View {
    let card: ReviewCard
    let isToday: Bool
    @EnvironmentObject var dataManager: DataManager
    @State private var showingDetail = false

    var nextReviewDate: Date? {
        EbbinghausManager.getNextReviewDate(for: card)
    }

    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(card.title)
                        .font(.headline)
                    Spacer()
                    if isToday {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                    }
                }

                if let nextDate = nextReviewDate {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(formatDate(nextDate))
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }

                Text("已完成 \(card.completedReviews.count)/\(card.reviewDates.count) 次复习")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .foregroundColor(.primary)
        .sheet(isPresented: $showingDetail) {
            ReviewCardDetailSheet(card: card, isPresented: $showingDetail)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct ReviewCardDetailSheet: View {
    let card: ReviewCard
    @Binding var isPresented: Bool
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("标题")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(card.title)
                            .font(.headline)
                    }

                    if !card.content.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("内容")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(card.content)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("复习进度")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ForEach(card.reviewDates, id: \.self) { date in
                            HStack {
                                Image(systemName: isCompleted(date) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(isCompleted(date) ? .green : .gray)
                                Text(formatDate(date))
                                Spacer()
                                if !isCompleted(date) && Calendar.current.isDate(date, inSameDayAs: Date()) {
                                    Text("今日")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }

                    if let nextDate = EbbinghausManager.getNextReviewDate(for: card),
                       Calendar.current.isDate(nextDate, inSameDayAs: Date()) {
                        Button(action: markAsReviewed) {
                            HStack {
                                Spacer()
                                Text("标记为已复习")
                                Spacer()
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }

                    Text("提示：请在其他卡片软件中完成实际复习")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding()
            }
            .navigationTitle("复习详情")
            .navigationBarItems(trailing: Button("关闭") {
                isPresented = false
            })
        }
    }

    private func isCompleted(_ date: Date) -> Bool {
        card.completedReviews.contains(where: { completed in
            Calendar.current.isDate(completed, inSameDayAs: date)
        })
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func markAsReviewed() {
        if let index = dataManager.reviewCards.firstIndex(where: { $0.id == card.id }) {
            dataManager.reviewCards[index].completedReviews.append(Date())
            dataManager.saveData()
            isPresented = false
        }
    }
}

struct CreateReviewCardSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var dataManager: DataManager
    @State private var title = ""
    @State private var content = ""
    @State private var selectedGoalId: UUID?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("标题")) {
                    TextField("例如：Swift语法要点", text: $title)
                }

                Section(header: Text("内容（可选）")) {
                    TextEditor(text: $content)
                        .frame(height: 100)
                }

                Section(header: Text("关联目标")) {
                    if dataManager.goals.isEmpty {
                        Text("暂无目标")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("目标", selection: $selectedGoalId) {
                            Text("请选择").tag(nil as UUID?)
                            ForEach(dataManager.goals.filter { $0.isActive }) { goal in
                                Text(goal.name).tag(goal.id as UUID?)
                            }
                        }
                    }
                }

                Section {
                    Text("将按照艾宾浩斯遗忘曲线自动生成复习计划：\n1天、2天、4天、7天、15天后")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("创建复习卡片")
            .navigationBarItems(
                leading: Button("取消") { isPresented = false },
                trailing: Button("保存") {
                    if let goalId = selectedGoalId {
                        let reviewDates = EbbinghausManager.generateReviewDates(from: Date())
                        let card = ReviewCard(
                            title: title,
                            content: content,
                            goalId: goalId,
                            reviewDates: reviewDates
                        )
                        dataManager.reviewCards.append(card)
                        dataManager.saveData()
                        isPresented = false
                    }
                }
                .disabled(title.isEmpty || selectedGoalId == nil)
            )
        }
    }
}
