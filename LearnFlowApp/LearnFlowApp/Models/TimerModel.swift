import Foundation
import Combine

// 计时器管理器
class TimerManager: ObservableObject {
    @Published var remainingSeconds: Int = 0
    @Published var isRunning: Bool = false
    @Published var currentSession: FocusSession?
    @Published var screenTimeManager: ScreenTimeManager?

    private var timer: AnyCancellable?

    init() {
        if #available(iOS 16.0, *) {
            screenTimeManager = ScreenTimeManager.shared
        }
    }

    func startTimer(session: FocusSession) {
        self.currentSession = session

        guard session.currentPhaseIndex < session.timePlan.activePhases.count else {
            return
        }

        let phase = session.timePlan.activePhases[session.currentPhaseIndex]
        self.remainingSeconds = phase.duration * 60
        self.isRunning = true

        // 如果启用应用锁定
        if session.isAppBlockingEnabled {
            if #available(iOS 16.0, *) {
                screenTimeManager?.startBlocking()
            }
        }

        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    func pauseTimer() {
        isRunning = false
        timer?.cancel()
    }

    func resumeTimer() {
        isRunning = true
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    func stopTimer() {
        isRunning = false
        timer?.cancel()
        remainingSeconds = 0

        // 停止应用锁定
        if #available(iOS 16.0, *) {
            screenTimeManager?.stopBlocking()
        }

        currentSession = nil
    }

    func skipCurrentPhase() {
        guard var session = currentSession else { return }

        // 跳过当前阶段（如果是待办任务）
        if session.currentPhaseIndex < session.timePlan.activePhases.count {
            let currentPhase = session.timePlan.activePhases[session.currentPhaseIndex]
            if currentPhase.isTodo {
                session.currentPhaseIndex += 1
                currentSession = session

                if session.currentPhaseIndex < session.timePlan.activePhases.count {
                    let nextPhase = session.timePlan.activePhases[session.currentPhaseIndex]
                    remainingSeconds = nextPhase.duration * 60
                } else {
                    // 所有阶段完成
                    session.status = .completed
                    session.endTime = Date()
                    currentSession = session
                    stopTimer()
                }
            }
        }
    }

    private func tick() {
        if remainingSeconds > 0 {
            remainingSeconds -= 1
        } else {
            // 阶段结束，震动提醒
            triggerVibration()
            moveToNextPhase()
        }
    }

    private func triggerVibration() {
        #if os(iOS)
        import UIKit
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    private func moveToNextPhase() {
        guard var session = currentSession else { return }

        // 标记当前阶段已完成
        if session.currentPhaseIndex < session.timePlan.activePhases.count {
            let completedPhase = session.timePlan.activePhases[session.currentPhaseIndex]
            session.completedPhases.append(completedPhase.id)
        }

        session.currentPhaseIndex += 1

        if session.currentPhaseIndex < session.timePlan.activePhases.count {
            // 还有下一阶段
            let nextPhase = session.timePlan.activePhases[session.currentPhaseIndex]
            remainingSeconds = nextPhase.duration * 60
            currentSession = session
        } else {
            // 所有阶段完成
            session.status = .completed
            session.endTime = Date()
            currentSession = session
            stopTimer()
        }
    }

    func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}
