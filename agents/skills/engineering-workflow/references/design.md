# Design, UI and copy

Read for any UI, visual design or user-facing copy, in either runtime.

## Roles

- **Claude designs**: direction, the project's design system, visuals, UX flows
  and copy, through Claude Design (ask for a design, Output > Design, or
  `/design-sync` in Claude Code) and the `frontend-design` skill.
- **Codex builds** to the design system and the handed-over design. A design gap
  goes back to Claude; Codex does not choose visual direction.
- **Claude reviews** the rendered result against the design and this reference
  before it counts as done.
- A new project or new direction: Claude presents distinct alternatives and
  Sebastian picks. Inside an approved direction: proceed and show the result.

## Bespoke, never generic

- Every project gets its own direction, drawn from its purpose, audience and
  character. Record the direction and why in the project's `DESIGN.md`.
- Follow `frontend-design` for bespoke direction and its list of generated-
  design tells. Untouched library styling is one of those tells.
- Sebastian's picks between alternatives go into the taste notes in `DESIGN.md`.

## Design system

- Every element comes from the design system. Feature code composes components;
  it does not style them. A new need extends an existing component with a
  variant or option, or adds a new shared component. States and sizes are
  variants of one component, never copies.
- Colour, type, spacing, radius, shadow and motion are tokens (the Tailwind
  theme's CSS variables). Components use tokens only.
- Web stack: current stable Tailwind CSS, shadcn/ui and one icon set (Lucide),
  set up from current documentation. Other platforms apply the same principles
  with their standard toolkit.
- Libraries become ours: shadcn source lives in the repository and is restyled
  to the project's system. Every third-party UI library sits behind our own
  component (icons through one `Icon`; charts, date pickers and similar behind
  wrappers), so replacing a library is a one-file change.
- The repository holds the design system (tokens, components, `DESIGN.md`);
  Claude Design mirrors it one component to one component through
  `/design-sync`. Designs use placeholder data, never personal or customer data.
- Lint enforces it: no direct imports of icon or UI libraries outside their
  wrappers, and no hard-coded colour or spacing values in feature code.

## UX and frontend baseline

- The main task comes first, with one main action per screen. Show only what
  the user acts on; if a screen needs explaining, redesign it.
- Sensible defaults; undo rather than confirmation; every error says what to do
  next. Design the empty, loading and error states of every screen.
- Mobile-first, light and dark, no layout shift.
- Accessible: AA contrast, full keyboard use, visible focus, labelled inputs,
  44 px touch targets, reduced motion respected.
- Real content and locale formats for dates, numbers and currency.
- Recurring operator actions get in-app flows with honest state; a shell
  command is only a documented fallback.

## Sebastian's taste

Across projects he has rejected: stock component looks; pulsing or glowing live
dots; gradient hero boxes; rows of identical icon stat tiles; celebratory
headlines; glass on primary actions; emoji icons; coined names and metaphors in
the UI; helper sentences and explainer prose; ticking counters and layout jumps
on refresh; IDs, codes and versions in normal views unless they change a
decision; developer controls on operator surfaces.

He has picked: one strong action per surface with the rest quiet; actionable
and informational content visibly different; layered containers with tints; a
designed dark mode, not an inverted one; restrained spring motion; the same
capabilities on phone and desktop, each with its own structure; notifications
as a plain claim for the title plus two to four `key · value` lines.
Project-specific picks live in that project's `DESIGN.md`.

## Copy

- `DESIGN.md` holds the voice: audience, purpose, tone, formality, form of
  address per language (Swedish du or ni, German du or Sie), preferred and
  banned terms. All copy follows it: short, specific, actions named with their
  real verb.
- AI phrasing stays out ("unlock", "seamless", "elevate", "empower", filler
  triplets, stacked em dashes, exclamation marks, emoji) unless the voice
  explicitly allows it.
- **Each language is written natively, never translated.** Write each language's
  copy from what the text must achieve, following that language's grammar,
  word order, idiom, punctuation and capitalisation (Swedish uses sentence
  case), its formats and its form of address. Every string carries a short
  note on its purpose. No machine-translation step anywhere.
- Checks: a banned-phrase check on the copy files (shared list plus the
  project's banned terms); missing strings and fallback to another language
  fail.

## Verify UI

- Check in real engines: Safari on iPhone, Chrome on Android and desktop, light
  and dark. Look at every screenshot you capture.
- Before showing Sebastian any UI, walk the whole flow against his request word
  for word: every action, async results landing, phone and desktop widths. A
  lane's "done" is not yet presentable.
- `verify` for UI work also confirms: no one-off components or hard-coded
  values, no generic tells, and each language read in the rendered UI sounds
  native, follows its grammar and matches the voice.
- A model cannot stand in for a native speaker. For high-stakes copy (legal,
  launch), recommend a native human reader; that decision is Sebastian's.
