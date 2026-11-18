import Foundation

var failures = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() { print("PASS: \(message)") }
    else { failures += 1; print("FAIL: \(message)") }
}

// Exercise real Codable models using data written before the new fields existed.
let phase = TimePhase(nodeName: "Read", duration: 1, order: 0)
let plan = TimePlan(phases: [phase], totalDuration: 1)
let start = Date(timeIntervalSince1970: 1_700_000_000)
let oldSession = FocusSession(goalId: UUID(), timePlan: plan, startTime: start,
                              endTime: start.addingTimeInterval(45), status: .completed)
var oldJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(oldSession)) as! [String: Any]
oldJSON.removeValue(forKey: "actualDuration")
do {
    let restored = try JSONDecoder().decode(FocusSession.self, from: JSONSerialization.data(withJSONObject: oldJSON))
    check(restored.actualDuration == 45, "Legacy history derives actual elapsed seconds")
} catch { check(false, "Legacy focus history must decode: \(error)") }

let legacyConfig = #"{"provider":"OpenAI","apiKey":"migration-test-key","baseURL":"https://example.com/v1","model":"test"}"#.data(using: .utf8)!
do {
    let config = try JSONDecoder().decode(AIConfig.self, from: legacyConfig)
    check(config.customBaseURL && config.apiKey == "migration-test-key", "Legacy AI key and custom URL survive migration")
} catch { check(false, "Legacy AI config must decode: \(error)") }

let optional = TimePhase(nodeName: "Optional", duration: 1, order: 1, isTodo: true)
check(TimePlan(phases: [optional, phase]).activePhases.map(\.id) == [phase.id, optional.id],
      "Optional phases remain executable in order")

let workflow = Workflow(name: "Test", nodes: [WorkflowNode(name: "Read", minDuration: 1, maxDuration: 60)])
check(AIService.parseWorkflowFromResponse(#"{"nodes":[{"name":"Read","minDuration":200,"maxDuration":210}]}"#, goal: "Test") == nil,
      "AI rejects node duration that would crash the editor")
check(AIService.parseWorkflowFromResponse(#"{"nodes":[]}"#, goal: "Test") == nil, "AI rejects empty workflows")
check(AIService.parseWorkflowFromResponse("} reversed {", goal: "Test") == nil, "Malformed JSON cannot form an invalid string range")
check(AIService.parseTimePlansFromResponse(#"{"plans":[{}]}"#, workflow: workflow, availableMinutes: 60).isEmpty,
      "AI rejects empty plans")
check(AIService.parseTimePlansFromResponse(#"{"plans":[{"phases":[{"nodeName":"Read","duration":60,"order":0}]}]}"#, workflow: workflow, availableMinutes: 30).isEmpty,
      "AI rejects plans exceeding available time")
check(AIService.parseTimePlansFromResponse(#"{"plans":[{"phases":[{"nodeName":"Unknown","duration":1,"order":0}]}]}"#, workflow: workflow, availableMinutes: 30).isEmpty,
      "AI rejects unknown workflow nodes")
check(AIService.parseTimePlansFromResponse(#"{"plans":[{"phases":[{"nodeName":"Read","duration":1,"order":2}]}]}"#, workflow: workflow, availableMinutes: 30).isEmpty,
      "AI rejects invalid phase order")
let validPlans = AIService.parseTimePlansFromResponse(#"{"plans":[{"phases":[{"nodeName":"Read","duration":1,"order":0,"isTodo":true}],"totalDuration":1}]}"#, workflow: workflow, availableMinutes: 30)
check(validPlans.count == 1 && validPlans[0].activePhases.count == 1, "Valid optional plan is executable")

let redacted = try JSONEncoder().encode(AIConfig(provider: .openai, apiKey: "private-test-secret", customBaseURL: false).withoutAPIKey)
check(!String(decoding: redacted, as: UTF8.self).contains("private-test-secret"), "Preferences serialization excludes API key")
check(AIService.endpoint(config: AIConfig(provider: .openai, apiKey: "", baseURL: "http://example.com", customBaseURL: true), path: "models") == nil,
      "API endpoints reject plaintext transport")

let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: start)!
let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: start)!
var card = ReviewCard(title: "Review", goalId: UUID(), reviewDates: [yesterday, tomorrow])
check(card.completeNextReview(at: start), "Overdue review can be completed")
check(EbbinghausManager.getNextReviewDate(for: card) == tomorrow, "Late completion advances the scheduled occurrence")
check(!card.completeNextReview(at: start), "Future review cannot be completed early")
check(card.reviewCompletionTimes?.values.first == start, "Actual review completion time is retained")

final class TestClock {
    var date = Date(timeIntervalSince1970: 1_700_000_000)
    func advance(_ seconds: Double) { date = date.addingTimeInterval(seconds) }
}
let suite = "LearnFlowRegression-\(UUID())"
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
let dataManager = DataManager(defaults: defaults)
let clock = TestClock()
let manager = TimerManager(dataManager: dataManager, now: { clock.date })
let twoPhases = TimePlan(phases: [phase, optional], totalDuration: 2)

check(!manager.startTimer(session: FocusSession(goalId: UUID(), timePlan: TimePlan())), "Empty plan cannot start or persist")
check(dataManager.focusSessions.isEmpty, "Rejected plan leaves no orphan session")
check(manager.startTimer(session: FocusSession(goalId: UUID(), timePlan: twoPhases)), "Valid plan starts")
check(!manager.startTimer(session: FocusSession(goalId: UUID(), timePlan: plan)), "Duplicate start cannot replace an active session")
clock.advance(10)
manager.pauseTimer()
clock.advance(300)
manager.resumeTimer()
clock.advance(50)
manager.synchronize()
check(manager.currentSession?.currentPhaseIndex == 1, "Resume preserves first phase deadline")
clock.advance(60)
manager.synchronize()
check(manager.currentSession == nil && dataManager.focusSessions.last?.actualDuration == 120,
      "Cross-phase completion excludes earlier pause")

_ = manager.startTimer(session: FocusSession(goalId: UUID(), timePlan: plan))
clock.advance(10)
manager.pauseTimer()
clock.advance(120)
manager.stopTimer()
check(dataManager.focusSessions.last?.actualDuration == 10, "Stopping while paused excludes unfinished pause")

let backgroundStart = clock.date
_ = manager.startTimer(session: FocusSession(goalId: UUID(), timePlan: twoPhases))
clock.advance(600)
manager.synchronize()
check(manager.currentSession == nil && dataManager.focusSessions.last?.actualDuration == 120,
      "Background catch-up completes multiple phases without counting overshoot")
check(dataManager.focusSessions.last?.endTime == backgroundStart.addingTimeInterval(120), "Natural end uses scheduled deadline")

let skipPlan = TimePlan(phases: [TimePhase(nodeName: "Optional", duration: 1, order: 0, isTodo: true),
                                TimePhase(nodeName: "Read", duration: 1, order: 1)], totalDuration: 2)
_ = manager.startTimer(session: FocusSession(goalId: UUID(), timePlan: skipPlan))
clock.advance(15)
manager.skipCurrentPhase()
check(manager.remainingSeconds == 60 && manager.currentSession?.currentPhaseIndex == 1, "Skipping optional phase resets deadline")
clock.advance(60)
manager.synchronize()
check(dataManager.focusSessions.last?.actualDuration == 75, "Skipped duration is not counted as focus")
check(dataManager.focusSessions.last?.completedPhases.count == 1, "Skipped phase is not marked completed")

_ = manager.startTimer(session: FocusSession(goalId: UUID(), timePlan: skipPlan))
clock.advance(10)
manager.pauseTimer()
clock.advance(200)
manager.skipCurrentPhase()
check(manager.remainingSeconds == 60 && !manager.isRunning, "Skipping while paused keeps next phase frozen")
manager.resumeTimer()
clock.advance(60)
manager.synchronize()
check(dataManager.focusSessions.last?.actualDuration == 70, "Paused skip excludes pause and skipped time")

var beforeRestart: TimerManager? = TimerManager(dataManager: dataManager, now: { clock.date })
_ = beforeRestart?.startTimer(session: FocusSession(goalId: UUID(), timePlan: twoPhases))
beforeRestart = nil
clock.advance(90)
let reloaded = DataManager(defaults: defaults)
let restoredTimer = TimerManager(dataManager: reloaded, now: { clock.date })
check(restoredTimer.currentSession?.currentPhaseIndex == 1 && restoredTimer.remainingSeconds == 30,
      "Persisted timer resumes across process recreation")
restoredTimer.stopTimer()

let broken = Data("not JSON".utf8)
defaults.set(broken, forKey: "focusSessions")
let recovered = DataManager(defaults: defaults)
recovered.goals.append(Goal(name: "New", workflowId: UUID()))
recovered.saveData()
check(defaults.data(forKey: "focusSessions") == broken, "Unrelated save cannot overwrite unreadable focus history")
check(defaults.data(forKey: "focusSessions.recoveryBackup") == broken && recovered.persistenceError != nil,
      "Unreadable history is backed up with a visible error")

if failures > 0 { fatalError("\(failures) regression checks failed") }
print("All regression checks passed")
