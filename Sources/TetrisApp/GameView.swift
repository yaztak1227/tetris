import SpriteKit
import SwiftUI
import TetrisCore

struct GameView: View {
    private enum Screen {
        case home
        case settings
        case game
    }

    @State private var viewModel = GameViewModel()
    @State private var screen: Screen = .home
    @State private var settingsReturnScreen: Screen = .home
    @State private var bindingAction: GameInputAction?
    @State private var language: AppLanguage
    @State private var localizer: AppLocalizer
    @State private var scene = TetrisScene(size: CGSize(width: 360, height: 720))
    @AppStorage("app.language") private var storedLanguageCode = AppLanguage.preferred.rawValue

    init() {
        let initialLanguage = AppLanguage.resolved(
            storedCode: UserDefaults.standard.string(forKey: "app.language")
        )
        _language = State(initialValue: initialLanguage)
        _localizer = State(initialValue: AppLocalizer.loadOrFallback(language: initialLanguage))
    }

    var body: some View {
        ZStack {
            TOPBackground()

            currentScreen

            if screen == .game, viewModel.isPaused {
                pauseOverlay
            }

            KeyboardCaptureView { input in
                handle(input)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            restoreStoredLanguage()
            scene.scaleMode = .resizeFill
            viewModel.startLoop()
        }
        .onChange(of: viewModel.state.score) { _, _ in renderScene() }
        .onChange(of: viewModel.state.activePiece?.origin) { _, _ in renderScene() }
        .onChange(of: viewModel.state.lastAction) { _, _ in renderScene() }
        .onChange(of: viewModel.elapsedMilliseconds) { _, _ in renderScene() }
        .task {
            renderScene()
        }
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch screen {
        case .home:
            homeScreen
        case .settings:
            dedicatedSettingsScreen
        case .game:
            gameScreen
        }
    }

    private var homeScreen: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)

            Text(t("app/title"))
                .font(.system(size: 64, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.red, .orange, .yellow, .cyan, .purple], startPoint: .leading, endPoint: .trailing)
                )

            Text(t("home/mode/marathon"))
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 7)
                .background(LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.65), lineWidth: 2))

            VStack(spacing: 10) {
                Button(t("home/buttons/start")) {
                    beginGame()
                }
                .buttonStyle(TOPButtonStyle(tint: .green))
                .frame(width: 260)

                Button(t("home/buttons/settings")) {
                    openSettings(returningTo: .home)
                }
                .buttonStyle(TOPButtonStyle(tint: .cyan))
                .frame(width: 220)
            }

            HStack(spacing: 10) {
                HeaderMeter(title: t("home/meters/time"), value: "00:00")
                HeaderMeter(title: t("home/meters/status"), value: t("common/status/standby"), tint: .orange)
                HeaderMeter(title: t("home/meters/start"), value: viewModel.settings.displayBinding(for: .start, localizer: localizer), tint: .green)
            }

            Text(t("home/message/noPiecesUntilStart"))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.black.opacity(0.62))

            Spacer(minLength: 0)
        }
        .padding(22)
    }

    private var gameScreen: some View {
        VStack(spacing: 10) {
            header

            HStack(alignment: .center, spacing: 14) {
                nextRail
                playfieldStack
                rightDashboard
            }

            eventBar
        }
        .padding(18)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(modeTitle)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 7)
                .background(LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.65), lineWidth: 2))

            Spacer()

            HeaderMeter(title: t("home/meters/time"), value: timeText)
            HeaderMeter(title: t("home/meters/status"), value: statusText, tint: statusColor)
        }
    }

    private var nextRail: some View {
        VStack(spacing: 10) {
            TOPBadge(text: t("game/labels/next"))
            ForEach(Array(viewModel.state.nextQueue.preview.enumerated()), id: \.offset) { index, type in
                PiecePod(type: type, isDimmed: false)
                    .frame(width: index == 0 ? 112 : 96, height: index == 0 ? 76 : 66)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(width: 138, height: 604)
        .background(TOPPanelBackground())
    }

    private var playfieldStack: some View {
        VStack(spacing: 0) {
            Text(t("game/labels/player"))
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 5)
                .background(Color(red: 0.98, green: 0.68, blue: 0.10))
                .clipShape(Capsule())
                .offset(y: 12)
                .zIndex(1)

            SpriteView(scene: scene, options: [.allowsTransparency])
                .onAppear {
                    renderScene()
                }
                .frame(width: 300, height: 600)
                .background(Color(red: 0.035, green: 0.04, blue: 0.055))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(8)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(red: 0.93, green: 0.20, blue: 0.22), lineWidth: 3)
                )
                .shadow(color: .black.opacity(0.24), radius: 14, x: 0, y: 8)
        }
        .frame(width: 332, height: 626)
    }

    private var rightDashboard: some View {
        VStack(spacing: 12) {
            TOPBadge(text: t("game/labels/myInfo"))

            ScorePlate(
                title: t("game/labels/score"),
                score: viewModel.state.score,
                scoreDelta: viewModel.recentScoreDelta
            )

            VStack(spacing: 8) {
                TOPBadge(text: t("game/labels/hold"))
                PiecePod(type: viewModel.state.holdPiece, isDimmed: viewModel.state.holdUsed)
                    .frame(width: 118, height: 82)
            }
            .padding(10)
            .background(TOPInsetPanel())

            HStack(spacing: 8) {
                StatChip(title: t("game/stats/level"), value: "\(viewModel.state.level)", tint: .yellow)
                StatChip(title: t("game/stats/lines"), value: "\(viewModel.state.totalClearedLines)", tint: .cyan)
            }

            HStack(spacing: 8) {
                StatChip(title: t("game/stats/ren"), value: viewModel.state.combo > 0 ? "\(viewModel.state.combo)" : "-", tint: .green)
                StatChip(title: t("game/stats/b2b"), value: viewModel.state.backToBack ? t("game/stats/on") : "-", tint: .purple)
            }

            if !viewModel.isPaused {
                actionButtons
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 238, height: 604)
        .background(TOPPanelBackground())
    }

    private var dedicatedSettingsScreen: some View {
        VStack(spacing: 16) {
            HStack {
                Button(t("settings/buttons/back")) {
                    closeSettings()
                }
                .buttonStyle(TOPButtonStyle(tint: .orange))
                .frame(width: 136)

                Spacer()

                Text(t("settings/title"))
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.65), lineWidth: 2))

                Spacer()

                HeaderMeter(title: t("settings/meters/return"), value: settingsReturnTitle, tint: .cyan)
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    TOPBadge(text: t("settings/sections/language"))

                    HStack(spacing: 8) {
                        ForEach(AppLanguage.allCases) { language in
                            Button(localizer.languageName(language)) {
                                changeLanguage(to: language)
                            }
                            .buttonStyle(TOPButtonStyle(tint: self.language == language ? .green : .cyan))
                            .frame(maxWidth: .infinity)
                        }
                    }

                    Divider().overlay(.black.opacity(0.20))

                    TOPBadge(text: t("settings/sections/tuning"))

                    settingSlider(
                        title: t("settings/tuning/moveHold"),
                        value: holdMoveMultiplierBinding,
                        range: 1.0...2.0,
                        step: 0.1
                    )

                    settingSlider(
                        title: t("settings/tuning/horizontalDelay"),
                        value: horizontalAutoShiftDelayBinding,
                        range: 30...500,
                        step: 10,
                        format: "%.0fms"
                    )

                    settingSlider(
                        title: t("settings/tuning/horizontalInterval"),
                        value: horizontalAutoRepeatIntervalBinding,
                        range: 10...120,
                        format: "%.0fms"
                    )

                    settingSlider(
                        title: t("settings/tuning/gravity"),
                        value: gravityMultiplierBinding,
                        range: 1.0...2.0,
                        step: 0.1
                    )

                    Text(t("settings/help/changesApplyImmediately"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black.opacity(0.58))
                }
                .padding(16)
                .frame(width: 300, alignment: .topLeading)
                .background(TOPPanelBackground())

                VStack(alignment: .leading, spacing: 10) {
                    TOPBadge(text: t("settings/sections/keyConfig"))

                    LazyVGrid(columns: [GridItem(.fixed(178)), GridItem(.fixed(118))], alignment: .leading, spacing: 8) {
                        ForEach(GameInputAction.allCases) { action in
                            Text(action.title(localizer: localizer))
                                .font(.system(size: 12, weight: .black))
                                .foregroundStyle(.black.opacity(0.70))
                                .lineLimit(1)

                            Button(bindingAction == action ? t("common/keyCapture/press") : viewModel.settings.displayBinding(for: action, localizer: localizer)) {
                                bindingAction = action
                            }
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .buttonStyle(TOPButtonStyle(tint: bindingAction == action ? .yellow : .cyan))
                            .frame(width: 118)
                        }
                    }
                }
                .padding(16)
                .frame(width: 360, alignment: .topLeading)
                .background(TOPPanelBackground())
            }
        }
        .padding(22)
    }

    private var actionButtons: some View {
        VStack(spacing: 8) {
            if viewModel.isStarted {
                Button(t("game/buttons/pause")) {
                    viewModel.togglePause()
                }
                .buttonStyle(TOPButtonStyle(tint: .cyan))
                .frame(maxWidth: .infinity)
            } else {
                Button(t("home/buttons/start")) {
                    viewModel.start()
                    renderScene()
                }
                .buttonStyle(TOPButtonStyle(tint: .green))
                .frame(maxWidth: .infinity)
            }

            Button(t("game/buttons/restart")) {
                viewModel.restart()
                renderScene()
            }
            .buttonStyle(TOPButtonStyle(tint: .orange))
            .frame(maxWidth: .infinity)
            .keyboardShortcut("r", modifiers: [])
        }
    }

    private var eventBar: some View {
        Text(eventText)
            .font(.system(size: 23, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .monospacedDigit()
            .frame(height: 38)
            .frame(maxWidth: 720)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.16, blue: 0.28),
                        Color(red: 0.20, green: 0.26, blue: 0.42)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.36), lineWidth: 1))
    }

    private var pauseOverlay: some View {
        VStack(spacing: 14) {
            Text(t("pause/title"))
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Button(t("pause/buttons/resume")) {
                viewModel.resume()
            }
            .keyboardShortcut(.escape, modifiers: [])
            .buttonStyle(TOPButtonStyle(tint: .green))
            .frame(width: 180)

            Button(t("pause/buttons/restart")) {
                viewModel.restart()
                screen = .home
                renderScene()
            }
            .buttonStyle(TOPButtonStyle(tint: .orange))
            .frame(width: 180)

            Button(t("pause/buttons/settings")) {
                openSettings(returningTo: .game)
            }
            .buttonStyle(TOPButtonStyle(tint: .cyan))
            .frame(width: 180)
        }
        .frame(width: 300, height: 250)
        .background(Color.black.opacity(0.74))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.26), lineWidth: 1))
    }

    private var modeTitle: String {
        switch viewModel.state.mode {
        case .marathon:
            return t("home/mode/marathon")
        case .fortyLines:
            return "40 LINES"
        case .practice:
            return "PRACTICE"
        }
    }

    private var timeText: String {
        let totalSeconds = viewModel.elapsedMilliseconds / 1_000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var statusText: String {
        if viewModel.isPaused {
            return t("common/status/pause")
        }

        switch viewModel.state.status {
        case .ready:
            return t("common/status/ready")
        case .playing:
            return viewModel.isStarted ? t("common/status/play") : t("common/status/standby")
        case .paused:
            return t("common/status/pause")
        case .gameOver:
            return t("common/status/gameOver")
        case .completed:
            return t("common/status/complete")
        }
    }

    private var statusColor: Color {
        if viewModel.isPaused {
            return .yellow
        }

        switch viewModel.state.status {
        case .playing:
            return viewModel.isStarted ? .green : .orange
        case .gameOver:
            return .red
        case .completed:
            return .cyan
        case .ready, .paused:
            return .yellow
        }
    }

    private var settingsReturnTitle: String {
        switch settingsReturnScreen {
        case .home:
            return t("common/status/home")
        case .game:
            return t("common/status/pause")
        case .settings:
            return t("common/status/settings")
        }
    }

    private var eventText: String {
        switch viewModel.eventMessage {
        case "READY":
            return t("game/events/ready")
        case "GO":
            return t("game/events/go")
        case "PAUSED":
            return t("game/events/paused")
        case "RESUME":
            return t("game/events/resume")
        case "LOCK":
            return t("game/events/lock")
        case "LOCK ERROR":
            return t("game/events/lockError")
        case "GAME ERROR":
            return t("game/events/gameError")
        default:
            return viewModel.eventMessage
        }
    }

    private func settingSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 1,
        format: String = "%.1fx"
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.black.opacity(0.68))
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.74))
            }
            Slider(value: value, in: range, step: step)
        }
    }

    private var holdMoveMultiplierBinding: Binding<Double> {
        Binding(
            get: { viewModel.settings.holdMoveMultiplier },
            set: { newValue in
                viewModel.setHoldMoveMultiplier(newValue)
            }
        )
    }

    private var horizontalAutoShiftDelayBinding: Binding<Double> {
        Binding(
            get: { viewModel.settings.horizontalAutoShiftDelayMilliseconds },
            set: { newValue in
                viewModel.setHorizontalAutoShiftDelayMilliseconds(newValue)
            }
        )
    }

    private var horizontalAutoRepeatIntervalBinding: Binding<Double> {
        Binding(
            get: { viewModel.settings.horizontalAutoRepeatIntervalMilliseconds },
            set: { newValue in
                viewModel.setHorizontalAutoRepeatIntervalMilliseconds(newValue)
            }
        )
    }

    private var gravityMultiplierBinding: Binding<Double> {
        Binding(
            get: { viewModel.settings.gravityMultiplier },
            set: { newValue in
                viewModel.setGravityMultiplier(newValue)
            }
        )
    }

    private func handle(_ input: KeyInput) {
        if let bindingAction {
            viewModel.bind(input.key, to: bindingAction)
            self.bindingAction = nil
            return
        }

        guard let action = viewModel.settings.action(for: input.key) else {
            return
        }

        if input.phase == .up {
            switch action {
            case .moveLeft:
                viewModel.releaseHorizontalInput(.left)
            case .moveRight:
                viewModel.releaseHorizontalInput(.right)
            default:
                break
            }
            renderScene()
            return
        }

        switch action {
        case .moveLeft:
            viewModel.pressHorizontalInput(.left)
        case .moveRight:
            viewModel.pressHorizontalInput(.right)
        case .softDrop:
            viewModel.softDrop()
        case .hardDrop:
            viewModel.hardDrop()
        case .rotateClockwise:
            viewModel.rotateClockwise()
        case .rotateCounterClockwise:
            viewModel.rotateCounterClockwise()
        case .hold:
            viewModel.hold()
        case .restart:
            viewModel.restart()
            screen = .home
        case .start:
            if screen == .home {
                beginGame()
            }
        case .pause:
            if screen == .game {
                viewModel.togglePause()
            } else if screen == .settings {
                closeSettings()
            }
        }

        renderScene()
    }

    private func beginGame() {
        viewModel.start()
        screen = .game
        renderScene()
    }

    private func openSettings(returningTo returnScreen: Screen) {
        settingsReturnScreen = returnScreen
        if returnScreen == .game, viewModel.isStarted, !viewModel.isPaused {
            viewModel.togglePause()
        }
        screen = .settings
    }

    private func closeSettings() {
        screen = settingsReturnScreen
        bindingAction = nil
        renderScene()
    }

    private func restoreStoredLanguage() {
        guard let storedLanguage = AppLanguage(rawValue: storedLanguageCode) else {
            return
        }
        changeLanguage(to: storedLanguage)
    }

    private func changeLanguage(to newLanguage: AppLanguage) {
        language = newLanguage
        localizer = AppLocalizer.loadOrFallback(language: newLanguage)
        storedLanguageCode = newLanguage.rawValue
    }

    private func t(_ key: String) -> String {
        localizer.text(key)
    }

    private func renderScene() {
        scene.render(state: viewModel.state, showsGhost: viewModel.isStarted && !viewModel.isPaused)
    }
}

private struct TOPBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.98, blue: 1.0),
                    Color(red: 0.83, green: 0.92, blue: 0.98),
                    Color(red: 0.98, green: 0.94, blue: 0.86)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Canvas { context, size in
                let colors: [Color] = [.red, .orange, .yellow, .green, .cyan, .purple]
                for index in 0..<90 {
                    let x = CGFloat((index * 73) % Int(max(size.width, 1)))
                    let y = CGFloat((index * 41) % Int(max(size.height, 1)))
                    let rect = CGRect(x: x, y: y, width: 8, height: 8)
                    context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(colors[index % colors.count].opacity(0.10)))
                }
            }
            .ignoresSafeArea()
        }
    }
}

private struct TOPPanelBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: [.white, Color(red: 0.88, green: 0.96, blue: 1.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white, lineWidth: 2))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(red: 0.28, green: 0.58, blue: 0.78).opacity(0.52), lineWidth: 1))
            .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
    }
}

private struct TOPInsetPanel: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(red: 0.93, green: 0.98, blue: 1.0))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.12), lineWidth: 1))
    }
}

private struct TOPBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.7), lineWidth: 1))
    }
}

private struct HeaderMeter: View {
    let title: String
    let value: String
    var tint: Color = .cyan

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(.white.opacity(0.72))
            Text(value)
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color(red: 0.10, green: 0.16, blue: 0.27))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.28), lineWidth: 1))
    }
}

private struct ScorePlate: View {
    let title: String
    let score: Int
    let scoreDelta: Int?

    var body: some View {
        VStack(spacing: 5) {
            TOPBadge(text: title)
            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)

                Text(scoreDelta.map { "+\($0)" } ?? " ")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.34, green: 0.95, blue: 0.48))
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .padding(.vertical, 7)
            .background(Color(red: 0.16, green: 0.18, blue: 0.24))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(red: 1.0, green: 0.74, blue: 0.20), lineWidth: 2))
        }
        .padding(10)
        .background(TOPInsetPanel())
    }
}

private struct StatChip: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(.black.opacity(0.52))
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(width: 96, height: 54)
        .background(tint)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.72), lineWidth: 1))
    }
}

private struct PiecePod: View {
    let type: PieceType?
    let isDimmed: Bool

    var body: some View {
        PieceMiniView(type: type)
            .opacity(isDimmed ? 0.34 : 1.0)
            .padding(6)
            .background(Color(red: 0.09, green: 0.12, blue: 0.15))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.42), lineWidth: 1))
    }
}

private struct TOPButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(tint.opacity(configuration.isPressed ? 0.72 : 1.0))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.7), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
    }
}

private struct ClearEffectToastView: View {
    let effect: ClearEffectToast

    var body: some View {
        VStack(spacing: 4) {
            Text(effect.title)
                .font(.system(size: 32, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            if !effect.subtitle.isEmpty {
                Text(effect.subtitle)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .padding(.vertical, 13)
        .frame(minWidth: 220)
        .background(effectColor.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.28), lineWidth: 1))
        .shadow(color: effectColor.opacity(0.45), radius: 18, x: 0, y: 0)
        .offset(y: -56)
    }

    private var effectColor: Color {
        switch effect.kind {
        case .normal:
            return Color(red: 0.20, green: 0.42, blue: 0.76)
        case .tetris:
            return Color(red: 0.08, green: 0.62, blue: 0.72)
        case .tSpin:
            return Color(red: 0.58, green: 0.26, blue: 0.86)
        }
    }
}

private struct PieceMiniView: View {
    let type: PieceType?

    var body: some View {
        Canvas { context, size in
            guard let type else {
                let rect = CGRect(origin: .zero, size: size)
                context.stroke(Path(roundedRect: rect, cornerRadius: 4), with: .color(.white.opacity(0.22)), lineWidth: 1)
                return
            }

            let cells = miniCells(for: type)
            let block = min(size.width / 4.6, size.height / 3.6)
            let offsetX = (size.width - 4 * block) / 2
            let offsetY = (size.height - 3 * block) / 2
            for cell in cells {
                let rect = CGRect(
                    x: offsetX + CGFloat(cell.x) * block,
                    y: offsetY + CGFloat(2 - cell.y) * block,
                    width: block - 2,
                    height: block - 2
                )
                context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(pieceColor(type)))
                context.stroke(Path(roundedRect: rect, cornerRadius: 2), with: .color(.white.opacity(0.32)), lineWidth: 1)
            }
        }
    }

    private func miniCells(for type: PieceType) -> [Cell] {
        switch type {
        case .i:
            return [Cell(x: 0, y: 1), Cell(x: 1, y: 1), Cell(x: 2, y: 1), Cell(x: 3, y: 1)]
        case .o:
            return [Cell(x: 1, y: 1), Cell(x: 2, y: 1), Cell(x: 1, y: 2), Cell(x: 2, y: 2)]
        case .t:
            return [Cell(x: 0, y: 1), Cell(x: 1, y: 1), Cell(x: 2, y: 1), Cell(x: 1, y: 2)]
        case .s:
            return [Cell(x: 1, y: 1), Cell(x: 2, y: 1), Cell(x: 0, y: 2), Cell(x: 1, y: 2)]
        case .z:
            return [Cell(x: 0, y: 1), Cell(x: 1, y: 1), Cell(x: 1, y: 2), Cell(x: 2, y: 2)]
        case .j:
            return [Cell(x: 0, y: 1), Cell(x: 1, y: 1), Cell(x: 2, y: 1), Cell(x: 0, y: 2)]
        case .l:
            return [Cell(x: 0, y: 1), Cell(x: 1, y: 1), Cell(x: 2, y: 1), Cell(x: 2, y: 2)]
        }
    }
}

private func pieceColor(_ type: PieceType) -> Color {
    switch type {
    case .i:
        return Color(red: 0.15, green: 0.82, blue: 0.94)
    case .o:
        return Color(red: 0.96, green: 0.82, blue: 0.18)
    case .t:
        return Color(red: 0.66, green: 0.38, blue: 0.92)
    case .s:
        return Color(red: 0.28, green: 0.82, blue: 0.38)
    case .z:
        return Color(red: 0.92, green: 0.24, blue: 0.28)
    case .j:
        return Color(red: 0.22, green: 0.42, blue: 0.94)
    case .l:
        return Color(red: 0.95, green: 0.55, blue: 0.20)
    }
}
