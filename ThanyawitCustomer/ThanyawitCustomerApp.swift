import SwiftUI

@main
struct ThanyawitCustomerApp: App {
    @StateObject private var store = CustomerStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
