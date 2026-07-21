# Headroom

Context compression layer for Claude Code sessions.

## Launch

```bash
headroom wrap claude                    # full integration (preferred)
headroom wrap claude -- --model opus    # pass flags through to claude
headroom unwrap claude                  # remove durable wrapping
```

## Meta commands

```bash
headroom stats                          # token savings
headroom update                         # self-update
headroom learn                          # mine session learnings → CLAUDE.md
```
