// LoginView.swift
// Nexus — Jamf EA Dependency Analyzer
// Copyright © 2025 Murat Kolar. Licensed under GNU GPL v3.
// https://github.com/MUMO97/nexus

import SwiftUI
import Combine

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var license = LicenseManager.shared
    @State private var showAddProfile  = false
    @State private var showUpgrade     = false

    var body: some View {
        ZStack {
            AnimatedBackgroundView()

            ScrollView {
                VStack(spacing: 36) {

                    // MARK: Header with real logo
                    VStack(spacing: 10) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 90, height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .neonGlow(color: AppTheme.accentBlue, radius: 16)

                        Text("Nexus")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Jamf EA Dependency Analyzer")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.mutedText)
                    }
                    .padding(.top, 60)

                    // MARK: Server profiles
                    VStack(spacing: 12) {
                        if appState.serverProfiles.isEmpty {
                            EmptyProfileCard(showAdd: $showAddProfile)
                        } else {
                            ProfilesCard(showAdd: $showAddProfile, showUpgrade: $showUpgrade)
                        }
                    }
                    .frame(width: 440)

                    // MARK: Status
                    VStack(spacing: 8) {
                        if appState.isLoading {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(AppTheme.accentBlue)
                                    .scaleEffect(0.75)
                                Text(appState.loadingMessage)
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.mutedText)
                            }
                            MotivationalMessageView()
                        }

                        if let err = appState.errorMessage {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.dangerRed)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20).padding(.vertical, 8)
                                .background(AppTheme.dangerRed.opacity(0.1),
                                            in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .frame(width: 440)

                    Spacer(minLength: 40)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showAddProfile) { AddProfileSheet().environmentObject(appState) }
        .sheet(isPresented: $showUpgrade)     { ProUpgradeView() }
    }
}

// MARK: - Animated Background
struct AnimatedBackgroundView: View {
    @State private var t: Float = 0
    let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if #available(macOS 15, *) {
                MeshGradient(width: 3, height: 3, points: [
                    [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                    [0.0, 0.5],
                    [Float(0.5 + 0.3 * sin(t)),
                     Float(0.5 + 0.3 * cos(t * 0.7))],
                    [1.0, 0.5],
                    [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                ], colors: [
                    Color(hex: "0D0D12"), Color(hex: "0D1B33"), Color(hex: "0D0D12"),
                    Color(hex: "1A0533"), Color(hex: "1B1040"), Color(hex: "0D1B33"),
                    Color(hex: "0D0D12"), Color(hex: "0D0D12"), Color(hex: "0D1B33")
                ])
                .ignoresSafeArea()
                .onReceive(timer) { _ in t += 0.008 }
            } else {
                AppTheme.background.ignoresSafeArea()
            }
        }
    }
}

// MARK: - Empty Profile Card
struct EmptyProfileCard: View {
    @Binding var showAdd: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "server.rack")
                .font(.system(size: 32))
                .foregroundColor(AppTheme.mutedText)
            Text("No Jamf servers added yet")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
            Text("Add your first Jamf Pro server to get started")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.mutedText)
                .multilineTextAlignment(.center)
            AddServerButton(showAdd: $showAdd, showUpgrade: .constant(false))
        }
        .padding(32)
        .glassCard(cornerRadius: 20)
    }
}

// MARK: - Profiles Card
struct ProfilesCard: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var license = LicenseManager.shared
    @Binding var showAdd: Bool
    @Binding var showUpgrade: Bool

    private var atFreeLimit: Bool {
        !license.isPro && appState.serverProfiles.count >= LicenseManager.freeServerLimit
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Saved Servers")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.mutedText)
                if atFreeLimit {
                    ProBadge()
                }
                Spacer()
                AddServerButton(showAdd: $showAdd, showUpgrade: $showUpgrade, atLimit: atFreeLimit)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().overlay(AppTheme.border)

            VStack(spacing: 0) {
                ForEach(appState.serverProfiles) { profile in
                    ProfileRow(profile: profile)
                    if profile != appState.serverProfiles.last {
                        Divider().overlay(AppTheme.border).padding(.horizontal, 20)
                    }
                }
            }
            .padding(.bottom, 8)

            // Pro upsell banner when at free limit
            if atFreeLimit {
                Divider().overlay(AppTheme.border)
                HStack(spacing: 8) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    Text("Upgrade to Pro for unlimited server profiles")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.mutedText)
                    Spacer()
                    Button("Upgrade") { showUpgrade = true }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.accentBlue)
                        .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
        }
        .glassCard(cornerRadius: 20)
    }
}

// MARK: - Profile Row
struct ProfileRow: View {
    @EnvironmentObject var appState: AppState
    let profile: ServerProfile
    @State private var isHovering    = false
    @State private var confirmDelete = false
    @State private var showEdit      = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.accentBlue.opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: "server.rack")
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.accentBlue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(profile.url)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.mutedText)
            }

            Spacer()

            if isHovering {
                HStack(spacing: 8) {
                    // Edit button
                    Button { showEdit = true } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.accentBlue)
                            .padding(6)
                            .background(AppTheme.accentBlue.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)

                    // Delete button
                    Button { confirmDelete = true } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.dangerRed)
                            .padding(6)
                            .background(AppTheme.dangerRed.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)

                    ConnectButton(profile: profile)
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(isHovering ? Color.white.opacity(0.04) : Color.clear)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
        .alert("Delete \(profile.name)?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { appState.deleteProfile(profile) }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showEdit) {
            EditProfileSheet(profile: profile).environmentObject(appState)
        }
    }
}

// MARK: - Connect Button
struct ConnectButton: View {
    @EnvironmentObject var appState: AppState
    let profile: ServerProfile
    @State private var isHovering = false

    var body: some View {
        Button {
            Task { await appState.connect(profile: profile) }
        } label: {
            Text("Connect")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(colors: [AppTheme.accentBlue, AppTheme.accentPurple],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(Capsule())
                .neonGlow(color: AppTheme.accentBlue, radius: isHovering ? 10 : 0)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.05 : 1.0)
        .animation(.spring(duration: 0.2), value: isHovering)
        .onHover { isHovering = $0 }
        .disabled(appState.isLoading)
    }
}

// MARK: - Add Server Button
struct AddServerButton: View {
    @Binding var showAdd: Bool
    @Binding var showUpgrade: Bool
    var atLimit: Bool = false

    var body: some View {
        Button {
            if atLimit { showUpgrade = true } else { showAdd = true }
        } label: {
            HStack(spacing: 6) {
                if atLimit {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                } else {
                    Image(systemName: "plus.circle.fill")
                }
                Text(atLimit ? "Go Pro" : "Add Server")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(atLimit ? AppTheme.accentBlue : AppTheme.accentBlue)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pro Badge
struct ProBadge: View {
    var body: some View {
        Text("FREE")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(AppTheme.accentBlue)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(AppTheme.accentBlue.opacity(0.15), in: Capsule())
            .overlay(Capsule().stroke(AppTheme.accentBlue.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Add Profile Sheet
struct AddProfileSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var name         = ""
    @State private var url          = ""
    @State private var clientID     = ""
    @State private var clientSecret = ""

    var canSave: Bool { !name.isEmpty && !url.isEmpty && !clientID.isEmpty && !clientSecret.isEmpty }

    var body: some View {
        ServerFormSheet(
            title: "Add Jamf Server",
            saveLabel: "Save Server",
            name: $name,
            url: $url,
            clientID: $clientID,
            clientSecret: $clientSecret,
            canSave: canSave
        ) {
            let profile = ServerProfile(name: name,
                                        url: url.trimmingCharacters(in: .whitespacesAndNewlines)
                                               .trimmingCharacters(in: CharacterSet(charactersIn: "/")),
                                        clientID: clientID.trimmingCharacters(in: .whitespacesAndNewlines))
            appState.addProfile(profile, secret: clientSecret.trimmingCharacters(in: .whitespacesAndNewlines))
            dismiss()
        } onCancel: {
            dismiss()
        }
    }
}

// MARK: - Edit Profile Sheet
struct EditProfileSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let profile: ServerProfile

    @State private var name: String
    @State private var url: String
    @State private var clientID: String
    @State private var clientSecret: String

    init(profile: ServerProfile) {
        self.profile = profile
        _name         = State(initialValue: profile.name)
        _url          = State(initialValue: profile.url)
        _clientID     = State(initialValue: profile.clientID)
        _clientSecret = State(initialValue: KeychainService.shared.load(for: profile.id.uuidString) ?? "")
    }

    var canSave: Bool { !name.isEmpty && !url.isEmpty && !clientID.isEmpty && !clientSecret.isEmpty }

    var body: some View {
        ServerFormSheet(
            title: "Edit Server",
            saveLabel: "Update Server",
            name: $name,
            url: $url,
            clientID: $clientID,
            clientSecret: $clientSecret,
            canSave: canSave
        ) {
            let updated = ServerProfile(id: profile.id,
                                        name: name,
                                        url: url.trimmingCharacters(in: .whitespacesAndNewlines)
                                               .trimmingCharacters(in: CharacterSet(charactersIn: "/")),
                                        clientID: clientID.trimmingCharacters(in: .whitespacesAndNewlines))
            appState.updateProfile(updated, secret: clientSecret.trimmingCharacters(in: .whitespacesAndNewlines))
            dismiss()
        } onCancel: {
            dismiss()
        }
    }
}

// MARK: - Shared Form Sheet
struct ServerFormSheet: View {
    let title: String
    let saveLabel: String
    @Binding var name: String
    @Binding var url: String
    @Binding var clientID: String
    @Binding var clientSecret: String
    let canSave: Bool
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button { onCancel() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.mutedText)
                }
                .buttonStyle(.plain)
            }
            .padding(24)

            Divider().overlay(AppTheme.border)

            VStack(spacing: 16) {
                SheetField(label: "Friendly Name", placeholder: "Production Jamf", text: $name)
                SheetField(label: "Jamf URL", placeholder: "https://yourcompany.jamfcloud.com", text: $url)
                SheetField(label: "Client ID", placeholder: "API Client ID", text: $clientID, stripWhitespace: true)
                SheetField(label: "Client Secret", placeholder: "••••••••••••", text: $clientSecret, secure: true, stripWhitespace: true)

                Text("Create a read-only API client in Jamf Pro → Settings → API Roles & Clients with: Read Computer Extension Attributes, Read Smart Computer Groups, Read Advanced Computer Searches.")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.mutedText)
                    .multilineTextAlignment(.leading)
                    .padding(12)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(24)

            Divider().overlay(AppTheme.border)

            HStack(spacing: 12) {
                Spacer()
                Button("Cancel") { onCancel() }
                    .buttonStyle(.plain)
                    .foregroundColor(AppTheme.mutedText)

                Button(saveLabel) { onSave() }
                    .disabled(!canSave)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(canSave ? AppTheme.accentBlue : AppTheme.surface,
                                in: RoundedRectangle(cornerRadius: 10))
                    .animation(.easeInOut(duration: 0.2), value: canSave)
            }
            .padding(24)
        }
        .background(AppTheme.background)
        .frame(width: 480)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Sheet Field
struct SheetField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var secure = false
    var stripWhitespace = false

    @State private var revealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppTheme.mutedText)
                .textCase(.uppercase)

            HStack(spacing: 0) {
                Group {
                    if secure && !revealed {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .onChange(of: text) {
                    if stripWhitespace {
                        let filtered = text.filter { !$0.isWhitespace && !$0.isNewline }
                        if filtered != text { text = filtered }
                    }
                }

                if secure {
                    Button {
                        revealed.toggle()
                    } label: {
                        Image(systemName: revealed ? "eye.slash" : "eye")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.mutedText)
                            .padding(.horizontal, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
        }
    }
}

// MARK: - Motivational Message View
struct MotivationalMessageView: View {
    @State private var index = Int.random(in: 0..<messages.count)
    @State private var opacity: Double = 1
    let timer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    static let messages = [
        "Herding Macs… this may take a moment.",
        "Politely interrogating your Extension Attributes.",
        "Smart Groups are judging your EA naming conventions.",
        "99 EAs and an orphan is one.",
        "Separating the useful from the digital clutter.",
        "Your Jamf instance has character. A lot of it.",
        "Asking each EA what it has been up to lately.",
        "Why delete manually when you can automate regret?",
        "grep -r 'why' /JSSResource/ … no results found.",
        "The dependency graph does not lie. Usually.",
        "Running diagnostic on orphaned EAs. They're fine.",
        "Checking which EAs ghosted their Smart Groups.",
        "Patience is a virtue. So is a clean Jamf instance.",
        "Some EAs were created in 2016 and never spoke again.",
        "This is fine. Everything is fine. The scan is fine.",
        "Counting beans. IT beans.",
        "EA stands for Extension Attribute, not Electronic Arts.",
        "Advanced Searches: making simple things complicated since 2010.",
        "Your future self will thank you for this cleanup.",
        "Jamf admins don't sleep. They scan.",
    ]

    var body: some View {
        Text(Self.messages[index])
            .font(.system(size: 11))
            .foregroundColor(AppTheme.mutedText.opacity(0.7))
            .multilineTextAlignment(.center)
            .opacity(opacity)
            .padding(.horizontal, 20)
            .onReceive(timer) { _ in
                withAnimation(.easeOut(duration: 0.4)) { opacity = 0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    index = (index + 1) % Self.messages.count
                    withAnimation(.easeIn(duration: 0.4)) { opacity = 1 }
                }
            }
    }
}
