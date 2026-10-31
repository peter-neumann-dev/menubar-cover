import Combine
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    private let refresh = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section {
                if model.items.isEmpty {
                    Text(model.hasAccessibility ? "Looking for icons…" : "Needs the Accessibility permission.")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.items) { item in
                    Toggle(isOn: Binding(get: { model.isVisible(item) }, set: { model.setVisible(item, $0) })) {
                        HStack(spacing: 10) {
                            ItemPreview(image: model.thumbnails[item.id], size: item.frame.size)
                            Text(item.appName)
                        }
                    }
                }
            } header: {
                Text("Visible icons")
            } footer: {
                Text("Icons that are switched off get covered.")
            }

            Section("Displays") {
                Picker("Cover on", selection: $model.coverAllDisplays) {
                    Text("All displays").tag(true)
                    Text("Selected displays").tag(false)
                }
                .pickerStyle(.radioGroup)

                if !model.coverAllDisplays {
                    ForEach(model.displays) { display in
                        Toggle(isOn: Binding(get: { model.isCovered(display) }, set: { model.setCovered(display, $0) })) {
                            Text(display.name)
                            if display.isMain { Text("Main display") }
                        }
                    }
                }
            }

            Section("Permissions") {
                PermissionRow(
                    title: "Accessibility",
                    detail: "Finds the positions of the icons.",
                    granted: model.hasAccessibility,
                    request: model.requestAccessibility
                )
                PermissionRow(
                    title: "Screen Recording",
                    detail: "Reads the wallpaper so the covers look like an empty menu bar.",
                    granted: model.hasScreenRecording,
                    request: model.requestScreenRecording
                )
            }

            Section {
                Toggle("Launch at login", isOn: $model.launchAtLogin)
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ActivationBar(model: model)
        }
        .frame(width: 460, height: 680)
        .onReceive(refresh) { _ in model.refreshEnvironment() }
    }
}

private struct ActivationBar: View {
    @ObservedObject var model: AppModel

    private var status: String {
        let hidden = model.items.filter { !model.isVisible($0) }.count
        let screens = model.displays.filter(model.isCovered).count
        let icons = hidden == 1 ? "1 icon" : "\(hidden) icons"
        let displays = screens == 1 ? "1 display" : "\(screens) displays"
        return model.isActive ? "Covering \(icons) on \(displays)" : "Will cover \(icons) on \(displays)"
    }

    var body: some View {
        VStack(spacing: 10) {
            Button {
                model.isActive.toggle()
            } label: {
                Label(model.isActive ? "Stop Covering" : "Cover Icons",
                      systemImage: model.isActive ? "eye" : "eye.slash")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.extraLarge)
            .tint(model.isActive ? .pink : .accentColor)
            .keyboardShortcut(.defaultAction)

            Label(status, systemImage: model.isActive ? "circle.fill" : "circle")
                .font(.callout)
                .foregroundStyle(model.isActive ? .pink : .secondary)
                .symbolRenderingMode(.monochrome)
                .imageScale(.small)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}

/// The item as it looks in the menu bar, on a dark chip so white glyphs stay readable in light mode.
private struct ItemPreview: View {
    let image: CGImage?
    let size: CGSize

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: CGFloat(image.width) / max(size.width, 1))
            } else {
                Color.clear.frame(width: size.width, height: size.height)
            }
        }
        .frame(height: 24)
        .padding(.horizontal, 6)
        .background(Color(white: 0.13), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let granted: Bool
    let request: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if granted {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Button("Allow…", action: request)
            }
        }
    }
}
