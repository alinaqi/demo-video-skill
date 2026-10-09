# demo-video — a Claude Code skill for captioned proof videos

[![test](https://github.com/alinaqi/demo-video-skill/actions/workflows/test.yml/badge.svg)](https://github.com/alinaqi/demo-video-skill/actions/workflows/test.yml)

Ask your coding agent to *show* that a feature works, not just say so. This skill teaches
[Claude Code](https://claude.com/claude-code) (or any agent that reads `SKILL.md` files) to:

1. write a throwaway Playwright spec that walks a real user flow,
2. record it with Playwright's built-in video and narrate each chapter with a caption bar,
3. keep real assertions in it, so the video is also a passing E2E test,
4. convert it to mp4 and **look at the frames** before handing it over,
5. run a **motion gate** (`validate-video.sh`) that fails videos where the caption changes
   but the screen doesn't,
6. save it as `YYYY-MM-DD-NN-<project>-<what-it-proves>.mp4` and delete the temporary spec.

Good for stakeholder updates, client-feedback proof, PR evidence and bug-fix demos.

## Install

```bash
git clone https://github.com/alinaqi/demo-video-skill.git
mkdir -p ~/.claude/skills
cp -r demo-video-skill/skills/demo-video ~/.claude/skills/
```

For a single project, copy it into `<project>/.claude/skills/` instead.

Requirements: `@playwright/test` in the project you're recording, and `ffmpeg`/`ffprobe` on PATH.

## Use

In Claude Code:

```
/demo-video Record the signup flow on http://localhost:3000: open the landing page,
sign up with a test account, land on the dashboard. Caption each step.
```

Or just ask for "a video showing the fix works". The skill's `when-to-use` makes the agent
reach for it on its own.

## The motion gate

The most common failure in agent-made demo videos: every chapter lands on a near-identical
view, so the footage looks frozen while only the caption text changes. `validate-video.sh`
samples the video, compares consecutive frames with ffmpeg's SSIM, and fails when there are
too few real screen changes or one screen fills most of the run:

```bash
bash ~/.claude/skills/demo-video/validate-video.sh out.mp4 [sample_fps=1] [max_ssim=0.985]
# duration=12.16s  transitions=5  longest_static_run=3 frames (~3s at 1fps)
# PASS: video changes across chapters.
```

Exit `0` means pass and `1` means fail, with the reason printed.

## Example

[`examples/demo-video.spec.ts`](examples/demo-video.spec.ts) is a complete five-chapter capture
spec against playwright.dev. It passes as a test and passes the motion gate:

```bash
npm i -D @playwright/test && npx playwright install chromium
npx playwright test examples/demo-video.spec.ts
```

## Tests

```bash
bash tests/test-validate-video.sh
```

These build synthetic videos with ffmpeg (static, multi-chapter, one dominant screen, too
short) and check the validator's verdict on each. CI runs them on every push.

## License

MIT
