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

    var progress: Double {
        guard session.timePlan.activePhases.count > 0 else { return 0 }
        return Double(session.currentPhaseIndex) / Double(session.timePlan.activePhases.count)
    }

    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部信息栏
                VStack(spacing: 12) {
                    if let phase = currentPhase {
                        // 阶段标签
                        HStack {
                            Text("阶段 \(session.currentPhaseIndex + 1)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("/")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(session.timePlan.activePhases.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.3))
                        .cornerRadius(12)

                        // 节点名称
                        Text(phase.nodeName)
                            .font(.system(size: 24, weight: .medium))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        // 待办标记
                        if phase.isTodo {
                            HStack(spacing: 6) {
                                Image(systemName: "clock.badge.exclamationmark")
                                    .font(.caption2)
                                Text("此阶段可选跳过")
                                    .font(.caption)
                            }
                            .foregroundColor(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                    } else {
                        Text("已完成所有阶段")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.green)
                    }
                }
                .padding(.top, 40)
                .padding(.bottom, 20)

                Spacer()

                // 主计时器显示
                VStack(spacing: 24) {
                    // 圆形进度条
                    ZStack {
                        // 背景圆环
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 12)
                            .frame(width: 240, height: 240)

                        // 进度圆环
                        Circle()
                            .trim(from: 0, to: CGFloat(1 - (Double(timerManager.remainingSeconds) / Double((currentPhase?.duration ?? 1) * 60))))
                            .stroke(
                                LinearGradient(
                                    colors: [Color.blue, Color.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                            )
                            .frame(width: 240, height: 240)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: timerManager.remainingSeconds)

                        // 中心时间显示
                        VStack(spacing: 4) {
                            Text(timerManager.formatTime(timerManager.remainingSeconds))
                                .font(.system(size: 56, weight: .thin, design: .rounded))
                                .monospacedDigit()

                            Text(timerManager.isRunning ? "专注中" : "已暂停")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // 阶段进度指示器
                    HStack(spacing: 8) {
                        ForEach(0..<session.timePlan.activePhases.count, id: \.self) { index in
                            let phase = session.timePlan.activePhases[index]
                            ZStack {
                                // 背景圆
                                Circle()
                                    .fill(
                                        index < session.currentPhaseIndex ? Color.green :
                                        index == session.currentPhaseIndex ? Color.blue :
                                        Color.gray.opacity(0.3)
                                    )
                                    .frame(width: 16, height: 16)

                                // 待办标记
                                if phase.isTodo {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 6))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Spacer()

                // 控制按钮
                HStack(spacing: 32) {
                    // 暂停/继续按钮
                    Button(action: {
                        if timerManager.isRunning {
                            timerManager.pauseTimer()
                        } else {
                            timerManager.resumeTimer()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 80, height: 80)
                                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)

                            Image(systemName: timerManager.isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.blue)
                        }
                    }
                    .disabled(currentPhase == nil)

                    // 跳过按钮（待办任务）
                    if let phase = currentPhase, phase.isTodo {
                        Button(action: {
                            showingSkipConfirmation = true
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 80, height: 80)
                                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)

                                Image(systemName: "forward.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.orange)
                            }
                        }
                    }

                    // 停止按钮
                    Button(action: {
                        showingEndConfirmation = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 80, height: 80)
                                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)

                            Image(systemName: "stop.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("专注模式")
                    .font(.headline)
            }
        }
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
                ZStack {
                    LinearGradient(
                        colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()

                    VStack(spacing: 24) {
                        Image(systemName: "timer")
                            .font(.system(size: 80))
                            .foregroundColor(.blue.opacity(0.5))

                        VStack(spacing: 8) {
                            Text("暂无进行中的专注")
                                .font(.title3)
                                .fontWeight(.medium)

                            Text("创建目标并开始专注")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
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
