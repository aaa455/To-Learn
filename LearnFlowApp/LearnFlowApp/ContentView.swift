import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var timerManager = TimerManager()
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                GoalView()
                    .tabItem {
                        Label("目标", systemImage: "target")
                    }
                    .tag(0)

                WorkflowView()
                    .tabItem {
                        Label("工作流", systemImage: "list.bullet")
                    }
                    .tag(1)

                StatisticsView()
                    .tabItem {
                        Label("统计", systemImage: "chart.bar")
                    }
                    .tag(2)

                TodoView()
                    .tabItem {
                        Label("待办", systemImage: "checkmark.circle")
                    }
                    .tag(3)

                ReviewView()
                    .tabItem {
                        Label("复习", systemImage: "book")
                    }
                    .tag(4)

                SettingsView()
                    .tabItem {
                        Label("设置", systemImage: "gearshape")
                    }
                    .tag(5)
            }

            if let error = dataManager.persistenceError {
                VStack {
                    Text(error).font(.caption).padding().background(Color.yellow)
                    Spacer()
                }.zIndex(2)
            }

            // 专注视图全屏覆盖
            if let session = timerManager.currentSession {
                FocusView(initialSession: session, timerManager: timerManager)
                    .transition(.move(edge: .bottom))
                    .zIndex(1)
            }
        }
        .environmentObject(timerManager)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StartFocusSession"))) { notification in
            if let session = notification.object as? FocusSession {
                withAnimation { _ = timerManager.startTimer(session: session) }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(DataManager.shared)
    }
}
