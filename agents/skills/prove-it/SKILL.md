---
name: prove-it
description: Produce evidence, observed yourself, that a change works on the real target - reproduction before and after, screenshots, recordings, live readback. Use before reporting a change done or merging it, for anything with UI, runtime, device or data behaviour, when checking whether something works or breaks (a report that a page breaks on a phone, a service misbehaves), and when Sebastian asks to see that something works ("show me it works", "on mobile", "on my phone", "does it actually work"), or for proof, a screenshot or a recording.
---

# Prove it

Proof is evidence you observed in this session on the real target. Green
tests, a healthy process or a confident summary say it is time to look; they
are not the look. Use the most direct proof the change allows.

- **A fix:** reproduce the original failure first, apply the fix, watch the
  same reproduction pass. Add one focused test that fails without the fix
  when the repository has a test setup.
- **UI:** run the app and look at the changed screens next to the version
  they replace: light and dark, desktop and phone width, against `DESIGN.md`
  and the approved design. In T3 Code, in this order:
  1. `preview_open {"url": "localhost:5173/<page>"}`
  2. `preview_resize {"mode": "preset", "preset": "iphone-12-pro"}`, then
     `{"mode": "freeform", "width": 1440, "height": 900}` for desktop. Check the
     size it returns: a narrow pane cannot show a desktop layout.
  3. `preview_set_appearance {"colorScheme": "dark"}`, then `"light"`.
  4. `preview_snapshot {"save": true}` for each state. Embed the returned
     `screenshotPath` as `![<state>](<screenshotPath>)` in your reply: that is
     the only way Sebastian sees it.
  5. A flow: `preview_recording_start {}`, drive it with `preview_click` and
     `preview_type`, then `preview_recording_stop {}`, which returns the
     video's path.

  Pages that need his sign-in use his browser (Claude in Chrome, or the
  `chrome` backend in Codex).
- **Simulators and devices:** `device_list {}` for ids, then
  `device_open {"deviceId": "<id>"}`. Drive the device with the
  `agent-device` command it returns, and capture with
  `device_screenshot {"deviceId": "<id>"}`. Don't write tap scripts of your
  own.
- **Services, infrastructure, data:** live readback of the running version
  and the user-facing behaviour, through the path a real user or operator
  takes. An intermittent failure is watched long enough that it would have
  shown.
- **Measured qualities** (speed, precision, cost): the number on real data
  against a stated baseline, not a test count.

Then:

- Put the proof where Sebastian will see it: screenshots or a recording in the
  pull request's Proof section (`ship`), or one `html_render` page in the
  thread for a before and after side by side.
- Name anything you could not observe and why. A substitute (a mock, an
  emulator where a device matters, staging for production) is labelled as
  one, and the item it supports stays open.

Bad: "All 214 tests pass and the build is green, so the dark mode fix works."

Good: "Dark mode, iPhone 12 Pro width, settings page: the toggle text is now
readable (screenshots before and after below). Not observed: Safari on a real
iPhone; the preview runs Chromium."
