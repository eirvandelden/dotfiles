# speed-run

Vendored from a gist by `searls` (GitHub), snapshot taken 2026-10-30.

- Gist: https://gist.github.com/searls/0605331c25e839eeac40464d1c65a2e8
- Revision: `2a2a66645ce81672ead47d3640f85b73290ea39b`
- Raw file: https://gist.githubusercontent.com/searls/0605331c25e839eeac40464d1c65a2e8/raw/2a2a66645ce81672ead47d3640f85b73290ea39b/speed-run.md
- Licence: none stated in the gist.

Local changes to `SKILL.md`:

- Added `disable-model-invocation: true` to the frontmatter, matching `agents/openai.yaml`, so the skill runs only on explicit invocation.
- Session folder moved from `${CODEX_HOME:-$HOME/.codex}/speed-run/` to `$HOME/.agents/speed-run/`, so it is agent agnostic.
- No merging into the base branch: each accepted report becomes its own draft pull request, and `/finish` stays the merge approval (rules 7 and 17 of the playbook). Statuses `ready-to-merge`, `integrating` and `merged` became `ready-for-pr`, `opening-pr` and `pr-open`.
- The `foreign-subagent` skill reference became `codex exec` from Claude and `claude -p` from Codex.
- The DeviceHub step was removed.

Not tracked in `VENDORED-SKILLS.yml`: that manifest pins tagged upstream repositories, and a gist has no tag.
