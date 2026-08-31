import SwiftUI

/// A quick, searchable language picker presented as a sheet.
struct LanguagePickerView: View {
    @Binding var selected: AppLanguage
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [AppLanguage] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return AppLanguage.all }
        return AppLanguage.all.filter { $0.name.lowercased().contains(q) || $0.endonym.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(filtered) { lang in
                        Button {
                            selected = lang
                            dismiss()
                        } label: {
                            HStack(spacing: Theme.Space.s) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(lang.endonym).font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                                    Text(lang.name).font(.caption).foregroundStyle(Theme.inkSecondary)
                                }
                                Spacer()
                                if lang == selected {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.primary).font(.title3)
                                }
                            }
                            .padding(.vertical, 12).padding(.horizontal, Theme.Space.m)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(lang == selected ? Theme.primary.opacity(0.10) : Theme.surface))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.vertical, Theme.Space.m)
            }
            .background(Theme.ground)
            .navigationTitle("Language")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Theme.primary)
                }
            }
        }
    }
}
