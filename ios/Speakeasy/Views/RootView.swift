import SwiftUI

enum AppRoute: Hashable, CaseIterable {
    case home, savedDetails, history, about

    var title: String {
        switch self {
        case .home: return "Speakeasy"
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
        let s = AppStore()
        _store = StateObject(wrappedValue: s)
        _vm = StateObject(wrappedValue: SessionViewModel(store: s))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            NavigationStack {
                ZStack {
                    Theme.ground.ignoresSafeArea()
                    routedContent
                }
                .navigationTitle(route.title)
                .navigationBarTitleDisplayMode(route == .home ? .large : .inline)
                .toolbarBackground(Theme.ground, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { openDrawer() } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                        }
                        .accessibilityLabel("Menu")
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
            SavedDetailsView(details: $store.details)
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
            .foregroundStyle(Theme.primary)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(Theme.surface))
            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
        }
        .disabled(!vm.canAcceptInput)
    }

    private func openDrawer() { withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { showDrawer = true } }
    private func closeDrawer() { withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { showDrawer = false } }
}

#Preview { RootView() }
