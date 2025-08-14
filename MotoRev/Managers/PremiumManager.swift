import Foundation
import Combine

final class PremiumManager: ObservableObject {
    static let shared = PremiumManager()
    @Published var isPremium: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        SocialManager.shared.$currentSubscriptionTier
            .map { ($0.lowercased() == "pro") }
            .assign(to: &$isPremium)
    }
} 