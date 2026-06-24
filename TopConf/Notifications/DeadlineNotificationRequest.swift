import Foundation

struct DeadlineNotificationRequest: Equatable {
    let identifier: String
    let deadlineID: String
    let title: String
    let body: String
    let deliveryDate: Date
}
