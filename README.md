# Journal for Mac

An introspective, AI-augmented journaling environment for macOS. This application leverages **SwiftUI**, **AppKit**, and **SwiftData** to create a seamless, desktop writing experience powered by OpenAI's GPT models.

Unlike traditional journaling apps, **Journal for Mac** acts as an active participant in the writing process—distilling thoughts into cohesive narratives, providing tone-based creative suggestions, and facilitating a "Canvas" mode where AI-driven insights are merged into the user's primary entries.

---

## 🏗 Architecture & Technical Stack

The project is built with a focus on high-performance text rendering and reactive state management.

### Core Frameworks

| Framework | Role |
|---|---|
| **SwiftUI** | Orchestrates the primary UI layer and layout |
| **AppKit (NSTextView)** | Utilized via `NSViewRepresentable` for granular control over the responder chain, focus states, and text formatting |
| **SwiftData** | Manages the persistent local database with a schema optimized for one-to-many relationships (`JournalEntry` ↔ `JournalNote`) |
| **Combine** | Powers the reactive pipelines via the `AlwaysPublished` property wrapper and cross-component focus tracking |

### Key Architectural Patterns

- **Hybrid MVVM:** ViewModels (`JournalEntryViewModel`, `JournalChatViewModel`) handle business logic and AI task coordination, while the `JournalFocusModel` acts as a central coordinator for UI focus and responder chain states.
- **Data Source Abstraction:** Decouples the UI from the database, allowing for seamless transitions between live SwiftData contexts and `MockData` for development/testing.
- **Granular Undo Management:** A custom `CustomUndoManager` is implemented per-note, ensuring that AI transformations and user edits maintain independent, predictable history stacks.

---

## 🌟 Key Features

### 1. AI-Driven Narrative Synthesis

- **Summary Panel:** Automatically generates a first-person summary of the entry's disparate notes. Uses a **debounced observation pattern** to keep summaries up-to-date without over-calling the API during active writing.
- **Canvas Mode:** A distraction-free editing environment where the `CanvasMergeCoordinator` uses LLM logic to intelligently insert new thoughts into existing text without overwriting user content.

### 2. Text Handling

- **FocusableTextView:** A custom `NSTextView` subclass that manages focus transitions, custom key equivalents (`Cmd+S` to save/resign), and tone-cycling shortcuts.
- **ResizingTextView:** A dynamic chat input that grows with content up to a specific threshold before enabling internal scrolling.

### 3. Contextual AI Chat

- **Entry-Aware Conversation:** The chat layer is aware of the current entry's title and recent notes, providing a conversational partner that understands the user's current emotional state.
- **Add-as-Note:** Users can instantly promote AI-generated insights from the chat directly into their journal as editable notes.

### 4. Emotional Intelligence — Tone Engine

The `JournalTone` engine maps emotional states (*Reflective, Hopeful, Melancholy*) to visual themes and AI behavior. Users can "cycle" the tone of a note to see alternative expressive versions of their own thoughts.

---

## 📂 Project Structure

```text
├── App
│   └── JournalAppApp.swift         # Entry point & ModelContainer config
├── Models
│   ├── JournalModels.swift         # SwiftData Schema (Entry, Note, Chat)
│   └── JournalTone.swift           # Emotional mapping engine
├── ViewModels
│   ├── JournalEntryViewModel.swift  # Note lifecycle & AI orchestration
│   ├── JournalChatViewModel.swift   # Pagination & Chat state
│   └── SummaryPanelViewModel.swift  # Summarization logic & Debouncing
├── Views
│   ├── MainView.swift              # Sidebar navigation & Layout hub
│   ├── JournalEntryView.swift      # Note vs. Canvas view orchestration
│   ├── JournalChatView.swift       # Interactive AI chat interface
│   └── NoteRow.swift               # Individual note unit with AI controls
└── Core
    ├── GPTClient.swift             # OpenAI API implementation
    ├── CustomUndoManager.swift     # Granular state history logic
    └── TextViewWrapper.swift       # The SwiftUI/AppKit bridge
```

---

## 🚀 Getting Started

**Prerequisites:** macOS 14.0+ and Xcode 15.0+

1. Open `Info.plist`.
2. Locate the `OpenAI_API_Key` key and insert your OpenAI Bearer token.
3. Select the `JournalApp` scheme and run (`Cmd+R`).

---

## 🛠 Engineering Highlights

- **Typewriter Animation Engine:** Located in `MessageBubble`, uses custom timing logic to render AI responses character-by-character, enhancing the "alive" feel of the interface.
- **Responder Chain Mastery:** The `NSViewRepresentable` integration allows the app to programmatically move focus between the sidebar, the note grid, and the chat input via `JournalFocusModel`.
- **Prompt Engineering:** The `GPTPrompts` class contains highly tuned system instructions that enforce first-person perspective and ensure AI merges are non-destructive to user-written text.

---

## 📈 Roadmap

- [ ] **CloudSync** — Moving from local SwiftData to CloudKit for multi-device support
- [ ] **Media Integration** — Supporting image-to-text analysis for visual journaling
- [ ] **Local LLM Support** — Integration with Ollama or Apple's MLX for offline-first privacy

---

*Developed by Andrei Marincas*
