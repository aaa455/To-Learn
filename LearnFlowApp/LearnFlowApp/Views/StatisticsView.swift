import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedPeriod: TimePeriod = .week

    enum TimePeriod: String, CaseIterable {
        case week = "周"
        case month = "月"
    }

    var completedSessions: [FocusSession] {
        dataManager.focusSessions.filter { $0.status == .completed }
    }

    var totalFocusMinutes: Int {
        completedSessions.reduce(0) { $0 + $1.actualDuration } / 60
    }

    var todayMinutes: Int {
        let calendar = Calendar.current
        let today = Date()
        return completedSessions
            .filter { session in
                if let endTime = session.endTime {
                    return calendar.isDate(endTime, inSameDayAs: today)
                }
                return false
            }
            .reduce(0) { $0 + $1.actualDuration } / 60
    }

    var periodData: [(Date, Int)] {
        let calendar = Calendar.current
        let now = Date()

        let days = selectedPeriod == .week ? 7 : 30
        var data: [(Date, Int)] = []

        for i in 0..<days {
            if let date = calendar.date(byAdding: .day, value: -i, to: now) {
                let dayStart = calendar.startOfDay(for: date)
                let minutes = completedSessions
                    .filter { session in
                        if let endTime = session.endTime {
                            return calendar.isDate(endTime, inSameDayAs: dayStart)
                        }
                        return false
                    }
                    .reduce(0) { $0 + $1.actualDuration } / 60

                data.append((dayStart, minutes))
            }
        }

        return data.reversed()
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 今日统计
                    VStack(spacing: 16) {
                        Text("今日专注")
                            .font(.headline)

                        HStack(spacing: 40) {
                            VStack {
                                Text("\(todayMinutes)")
                                    .font(.system(size: 48, weight: .thin))
                                Text("分钟")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            VStack {
                                Text(completedSessions.filter { session in
                                    if let endTime = session.endTime {
                                        return Calendar.current.isDate(endTime, inSameDayAs: Date())
                                    }
                                    return false
                                }.count.formatted())
                                    .font(.system(size: 48, weight: .thin))
                                Text("次数")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)

                    // 总统计
                    VStack(spacing: 16) {
                        Text("总计")
                            .font(.headline)

                        HStack(spacing: 40) {
                            VStack {
                                Text("\(totalFocusMinutes / 60)")
                                    .font(.system(size: 36, weight: .thin))
                                Text("小时")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            VStack {
                                Text("\(completedSessions.count)")
                                    .font(.system(size: 36, weight: .thin))
                                Text("次数")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()

                    Divider()

                    // 时间段选择
                    Picker("时间段", selection: $selectedPeriod) {
                        ForEach(TimePeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // 图表
                    VStack(alignment: .leading, spacing: 8) {
                        Text("专注时长趋势")
                            .font(.headline)
                            .padding(.horizontal)

                        SimpleBarChart(data: periodData)
                            .frame(height: 200)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("统计")
        }
    }
}

struct SimpleBarChart: View {
    let data: [(Date, Int)]

    var maxValue: Int {
        data.map { $0.1 }.max() ?? 1
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(data.indices, id: \.self) { index in
                    let (date, value) = data[index]
                    VStack(spacing: 4) {
                        Spacer()

                        if value > 0 {
                            Rectangle()
                                .fill(Color.blue)
                                .frame(height: CGFloat(value) / CGFloat(maxValue) * (geometry.size.height - 40))
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 4)
                        }

                        Text(formatDate(date))
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}
