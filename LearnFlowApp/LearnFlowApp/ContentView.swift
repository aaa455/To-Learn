import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedTab = 0

    var body: some View {
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

            ReviewView()
                .tabItem {
                    Label("复习", systemImage: "book")
                }
                .tag(3)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(DataManager.shared)
    }
}
