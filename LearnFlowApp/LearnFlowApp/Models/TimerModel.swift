import Foundation
import Combine
#if os(iOS)
import UIKit
import UserNotifications
#endif

class TimerManager: ObservableObject {
    @Published private(set) var remainingSeconds = 0
    @Published private(set) var isRunning = false
    @Published private(set) var currentSession: FocusSession?

    private var timer: AnyCancellable?
    private let dataManager: DataManager
    private let now: () -> Date
    private var notificationGeneration = UUID()
    private var notificationIDs: [String] = []

    init(dataManager: DataManager = .shared, now: @escaping () -> Date = Date.init) {
        self.dataManager = dataManager
        self.now = now
        #if os(iOS)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification, object: nil)
        #endif
        restoreSession()
    }

    deinit {
        timer?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    @discardableResult
    func startTimer(session: FocusSession) -> Bool {
        guard currentSession == nil, session.timePlan.isExecutable else { return false }
        var session = session
        session.currentPhaseIndex = 0
        session.status = .running
        session.startTime = now()
        session.endTime = nil
        session.pausedAt = nil
        session.totalPausedDuration = 0
        session.actualDuration = 0
        session.completedPhases = []
        session.phaseEndTime = now().addingTimeInterval(Double(session.timePlan.activePhases[0].duration * 60))
        currentSession = session
        isRunning = true
        saveSession()
        updateRemaining()
        #if os(iOS)
        if session.isAppBlockingEnabled { ScreenTimeManager.shared.startBlocking() }
        #endif
        startTicks()
        scheduleNotifications()
        return true
    }

    func pauseTimer() {
        guard isRunning else { return }
        synchronize()
        guard var session = currentSession else { return }
        session.pausedAt = now()
        session.status = .paused
        currentSession = session
        isRunning = false
        timer?.cancel()
        cancelNotifications()
        saveSession()
    }

    func resumeTimer() {
        guard !isRunning, var session = currentSession, let paused = session.pausedAt else { return }
        let interval = max(0, now().timeIntervalSince(paused))
        session.totalPausedDuration += Int(interval)
        session.phaseEndTime = session.phaseEndTime?.addingTimeInterval(interval)
        session.pausedAt = nil
        session.status = .running
        currentSession = session
        isRunning = true
        saveSession()
        synchronize()
        startTicks()
        scheduleNotifications()
    }

    func stopTimer() {
        if isRunning { synchronize() }
        guard currentSession != nil else { return }
        finish(at: now())
    }

    func skipCurrentPhase() {
        if isRunning { synchronize() }
        guard let session = currentSession,
              session.timePlan.activePhases.indices.contains(session.currentPhaseIndex),
              session.timePlan.activePhases[session.currentPhaseIndex].isTodo else { return }
        // While paused, the next phase also remains frozen until resume.
        advancePhase(at: session.pausedAt ?? now(), completed: false)
        updateRemaining()
        scheduleNotifications()
    }

    // Reconcile every expired phase against its original deadline, including time asleep.
    func synchronize() {
        guard isRunning else { return }
        let timestamp = now()
        var advanced = false
        while let session = currentSession, let deadline = session.phaseEndTime, deadline <= timestamp {
            advancePhase(at: deadline, completed: true)
            advanced = true
        }
        updateRemaining()
        #if os(iOS)
        if advanced { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        #endif
    }

    private func advancePhase(at boundary: Date, completed: Bool) {
        guard var session = currentSession else { return }
        let phases = session.timePlan.activePhases
        if completed { session.completedPhases.append(phases[session.currentPhaseIndex].id) }
        session.currentPhaseIndex += 1
        currentSession = session
        guard session.currentPhaseIndex < phases.count else {
            finish(at: completed ? boundary : now())
            return
        }
        session.phaseEndTime = boundary.addingTimeInterval(Double(phases[session.currentPhaseIndex].duration * 60))
        currentSession = session
        saveSession()
    }

    private func finish(at timestamp: Date) {
        guard var session = currentSession else { return }
        let activeEnd = session.pausedAt ?? timestamp
        session.actualDuration = max(0, Int(activeEnd.timeIntervalSince(session.startTime ?? activeEnd)) - session.totalPausedDuration)
        if let paused = session.pausedAt {
            session.totalPausedDuration += max(0, Int(timestamp.timeIntervalSince(paused)))
        }
        session.endTime = timestamp
        session.status = .completed
        session.pausedAt = nil
        session.phaseEndTime = nil
        currentSession = session
        saveSession()
        timer?.cancel()
        isRunning = false
        remainingSeconds = 0
        cancelNotifications()
        #if os(iOS)
        ScreenTimeManager.shared.stopBlocking()
        #endif
        currentSession = nil
    }

    private func updateRemaining() {
        guard let session = currentSession, let deadline = session.phaseEndTime else {
            remainingSeconds = 0
            return
        }
        remainingSeconds = max(0, Int(ceil(deadline.timeIntervalSince(session.pausedAt ?? now()))))
    }

    private func startTicks() {
        timer?.cancel()
        guard isRunning else { return }
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.synchronize() }
    }

    private func saveSession() {
        guard let session = currentSession else { return }
        if let index = dataManager.focusSessions.firstIndex(where: { $0.id == session.id }) {
            dataManager.focusSessions[index] = session
        } else {
            dataManager.focusSessions.append(session)
        }
        dataManager.saveData()
    }

    private func restoreSession() {
        guard let session = dataManager.focusSessions.last(where: { $0.status == .running || $0.status == .paused }),
              session.timePlan.isExecutable,
              session.timePlan.activePhases.indices.contains(session.currentPhaseIndex),
              session.phaseEndTime != nil,
              session.status != .paused || session.pausedAt != nil else { return }
        currentSession = session
        isRunning = session.status == .running
        synchronize()
        updateRemaining()
        startTicks()
        scheduleNotifications()
    }

    private func cancelNotifications() {
        notificationGeneration = UUID()
        #if os(iOS)
        if let id = currentSession?.id {
            notificationIDs += (0..<64).map { "focus-\(id)-\($0)" }
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: notificationIDs)
        #endif
        notificationIDs = []
    }

    private func scheduleNotifications() {
        cancelNotifications()
        #if os(iOS)
        guard isRunning, let session = currentSession, let deadline = session.phaseEndTime else { return }
        let generation = notificationGeneration
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                guard let self = self, granted, self.isRunning, self.notificationGeneration == generation else { return }
                var end = deadline
                let phases = session.timePlan.activePhases
                for index in session.currentPhaseIndex..<phases.count {
                    if index > session.currentPhaseIndex { end = end.addingTimeInterval(Double(phases[index].duration * 60)) }
                    let delay = end.timeIntervalSince(self.now())
                    guard delay > 0 else { continue }
                    let content = UNMutableNotificationContent()
                    content.title = index == phases.count - 1 ? "专注已完成" : "进入下一阶段"
                    content.body = index == phases.count - 1 ? "本次专注已结束，请返回应用查看记录。" : phases[index + 1].nodeName
                    content.sound = .default
                    let id = "focus-\(session.id)-\(index)"
                    self.notificationIDs.append(id)
                    let request = UNNotificationRequest(identifier: id, content: content,
                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false))
                    UNUserNotificationCenter.current().add(request)
                }
            }
        }
        #endif
    }

    #if os(iOS)
    @objc private func appDidEnterBackground() {
        synchronize()
        saveSession()
        timer?.cancel()
    }

    @objc private func appWillEnterForeground() {
        synchronize()
        startTicks()
    }
    #endif

    func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        return hours > 0 ? String(format: "%02d:%02d:%02d", hours, minutes, secs) : String(format: "%02d:%02d", minutes, secs)
    }
}
