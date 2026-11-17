import SwiftUI

struct FocusView: View {
    let session: FocusSession
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var timerManager = TimerManager()
    @State private var showingEndConfirmation = false
    @State private var showingSkipConfirmation = false

    var currentPhase: TimePhase? {
        guard session.currentPhaseIndex < session.timePlan.activePhases.count else {
            return nil
        }
        return session.timePlan.activePhases[session.currentPhaseIndex]
    }

    var body: some View {
        VStack(spacing: 24) {
            // 当前阶段
            if let phase = currentPhase {
                VStack(spacing: 8) {
                    Text("阶段 \(session.currentPhaseIndex + 1)/\(session.timePlan.phases.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(phase.nodeName)
                        .font(.title2)
                        .fontWeight(.semibold)
                }
            } else {
                Text("已完成所有阶段")
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Spacer()

            // 倒计时显示
            Text(timerManager.formatTime(timerManager.remainingSeconds))
                .font(.system(size: 72, weight: .thin, design: .rounded))
                .monospacedDigit()

            Spacer()

            // 当前阶段信息
            if let phase = currentPhase, phase.isTodo {
                Text("此阶段为待办任务，可选择跳过")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.bottom, 8)
            }

            // 进度指示器
            HStack(spacing: 12) {
                ForEach(0..<session.timePlan.activePhases.count, id: \.self) { index in
                    let phase = session.timePlan.activePhases[index]
                    Circle()
                        .fill(index < session.currentPhaseIndex ? Color.green :
                              index == session.currentPhaseIndex ? Color.blue :
                              Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                        .overlay(
                            phase.isTodo ?
                            Image(systemName: "ellipsis")
                                .font(.system(size: 6))
                                .foregroundColor(.white)
                            : nil
                        )
                }
            }
            .padding(.bottom, 24)

            // 控制按钮
            HStack(spacing: 24) {
                Button(action: {
                    if timerManager.isRunning {
                        timerManager.pauseTimer()
                    } else {
                        timerManager.resumeTimer()
                    }
                }) {
                    Image(systemName: timerManager.isRunning ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                }
                .disabled(currentPhase == nil)

                if let phase = currentPhase, phase.isTodo {
                    Button(action: {
                        showingSkipConfirmation = true
                    }) {
                        Image(systemName: "forward.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.orange)
                    }
                }

                Button(action: {
                    showingEndConfirmation = true
                }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .navigationTitle("专注中")
        .onAppear {
            if timerManager.currentSession == nil {
                timerManager.startTimer(session: session)
            }
        }
        .alert("确认结束", isPresented: $showingEndConfirmation) {
            Button("取消", role: .cancel) { }
            Button("结束", role: .destructive) {
                endSession()
            }
        } message: {
            Text("确定要结束当前专注吗?")
        }
        .alert("跳过待办", isPresented: $showingSkipConfirmation) {
            Button("取消", role: .cancel) { }
            Button("跳过", role: .default) {
                timerManager.skipCurrentPhase()
            }
        } message: {
            Text("确定跳过当前待办任务吗？你可以稍后单独完成。")
        }
    }

    private func endSession() {
        timerManager.stopTimer()
        // 更新会话状态
        if let index = dataManager.focusSessions.firstIndex(where: { $0.id == session.id }) {
            dataManager.focusSessions[index].status = .completed
            dataManager.focusSessions[index].endTime = Date()
            dataManager.saveData()
        }
    }
}

struct ActiveFocusView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var currentSessionId: UUID?

    var currentSession: FocusSession? {
        guard let id = currentSessionId else { return nil }
        return dataManager.focusSessions.first(where: { $0.id == id && $0.status != .completed })
    }

    var body: some View {
        Group {
            if let session = currentSession {
                FocusView(session: session)
            } else {
                VStack {
                    Image(systemName: "timer")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    Text("暂无进行中的专注")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StartFocusSession"))) { notification in
            if let session = notification.object as? FocusSession {
                currentSessionId = session.id
            }
        }
    }
}
