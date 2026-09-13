import SwiftUI

enum AppRoute: Hashable, CaseIterable {
    case home, savedDetails, history, about

    var title: String {
        switch self {
        case .home: return "KindlyCall"
        case .savedDetails: return "Your details"
        case .history: return "History"
        case .about: return "How it works"
        }
    }
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .savedDetails: return "person.text.rectangle.fill"
        case .history: return "clock.arrow.circlepath"
        case .about: return "questionmark.circle.fill"
        }
    }
}

/// App shell: a burger-menu side drawer + the routed screens. Owns the store and
/// the session view model so they persist across navigation.
struct RootView: View {
    @StateObject private var store: AppStore
    @StateObject private var vm: SessionViewModel
    @State private var route: AppRoute = .home
    @State private var showDrawer = false
    @State private var showLanguages = false

    init() {
#if DEBUG
        let scenario = ProcessInfo.processInfo.environment["KINDLYCALL_DEMO_SCENARIO"]
        let defaults = scenario == nil ? UserDefaults.standard : UserDefaults(suiteName: "kindlycall.demo")!
        if scenario != nil { defaults.removePersistentDomain(forName: "kindlycall.demo") }
        let s = AppStore(defaults: defaults)
#else
        let s = AppStore()
#endif
        _store = StateObject(wrappedValue: s)
#if DEBUG
        if let scenario {
            s.autoAddToCalendar = false
            s.textForward = ProcessInfo.processInfo.environment["KINDLYCALL_DEMO_AUDIO"] != "1"
            let model = SessionViewModel(store: s, api: DemoKindlyCallAPI(scenario: scenario))
            if let code = ProcessInfo.processInfo.environment["KINDLYCALL_DEMO_LANGUAGE"] { model.language = AppLanguage.byCode(code) }
            _vm = StateObject(wrappedValue: model)
        } else { _vm = StateObject(wrappedValue: SessionViewModel(store: s)) }
#else
        _vm = StateObject(wrappedValue: SessionViewModel(store: s))
#endif
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            NavigationStack {
                ZStack {
                    Theme.backgroundGradient.ignoresSafeArea()
                    routedContent
                }
                .safeAreaInset(edge: .top) {
#if DEBUG
                    if ProcessInfo.processInfo.environment["KINDLYCALL_DEMO_SCENARIO"] != nil {
                        Text(F.t("Demo · simulated call", vm.language.code) + " · SIMULATED")
                            .font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSecondary)
                            .padding(8).frame(maxWidth: .infinity).background(Theme.surfaceSunk)
                    }
#endif
                }
                .navigationTitle(F.t(route.title, vm.language.code))
                .navigationBarTitleDisplayMode(route == .home ? .large : .inline)
                .toolbarBackground(Theme.ground, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { openDrawer() } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                        }
                        .accessibilityLabel(F.t("Menu", vm.language.code))
                    }
                    if route == .home {
                        ToolbarItem(placement: .topBarTrailing) { languagePill }
                    }
                }
            }

            if showDrawer {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { closeDrawer() }
                    .transition(.opacity)
                SideDrawer(
                    current: route,
                    language: vm.language,
                    savedCount: store.details.filledCount,
                    historyCount: store.history.count,
                    onSelect: { r in route = r; closeDrawer() },
                    onLanguages: { closeDrawer(); showLanguages = true }
                )
                .transition(.move(edge: .leading))
                .zIndex(1)
            }
        }
        .environment(\.layoutDirection, vm.language.rtl ? .rightToLeft : .leftToRight)
        .sheet(isPresented: $showLanguages) {
            LanguagePickerView(selected: $vm.language)
        }
    }

    @ViewBuilder private var routedContent: some View {
        switch route {
        case .home:
            HomeView(vm: vm)
        case .savedDetails:
            SavedDetailsView(store: store, lang: vm.language.code)
        case .history:
            HistoryView(store: store) { text, code in
                vm.speech.speak(text, localeId: AppLanguage.byCode(code).ttsLocale)
            }
        case .about:
            AboutView()
        }
    }

    private var languagePill: some View {
        Button { showLanguages = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                Text(vm.language.endonym).font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Theme.actionInk)
            .padding(.horizontal, 14).frame(minHeight: 44)
            .background(Capsule().fill(Theme.surface))
            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
        }
        .disabled(!vm.canAcceptInput)
    }

    private func openDrawer() { withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { showDrawer = true } }
    private func closeDrawer() { withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { showDrawer = false } }
}

#Preview { RootView() }
