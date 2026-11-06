# iPadOS Notes Math and Handwriting Research

Research checked on 2026-11-06 against Apple Support documentation. This document records the user-visible behavior to bring into Mathevo's handwritten calculator mode. Apple implementation details are not public, so this specifies compatible behavior rather than claiming to reproduce Apple's private recognition models or source code.

## Apple behavior observed in documentation

### Math entry and results

- In Notes and Math Notes, a person can write with Apple Pencil or type an expression. An equals sign asks Notes to evaluate a solvable expression inline.
- Math Notes supports three result modes: insert results automatically, show a Solve suggestion, or turn math results off.
- A vertical stack of numbers can be added with a horizontal line beneath it. An operator placed beside a digit changes the operation for that row.
- Variables can be assigned and reused in later expressions, for example `a = 3` followed by an expression using `a`.
- Recognition feedback distinguishes ambiguous characters and unrecognized or unsolvable expressions, and lets the person correct or edit the entry.
- Math Notes can graph two-variable and three-variable equations. Graphs can be panned, zoomed, inspected, and rotated in 3D.

### Handwriting and drawing

- Notes supports Pencil or finger input, multiple tools, colors, stroke thickness and opacity, a ruler, undo, and erasing.
- Handwriting can be selected and moved, copied, or deleted. The eraser and scratch-out gestures provide direct correction.
- Smart Script can refine handwriting while preserving its visual character. Apple documents handwriting refinement, transcription, spelling feedback, and language/model availability constraints.
- Scribble converts Pencil handwriting into typed text in supported text fields. It is distinct from mathematical recognition.

## Mathevo gap analysis

Mathevo's Draw mode already provides a large canvas, finger/stylus pointer input, undo-last-stroke, clear, ML Kit text recognition, automatic math normalization, solving, and a route to continue editing the recognized expression in the calculator. Recognition currently runs after a pause and on demand.

The existing implementation is narrower than Math Notes: it has no visible automatic/suggestion/off preference, no explicit handwritten equals trigger, no vertical arithmetic interpretation, no recognized-variable assignments, and no pen color/width or erase tool. Recognition errors are presented as a generic dialog, and the person has no persistent review surface for correcting recognized characters before solving. Drawing state is cleared when switching into Draw mode and is not saved as a note.

## Mathevo behavior specification

### Draw workspace

1. Keep a dedicated, edge-to-edge writing canvas with pointer/stylus and touch support. Use pressure when the platform supplies it, with a stable fallback width elsewhere.
2. Provide pen, highlighter, eraser, color, width, undo, redo, and clear controls. Erasing must edit strokes rather than paint white over the canvas.
3. Make the result policy explicit: **Automatic**, **Suggest**, and **Off**. Automatic evaluates recognizable math after a short pause or an equals sign. Suggest shows a Solve action. Off still recognizes handwriting but does not compute.
4. Preserve strokes and recognized content while the Draw workspace is active. A visible clear action removes the current work.

### Recognition and calculation

1. Convert recognized handwriting into a normalized math expression while retaining the original strokes.
2. Show the recognized expression as editable math. Mark uncertain or unsupported recognition inline and let the person correct the expression before solving.
3. Support horizontal arithmetic and a vertical stack of numeric rows. A drawn rule under the stack requests the total; row-leading plus, minus, multiply, or divide sets that row's operation.
4. Support simple variable assignments and reuse in the current note/session. Reject unresolved variables with a clear prompt rather than silently dropping them.
5. Add each confirmed computation as one history entry with recognized expression and result. Let the person send the corrected expression to the full calculator.
6. Where a recognized two-variable equation can be handled by the existing visualization engine, offer **Open equation in Graphing**. Do not claim 3D graphing for forms the plot engine cannot parse.

### Recognition boundaries

- On-device OCR is a best-effort transcription step, not a symbolic math handwriting model. Recognition output must remain reviewable before the app commits a result.
- Supported operations are limited to the math engine and visualization parser. Unsupported notation must remain intact for editing and produce an explicit unsupported result.
- Automatic handwriting refinement, personalized handwriting synthesis, Apple Pencil hover/squeeze, and Apple's language-specific handwriting model are Apple platform features. Mathevo will provide equivalent interaction goals where Flutter and device APIs allow, without implying access to Apple's implementation.

## Implementation record

This section is updated as the Draw mode changes and emulator/device verification is completed.

- [x] Add Automatic, Suggest, and Off result policies with an explicit Solve action.
- [x] Add editable recognition review and inline recognition/solver feedback.
- [x] Add vertical arithmetic interpretation with row-specific operators.
- [x] Add variable assignment and reuse within the active drawing session.
- [x] Offer recognized `y = f(x)` equations to the existing Graphing calculator mode.
- [x] Add pen, highlighter, color, width, pressure-aware stroke width, stroke eraser, undo, and redo.
- [x] Preserve drawing strokes and recognized content while switching calculator modes.
- [ ] Persist handwritten notes across app restarts and add a saved notes list.
- [x] Add an Android emulator end-to-end flow covering handwriting recognition, editable correction, solving, variable assignment/reuse, and calculator handoff.
- [ ] Validate Pencil pressure and tilt on physical Apple Pencil hardware. The Android emulator only validates touch/stylus-like pointer input and OCR behavior on that target.

## Apple sources

- [Enter formulas and equations in Notes on iPad](https://support.apple.com/guide/ipad/enter-formulas-and-equations-ipad10f28bec/ipados)
- [Solve math with Math Notes in Calculator on iPad](https://support.apple.com/en-mz/guide/ipad/ipadeb38d0f8/ipados)
- [Work with graphs in Math Notes in Calculator on iPad](https://support.apple.com/en-sa/guide/ipad/ipad7dfe4006/ipados)
- [Add drawings and handwriting in Notes on iPad](https://support.apple.com/guide/ipad/add-drawings-and-handwriting-ipada87a6078/ipados)
- [Use handwriting in Notes on iPad](https://support.apple.com/en-ca/121259)
- [Enter text with Scribble on iPad](https://support.apple.com/en-ca/guide/ipad/ipad355ab2a7/ipados)
- [Draw with Apple Pencil on iPad](https://support.apple.com/en-ph/guide/ipad/-ipadc55b6c7a/ipados)
