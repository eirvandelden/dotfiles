# Fizzy Sync Examples

## Sync Fingerprint Examples

### New GitHub issue (first sync)

GitHub issue: `conductor/dotfiles#42 — Add Fizzy sync skill`
- Status field: "To Do"
- No existing Fizzy card

Fizzy card created:
- Title: `conductor/dotfiles#42 — Add Fizzy sync skill`
- Column: Anytime
- Description:
  ```
  Issue: https://github.com/conductor/dotfiles/issues/42
  
  Sync: github_status=To Do, fizzy_state=Anytime, last_synced=2026-07-23
  ```

### GitHub side changed

Previous fingerprint: `Sync: github_status=To Do, fizzy_state=Anytime, last_synced=2026-07-20`
Current GitHub status: "In Progress"
Current Fizzy column: Anytime

Detection:
- GitHub status "In Progress" ≠ fingerprint "To Do" ✓
- Fizzy state Anytime = fingerprint "Anytime" ✓
- **Action**: GitHub changed. Move Fizzy card to "In Progress" column.

Updated fingerprint:
```
Sync: github_status=In Progress, fizzy_state=In Progress, last_synced=2026-07-23
```

### Fizzy side changed

Previous fingerprint: `Sync: github_status=In Progress, fizzy_state=In Progress, last_synced=2026-07-20`
Current GitHub status: "In Progress"
Current Fizzy column: In Review

Detection:
- GitHub status "In Progress" = fingerprint "In Progress" ✓
- Fizzy state In Review ≠ fingerprint "In Progress" ✓
- **Action**: Fizzy changed. Update GitHub Project Status field to "In Review".

Updated fingerprint:
```
Sync: github_status=In Review, fizzy_state=In Review, last_synced=2026-07-23
```

### Conflict: both sides changed

Previous fingerprint: `Sync: github_status=In Progress, fizzy_state=In Progress, last_synced=2026-07-20`
Current GitHub status: "Done"
Current Fizzy column: In Review

Detection:
- GitHub status "Done" ≠ fingerprint "In Progress" ✓
- Fizzy state In Review ≠ fingerprint "In Progress" ✓
- **Action**: Both changed. GitHub wins. Close the Fizzy card (Done → closed).

Updated fingerprint:
```
Sync: github_status=Done, fizzy_state=closed, last_synced=2026-07-23
```

Report line:
```
⚠️ conductor/dotfiles#42: GitHub "Done" vs Fizzy "In Review" — resolved GitHub-wins, card now closed
```

## Dedup Examples

### Slack saved item vs self-DM line

Saved item:
- Permalink: `https://conductor.slack.com/archives/C1234567/p123456789`
- Text: "Review PR #15"
- Date: 2026-07-20

Self-DM line:
- Text: "Review PR #15"
- Date: 2026-07-20
- Permalink: derived from self-DM thread

**Decision**: Dedupe by normalized text + date. Create one Fizzy card; include both links in description.

### Slack self-DM line splitting

Raw message in saved-to-self DM:
```
Code review checklist:
- Review PR #15
- Run tests
- Deploy to staging
- Update docs
```

Splits into:
- "Code review checklist:" (skip, header)
- "Review PR #15" → one Fizzy card
- "Run tests" → one Fizzy card
- "Deploy to staging" → one Fizzy card
- "Update docs" → one Fizzy card

### Outlook dedup (same thread, multiple flags)

Email 1:
- Subject: "Q3 Planning"
- From: manager@conductor.com
- Date: 2026-07-20 10:30 AM
- Message link: `.../messages/ABC123`

Email 2 (forward of Email 1):
- Subject: "FW: Q3 Planning"
- From: myself@conductor.com (forwarded to self)
- Date: 2026-07-20 2:00 PM
- Message link: `.../messages/XYZ789`

**Decision**: Dedupe by normalized subject ("Q3 Planning") + sender ("manager@conductor.com"). Create one Fizzy card; note both message links.

### Slite assigned todo dedup

Document 1:
- Link: `https://slite.com/app/docs/doc-123`
- Todo: "Review security audit"
- Assigned: you
- Date: 2026-07-19

Document 2:
- Link: `https://slite.com/app/docs/doc-456` (different doc, same project)
- Text mentions: "See the security audit review in doc-123"
- Assigned/responsible: you

**Decision**: Document 2 is an incidental mention (not assigned, not marked responsible). Create Fizzy card only for Document 1.

## Column Mapping Edge Cases

### "Today" from Slack self-DM

Self-DM line: "today: review PR #15"

**Mapping**: Slack line mentions "today" → Fizzy Today column (priority signal), not Anytime.

### Outlook flagged email with ambiguous urgency

Email subject: "Information: Q3 report attached"

**Decision**: No explicit urgency marker. Default to Anytime column. If multiple follow-ups from sender suggest action, ask for clarification.

### GitHub issue with no Project / no Status field

Issue: `conductor/dotfiles#99 — Document deployment process`
- Assigned: you
- Status: open
- Project: not in any Project

**Fallback**: No Status field means no two-way sync. Create Fizzy card in Anytime column. On future syncs, skip two-way reconciliation for this issue (it will not update GitHub status based on Fizzy moves).

## Final Report Template

```
✅ Sync complete

📊 Fetched:
  • GitHub: [N] open issues assigned to you
  • Slack saved: [N] items
  • Slack self-DM: [N] lines ([M] skipped as filler)
  • Outlook: [N] flagged emails
  • Slite: [N] assigned todos

💼 Nedap board:
  • Created: [N] cards
  • Updated: [N] cards (detail changes)
  • Closed: [N]

🐿️ Etienne & Tech board:
  • Created: [N] cards
  • Updated: [N] cards (detail changes)
  • Closed: [N]

🔗 GitHub mutations:
  • Updated status field: [N] issues

⚠️ Conflicts detected: [N]
  [list each conflict with old/new states]

❌ Blocked:
  [list any fetch errors or skipped actions]

✏️ Sync fingerprints updated: [N]
```
