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

// Decode failures retain the original bytes and block overwriting that collection.
class DataManager: ObservableObject {
    static let shared = DataManager()
    @Published var workflows: [Workflow] = []
    @Published var goals: [Goal] = []
    @Published var focusSessions: [FocusSession] = []
    @Published var reviewCards: [ReviewCard] = []
    @Published private(set) var persistenceError: String?
    private let defaults: UserDefaults
    private var unreadableKeys = Set<String>()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadData()
    }

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            let value = try JSONDecoder().decode(type, from: data)
            unreadableKeys.remove(key)
            return value
        } catch {
            unreadableKeys.insert(key)
            if defaults.data(forKey: key + ".recoveryBackup") == nil {
                defaults.set(data, forKey: key + ".recoveryBackup")
            }
            persistenceError = "部分历史数据无法读取，已保留原始备份。该部分新修改暂不能保存，请先恢复数据。"
            return nil
        }
    }

    func loadData() {
        workflows = load([Workflow].self, key: "workflows") ?? workflows
        goals = load([Goal].self, key: "goals") ?? goals
        focusSessions = load([FocusSession].self, key: "focusSessions") ?? focusSessions
        reviewCards = load([ReviewCard].self, key: "reviewCards") ?? reviewCards
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        guard !unreadableKeys.contains(key) else { return }
        do { defaults.set(try JSONEncoder().encode(value), forKey: key) }
        catch { persistenceError = "保存失败，请重试：\(error.localizedDescription)" }
    }

    func saveData() {
        save(workflows, key: "workflows")
        save(goals, key: "goals")
        save(focusSessions, key: "focusSessions")
        save(reviewCards, key: "reviewCards")
    }
}
