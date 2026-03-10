import SwiftUI
import AtelierDesign
import AtelierKit

struct ConversationWindow: View {
    @State private var controller: ConversationController
    @State private var draft = ""
    @State private var pendingAttachments: [FileAttachment] = []
    @State private var isDropTargeted = false
    @State private var showInspector = false
    @State private var inspectorTab: InspectorTab = .capabilities
    @State private var showComposeField = false
    @State private var showSessionMenu = false

    let projectName: String
    let scheduleStore: ScheduleStore

    init(
        projectName: String,
        capabilityStore: CapabilityStore,
        sessionPersistence: SessionPersistence,
        workingDirectory: URL?,
        scheduleStore: ScheduleStore
    ) {
        self.projectName = projectName
        self._controller = State(initialValue: ConversationController(
            capabilityStore: capabilityStore,
            sessionPersistence: sessionPersistence,
            workingDirectory: workingDirectory
        ))
        self.scheduleStore = scheduleStore
    }

    var body: some View {
        NavigationStack {
            TimelineView(session: controller.session, capabilityStore: controller.capabilityStore, draft: $draft, selectedToolID: controller.selectedToolEvent?.id, onSelectTool: { event in
                    if controller.selectedToolEvent?.id == event.id {
                        controller.selectedToolEvent = nil
                    } else {
                        controller.selectedToolEvent = event
                        inspectorTab = .detail
                        showInspector = true
                    }
                }, onApprovalDecision: { id, toolName, decision in
                    controller.handleApprovalDecision(id: id, toolName: toolName, decision: decision)
                }, onAskUserResponse: { id, selectedIndex, customText in
                    controller.handleAskUserResponse(id: id, selectedIndex: selectedIndex, customText: customText)
                }, onPlanApprove: {
                    controller.handlePlanApprove()
                }, onEnableCapability: { id in
                    controller.enableCapability(id)
                })
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(.bar)
                        .frame(height: Spacing.xxl)
                        .mask {
                            LinearGradient(
                                stops: [
                                    .init(color: .black, location: 0),
                                    .init(color: .black, location: 0.5),
                                    .init(color: .clear, location: 1),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                        .ignoresSafeArea(edges: .top)
                        .allowsHitTesting(false)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    TaskListOverlay(session: controller.session)
                        .padding(.bottom, Spacing.xs)
                }
                // WORKAROUND: NavigationStack (required for .inspector() to compress
                // content in-place) animates safeAreaInset content on first layout.
                // Keeping ComposeField always in the layout (stable safe area from
                // frame 1) and fading opacity avoids the position animation. Revisit.
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    VStack(spacing: Spacing.xs) {
                        if !pendingAttachments.isEmpty {
                            ComposeAttachmentStrip(attachments: $pendingAttachments)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        ComposeField(
                            text: $draft,
                            isStreaming: controller.session.isStreaming,
                            onSubmit: { sendMessage() },
                            onStop: { controller.stopGeneration() }
                        )
                    }
                    .disabled(!controller.cliAvailable)
                    .frame(maxWidth: Layout.readingWidth)
                    .padding(Spacing.md)
                    .background {
                        // Fade gradient behind (not on top of) compose field so
                        // text and button render at full brightness.
                        Rectangle()
                            .fill(.bar)
                            .mask {
                                LinearGradient(
                                    colors: [.clear, .black],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            }
                            .ignoresSafeArea(edges: .bottom)
                    }
                    .animation(Motion.morph, value: pendingAttachments.isEmpty)
                    .opacity(showComposeField ? 1 : 0)
                    .animation(Motion.appear, value: showComposeField)
                }
            // WORKAROUND: SwiftUI .inspector() on macOS expands the window instead of
            // compressing content in-place (unlike AppKit NSSplitViewController which
            // uses holdingPriority). Wrapping in NavigationStack prevents the window
            // from growing. File FB to Apple.
            .inspector(isPresented: $showInspector) {
                InspectorPanel(
                    selectedTab: $inspectorTab,
                    capabilityStore: controller.capabilityStore,
                    scheduleStore: scheduleStore,
                    projectPath: controller.workingDirectory?.path,
                    selectedTool: controller.selectedToolEvent
                )
                .inspectorColumnWidth(min: 260, ideal: 320, max: 480)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            let valid = DropPathValidator.validated(urls, workingDirectory: controller.workingDirectory)
            let remaining = FileAttachment.maxAttachments - pendingAttachments.count
            let attachments = valid.prefix(remaining).map { FileAttachment(url: $0) }
            guard !attachments.isEmpty else { return }
            withAnimation(Motion.morph) {
                pendingAttachments.append(contentsOf: attachments)
            }
        }
        .dropConfiguration { _ in
            DropConfiguration(operation: .copy)
        }
        .onDropSessionUpdated { session in
            switch session.phase {
            case .entering, .active:
                isDropTargeted = true
            default:
                isDropTargeted = false
            }
        }
        .dropPreviewsFormation(.pile)
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: Radii.lg, style: .continuous)
                    .strokeBorder(.contentAccent.opacity(0.4), lineWidth: 2)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(Motion.settle, value: isDropTargeted)
        .frame(minWidth: Layout.minimumWindowWidth, minHeight: Layout.minimumWindowHeight)
        .navigationTitle("")
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .toolbar {
            SessionMenuToolbarItem(
                projectName: projectName,
                showMenu: $showSessionMenu,
                sessions: controller.sessionList,
                currentSessionId: controller.session.sessionId,
                onSelect: { controller.switchToSession(id: $0) },
                onNewConversation: { controller.startNewConversation() }
            )

            ConversationToolbar(
                showInspector: $showInspector,
                inspectorTab: $inspectorTab
            )
        }
        .onKeyPress(.escape) {
            guard controller.session.isStreaming else { return .ignored }
            controller.stopGeneration()
            return .handled
        }
        .task {
            await controller.start()

            // WORKAROUND continued: NavigationStack animates safeAreaInset content
            // on first layout. Wait for that to settle, then reveal ComposeField.
            // The scoped .animation(_:value:) on ComposeField handles the fade —
            // no withAnimation here to avoid giving NavigationStack an animation
            // context it can hijack for position changes.
            try? await Task.sleep(for: .milliseconds(160))
            showComposeField = true
        }
        .onChange(of: controller.selectedToolEvent?.id) { _, newID in
            controller.loadToolPayloadIfNeeded(for: newID)
        }
        .focusedSceneValue(\.inspectorVisibility, $showInspector)
        .onAppear {
            controller.checkAvailability()
        }
        .onDisappear {
            controller.shutdown()
        }
    }

    private func sendMessage() {
        let text = draft
        let attachments = pendingAttachments
        draft = ""
        pendingAttachments = []
        controller.sendMessage(text, attachments: attachments)
    }
}
