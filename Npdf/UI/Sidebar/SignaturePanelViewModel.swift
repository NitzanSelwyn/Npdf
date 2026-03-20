import Foundation
import NpdfKit

final class SignaturePanelViewModel: ObservableObject {
    @Published var signatures: [SignatureModel] = []
    let store: SignatureStore

    init(store: SignatureStore) {
        self.store = store
        reload()
    }

    func reload() {
        signatures = store.loadAll()
    }
}
