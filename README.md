# Npdf

A free, native macOS PDF editor. No subscriptions, no cloud, no nonsense.

Built entirely on Apple's own frameworks — fast, lightweight, and handles large files without breaking a sweat.

---

## Features

- **Freehand ink drawing** — draw directly on any PDF page with smooth, GPU-accelerated strokes
- **Stamps** — place checkmarks ✓, X marks ✗, dots •, circles ○, and arrows → in any color
- **Text annotations** — add resizable text boxes anywhere on the page
- **Signatures** — capture your signature once, save it, and stamp it anywhere
- **Highlight** — mark up text with translucent color overlays
- **Eraser** — remove any annotation with a single click
- **Selection & resize** — click any annotation to move or resize it
- **Full undo/redo** — unlimited history, wired natively into macOS ⌘Z / ⌘⇧Z
- **Large file support** — opens 100MB+ PDFs instantly with lazy page rendering
- **Standard PDF output** — all annotations are saved as real PDF annotations, readable in Preview, Acrobat, Chrome, etc.
- **Drag & drop** — drop a PDF onto the window to open it

---

## Architecture

Npdf uses a three-layer architecture:

```
┌─────────────────────────────────────┐
│           Npdf.app (macOS)          │  AppKit + SwiftUI UI layer
├─────────────────────────────────────┤
│       NpdfKit (Swift Package)       │  PDF engine — annotations, signatures, coordinates
├─────────────────────────────────────┤
│   Apple PDFKit + Core Graphics      │  System foundation
└─────────────────────────────────────┘
```

**Npdf.app** is an NSDocument-based macOS application. The NSDocument architecture gives free undo/redo menu integration, autosave, recent documents, and multi-window support.

**NpdfKit** is a local Swift package that contains all the business logic — annotation building, signature persistence, coordinate conversion, and serialization. It's independently testable and decoupled from the UI.

**Apple PDFKit** provides the PDF renderer. It lazy-loads pages, handles zoom and scroll, and renders annotations natively. No third-party PDF engine is needed for Phase 1.

---

## Project Structure

```
Npdf/
├── project.yml                    # xcodegen spec — source of truth for the Xcode project
├── Npdf/                          # macOS app target
│   ├── App/
│   │   └── AppDelegate.swift      # NSApplicationDelegate, open panel
│   ├── Document/
│   │   └── PDFEditorDocument.swift  # NSDocument subclass
│   ├── UI/
│   │   ├── MainWindow/            # Window controller, split view
│   │   ├── Viewer/                # PDFView + per-page annotation overlay
│   │   ├── Sidebar/               # Thumbnail sidebar, signature panel
│   │   ├── Toolbar/               # Tool picker, color well, size slider
│   │   └── Panels/                # Signature capture sheet
│   └── Tools/
│       ├── ToolMode.swift         # Enum: select, ink, text, stamp, signature, eraser, highlight
│       └── ToolSettings.swift     # Observable color, stroke width, font size state
│
└── NpdfKit/                       # Swift Package (local)
    └── Sources/NpdfKit/
        ├── PDFLoader.swift          # Async open/save, password support
        ├── AnnotationManager.swift  # CRUD with NSUndoManager integration
        ├── InkAnnotation.swift      # Freehand ink path builder
        ├── StampAnnotation.swift    # Checkmark, X, dot, circle, arrow via Core Graphics
        ├── TextAnnotation.swift     # FreeText annotation builder
        ├── SignatureModel.swift     # Codable signature data model
        ├── SignatureStore.swift     # Persists signatures to ~/Library/Application Support/Npdf/
        ├── AnnotationSerializer.swift  # Identifies annotation types from PDF metadata
        └── CoordinateConverter.swift   # PDF ↔ screen coordinate math
```

---

## Tech Stack

| Layer | Technology | Why |
|---|---|---|
| Language | Swift 5.9 | Native, modern, safe concurrency |
| UI | AppKit + SwiftUI | PDFView performs best in AppKit; SwiftUI for panels |
| PDF Engine | Apple PDFKit | Free, native, lazy-loading, no licensing |
| Drawing | CAShapeLayer + Core Graphics | GPU-accelerated 60fps real-time strokes |
| Undo/Redo | NSUndoManager | Native macOS integration, wired to ⌘Z automatically |
| Persistence | File system + JSON | Signatures stored as PNG in Application Support |
| Build | Swift Package Manager + xcodegen | No CocoaPods, no Carthage |
| Distribution | Direct / Mac App Store | Free app, no subscription |

---

## Building

**Requirements:** macOS 13+, Xcode 15+

```bash
# Clone
git clone https://github.com/NitzanSelwyn/Npdf.git
cd Npdf

# Generate the Xcode project (required after cloning or adding files)
xcodegen generate

# Build from command line
xcodebuild -project Npdf.xcodeproj -scheme Npdf -configuration Debug build

# Or just open in Xcode
open Npdf.xcodeproj
```

**Run tests** (NpdfKit unit tests, no Xcode needed):

```bash
cd NpdfKit
swift test
```

> **Note:** After adding or removing source files, run `xcodegen generate` to regenerate `Npdf.xcodeproj`. The `project.yml` file is the source of truth — don't edit the `.xcodeproj` directly.

---

## Roadmap

### Phase 1 — MVP ✅
- [x] Freehand ink drawing (real-time CAShapeLayer, committed as PDFAnnotationInk)
- [x] Stamps: checkmark, X, dot, circle, arrow
- [x] Text annotations (FreeText)
- [x] Signature capture, storage, and placement
- [x] Highlight tool
- [x] Eraser
- [x] Selection + move/resize
- [x] Full undo/redo
- [x] Color picker + stroke size
- [x] Thumbnail sidebar
- [x] Drag & drop to open
- [x] Large file support

### Phase 2 — Text Editing
- [ ] True inline text editing (double-click FreeText annotation to edit)
- [ ] Font, size, bold, italic controls
- [ ] Text stream editing via PDFium (Apache 2.0 C wrapper in NpdfKit)

### Phase 3 — Polish
- [ ] Image annotation (drag image files onto PDF)
- [ ] Page management (reorder, insert, delete pages)
- [ ] Export single page as PNG/JPEG
- [ ] Print support
- [ ] App icon + DMG distribution

---

## License

MIT
