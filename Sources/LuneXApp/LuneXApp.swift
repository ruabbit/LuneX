import SwiftUI

@main
struct LuneXApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        #if os(tvOS)
        WindowGroup {
            rootView
        }
        #elseif os(macOS)
        WindowGroup {
            rootView
        }
        .defaultSize(width: 1280, height: 800)
        .windowResizability(.contentSize)
        #else
        WindowGroup {
            rootView
        }
        .defaultSize(width: 1280, height: 800)
        #endif
    }

    private var rootView: some View {
        RootView()
            .environment(appModel)
    }
}
