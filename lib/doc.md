PDF Reader App — Product & Technical Specification
Flutter Mobile Application

1. Product Overview

A fast, clean PDF reader and lightweight editor for everyday use: opening, reading, searching, annotating, organizing, and editing PDF files, plus scanning physical documents into PDFs. Most of the app is free and ad-supported (AdMob). A small set of higher-effort features (Text-to-Speech, in-place text editing, page deletion, and password protection) sit behind a single "Pro" in-app purchase, which also removes all ads. There is no separate "Remove Ads only" tier — Pro is the one purchase in the app. (Assumption stated here: if you actually want two separate purchases — an ads-only removal plus a separate premium unlock — flag it and this gets split into two IAP flows instead of one.)

Core promise: open any PDF in under a second, read it comfortably, mark it up naturally, and make real edits — all without the app feeling like a generic template.

2. Functional Requirements

Each requirement has an ID (FR-#) for traceability. The Tier column marks each requirement Free (available to everyone, ad-supported) or Pro (unlocked by the single Pro in-app purchase, which also removes ads). The Release column marks whether it ships in the first version (V1) or is deferred (Phase 2).

2.1 Core Reading
ID	Requirement	Tier	Release
FR-1	Open PDF from device storage, "Open with" intent, and recent files list	Free	V1
FR-2	Continuous-scroll and page-by-page pagination modes, toggle between them	Free	V1
FR-3	Pinch-to-zoom and double-tap zoom	Free	V1
FR-4	Library/recents view with auto-generated first-page thumbnails	Free	V1
FR-5	Search inside PDF — find text across all pages, jump to match, highlight matches on page	Free	V1
FR-6	Bookmarks/favorites — user can bookmark specific pages or entire files for quick access; also expose the PDF's own internal outline/bookmarks (table of contents) if present in the file	Free	V1
FR-7	Night mode — inverts the rendered PDF page colors (not just app chrome) for comfortable low-light reading	Free	V1
FR-8	Text-to-speech — reads the current page's text aloud, with play/pause/skip-page controls	Pro	V1
2.2 Annotation (non-destructive markup)
ID	Requirement	Tier	Release
FR-9	Highlight selected text	Free	V1
FR-10	Underline / strikethrough selected text	Free	V1
FR-11	Freehand drawing / pen tool	Free	V1
FR-12	Sticky note / comment on a page	Free	V1
FR-13	All annotations must be saved into the actual PDF file (not just held in app state) so they persist and are visible in other PDF apps	Free	V1
2.3 Editing (the app's primary differentiator)
ID	Requirement	Tier	Release
FR-14	In-place text editing — user taps existing text in the PDF, edits it, and the change is saved into the document	Pro	V1
FR-15	Merge multiple PDF files into one	Free	V1
FR-16	Split a PDF into multiple files by page range	Free	V1
FR-17	Reorder pages via drag-and-drop thumbnail grid	Free	V1
FR-18	Delete individual pages	Pro	V1
FR-19	Password-protect / encrypt a PDF with a user-set password	Pro	V1
FR-20	Convert PDF pages to image files (PNG/JPEG)	Free	V1

Note on FR-18: page deletion is intentionally Pro while Merge/Split/Reorder stay free — this is a deliberate product decision (many competing PDF apps also gate delete behind a paywall), not a technical necessity. All four use the same underlying API (Section 5.7), so there's no cost difference between them; the paywall is purely a monetization choice.

FR-21 (Convert PDF → Word) has been moved to Section 2.6, Later Advancements. Unlike everything else in this document, it cannot be built as an on-device, zero-marginal-cost feature — see Section 7 for why. It is deferred out of the first release rather than cut, so it should stay in the codebase's roadmap but not in the V1 build plan.

2.4 Scanning
ID	Requirement	Tier	Release
FR-22	Scan physical documents via camera with automatic edge detection, crop, and perspective correction	Free	V1
FR-23	Multi-page scan session — capture several pages, assemble into one PDF	Free	V1
FR-24	Run OCR on scanned pages to produce a searchable/selectable text layer	Free	V1
2.5 Sharing & Monetization
ID	Requirement	Tier	Release
FR-25	Share PDF (original or edited/annotated) via system share sheet	Free	V1
FR-26	AdMob: App Open ad (not on first launch), interstitial only at natural breakpoints (closing a file, returning to library), banner on library screen	Free (ad-supported)	V1
FR-27	IAP "Pro" — single purchase or subscription that (a) unlocks FR-8, FR-14, FR-18, and FR-19, and (b) disables all AdMob placements (FR-26). This is the app's only purchase; there is no separate ads-only tier	Pro purchase flow	V1
2.6 Later Advancements (Phase 2 — Not in First Release)

These items are documented now so they're on the roadmap and the codebase can be structured to accommodate them later, but they are explicitly excluded from V1. The common thread: each one requires a paid third-party service or backend infrastructure to work at production quality — see Section 7 for the specific cost breakdown behind each.

ID	Requirement	Why it's deferred
FR-21	Convert PDF to an editable Word (.docx) file	No on-device Dart/Flutter path exists for high-fidelity conversion; requires either a paid conversion API (e.g. a cloud document-conversion service billed per conversion) or a self-hosted backend (server costs + maintenance). Real per-use cost with no offsetting premium tier.

An AI agent scaffolding the project should still create a placeholder route/screen for "Convert to Word" if useful for navigation completeness, but must not implement the conversion logic itself in V1 — surface it as "Coming soon" rather than wiring it to a real (costed) backend.

2.7 Personalization
ID	Requirement	Tier	Release
FR-28	App-wide theme toggle — user can manually switch between Light and Dark mode from Settings (in addition to following system default), using the palettes defined in Section 4	Free	V1
3. Design Philosophy — Avoiding a "Generic AI-Generated" Look

This section exists because template-generated apps have recognizable tells. An AI agent building the UI should treat the table below as binding constraints, not suggestions.

Avoid	Do instead
Default Material purple/blue gradient everywhere	One restrained accent color (see Section 4), used sparingly
Uniform corner radius on every element	Small radius (6–8px) for dense UI like list rows; larger (16px) for cards/sheets
Repeated centered icon+heading+subtext block on every screen	Each screen's layout follows its own content, not a copy-pasted template
Mixed default Material/Cupertino icons	One icon family used consistently everywhere (e.g. Phosphor or Lucide icon set)
Drop shadows on every surface	Shadows only for real elevation (FAB, modal sheets); flat elsewhere
Generic 3-slide text onboarding	Show the app doing the thing (real UI preview of opening + highlighting a PDF)

Binding rule for implementation: for every screen built, it should not look identical if the app name were swapped out. This is a reading/editing tool — it should feel quiet, fast, and utilitarian, like a native Files or Notes app, not a marketing landing page.

3.1 Typography
UI chrome font: Manrope or Urbanist, sizes 13–17px.
Do not use the google_fonts package. It fetches font files over the network at runtime by default, which is known to fail or cause visible flashes of fallback text on some devices/network conditions. Instead: download the .ttf files for the chosen font directly from Google Fonts, bundle them under /assets/fonts/ in the project, and register them in pubspec.yaml under flutter > fonts with a fontFamily name. Reference that fontFamily in the app's ThemeData. This guarantees the font is always available offline and on first launch, with no runtime download step.
Never apply a custom font to the rendered PDF page — that is the document's own content and must render as authored.
3.2 Navigation
Bottom navigation, 4 tabs max: Library / Recent / Tools / Settings.
Reader screen: chrome auto-hides on scroll/tap for immersive reading, reappears on tap.
3.3 Micro-interactions
Page turn: subtle, physically-plausible transition, not an instant cut.
Highlight tool: color picker appears as a small pill/radial menu near the text selection, not a full modal sheet.
Haptic feedback on: annotation placed, page bookmarked, export completed.
Empty states: one short human sentence + one clear action button, not a generic "No data found" illustration.
3.4 Ad Placement Rules (binding — affects perceived quality directly)
No interstitial while actively reading a document.
Ads must carry a visible "Ad" label and never sit inline within the file list where they could be mistaken for a real file.
4. Color Palette

Rationale: the document view must stay comfortable to read for long sessions, while the app chrome around it should feel calm rather than competing for attention.

4.1 Light Mode
Role	Hex
Background (app chrome)
#FAF9F6
Surface / cards
#FFFFFF
Primary text
#1C1C1E
Secondary text
#6B6B70
Accent (primary actions)
#0F6E63 (deep teal)
Accent secondary (default highlight color)
#F2B705 (warm amber)
Divider / borders
#E7E5E0
Error / delete
#C24E4E
4.2 Dark Mode
Role	Hex
Background
#121214
Surface / cards
#1C1C1F
Primary text
#F2F2F0
Secondary text
#9A9A9E
Accent
#3FA79A
Accent secondary
#F2B705
Divider / borders
#2C2C30

Rule: the PDF page itself stays paper-white regardless of app theme, except when the user explicitly enables Night Mode (FR-7), which applies a color-inversion filter to the rendered page only — app chrome theme and PDF page theme are controlled independently.

5. Technical Architecture
   5.1 Package Roles (clarifying a common point of confusion)

syncfusion_flutter_pdfviewer and syncfusion_flutter_pdf are not two competing options — they are two layers of the same pipeline and both are required:

syncfusion_flutter_pdfviewer — the UI widget (SfPdfViewer). Renders pages, handles scroll/zoom/pagination, text selection, and built-in text-markup annotations (highlight/underline/strikethrough/squiggly). This is what the user sees and interacts with.
syncfusion_flutter_pdf — the headless, non-UI document library (PdfDocument, PdfPage, PdfTextExtractor, low-level annotation and security objects). This is what reads/writes raw PDF bytes, extracts text with position data, and performs structural operations (merge, split, encrypt).

pdfviewer depends on pdf internally. Implementation rule: use pdfviewer for anything the user sees and touches; drop down to pdf for anything that manipulates the file's actual bytes/structure.

5.2 Full Package List
Concern	Package
PDF rendering & viewing	syncfusion_flutter_pdfviewer
Document structure manipulation (merge/split/encrypt/extract)	syncfusion_flutter_pdf
In-place text editing	dart_pdf_editor (see Section 5.4)
Document scanning (edge detection, crop, perspective correction)	google_mlkit_document_scanner
OCR (searchable text layer on scans)	google_mlkit_text_recognition
Text-to-speech	flutter_tts
Image compression (for size-reduction pipeline)	flutter_image_compress
File picking	file_picker
Sharing	share_plus
Ads	google_mobile_ads
In-app purchase	in_app_purchase
Local storage (recents, bookmarks, settings)	hive or sqflite
Fonts	Bundled local .ttf assets (Manrope/Urbanist), registered via pubspec.yaml — not the google_fonts package (see Section 3.1)
State management	riverpod or bloc (match existing project convention)
5.3 Annotation Save Flow (FR-9 through FR-13)

Implementation constraint: annotations must be created using the library's built-in annotation objects, which are bound to document/text coordinates. Do not position annotations using screen pixel offsets or scroll position — that approach does not persist on save and will visually drift as the document scrolls, because it is not actually part of the PDF's data, only the widget tree.

dart
final PdfViewerController controller = PdfViewerController();

// Adding a highlight: bound to selected text's document position
void addHighlight() {
final textLines = pdfViewerKey.currentState?.getSelectedTextLines();
if (textLines != null && textLines.isNotEmpty) {
final highlight = HighlightAnnotation(textBoundsCollection: textLines);
controller.addAnnotation(highlight);
}
}

// Saving: bakes all annotations into real PDF bytes
Future<void> saveDocument() async {
final List<int> bytes = await controller.saveDocument();
await File(outputPath).writeAsBytes(bytes);
}

saveDocument() returns the modified file with annotations embedded in the actual PDF structure — this is the persistence step, and it is also what makes annotations visible when the file is opened in any other PDF app.

5.4 Text Editing Flow (FR-14 — Pro)

syncfusion_flutter_pdf supports adding new content (text boxes, stamps, watermarks) but does not support true in-place editing of existing text runs. Implementation path:

Use dart_pdf_editor (pure-Dart PDF editor, no native platform code, runs identically on iOS/Android/web/desktop) for in-place text editing. It is purpose-built for this exact requirement, including an OCR seam (PdfEditor.applyOcr) for adding an editable text layer to scanned pages, which also covers FR-24.
Before committing to it as the sole editing engine, prototype against a representative sample of real-world PDFs (varied fonts, scanned pages, forms) since it is a newer package — validate output fidelity before removing fallback options.
Fallback implementation if dart_pdf_editor doesn't cover a case: use PdfTextExtractor (from syncfusion_flutter_pdf) to get a text run's bounds and font metadata, cover the original text with a matching-color rectangle, then redraw the new string at the same position/size via PdfGraphics.drawString. This does not support text reflow but is visually correct for single-word/line edits, which covers the majority of real user edits (fixing a name, date, or figure).
5.5 Compression Pipeline (referenced for future scope — not in current FR list, flag if added)

Standard document.saveSync() re-serializes PDF structure without re-encoding embedded images, so file size does not meaningfully shrink. Real compression requires re-encoding the embedded images: extract each image via syncfusion_flutter_pdf, recompress with flutter_image_compress at reduced quality/resolution, and re-insert. This preserves text selectability while reducing size — the correct approach if compression is added as a future feature.

5.6 Scan-to-PDF Pipeline (FR-22 through FR-24)
Camera capture → google_mlkit_document_scanner handles edge detection, auto-crop, and perspective correction natively (multi-page capture supported in one session).
Assemble cropped page images into a single PDF using syncfusion_flutter_pdf (PdfDocument, add each image as a page).
Optional, free (FR-24): run google_mlkit_text_recognition on each page image before assembly to produce OCR text data, then use dart_pdf_editor's PdfEditor.applyOcr seam to inject an invisible, selectable text layer aligned to the recognized text — this is what makes a scanned PDF searchable and editable rather than just a picture. "Optional" here refers to a user-facing toggle (skip OCR for faster scanning vs. run it for searchability), not a paywall.
5.7 Merge / Split / Reorder / Delete (FR-15 through FR-18 — Delete is Pro, others Free)

All four operate on PdfDocument.pages from syncfusion_flutter_pdf:

Merge: PdfDocument.merge / import each source document's pages into one target document, save.
Split: create a new PdfDocument per target range, copy the relevant page range in, save each as a separate file.
Reorder: manipulate page collection order before save; UI is a drag-and-drop thumbnail grid.
Delete (Pro — gate behind the Pro purchase check before allowing this action): document.pages.removeAt(index), save.
5.8 Password Protection (FR-19 — Pro)

Use syncfusion_flutter_pdf's document security API to set a user password on PdfDocument.security before saving. Gate this action behind the Pro purchase check per FR-19.

5.9 Conversion (FR-20 — V1; FR-21 — Phase 2)
PDF → Image (FR-20): rasterize each page to PNG/JPEG. Achievable fully on-device, zero marginal cost, build in V1.
PDF → Word (FR-21, deferred — see Section 2.6 and Section 7): reconstructing an editable DOCX from arbitrary PDF layout is a genuinely hard problem — there is no reliable on-device Dart/Flutter solution for high-fidelity conversion. It requires a small backend service or a commercial conversion API, both of which carry real ongoing cost. Not part of the V1 build.
6. Non-Functional Requirements
   Must run smoothly on mid-range Android devices (not just flagship) — profile scroll performance with SfPdfViewer on large (100+ page) documents.
   Night mode color inversion (FR-7) should be tested for scroll performance impact on lower-end devices before shipping as default-on.
   All file-modifying operations (saveDocument, merge/split, OCR) are potentially slow on large files — run on a background isolate and show a loading state rather than blocking the UI thread.
   Annotation and edit operations must never silently fail — any save operation that doesn't succeed must surface an error to the user rather than losing their change.
7. Cost & Licensing Notes — What Actually Costs Money

Everything in the V1 scope (Section 2.1–2.5) runs on-device with free/open-source or free-tier packages — there is no hidden per-user or per-request infrastructure cost anywhere in the app, including the four features now gated behind the Pro purchase (FR-8, FR-14, FR-18, FR-19). Those four are paywalled as a monetization decision, not because they cost anything extra to build or run — worth keeping that distinction clear so the Pro-tier boundary can be revisited freely later without any technical constraint. This section makes the true cost picture explicit so it isn't discovered later during a billing review.

7.1 Genuinely free at any scale
google_mlkit_document_scanner, google_mlkit_text_recognition — Google ML Kit runs fully on-device; no API key, no per-call billing, no cloud dependency.
flutter_tts — wraps the OS's built-in TTS engine (Android/iOS); no external service.
dart_pdf_editor — open-source, pure-Dart, no licensing fee.
flutter_image_compress, file_picker, share_plus, hive/sqflite — standard open-source Flutter packages, free.
Bundled .ttf font assets — a one-time download from Google Fonts' website, no package or runtime dependency, no cost (see Section 3.1 for why google_fonts the package is avoided).
google_mobile_ads — free to integrate; AdMob's business model is a revenue share on ad impressions, not a cost you pay upfront.
in_app_purchase — free package; store platform fees (Apple/Google's standard cut on IAP transactions) apply to the Pro purchase itself, which is normal for any app and not an added infrastructure cost.
7.2 Watch item: Syncfusion licensing

syncfusion_flutter_pdfviewer and syncfusion_flutter_pdf are commercial packages. Syncfusion offers a free Community License for companies/individuals under a specific annual revenue threshold (verify the current figure on Syncfusion's licensing page before release, as thresholds can change). This should be free for an early-stage independent app, but it's a licensing condition to monitor as the app grows — not a cost today, but flag it for a revenue-threshold check before scaling.

7.3 The one real cost: FR-21 (PDF → Word)

This is the only requirement in this entire document that cannot be built for free on-device. It needs either:

A paid cloud document-conversion API (billed per conversion or per API call), or
A self-hosted backend running a conversion engine (server hosting cost + ongoing maintenance).

This is exactly why it's been placed in Section 2.6, Later Advancements, rather than V1 — building it now would introduce the app's first recurring operating cost, and it isn't part of the Pro bundle (FR-8/14/18/19), so there's currently no revenue stream earmarked to cover it. Revisit it once there's enough ad + Pro revenue or usage data to justify the added cost, or once a specific low-cost/free conversion API is identified — at that point it could either join the Pro bundle or ship as its own separate purchase.

8. Open Items (Pending Decisions — Not Yet Finalized)
   Final "Pro" pricing model (one-time purchase vs. subscription).
   Whether dart_pdf_editor fully replaces the "cover and redraw" fallback for text editing, or whether both ship together long-term.
   Backend/API vendor choice for PDF → Word conversion, to be revisited when FR-21 is pulled into an active release (see Section 7.3) — including whether it joins the Pro bundle or becomes its own purchase.
   Exact app name (pending, per prior discussion).
9. # Content Writing Guidelines — PDF Reader App
### For any AI agent (e.g. Cursor) generating in-app text

**Applies to:** onboarding copy, empty-state messages, button labels and tooltips, settings descriptions, error messages, paywall/Pro-upgrade screens, and app store listing text. Any time text is written or generated for this app, it must follow these rules.

---

## Rules

- Write naturally, as an experienced human copywriter would — not in a detectable "AI voice."
- Do not use em dashes (—). Use commas, full stops, or parentheses instead.
- Avoid robotic transitions and repetitive sentence patterns (e.g. don't open every paragraph the same way, don't lean on "Additionally," "Furthermore," "In conclusion," etc.).
- Vary sentence length and paragraph structure — mix short, punchy lines with longer ones.
- Do not repeat the same phrases across multiple screens or pages of the app.
- Make every screen's copy genuinely useful and distinct — no filler text, no generic placeholder-sounding lines.

## Why this matters for this app specifically

This app's whole design philosophy (Section 3 of the main spec) is about not feeling like a generic, templated, AI-generated product. Copy is part of that just as much as visuals — repetitive, robotic phrasing in onboarding or empty states will undercut the design work even if the UI itself is well built. Treat every string of user-facing text with the same care as the screens in Section 3's "Avoid / Do instead" table.

## Practical checklist before finalizing any in-app copy

- [ ] Read it aloud — does it sound like something a person would actually say?
- [ ] Check for em dashes and swap them out.
- [ ] Scan nearby screens — is this phrase or sentence structure reused somewhere else in the app? If so, rewrite one of them.
- [ ] Does this sentence add real information, or could it be cut without losing anything?
