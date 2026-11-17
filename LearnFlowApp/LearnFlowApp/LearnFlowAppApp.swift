import SwiftUI

@main
struct LearnFlowAppApp: App {
    @StateObject private var dataManager = DataManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
        }
    }
}

// 数据管理器
class DataManager: ObservableObject {
    static let shared = DataManager()

    @Published var workflows: [Workflow] = []
    @Published var goals: [Goal] = []
    @Published var focusSessions: [FocusSession] = []
    @Published var reviewCards: [ReviewCard] = []

    private init() {
        loadData()
    }

    func loadData() {
        // 从UserDefaults加载数据
        if let workflowsData = UserDefaults.standard.data(forKey: "workflows"),
           let decoded = try? JSONDecoder().decode([Workflow].self, from: workflowsData) {
            workflows = decoded
        }

        if let goalsData = UserDefaults.standard.data(forKey: "goals"),
           let decoded = try? JSONDecoder().decode([Goal].self, from: goalsData) {
            goals = decoded
        }

        if let sessionsData = UserDefaults.standard.data(forKey: "focusSessions"),
           let decoded = try? JSONDecoder().decode([FocusSession].self, from: sessionsData) {
            focusSessions = decoded
        }

        if let reviewData = UserDefaults.standard.data(forKey: "reviewCards"),
           let decoded = try? JSONDecoder().decode([ReviewCard].self, from: reviewData) {
            reviewCards = decoded
        }
    }

    func saveData() {
        if let encoded = try? JSONEncoder().encode(workflows) {
            UserDefaults.standard.set(encoded, forKey: "workflows")
        }

        if let encoded = try? JSONEncoder().encode(goals) {
            UserDefaults.standard.set(encoded, forKey: "goals")
        }

        if let encoded = try? JSONEncoder().encode(focusSessions) {
            UserDefaults.standard.set(encoded, forKey: "focusSessions")
        }

        if let encoded = try? JSONEncoder().encode(reviewCards) {
            UserDefaults.standard.set(encoded, forKey: "reviewCards")
        }
    }
}
