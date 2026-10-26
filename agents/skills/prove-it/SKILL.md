---
name: prove-it
description: Produce evidence, observed yourself, that a change works on the real target - reproduction before and after, screenshots, recordings, live readback. Use before reporting a change done or merging it, for anything with UI, runtime, device or data behaviour, and when Sebastian asks to see that something works ("show me it works", "on mobile", "on my phone", "does it actually work"), or for proof, a screenshot or a recording.
---

# Prove it

Proof is evidence you observed in this session on the real target. Green
tests, a healthy process or a confident summary say it is time to look; they
are not the look. Use the most direct proof the change allows.

- **A fix:** reproduce the original failure first, apply the fix, watch the
  same reproduction pass. Add one focused test that fails without the fix
  when the repository has a test setup.
- **UI:** run the app and look at the changed screens next to the version
  they replace, in light and dark and at phone width, against `DESIGN.md`
  and the approved design. In T3 Code: `preview_open`, `preview_snapshot`,
  `preview_resize`, `preview_set_appearance`, and
  `preview_recording_start`/`stop` for a flow. Signed-in pages: Sebastian's
  browser (Claude in Chrome, or the `chrome` backend in Codex).
- **Simulators and devices:** T3's `device_list`, `device_open` and
  `device_screenshot` before any hand-written tap scripts.
- **Services, infrastructure, data:** live readback of the running version
  and the user-facing behaviour, through the path a real user or operator
  takes. An intermittent failure is watched long enough that it would have
  shown.
- **Measured qualities** (speed, precision, cost): the number on real data
  against a stated baseline, not a test count.

Then:

- Put the proof where Sebastian will see it: screenshots or a recording in the
  pull request body (`pr`), or `html_render` in the thread for a side-by-side.
- Name anything you could not observe and why. A substitute (a mock, an
  emulator where a device matters, staging for production) is labelled as
  one, and the item it supports stays open.
