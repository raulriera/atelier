import SwiftUI
import UniformTypeIdentifiers
import AtelierDesign
import AtelierKit

struct ConversationWindow: View {
    @State private var controller: ConversationController
    @State private var draft = ""
    @State private var pendingAttachments: [FileAttachment] = []
    @State private var isDropTargeted = false
    @State private var showInspector = false
    @State private var inspectorTab: InspectorTab = .capabilities
    @State private var showSessionMenu = false
    @State private var didInjectCompletions = false
    @State private var showAttachmentPicker = false
    /// Stable identity cache — closures are set once in `onAppear` and never reassigned.
    /// Plain class (not `@Observable`) because child views only call closures, never read state.
    @State private var actions = TimelineActions()

    let projectName: String
    let projectId: UUID
    let scheduleStore: ScheduleStore

    init(
        projectName: String,
        projectId: UUID,
        capabilityStore: CapabilityStore,
        sessionPersistence: SessionPersistence,
        workingDirectory: URL?,
        scheduleStore: ScheduleStore
    ) {
        self.projectName = projectName
        self.projectId = projectId
        self._controller = State(initialValue: ConversationController(
            capabilityStore: capabilityStore,
            sessionPersistence: sessionPersistence,
            workingDirectory: workingDirectory
        ))
        self.scheduleStore = scheduleStore
    }

    var body: some View {
        NavigationStack {
            TimelineView(session: controller.session, capabilityStore: controller.capabilityStore, isLoaded: controller.isLoaded, draft: $draft, selectedToolID: controller.selectedToolEvent?.id)
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
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    ComposeBar(
                        draft: $draft,
                        pendingAttachments: $pendingAttachments,
                        showAttachmentPicker: $showAttachmentPicker,
                        selectedModel: $controller.selectedModel,
                        isStreaming: controller.session.isStreaming,
                        cliAvailable: controller.cliAvailable,
                        onSubmit: { sendMessage() },
                        onStop: { controller.stopGeneration() }
                    )
                }
            .overlay(alignment: .trailing) {
                if showInspector {
                    GlassEffectContainer {
                        InspectorPanel(
                            selectedTab: $inspectorTab,
                            capabilityStore: controller.capabilityStore,
                            scheduleStore: scheduleStore,
                            projectPath: controller.workingDirectory?.path,
                            projectId: projectId,
                            selectedTool: controller.selectedToolEvent,
                            selectedTaskCompletion: controller.selectedTaskCompletion
                        )
                        .padding(.top, Spacing.xxl)
                        .frame(width: Layout.inspectorWidth)
                        .frame(maxHeight: .infinity)
                        .glassEffect(.regular, in: .rect)
                    }
                    .ignoresSafeArea()
                    .transition(Motion.inspectorSlide)
                }
            }
            .animation(.interactiveSpring, value: showInspector)
        }
        .environment(\.timelineActions, actions)
        .onDrop(of: [.fileURL, .image], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
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
            guard !Task.isCancelled else { return }

            // Inject last run results for this project's tasks when resuming
            // a previous session. Skipped for empty sessions (fresh start).
            // Guard prevents re-injection if .task fires again.
            if !didInjectCompletions, !controller.session.items.isEmpty, let path = controller.workingDirectory?.path {
                didInjectCompletions = true
                for task in scheduleStore.tasks(forProjectPath: path) {
                    guard let result = task.lastRunResult else { continue }
                    controller.session.appendTaskCompletion(TaskCompletionEvent(name: task.name, result: result))
                }
            }

        }
        .onChange(of: controller.selectedToolEvent?.id) { _, newID in
            controller.loadToolPayloadIfNeeded(for: newID)
        }
        .onChange(of: showInspector) { _, isVisible in
            if !isVisible {
                controller.selectedToolEvent = nil
                controller.selectedTaskCompletion = nil
            }
        }
        .fileImporter(
            isPresented: $showAttachmentPicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result else { return }
            let valid = DropPathValidator.validated(urls, workingDirectory: controller.workingDirectory)
            appendAttachments(valid.map { FileAttachment(url: $0) })
        }
        .focusedSceneValue(\.newConversation) { [controller] in
            controller.startNewConversation()
        }
        .focusedSceneValue(\.showAttachmentPicker, $showAttachmentPicker)
        .focusedSceneValue(\.inspectorVisibility, $showInspector)
        .onAppear {
            controller.checkAvailability()
            configureTimelineActions()
        }
        .onDisappear {
            controller.shutdown()
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        let workingDirectory = controller.workingDirectory

        for provider in providers {
            // Prefer file URLs — most drops (Finder, saved screenshots) provide one.
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                handled = true
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    let valid = DropPathValidator.validated([url], workingDirectory: workingDirectory)
                    guard let attachment = valid.first.map({ FileAttachment(url: $0) }) else { return }
                    Task { @MainActor in self.appendAttachments([attachment]) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                // In-flight screenshots and image data without a file URL.
                handled = true
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    guard let data,
                          let attachment = try? FileAttachment.fromImageData(data) else { return }
                    Task { @MainActor in self.appendAttachments([attachment]) }
                }
            }
        }

        return handled
    }

    private func appendAttachments(_ attachments: [FileAttachment]) {
        let remaining = FileAttachment.maxAttachments - pendingAttachments.count
        let capped = Array(attachments.prefix(remaining))
        guard !capped.isEmpty else { return }
        withAnimation(Motion.morph) {
            pendingAttachments.append(contentsOf: capped)
        }
    }

    private func sendMessage() {
        let text = draft
        let attachments = pendingAttachments
        draft = ""
        pendingAttachments = []
        controller.sendMessage(text, attachments: attachments)
    }

    private func configureTimelineActions() {
        actions.onSelectTool = { event in
            if controller.selectedToolEvent?.id == event.id {
                controller.selectedToolEvent = nil
                showInspector = false
            } else {
                controller.selectedToolEvent = event
                controller.selectedTaskCompletion = nil
                inspectorTab = .detail
                showInspector = true
            }
        }
        actions.onSelectTaskCompletion = { event in
            controller.selectedToolEvent = nil
            controller.selectedTaskCompletion = event
            inspectorTab = .detail
            showInspector = true
        }
        actions.onApprovalDecision = { id, toolName, decision in
            controller.handleApprovalDecision(id: id, toolName: toolName, decision: decision)
        }
        actions.onAskUserResponse = { id, selectedIndex, customText in
            controller.handleAskUserResponse(id: id, selectedIndex: selectedIndex, customText: customText)
        }
        actions.onPlanApprove = {
            controller.handlePlanApprove()
        }
        actions.onEnableCapability = { id in
            controller.enableCapability(id)
        }
    }
}
