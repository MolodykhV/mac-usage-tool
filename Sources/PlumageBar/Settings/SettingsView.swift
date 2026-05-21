import PlumageBarCore
import SwiftUI

struct SettingsView: View {
    @Bindable var store: SettingsStore
    var autostartManager: AutostartManager
    @Bindable var notificationAdapter: NotificationCenterAdapter

    var body: some View {
        TabView {
            GeneralSettingsView(store: store, autostartManager: autostartManager)
                .tabItem { Label("settings.tab.general", systemImage: "gearshape") }

            DisplaySettingsView(store: store)
                .tabItem { Label("settings.tab.display", systemImage: "rectangle.dashed") }

            ThresholdsSettingsView(store: store, notificationAdapter: notificationAdapter)
                .tabItem { Label("settings.tab.thresholds", systemImage: "exclamationmark.bubble") }
        }
        .frame(width: 460, height: 380)
        .padding(.top, 8)
    }
}

struct GeneralSettingsView: View {
    @Bindable var store: SettingsStore
    var autostartManager: AutostartManager

    var body: some View {
        Form {
            Section {
                let interval = Binding(
                    get: { store.settings.sampling.intervalSeconds },
                    set: { newValue in
                        store.update { $0.sampling.intervalSeconds = SamplingSettings.clamp(newValue) }
                    }
                )
                Slider(
                    value: interval,
                    in: SamplingSettings.allowedRange,
                    step: 0.5
                ) {
                    Text("settings.general.interval.label")
                } minimumValueLabel: {
                    Text("1s")
                } maximumValueLabel: {
                    Text("10s")
                }
                Text(intervalDescription(interval.wrappedValue))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("settings.general.sampling")
            }

            Section {
                let autostart = Binding(
                    get: { store.settings.autostart },
                    set: { newValue in
                        // Update store optimistically so SwiftUI redraws the
                        // Toggle to the intended state, then reconcile with
                        // SMAppService. If it refuses (e.g. requires approval),
                        // flip the stored value back — the second update fires
                        // a fresh Observable invalidation and the Toggle snaps
                        // back to its previous state.
                        store.update { $0.autostart = newValue }
                        let succeeded = autostartManager.setEnabled(newValue)
                        if !succeeded {
                            store.update { $0.autostart = !newValue }
                        }
                    }
                )
                Toggle("settings.general.autostart", isOn: autostart)
                Text(LocalizedStringKey(autostartManager.status.localizationKey))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("settings.general.startup")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private func intervalDescription(_ seconds: Double) -> String {
        String(format: NSLocalizedString("settings.general.interval.description", comment: ""), seconds)
    }
}

struct DisplaySettingsView: View {
    @Bindable var store: SettingsStore

    var body: some View {
        Form {
            Section {
                ForEach(MenuBarMetric.allCases) { metric in
                    let binding = Binding<Bool>(
                        get: { store.settings.menuBar.visibleMetrics.contains(metric) },
                        set: { include in
                            store.update {
                                var visible = $0.menuBar.visibleMetrics
                                if include {
                                    if !visible.contains(metric) { visible.append(metric) }
                                } else {
                                    visible.removeAll { $0 == metric }
                                }
                                $0.menuBar.visibleMetrics = visible
                            }
                        }
                    )
                    Toggle(isOn: binding) {
                        Label(LocalizedStringKey(metric.localizationKey), systemImage: metric.systemImageName)
                    }
                }
            } header: {
                Text("settings.display.visible")
            } footer: {
                Text("settings.display.visible.hint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker(
                    selection: Binding(
                        get: { store.settings.menuBar.ramFormat },
                        set: { fmt in store.update { $0.menuBar.ramFormat = fmt } }
                    )
                ) {
                    Text("settings.display.ramFormat.percent").tag(RAMFormat.percent)
                    Text("settings.display.ramFormat.absolute").tag(RAMFormat.absolute)
                } label: {
                    Text("settings.display.ramFormat.label")
                }
                .pickerStyle(.segmented)
            } header: {
                Text("settings.display.format")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

struct ThresholdsSettingsView: View {
    @Bindable var store: SettingsStore
    @Bindable var notificationAdapter: NotificationCenterAdapter

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("notifications.status.label")
                    Spacer()
                    Text(LocalizedStringKey(notificationAdapter.statusLocalizationKey))
                        .foregroundStyle(notificationAdapter.isAuthorized ? .green : .secondary)
                        .monospacedDigit()
                }
                HStack {
                    if notificationAdapter.isAuthorized {
                        Button("notifications.action.test") {
                            notificationAdapter.sendTestNotification()
                        }
                    } else {
                        Button("notifications.action.openSystemSettings") {
                            notificationAdapter.openSystemSettings()
                        }
                    }
                }
            } header: {
                Text("notifications.status.section")
            } footer: {
                if !notificationAdapter.isAuthorized {
                    Text("notifications.status.hint")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle(
                    "settings.notifications.master",
                    isOn: Binding(
                        get: { store.settings.notifications.enabled },
                        set: { v in store.update { $0.notifications.enabled = v } }
                    ))
                Toggle(
                    "settings.notifications.cpu",
                    isOn: Binding(
                        get: { store.settings.notifications.cpu },
                        set: { v in store.update { $0.notifications.cpu = v } }
                    )
                )
                .disabled(!store.settings.notifications.enabled)
                Toggle(
                    "settings.notifications.gpu",
                    isOn: Binding(
                        get: { store.settings.notifications.gpu },
                        set: { v in store.update { $0.notifications.gpu = v } }
                    )
                )
                .disabled(!store.settings.notifications.enabled)
                Toggle(
                    "settings.notifications.ram",
                    isOn: Binding(
                        get: { store.settings.notifications.ram },
                        set: { v in store.update { $0.notifications.ram = v } }
                    )
                )
                .disabled(!store.settings.notifications.enabled)
            } header: {
                Text("settings.notifications.section")
            } footer: {
                Text("settings.notifications.hint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                thresholdSlider(
                    title: "settings.thresholds.cpu",
                    value: Binding(
                        get: { store.settings.thresholds.cpuPercent },
                        set: { v in
                            store.update { $0.thresholds.cpuPercent = ThresholdSettings.clampPercent(v) }
                        }
                    )
                )
                thresholdSlider(
                    title: "settings.thresholds.gpu",
                    value: Binding(
                        get: { store.settings.thresholds.gpuPercent },
                        set: { v in
                            store.update { $0.thresholds.gpuPercent = ThresholdSettings.clampPercent(v) }
                        }
                    )
                )
                thresholdSlider(
                    title: "settings.thresholds.ram",
                    value: Binding(
                        get: { store.settings.thresholds.ramPercent },
                        set: { v in
                            store.update { $0.thresholds.ramPercent = ThresholdSettings.clampPercent(v) }
                        }
                    )
                )
            } header: {
                Text("settings.thresholds.levels")
            } footer: {
                Text("settings.thresholds.note")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                let sustain = Binding(
                    get: { store.settings.thresholds.sustainedSeconds },
                    set: { v in store.update { $0.thresholds.sustainedSeconds = max(5, min(v, 600)) } }
                )
                Slider(value: sustain, in: 5...120, step: 5) {
                    Text("settings.thresholds.sustained.label")
                } minimumValueLabel: {
                    Text("5s")
                } maximumValueLabel: {
                    Text("120s")
                }
                Text(
                    String(
                        format: NSLocalizedString("settings.thresholds.sustained.description", comment: ""),
                        sustain.wrappedValue)
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } header: {
                Text("settings.thresholds.sustained")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func thresholdSlider(title: LocalizedStringKey, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue.rounded()))%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0...100, step: 1)
        }
    }
}
