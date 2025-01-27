import ComposableArchitecture
import SwiftUI

struct RootFeatureView: View {
  @Bindable var store: StoreOf<RootFeature> = Store(initialState: .init()) { RootFeature() }

#if os(iOS)
  init() {
    UILabel.appearance(whenContainedInInstancesOf: [UINavigationBar.self])
      .lineBreakMode = .byTruncatingMiddle
  }
#endif

  var body: some View {
    TabView(selection: $store.activeTab.sending(\.tabChanged)) {
      FromStateView(store: store.scope(state: \.fromState, action: \.fromState))
        .padding()
        .tabItem {
          Label("FromState", systemImage: "1.circle")
        }
        .tag(RootFeature.Tab.fromStateFeature)

      FromQueryView(store: store.scope(state: \.fromQuery, action: \.fromQuery))
        .padding()
        .tabItem {
          Label("FromQuery", systemImage: "2.circle")
        }
        .tag(RootFeature.Tab.fromQueryFeature)
    }
  }
}

extension RootFeatureView {
  static var preview: some View {
    @Dependency(\.modelContextProvider) var context
    return RootFeatureView()
      .modelContext(context)
  }
}

#Preview {
  RootFeatureView.preview
}
