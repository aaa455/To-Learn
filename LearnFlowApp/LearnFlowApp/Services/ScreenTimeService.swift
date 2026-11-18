import Foundation
import FamilyControls
import ManagedSettings

// 屏幕使用时间管理器
@available(iOS 16.0, *)
class ScreenTimeManager: ObservableObject {
    static let shared = ScreenTimeManager()

    private let authorizationCenter = AuthorizationCenter.shared
    private let managedSettingsStore = ManagedSettingsStore()

    @Published var isAuthorized = false
    @Published var isBlocking = false
    @Published var blockedApps: Set<ApplicationToken> = []

    private init() {
        checkAuthorization()
    }

    // 检查授权状态
    func checkAuthorization() {
        switch authorizationCenter.authorizationStatus {
        case .approved:
            isAuthorized = true
        default:
            isAuthorized = false
        }
    }

    // 请求授权
    @MainActor func requestAuthorization() async throws {
        do {
            try await authorizationCenter.requestAuthorization(for: .individual)
            checkAuthorization()
        } catch {
            throw error
        }
    }

    // 开始屏蔽应用（专注模式）
    func startBlocking(allowedApps: Set<ApplicationToken> = []) {
        checkAuthorization()
        guard isAuthorized else { return }

        // 屏蔽所有应用，除了白名单
        managedSettingsStore.shield.applications = nil // 先清除

        // 如果有白名单，只屏蔽非白名单应用
        if !allowedApps.isEmpty {
            // 注意：FamilyControls需要反向逻辑，我们设置shield来屏蔽
            // 这里需要获取所有应用，然后排除白名单
            // 由于API限制，我们简化为全屏蔽模式
            managedSettingsStore.shield.applicationCategories = .all(except: allowedApps)
        } else {
            // 屏蔽所有应用
            managedSettingsStore.shield.applicationCategories = .all()
        }

        isBlocking = true
    }

    // 停止屏蔽
    func stopBlocking() {
        managedSettingsStore.shield.applications = nil
        managedSettingsStore.shield.applicationCategories = nil
        isBlocking = false
    }

    // 设置白名单应用
    func setWhitelistApps(_ apps: Set<ApplicationToken>) {
        blockedApps = apps
    }
}

// 应用选择器配置
struct AppBlockingConfig: Codable {
    var isEnabled: Bool
    var useWhitelist: Bool // true=白名单模式，false=全部屏蔽

    init(isEnabled: Bool = false, useWhitelist: Bool = false) {
        self.isEnabled = isEnabled
        self.useWhitelist = useWhitelist
    }
}
