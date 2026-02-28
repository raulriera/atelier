# Atelier — The Product

> What you see. What you do. What it feels like.

---

## You launch Atelier for the first time.

A window opens. Clean, native, quiet. A text field and a greeting. It feels like opening Notes — not a dashboard, not a control panel.

You sign in with your Anthropic account. That's it. You can start talking immediately — no project, no folder, no setup required.

---

## Your first conversation.

You type a message. Claude responds. It's fast, it's warm, and it knows nothing about you yet — just like meeting someone new.

You ask it to help you rewrite an email. It does. You ask it to summarize a long PDF. You drag the file onto the window and it reads it. Simple things, done simply.

This is Atelier at its most basic: a conversation in a window.

---

## You open a project.

At some point, you want Claude to work with a folder — your codebase, your manuscript, your research notes. You drag the folder onto the window, or use `⌘O`.

Atelier scans it quietly and tells you what it found: *"This looks like a collection of research papers — 24 PDFs and some notes. I can help with summaries, comparisons, and drafting."* Or for a developer: *"This is a Swift package with 3 targets. I can help with code, reviews, and refactoring."*

The conversation is now scoped to this project. Claude can see the files, understands the structure, and remembers this context across sessions.

---

## The conversation comes alive.

As you work, the conversation is more than text bubbles. When Claude reads a file, you see it happen — a small card showing what it opened. When it starts working on something, progress unfolds inline. When there are changes to review, a diff appears right in the thread.

It reads like a story:

> You asked → Claude investigated → found something → made a change → showed you → you approved → done.

Everything — questions, answers, file reads, task progress, diffs, approvals — lives together in one flowing timeline. There are no modes to switch between, no tabs to choose. The conversation adapts to what's happening.

---

## It works in the background.

Sometimes Claude needs time. A big refactor, a long analysis, generating a report. You see the work begin in the conversation, and then you can just... do something else. Switch to another window. Close the lid.

The work continues. When it's done, you get a notification. Open the window and the results are there in the conversation, waiting for your review.

---

## Multiple projects, multiple windows.

Your second project is a second window. `⌘O` to open a folder, and it appears in its own window with its own conversation.

Switch between them the way you switch between anything on a Mac: `⌘``, Mission Control, Stage Manager, or just click. Each window remembers its project, its conversation, its scroll position. Open as many as you want.

No project picker. No sidebar. Just windows.

---

## It learns your project over time.

The first time you open a project, Claude scans it and gets oriented. The second time, it already knows. The tenth time, it knows where the tricky parts are, what you've worked on before, and what patterns you prefer.

Context builds up naturally — through your conversations, through context files in the project folder, through the choices you've made. You never have to re-explain.

---

## Security is visible, not hidden.

When Claude wants to do something sensitive — delete a file, run a command, make a network request — you see it first. An approval appears in the conversation, showing exactly what will happen. You approve with a click.

Files go to Trash, never deleted permanently. Your credentials live in the macOS Keychain. The work happens in an isolated container that can't reach the rest of your system. Token usage is visible when you want to see it.

You're always in control, but you're not constantly interrupted. The app learns which actions you trust and which you want to review.

---

## It's a Mac app, not a web page.

Right-click any text in any app — "Rewrite with Claude," "Summarize with Claude." Results appear in place.

Drag files into the window to add them to the conversation. Drag results out to Finder, Mail, or wherever they need to go.

A global hotkey summons a quick conversation from anywhere. Shortcuts.app lets you chain Atelier into automations. Spotlight indexes your past sessions.

These things surface gradually. You'll discover them as you use the app, not during onboarding.

---

## The first milestone is small.

We're not building all of this at once. The first milestone is three things:

1. A native window that exists
2. A container that boots
3. Files moving between the host and the container

Everything above is where we're going. The milestones in [INDEX.md](INDEX.md) define how we get there.
