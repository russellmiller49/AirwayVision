import Foundation
import MetricKit

class AnalyticsManager: NSObject, MXMetricManagerSubscriber {
    static let shared = AnalyticsManager()
    private override init() {
        super.init()
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        // Process metrics, e.g. thermal throttling
    }
}
