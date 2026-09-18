# Public site and documentation implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prepare an original, dependency-free GitHub Pages landing page and
clear English open-source documentation for the free MIT release of
QuotaCreature.

**Architecture:** Serve a small static page directly from `docs/`. Use
semantic HTML, local CSS, and original inline SVG pixel art. Keep installation
and security information in the existing Markdown documents so the web page
links to the repository source of truth instead of duplicating an app backend.

**Tech Stack:** HTML5, CSS3, Markdown, zsh validation; no JavaScript, build
tool, package, external font, or CDN.

**Spec:** docs/superpowers/specs/2026-09-18-open-source-creature-design.md

## Global constraints

- The project remains free and MIT-licensed. Do not add Pro, payment, account,
  signup, donation, analytics, telemetry, updater, or backend language.
- Use TokenBar only as structural inspiration: hero, installation, privacy,
  and FAQ. Do not copy its text, assets, SVG paths, CSS, JavaScript, or brand.
- Do not invent a GitHub owner, repository URL, release URL, Homebrew Cask,
  notarized binary, or supported Claude quota reader.
- Keep every public claim direct and factual. Apply the humanizer rules to
  prose only; preserve commands, file paths, API names, and link targets.
- The static site must contain no external requests: no `<script>`, remote
  URL, `@import`, tracker, cookie banner, iframe, or web font.
- Respect `prefers-reduced-motion`; all animation stops under Reduce Motion.
- Describe Claude Code as Beta, detected locally only, with usage reading still
  being tested. Never claim that its quota is displayed.

---

### Task 1: Create the dependency-free GitHub Pages landing page

**Files:**

- Create: docs/index.html
- Create: docs/site.css

- [ ] **Step 1: Add the semantic page skeleton**

Create an English `docs/index.html` with:

1. `<!doctype html>`, `<html lang="en">`, viewport metadata, a factual
   title, and one local stylesheet link to `site.css`.
2. A `<main>` containing five labeled sections: hero, install, what it
   shows, local-by-design, and questions.
3. A small footer linking with repository-relative paths to
   `../README.md`, `./INSTALL.md`, `./ARCHITECTURE.md`,
   `./THREAT_MODEL.md`, `../PRIVACY.md`, `../SECURITY.md`, and
   `../LICENSE`.

Use a short original page description, for example:

> A local macOS menu-bar creature for the Codex limits your CLI already
> exposes.

Avoid unsupported claims about a public release, a hosted download, or a
working Claude quota endpoint.

- [ ] **Step 2: Add original inline pixel creature art**

Place one inline `<svg>` in the hero. It must use a simple 16-by-16
pixel-grid shape made from original `<rect>` elements, not an external image.
Give it either a useful `aria-label` or a visually hidden text equivalent.
The creature should match the app's general friendly silhouette without
reusing another project’s art.

Add a small status chip near the hero that says:

> Local-only · macOS 14+ · MIT

- [ ] **Step 3: Add the source-build installation section**

Use the current source-build commands exactly:

~~~zsh
git clone <your-public-repository-url>
cd <repository-directory>
codex login
swift test
swift run QuotaCreature
~~~

Because the public remote is not known yet, keep the first two lines visibly
as placeholders and explain that they become copyable when the repository is
published. Add the real local-bundle command separately:

~~~zsh
Scripts/install.sh
open "$HOME/Applications/QuotaCreature.app"
~~~

State that the installer refuses to overwrite an existing app bundle. Do not
offer Homebrew or a binary download.

- [ ] **Step 4: Add provider and privacy sections**

The what-it-shows section must distinguish:

- Codex: current remaining percentage, reset time, and, when supplied by the
  CLI, personal rate windows or Business/Enterprise monthly credits.
- Claude Code (Beta): local CLI detection only. Usage reading is still being
  tested.

Use this exact sentence once:

> Claude Code support is in beta. The app can detect a local CLI, but its usage
> reader is still being tested.

The local-by-design section must state that QuotaCreature has no direct
network client, telemetry, stored usage history, or credential-file reader.
It starts only the existing Codex CLI with a fixed App Server request.

Add a compact FAQ:

- Why does it show unavailable?
- Does it upload usage data?
- Does it support Claude Code?
- Why is there no download button?

Answers should link to the local documentation where useful and should not
promise features the repository does not ship.

- [ ] **Step 5: Style the site with local CSS**

Create `docs/site.css` with:

- system-ui / monospace system fallback fonts only;
- a restrained dark indigo and mint palette consistent with the app;
- readable desktop layout with a single-column small-screen layout at roughly
  760px;
- high-contrast link, keyboard focus, and selection states;
- `image-rendering: pixelated` and `shape-rendering: crispEdges` for the
  art where supported; and
- a short stepped bob animation using CSS only.

Use:

~~~css
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    scroll-behavior: auto !important;
  }
}
~~~

Do not use JavaScript for animation, copy buttons, navigation, or state.

- [ ] **Step 6: Validate the static boundary**

Run:

~~~bash
test -f docs/index.html
test -f docs/site.css
! rg -n '<script|https?://|@import|iframe|analytics|telemetry' docs/index.html docs/site.css
~~~

Expected: each file exists and the final search has no matches. Repository
relative links and the placeholder command are allowed.

---

### Task 2: Update public Markdown for Codex support and Claude Beta limits

**Files:**

- Modify: README.md
- Modify: docs/INSTALL.md
- Modify: docs/ARCHITECTURE.md
- Modify: docs/THREAT_MODEL.md
- Modify: PRIVACY.md
- Modify: SECURITY.md

- [ ] **Step 1: Update the README**

Add a short provider note after What it does:

> Codex usage is the supported reader. Claude Code support is in beta: the app
> can detect a local CLI, but its usage reader is still being tested.

Add a factual sentence explaining that the selection does not invoke Claude,
read Claude credentials, or parse terminal output. Keep the app positioned as
free, local, and unofficial. Do not add a pricing or release-download section.

- [ ] **Step 2: Update installation guidance**

In `docs/INSTALL.md`, retain the Codex requirements as mandatory for usable
quota data. Add an optional diagnostic command:

~~~zsh
claude --version
~~~

Explain that its absence does not affect Codex operation, and its presence
only enables the Claude Code Beta detection card. Preserve the current generic
unavailable guidance and the non-overwriting installer behavior.

- [ ] **Step 3: Update architecture and threat-model boundaries**

In `docs/ARCHITECTURE.md`, add a small provider branch after the existing
Codex flow:

~~~text
Claude Code (Beta)
        │ fixed absolute executable discovery only
        ▼
Detected / unavailable card
~~~

State that this path launches no child process and returns no usage values.

In `docs/THREAT_MODEL.md`, add explicit controls for:

- Claude credential/session/log access is prohibited.
- Claude detection uses fixed absolute locations and
  `FileManager.isExecutableFile(atPath:)`.
- No fallback uses `claude -p`, terminal capture, `~/.claude`, browser
  automation, or direct provider HTTP.

- [ ] **Step 4: Update privacy and security statements**

In `PRIVACY.md`, state that Claude detection does not persist a path,
account, usage number, or credential. In `SECURITY.md`, add that a future
Claude reader requires a documented noninteractive output contract, strict
decoding, a response cap, timeout, sanitized environment, and tests before it
can leave Beta.

Do not alter the already documented Codex security promises.

- [ ] **Step 5: Humanize and check wording**

Review the changed English prose against the humanizer rules:

- remove inflated or repetitive claims;
- prefer short, direct sentences;
- do not add em dashes where none are needed;
- keep Markdown links, commands, paths, and code literals exact; and
- ensure “Beta” is visible wherever Claude Code support is described.

- [ ] **Step 6: Run documentation checks**

Run:

~~~bash
rg -n 'Claude Code|claude -p|~/.claude|Pro|paid|payment|telemetry|analytics' README.md docs/INSTALL.md docs/ARCHITECTURE.md docs/THREAT_MODEL.md PRIVACY.md SECURITY.md
git diff --check
~~~

Expected: Claude uses are limited to Beta/detection/security language; no paid
product language is introduced; whitespace check passes.

---

### Task 3: Verify the open-source release surface without publishing

**Files:** None expected unless validation finds an issue.

- [ ] **Step 1: Run application and installer gates**

Run:

~~~bash
swift test
swift build -c release
zsh -n Scripts/install.sh
git diff --check
~~~

Expected: all commands exit zero.

- [ ] **Step 2: Run the final static-security scan**

Run:

~~~bash
! rg -n '<script|https?://|@import|iframe|analytics|telemetry' docs/index.html docs/site.css
rg -n 'URLSession|WebSocket|auth\.json|claude -p|~/.claude|Process\(' Sources Tests docs README.md PRIVACY.md SECURITY.md
~~~

Expected: the static page has no external resource or tracker code. The source
scan finds existing Codex `Process` handling and documentation prohibitions,
but no Claude process, prompt, credentials, or auth-file access.

- [ ] **Step 3: Manually check the rendered page**

Open the local `docs/index.html` in a browser and verify:

1. the creature is readable and animates without JavaScript;
2. keyboard focus is visible;
3. viewport sizing works at a narrow width;
4. the page is still readable when reduced motion is enabled; and
5. all statements about Claude call it Beta.

- [ ] **Step 4: Commit documentation and site changes**

~~~bash
git add README.md docs/index.html docs/site.css docs/INSTALL.md docs/ARCHITECTURE.md docs/THREAT_MODEL.md PRIVACY.md SECURITY.md
git diff --cached --check
git commit -m "docs: add public site and Claude beta guidance"
~~~

- [ ] **Step 5: Leave publishing configuration explicit**

Do not add a Git remote, push a branch, enable GitHub Pages, create a release,
or configure Homebrew. Those actions require the public owner/repository URL
and user authority. When available, replace the visible clone placeholder and
configure Pages from `docs/`.
