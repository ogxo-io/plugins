---
name: css-alignment-debug
description: Use when a CSS/HTML visual bug won't resolve from reading source — icon and text not lined up, element the wrong size, padding/margin off, sidebar overlapping main content, sticky/fixed element misplaced, a Vue/React/Svelte scoped style silently not applying, "my CSS edit isn't taking effect," or unsure an element is rendered where you think. Best after one round of reading the CSS hasn't revealed the cause.
paths: ["**/*.{html,css,scss,sass,less,vue,svelte,jsx,tsx,astro}"]
---

# CSS Alignment Debug

## Read This First

**Use this skill when the user reports a visual layout bug AND you have spent more than one round trip guessing at the cause from CSS source alone.** It exists because layout bugs frequently come from invisible boxes — pseudo-elements, ancestor flex containers, scoped-CSS misses, inherited font-size from unexpected parents. Reading CSS files doesn't show you what's *actually* in the DOM.

**The single fundamental move:** inject a temporary high-contrast outline + dashed border on the suspect container and *every descendant*, ship to the browser, ask the user for a screenshot, then read the picture to see which boxes are real, where they sit, and what's actually inheriting your CSS.

## When to Use

Use this skill when:
- A visual element is wrong size, wrong position, or wrong alignment
- Your CSS edits aren't taking effect and you can't tell why
- You're not sure whether a DOM element you're targeting is actually rendered, or rendered where you think
- A pseudo-element (`::before`, `::after`), a flex/grid child, or an unexpected ancestor seems to be the culprit
- You've already grep'd the CSS bundle for conflicting rules and found nothing definitive

Do NOT use this skill for:
- JavaScript runtime errors (use `live-debug`)
- Network/API issues (use `live-debug`)
- Designing new layouts from scratch — debug overlays are *diagnostic*, not authoring tools
- Browser performance work

## Why This Works

Three categories of layout bug are impossible to confirm without seeing the rendered DOM:

1. **Hidden ancestor effects** — a parent has `font-size: 2em`, `transform: scale(...)`, `display: contents`, etc., and your child's `em`-based sizing or alignment is inheriting that
2. **Phantom elements** — what you *think* is "the breadcrumb text" is actually a different DOM node (`<title>` in body, a leaked `<h1>`, a sibling rendered by another component)
3. **Scoping misses** — Vue `<style scoped>` adds `[data-v-xxxxxx]` attribute selectors; if `<router-link>` or any wrapper doesn't propagate that attribute to the actual rendered `<a>`, your scoped rule silently doesn't apply

A 2px outline + dashed descendant outline answers all three in one screenshot:
- Outline missing → element isn't inside the container you think → category 2 or 3
- Outline present but box is the wrong shape/position → category 1, look at ancestors
- Outline present and shape is right → your rule simply isn't winning specificity; climb the Specificity Ladder below

## The Loop

```
        ┌──────────────────────────────┐
        │ 1. STATE THE HYPOTHESIS      │
        │    "X is too big because Y"  │
        └──────────────┬───────────────┘
                       ▼
        ┌──────────────────────────────┐
        │ 2. INJECT DEBUG OVERLAY      │
        │    outline + dashed children │
        └──────────────┬───────────────┘
                       ▼
        ┌──────────────────────────────┐
        │ 3. ASK FOR SCREENSHOT        │
        │    "hard-refresh and send"   │
        └──────────────┬───────────────┘
                       ▼
        ┌──────────────────────────────┐
        │ 4. READ THE PICTURE          │
        │    confirm or refute         │
        └──────────────┬───────────────┘
                       ▼
        ┌──────────────────────────────┐
        │ 5. FIX                       │
        │    targeted at real cause    │
        └──────────────┬───────────────┘
                       ▼
        ┌──────────────────────────────┐
        │ 6. REMOVE DEBUG OVERLAY      │
        │    + verify                  │
        └──────────────┬───────────────┘
                       │ not fixed?
                       └────► back to 1
```

### Step 1 — State the hypothesis

Before injecting anything, write down (in one sentence) what you believe is happening and where. Examples:

- "The giant `mygit` text is the last `<li>` in `#breadcrumbs` inheriting `font-size` from an ancestor with `font-size: 2em`."
- "The sidebar is overlapping the main pane because `#main` isn't getting `padding-left: 16em` when sticky is on."
- "The icon and text are misaligned because the flex container is using `align-items: stretch` (default) instead of `center`."

Your overlay should test that specific hypothesis. If your overlay doesn't produce evidence for or against the hypothesis, you haven't stated it precisely enough.

### Step 2 — Inject the debug overlay

Add the overlay rules to a **global CSS file** (not a scoped Vue/component CSS) so they win specificity easily and you don't have to chase scoping. In most projects this is `styles.css`, `app.css`, `main.css`, `global.css`, or `index.css`.

The default overlay (covers 90% of cases):

```css
/* CSS-ALIGNMENT-DEBUG: remove before committing */
#suspect-container {
  outline: 2px solid red !important;
}
#suspect-container * {
  outline: 1px dashed orange !important;
}
```

Add a second pair if you also need to see a sibling container for comparison:

```css
.other-container {
  outline: 2px solid cyan !important;
}
.other-container * {
  outline: 1px dashed lime !important;
}
```

**Key choices:**

- **`outline`, not `border`** — outlines don't affect layout, so what you see is the layout as-is. Borders shift things by their own width and lie to you.
- **`!important` on the outlines** — to win any pre-existing border/outline rules.
- **Different colors per nesting level** — solid red for the container, dashed orange for descendants. Easy to distinguish in a screenshot.
- **Prefix every comment with `CSS-ALIGNMENT-DEBUG:`** so the cleanup step (Step 6) is trivially greppable. *Never* ship this rule.

When the symptom is specifically a sizing/inheritance issue (not "where is this element"), include the size/inheritance probe in the same overlay:

```css
/* CSS-ALIGNMENT-DEBUG: also lock font-size to see what overrides inheritance */
#suspect-container,
#suspect-container * {
  outline: 1px dashed orange !important;
  font-size: 13px !important;
  line-height: 1.4 !important;
}
#suspect-container .material-symbols,
#suspect-container .icon-class {
  font-size: 18px !important;  /* exception for icon fonts so glyphs don't break */
}
```

When the symptom is "things in the wrong z-stack" (modal hidden behind sidebar, etc.), use background tints instead of outlines:

```css
/* CSS-ALIGNMENT-DEBUG: tint to see z-stack */
#suspect       { background: rgba(255, 0, 0, 0.18) !important; }
#other-suspect { background: rgba(0, 200, 255, 0.18) !important; }
```

### Step 3 — Ask for a screenshot

Wait for the dev server/HMR to rebuild (1–3 seconds), then ask the user to hard-refresh and paste a screenshot. A useful prompt:

> "Rebuilt with a debug overlay. Hard-refresh (⌘⇧R) and screenshot the affected area. Red solid = the container; orange dashed = every descendant. Pixels with no outline are *not* inside the container."

If a browser tool is available in this session, take the screenshot yourself instead, and read computed styles directly where the tool supports it. With a tool that can run page JavaScript, you can inject the overlay at runtime instead of editing source.

### Step 4 — Read the picture

Look for these signals:

| What you see | What it tells you |
|---|---|
| Suspect text has *no* outline | Element is not where you think — it's outside the container you targeted. Pivot your hypothesis. |
| Outline is present but child boxes are misaligned vertically | Flex/grid axis alignment problem — fix `align-items`. |
| Outline is present, child sizes vary unexpectedly | Inheritance issue — find which ancestor is multiplying `em` units. |
| Outline is present and looks correct but visual still wrong | Specificity loss — your "real" rule isn't winning. Climb the Specificity Ladder one level at a time. |
| Outline appears in unexpected location (wrong viewport region) | Positioning bug — element is `position: fixed/absolute` and offset wrong. |
| Multiple outlines stacking in same location | The DOM has duplicate elements (component rendered twice). |

Write down what the picture told you. Then go fix the **actual** cause, not the symptom.

### Step 5 — Fix

Now write the real fix targeted at the cause you confirmed. **Keep the debug overlay in place during the fix** — it lets you verify the fix without a second overlay round-trip.

### Step 6 — Remove debug overlay + verify

Once you've confirmed the fix works:

```bash
# find every debug marker you left
grep -rn "CSS-ALIGNMENT-DEBUG" . --include="*.css" --include="*.scss" --include="*.sass" --include="*.less" --include="*.tsx" --include="*.jsx" --include="*.vue" --include="*.svelte" --include="*.astro" --include="*.html"
```

Remove every rule prefixed with the marker. Ask for one final screenshot to confirm:
1. Outlines are gone
2. The original symptom is gone
3. Nothing new is visually broken

**Never commit code with `CSS-ALIGNMENT-DEBUG` left in.** A pre-commit hook or grep in CI can enforce this.

## Specificity Ladder

If your hypothesis is right but your rule isn't winning, escalate one level at a time. Don't jump straight to `!important` — that hides scoping bugs that will resurface.

1. `.classname { ... }`
2. `.parent .classname { ... }`
3. `#id .classname { ... }`
4. `#id .classname { ... !important }`
5. `#id, #id * { ... !important }` (nuke from orbit)

If you needed level 4 or 5, leave a comment explaining *why* — future you (or another developer) will want to know whether to clean up the !important once the underlying bug is fixed.

## Vue/React/Svelte Scoping Gotchas

**Vue `<style scoped>`** adds `[data-v-xxxxxx]` to elements. When a slot or `<router-link>` wraps an element, the attribute may or may not propagate. If a scoped rule isn't applying:

- Add the rule unscoped to a global stylesheet
- Or use `:deep(selector)` in Vue 3 scoped CSS
- Or restructure so the styled element is the component's *root*

**React + CSS-in-JS / CSS Modules** generates hashed class names. Inspect the rendered element to see the hash, then match it in your debug overlay.

**Svelte scoped styles** add an `.svelte-xxxxxx` class. Same principles.

## Common Failure Modes

**"I see no outlines at all."**
The overlay rule is in a CSS file that isn't loaded for this route, or you put it in a scoped component CSS. Move to a global stylesheet that's always loaded (e.g. the entry-point CSS imported by `main.js`).

**"Everything has an outline, including unrelated parts of the page."**
Your selector is too broad. `* { outline: ... }` covers literally everything. Scope it: `#myContainer *`.

**"The element I'm trying to outline is `position: fixed` and the outline shows in a weird place."**
The outline is correct; the element really is positioned there. Check `top/left/right/bottom` in the computed styles, or look for ancestor `transform` that creates a new containing block.

**"Outline shows but the box is empty / collapsed."**
The element exists but has `display: none`, `visibility: hidden`, zero width/height, or all its children are absolute-positioned out of flow. Read the computed styles to see which.

**"Hot-reload doesn't pick up the overlay change."**
Some build systems cache CSS aggressively. Force a full reload: kill the dev server and restart, or temporarily edit a Vue/component file alongside the CSS to trigger a full rebuild.

## What This Skill Deliberately Does NOT Do

- Doesn't replace browser DevTools — for a one-off "what's this element" question, the user opening DevTools and inspecting is faster
- Doesn't author new layouts — it's a diagnostic tool, not a designer
- Doesn't ship debug overlays — Step 6 (cleanup) is mandatory
- Doesn't try to fix bugs in CSS specs / browser engines themselves
- Doesn't generate fix code automatically — once you've identified the cause, you still need to apply judgment about the right fix

## Quick Snippets

Copy-paste these as starting points and adapt the selector.

**Default overlay (container + all descendants):**
```css
/* CSS-ALIGNMENT-DEBUG: remove before committing */
#TARGET { outline: 2px solid red !important; }
#TARGET * { outline: 1px dashed orange !important; }
```

**Compare two containers side by side:**
```css
/* CSS-ALIGNMENT-DEBUG */
#A { outline: 2px solid red !important; }
#A * { outline: 1px dashed orange !important; }
#B { outline: 2px solid cyan !important; }
#B * { outline: 1px dashed lime !important; }
```

**Lock sizing while you debug inheritance:**
```css
/* CSS-ALIGNMENT-DEBUG */
#TARGET, #TARGET * {
  outline: 1px dashed orange !important;
  font-size: 13px !important;
  line-height: 1.4 !important;
}
#TARGET .material-symbols { font-size: 18px !important; }
```

**Z-stack visualisation (instead of outlines):**
```css
/* CSS-ALIGNMENT-DEBUG */
#header   { background: rgba(255, 0,   0, .18) !important; }
#sidebar  { background: rgba(0,   200, 255, .18) !important; }
#shelf    { background: rgba(132, 204, 22, .18) !important; }
#main     { background: rgba(245, 158, 11, .18) !important; }
```

**Find phantom duplicate elements (very specific selector + count):**
```css
/* CSS-ALIGNMENT-DEBUG */
.suspect-class {
  outline: 2px solid magenta !important;
  outline-offset: 2px !important;
}
.suspect-class::before {
  content: "DUP";
  position: absolute;
  background: magenta;
  color: white;
  font-size: 10px;
  padding: 1px 3px;
  z-index: 99999;
}
```
If you see more than one magenta tag on screen, the component is being mounted multiple times.

## Cleanup Helper

Drop this in a local pre-commit hook or a CI grep step:

```bash
# Fail if any debug-overlay rules are left in the source tree
if grep -rqn "CSS-ALIGNMENT-DEBUG" --include="*.css" --include="*.scss" --include="*.vue" --include="*.svelte" --include="*.jsx" --include="*.tsx" src/; then
  echo "ERROR: CSS-ALIGNMENT-DEBUG markers found. Remove before committing."
  grep -rn "CSS-ALIGNMENT-DEBUG" --include="*.css" --include="*.scss" --include="*.vue" --include="*.svelte" --include="*.jsx" --include="*.tsx" src/
  exit 1
fi
```
