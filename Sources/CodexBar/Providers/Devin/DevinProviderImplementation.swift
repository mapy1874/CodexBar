import CodexBarCore
import CodexBarMacroSupport
import Foundation
import SwiftUI

@ProviderImplementationRegistration
struct DevinProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .devin
}
