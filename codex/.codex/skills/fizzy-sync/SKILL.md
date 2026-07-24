---
name: fizzy-sync
description: Use when syncing GitHub/Slack/Outlook/Slite work items into Fizzy, or reconciling Fizzy card state back to GitHub issue status.
---

# Fizzy Sync

Sync work signals from GitHub (issues), Slack (saved items + self-DMs), Outlook (flagged emails), and Slite (assigned todos) into Fizzy, your personal task tracker. This skill handles both one-way ingestion (Slack, Slite) and two-way reconciliation (GitHub Project Status field, Outlook flags) with conflict detection.

## Preflight

Before syncing, verify:

1. **Environment**: `FIZZY_PAT` set and valid (Fizzy API token).
2. **Tool availability**: Fizzy MCP reachable; GitHub, Slack, Outlook, Slite connectors approved and accessible.
3. **Fizzy setup**: Both target boards exist:
   - 💼 **Nedap** (work/Nedap items)
   - 🐿️ **Etienne & Tech** (personal/open-source)
4. **GitHub setup**: Any assigned issues are in a Project with a "Status" field supporting states: To Do, In Progress, In Review, Needs Testing, Done.

If any tool is unavailable, ask whether to skip that source or pause until it's ready.

## Sources of Truth

Sync runs in this order; each source is independent (no cross-source dedup):

### 1. GitHub (two-way)

**Fetch**: Open issues assigned to you across all accessible repositories, except those under the Kabisa organisation.

**Dedupe**: By issue URL. Card title format: `<owner>/<repo>#<issue> — <issue title>` (e.g., `conductor/dotfiles#42 — Add Fizzy sync skill`).

**Placement**: 
- Nedap/Conductor repos → 💼 Nedap board.
- All others → 🐿️ Etienne & Tech board.

**Default column**: Anytime (unless GitHub's Project Status field or existing Fizzy card specifies otherwise).

**Description**: Include issue URL, current GitHub status, and sync fingerprint (see "Two-Way Sync" below).

### 2. Slack Saved Items (one-way)

**Fetch**: All saved items in your workspace (via approved Slack MCP; do not use unapproved channels or direct APIs).

**Dedupe**: By permalink, then normalized text + date + channel.

**Placement**: 🐿️ Etienne & Tech board.

**Default column**: Anytime.

**Description**: Permalink only; do not copy large message excerpts.

**One-way only**: If a Fizzy card sourced from a Slack saved item is closed, do not re-open it on subsequent syncs. Slack saved items are archived/discarded by you; closing the card is intentional and should not be reversed.

**Limitation**: If saved items aren't directly available via the approved MCP, report incompleteness and ask whether to proceed with self-DM lines only.

### 3. Slack Self-DM Messages (one-way)

**Fetch**: All messages in your saved-to-self DM thread (via approved Slack MCP).

**Split by line**: Each meaningful line becomes its own Fizzy task (skip empty lines and filler like "—" or "…").

**Dedupe**: By normalized text + date. Skip duplicates of saved items above.

**Placement**: 🐿️ Etienne & Tech board.

**Default column**: Anytime (unless the line mentions "today" or "in progress", in which case Today or In Progress).

**Description**: Full line text; include DM permalink if recoverable.

### 4. Outlook Flagged Emails (two-way)

**Fetch**: All flagged emails from your inbox and folders.

**Treat as work unless clearly personal** (e.g., personal bank account, vacation receipts — ask if unsure).

**Dedupe**: By message link, then normalized subject + sender + date.

**Placement**: Nedap/work → 💼 Nedap; personal → 🐿️ Etienne & Tech.

**Default column**: Anytime.

**Description**: Sender, subject, and message link only (no large content copies).

**Two-way behavior** (see "Two-Way Sync" below): Closing a Fizzy card sourced from a flagged email unflags it; reopening reflag it.

### 5. Slite (one-way)

**Fetch**: Documents where todos are assigned to you or explicitly mention you as responsible (not incidental mentions or authorship).

**Dedupe**: By doc/task link, then normalized title + date.

**Placement**: Nedap context (shared docs, team projects) → 💼 Nedap; personal/notes → 🐿️ Etienne & Tech.

**Default column**: Anytime.

**Description**: Doc link and task link only; no large excerpts.

## GitHub Two-Way Sync

After ingesting all five sources, reconcile Fizzy cards with their GitHub issue sources using a **sync-fingerprint** mechanism.

### Status Mapping

GitHub Project "Status" field ↔ Fizzy column:

| GitHub Status | Fizzy Column |
|---|---|
| To Do | Anytime |
| In Progress | In Progress |
| In Review | In Review |
| Needs Testing | closed |
| Done | closed |
| (no Status field / not in Project) | fall back to plain: open issue → active card (Anytime), closed issue → closed card |

Reverse direction (Fizzy → GitHub):
- Fizzy **Anytime or Today** → GitHub "To Do" (Today is priority-only in Fizzy; syncs identically to Anytime for GitHub purposes).
- Fizzy **In Progress** → GitHub "In Progress".
- Fizzy **In Review** → GitHub "In Review".
- Fizzy **closed** → GitHub "Needs Testing" (never auto-advances to "Done"; that transition is GitHub-only, reflecting human/CI decision).
- GitHub issue **actually closed** (not just Status field) → close the Fizzy card regardless of Status field state.
- GitHub issue **unassigned from you** → never auto-close or move the card; always ask for manual review before cleanup.

### Sync-Fingerprint Mechanism

Store a visible fingerprint line in each GitHub-linked Fizzy card description:

```
Sync: github_status=In Review, fizzy_state=In Review, last_synced=2026-07-23
```

**Each sync run**:

1. For every Fizzy card with a GitHub issue link:
   - **GitHub changed** (current GitHub status ≠ fingerprint's `github_status`, but current Fizzy state = fingerprint's `fizzy_state`): push GitHub → Fizzy (move column / close per mapping table), update fingerprint.
   - **Fizzy changed** (current Fizzy state ≠ fingerprint's `fizzy_state`, but current GitHub status = fingerprint's `github_status`): push Fizzy → GitHub (update Project Status field), update fingerprint.
   - **Both changed (conflict)**: GitHub wins; move Fizzy to match GitHub; flag the conflict explicitly in the final report (do not silently resolve, do not block, just report).
   - **Neither changed**: no-op.
   - **No fingerprint yet** (new card from GitHub): GitHub status is authoritative for initial Fizzy state; create fingerprint.

2. For GitHub issues that were closed since the last sync: close their corresponding Fizzy cards if still open.

## Outlook Two-Way Sync

**Closing a Fizzy card** sourced from a flagged email → **unflag** the email.

**Reopening a Fizzy card** sourced from a flagged email → **reflag** the email.

This is the only non-GitHub two-way relationship. Slack saved items, self-DM lines, and Slite actionables remain one-way (source → Fizzy only) because there is no reliable "mark done" API for those sources.

## Safety Rules

- **Never mention Fizzy/Slack/Outlook/Slite in GitHub issues.** Leave issues unchanged except for Project Status field.
- **No unapproved Slack MCP**: Use only the approved Slack connector; do not attempt direct API calls or undocumented endpoints.
- **Ambiguous merges/cleanup**: Always ask before:
  - Merging two likely-duplicate cards without clear link.
  - Closing or moving a card whose source is inaccessible or deleted.
  - Unassigning or archiving cards from unlinked (non-GitHub) sources.
- **Minimal metadata only**: No large content copies. Title + link + minimal context.
- **Clear diagnosis on errors**: If Fizzy PAT fails, DNS is down, or a session times out, report the exact error and ask for next steps rather than retrying silently.
- **Fizzy mutations require approval**: Per `codex/.codex/config.toml`, Fizzy tools (`fizzy.card.create`, `fizzy.card.update`, `fizzy.card.archive`, etc.) require explicit approval before execution. This skill respects that flow.

## Final Report

After all syncing, report:

- **Per-source counts**: GitHub issues fetched, Slack saved items, Slack self-message lines, Outlook flagged emails, Slite actionables.
- **Fizzy changes**: Cards created (per board), updated (title/description/column/state changes), closed/archived.
- **GitHub mutations**: Issues whose Project Status field was updated (two-way pushes).
- **Conflicts detected**: Count of GitHub-wins cases (both sides changed); list each with old/new states.
- **Blocked items**: Any sources that failed to fetch, tools unavailable, or actions that required manual approval and were skipped.
- **Sync fingerprints updated**: Count of GitHub cards with updated fingerprints.

Example:

```
✅ Sync complete

📊 Fetched:
  • GitHub: 12 open issues
  • Slack saved: 3 items
  • Slack self-DM: 7 lines (5 skipped as filler)
  • Outlook: 2 flagged emails
  • Slite: 1 assigned todo

💼 Nedap board:
  • Created: 3 cards
  • Updated: 2 cards (status moved In Progress → In Review)
  • Closed: 0

🐿️ Etienne & Tech board:
  • Created: 5 cards
  • Updated: 1 card (description updated)
  • Closed: 1

🔗 GitHub mutations:
  • Updated status field: 3 issues (Fizzy → GitHub pushes)

⚠️ Conflicts detected: 1
  • conductor/dotfiles#42: GitHub "Done" vs Fizzy "In Progress" — resolved GitHub-wins, card now closed

❌ Blocked:
  • Outlook flagged email (ID xyz): unable to recover sender; skipped
```

## Quick Start

1. Ensure Preflight checks pass.
2. Run the sync (implicit approval mode will pause for Fizzy mutations).
3. Review the final report and any conflicts.
4. If GitHub-to-Fizzy pushes occurred, check the affected cards to confirm state matches expectations.
