---
name: demo-video
description: Record captioned product walkthrough videos of any web app with Playwright + ffmpeg — proof videos for stakeholders, feature demos, bug-fix evidence
when-to-use: When asked for a video, screen recording, walkthrough, or visual proof of features/fixes in a web app, or as user-facing-flow evidence in a Definition of Done
user-invocable: true
effort: medium
---

# Demo Video Skill — visual validation for web apps

Record a captioned walkthrough video of a running web app, verify it frame-by-frame,
convert to mp4, and deliver it.

A demo video walks a real user flow end-to-end and doubles as a passing E2E test, so
"it works" is proven visually, not claimed. It complements screenshot-regression checks
(which catch pixel regressions) and the E2E suite (which proves behavior): a demo video
proves the whole user-facing flow the way a person would see it.

## The method

1. **Write a temporary Playwright spec** (`e2e/zz-<name>-video.spec.ts` or a scratch dir)
   that walks the real flows as one continuous test. One test = one video.
2. **Record via Playwright's built-in video**, never external screen capture:
   ```ts
   test.use({ video: { mode: 'on', size: { width: 1280, height: 800 } }, viewport: { width: 1280, height: 800 } })
   test.setTimeout(240000)
   ```
3. **Narrate with an injected caption bar** — the video must explain itself without audio.
   Call it before each chapter; the pause gives viewers time to read:
   ```ts
   async function caption(page: Page, text: string) {
     await page.evaluate((t) => {
       let bar = document.getElementById('demo-caption')
       if (!bar) {
         bar = document.createElement('div')
         bar.id = 'demo-caption'
         bar.style.cssText =
           'position:fixed;left:0;right:0;bottom:0;z-index:99999;background:#142b1e;color:#f7f5f0;' +
           'font:600 15px/1.4 Inter,system-ui,sans-serif;padding:12px 20px;letter-spacing:0.01em'
         document.body.appendChild(bar)
       }
       bar.textContent = t
     }, text)
     await page.waitForTimeout(2200)
   }
   ```
   The bar does not survive navigation; `caption()` re-creates it, so call it AFTER
   each `page.goto`.
4. **Structure as chapters**: caption → act → assert → caption the outcome. Keep real
   assertions in the spec so the video doubles as a passing test — a video of a broken
   flow must fail loudly, never ship silently.
5. **Reuse the project's e2e helpers** (logins, seeded data, fixtures) instead of
   hand-rolling flows. Prefer fake/deterministic AI modes so runs are repeatable.

## Recording gotchas (learned the hard way)

- **A new caption is NOT a new screen** (the #1 "the video just shows the same screen"
  bug): if several chapters land on a near-identical view — the same modal/drawer whose
  top is shared, the same list, the same page with one line different below the fold —
  the caption changes but the footage looks frozen. Each chapter must change what's
  *visibly prominent*: scroll the distinguishing element to the TOP of the viewport
  (`el.scrollIntoView({ block: 'start' })`, not `scrollIntoViewIfNeeded`, which is a
  no-op when the element is already marginally on-screen), or navigate/zoom so the thing
  that differs leads the frame. Then prove it changed with the motion check below.
- **Scroll-reveal animations**: elements animated in by IntersectionObserver stay
  invisible in captures unless you actually scroll. Walk the page (`scrollIntoViewIfNeeded`
  or step-scroll) before asserting/capturing.
- **OTP/async steps**: after submitting a form that triggers an email/side effect, wait
  for the next UI state (`await expect(page.locator('#code')).toBeVisible()`) before
  reading outboxes/fixtures — racing the write is the #1 flake.
- **Selector traps**: "first link" often matches a New/Create button; exclude it
  (`a[href^="/x/"]:not([href$="/new"])`).
- **Demonstrating error states**: drive the app's real error surface (e.g. navigate to
  the URL the failing action redirects to) rather than mocking pages that don't exist.

## Produce and verify

```bash
rm -rf test-results/zz-<name>*          # stale videos have the same filename
npx playwright test e2e/zz-<name>-video.spec.ts
find test-results -name "video.webm"    # the recording

# Convert to mp4 (universal playback, ~2-3x smaller)
ffmpeg -y -i "<video.webm>" -c:v libx264 -pix_fmt yuv420p -movflags +faststart out.mp4

# ALWAYS spot-check frames before delivering — extract a few and LOOK at them
ffmpeg -y -i out.mp4 -vf "select='eq(n\,60)+eq(n\,300)+eq(n\,600)'" -vsync vfr frame_%d.png
```

Read the extracted frames and confirm captions render and each chapter shows what it
claims. Never deliver an unviewed video.

**Then prove the video actually CHANGES** (reading a few frames can miss that chapters
repeat the same screen). Run the bundled validator, which sits next to this file — it
samples the video and uses ffmpeg's SSIM to count real screen changes and the longest
frozen stretch:

```bash
bash ~/.claude/skills/demo-video/validate-video.sh out.mp4   # defaults: 1 fps scan, SSIM>0.985 == "same screen"
```

It exits non-zero (and says why) when the footage is static or one screen fills most
of the run — treat that as a hard gate: fix the shot (see the "new caption is not a new
screen" gotcha) and re-record until it PASSES. A healthy multi-chapter walkthrough shows
many transitions and no single screen dominating. Build a contact sheet to eyeball all
chapters at once (tile cols×rows must equal the sampled frame count, or ffmpeg errors):

```bash
ffmpeg -y -i out.mp4 -vf "fps=1/3,scale=460:-1,tile=4x5" contact.png   # ~one frame/3s, 20-tile grid
```

Caveat: don't suppress ffmpeg's log level on the SSIM call (`-v error` hides the SSIM
result line and every pair looks identical) — the validator already avoids this.

## Deliver and clean up

- Copy the mp4 to a dated archive folder (e.g. `~/Documents/updates/<project>/`) and send
  it to the user.
- **Naming is mandatory and identifying**: `YYYY-MM-DD-NN-<project>-<what-it-proves>.mp4`
  — the date it was recorded, then a two-digit index so several videos on the same day
  stay ordered and every video is uniquely identifiable at a glance. Allocate the
  next *free* index with a no-clobber loop — never a count (`wc -l`), which reuses
  an index if an earlier file was deleted and silently overwrites an existing mp4:
  ```bash
  DIR=~/Documents/updates/<project>; DATE=$(date +%F); mkdir -p "$DIR"
  NN=1
  # The index orders the DAY, not the slug: check for any video at this index,
  # or two differently-named videos both claim -01 and the day stops sorting.
  while ls "$DIR/$DATE-$(printf '%02d' "$NN")-"*.mp4 >/dev/null 2>&1; do
    NN=$((NN+1))
  done
  cp out.mp4 "$DIR/$DATE-$(printf '%02d' "$NN")-<project>-<what-it-proves>.mp4"
  ```
  Never `video.mp4`, never a name without its date and index.
- **Delete the temporary spec** — it is a capture script, not a test; it must not join
  the suite or CI.

## Prerequisites

- Playwright installed in the project (`@playwright/test`) with a working dev/preview server.
- `ffmpeg`/`ffprobe` on PATH for conversion, frame extraction and the validator.
