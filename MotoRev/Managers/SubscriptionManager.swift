import Foundation
import StoreKit
import Combine

@available(iOS 15.0, *)
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    @Published var products: [Product] = []
    @Published var isPurchasing = false
    @Published var lastError: String?
    
    // Replace with your real product IDs
    let productIds = ["motorev.pro.monthly", "motorev.pro.yearly"]
    
    private init() {}
    
    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: productIds)
            await MainActor.run { self.products = storeProducts }
        } catch {
            await MainActor.run { self.lastError = error.localizedDescription }
        }
    }
    
    func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await updatePremiumEntitlement()
                    // Post receipt to backend (stub)
                    _ = NetworkManager.shared.verifyReceipt(productId: product.id, transactionId: String(transaction.id), payload: nil)
                        .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
                case .unverified(_, let error):
                    await MainActor.run { self.lastError = error.localizedDescription }
                }
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            await MainActor.run { self.lastError = error.localizedDescription }
        }
    }
    
    func updatePremiumEntitlement() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if productIds.contains(transaction.productID) {
                    await MainActor.run { PremiumManager.shared.isPremium = true }
                    return
                }
            }
        }
        await MainActor.run { PremiumManager.shared.isPremium = false }
    }
} 