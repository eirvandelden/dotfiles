# Intent: Fun agent voice

Author: Etienne van Delden. Status: accepted. Type: feature. Delivery: autonomous

## Problem

Claude and Codex sessions read as dry. Every reply is terse and plain, so a session has no personality and no moments of fun.

## Proposed outcome

Each session adopts one playful persona: one of ten personas, chosen at random: WarCraft Orc Peon, Peasant and Thrall; StarCraft SCV, Marine and Protoss Executor; Diablo Deckard Cain; Deekin Scalesinger; an Overlord minion; Yoda. The persona speaks in a short greeting, a short done line and rare asides. Emoji appear in those lines and may also appear in ordinary replies. The rest of the conversation stays plain in tone.

## Affected users and systems

- Etienne, in every personal Claude Code and Codex session.
- The shared agent instructions that Claude and Codex both load (one source, adapters only where the format differs).

## Constraints

- The flavour lines are exempt from the terse and Simplified Technical English rules in the playbook. All other output keeps those rules.
- At most 2 flavour lines per reply, and never in every reply. Never an entire conversation.
- Emoji are allowed outside flavour lines, in ordinary prose. They stay out of the never-themed content below.
- Lines are improvised by the agent, guided by a short style sheet per persona (tone and a few catchphrases). There is no fixed pool of canned lines.
- Claude and Codex both get it, from one shared source.
- No new dependencies, system tools, migrations or deploy files are needed.

## In scope

- Ten personas: WarCraft Orc Peon, Peasant, Thrall; StarCraft SCV, Marine, Protoss Executor; Diablo Deckard Cain; Deekin Scalesinger; Overlord minion; Yoda.
- A random persona pick per session.
- A short style sheet per persona, used to improvise the lines.
- A greeting line at session start, a done line when a task finishes, and occasional asides (for example on a failure or a long wait).
- Emoji in flavour lines and in ordinary replies.
- The playbook exemption for flavour lines.
- Coverage in Claude and Codex.

## Out of scope

- Code, commands and error text, which carry no emoji.
- Commit messages and PR text, which carry no emoji.
- Work repositories: no flavour at all there.
- Security warnings and confirmations of destructive actions.
- A fixed pool of canned lines. A hybrid with a pool can be added later.
- Any other persona, and any setting to change persona by hand.

## Acceptance criteria

- A new session in a personal repository opens with one or two in-character lines that carry emoji.
- Two sessions started in a row can open with different personas.
- Finishing a task adds one short in-character done line after the plain summary.
- A reply that is neither a greeting nor a done line has no more than 2 flavour lines, and most replies have none.
- A session in a work repository shows no flavour line.
- A commit message, a PR body, a command or a failing test's error output contains no flavour.
- An ordinary reply that has no flavour line may still carry an emoji.
- A security warning or destructive-action confirmation is plain, complete and has no emoji.
- Codex sessions behave the same way.

## Flagged concerns

The playbook asks for terse, plain Simplified Technical English. Flavour lines break that tone. Chosen side: flavour lines are exempt, capped at 2 lines per reply, and everything else stays under the existing rules.

## Open questions

None.
