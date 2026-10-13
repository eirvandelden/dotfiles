# Intent: Replace YARD tooling with inline RBS tooling

Author: Etienne van Delden de la Haije. Status: accepted (2026-10-13). Type: chore. Delivery: autonomous.

## Problem

Personal Ruby code moves to inline RBS signatures (`#:` / `# @rbs`) for method types. The dotfiles still enforce and install the YARD tooling. The fallback RuboCop config loads `rubocop-yard` and enables six `YARD/*` cops. `packages.conf` installs `rubocop-yard`, `yard`, `yard-activesupport-concern` and `yard-solargraph`, and CI installs `rubocop-yard`. Agents and linters push YARD parameter documentation that is no longer wanted.

Nothing in the dotfiles helps to write or check inline RBS. No type checker or annotation linter is installed, and no editor shows inline types. Solargraph 0.58.1 cannot read inline RBS: it loads RBS from gem signatures and `rbs_collection.yaml` only, and it takes types for project code from YARD tags.

The skills also conflict: `rails-architecture` says "Personal: also YARD-document every method", while `ruby-style` says "Personal: no doc comments".

## Proposed outcome

Nothing in the dotfiles installs, loads or asks for YARD tooling. A fresh machine gets the tools to use inline RBS: `rbs`, `steep` and `rubocop-rbs_inline`. The fallback RuboCop config checks inline annotations. Editors show inline-type diagnostics through Steep's language server, next to Solargraph. Solargraph uses RBS for gems and the standard library. A new personal repository gets a Steepfile that reads inline annotations. Personal Ruby guidance is one consistent rule in both skills: a one-line class summary, inline RBS signatures on methods, and other comments only for a non-obvious "why". YARD documentation rules stay, as work-only guidance.

## Affected users and systems

- The fallback RuboCop config `rubocop/.rubocop.yml`, used where a repository has no RuboCop config of its own.
- `packages.conf`, read by the install scripts on a new or refreshed machine.
- The `dotfiles-tests` GitHub Actions workflow, which installs the plugins that `rubocop_fallback_test.rb` loads.
- The Solargraph config `solargraph/.config/solargraph/config.yml`.
- Editor LSP wiring: Neovim (`neovim/.config/nvim/lsp/`, `lua/core/lsp.lua`), Zed (`zed/.config/zed/settings.json`), VS Code (`vscode/settings.json` and any extension list).
- The `rails-architecture`, `ruby-style` and `new-repo-setup` skills, read by Claude and Codex.

## Constraints

- Approved now for autonomous delivery (rules 11 and 13):
  - edit `.github/workflows/dotfiles-tests.yml`;
  - remove `rubocop-yard`, `yard`, `yard-activesupport-concern` and `yard-solargraph` from `packages.conf`;
  - add `rbs`, `steep` and `rubocop-rbs_inline` to `packages.conf` and the CI gem install line (`rubocop-rbs_inline` pulls in `rbs-inline`);
  - add any editor extension entry that the Steep language server wiring needs.
- Config only: no `gem install`, `gem uninstall` or editor extension install on any machine (rule 8).
- Work guidance for YARD stays intact.
- `yard` remains installed as a runtime dependency of `solargraph`. That is expected and not a defect.
- Inline RBS uses the upstream RBS 4 syntax. Never add `sig/*.rbs` files or generated `.rbs` files to repositories.
- Escalation: if `rubocop-rbs_inline` (built on the `rbs-inline` 0.14 prototype) rejects valid RBS 4 inline syntax, stop and ask Etienne before going on.

## In scope

- `rubocop/.rubocop.yml`: remove `rubocop-yard` from `plugins:` and the six `YARD/*` cop entries with their heading. Load `rubocop-rbs_inline` and enable its cops explicitly (the config uses `DisabledByDefault: true`).
- `packages.conf`: remove the four YARD gems; add `rbs`, `steep` and `rubocop-rbs_inline`.
- `.github/workflows/dotfiles-tests.yml`: drop `rubocop-yard` from the gem install line, and add `rubocop-rbs_inline`.
- Solargraph config: let Solargraph use RBS for gems and the standard library.
- Editors: run Steep's language server next to Solargraph in Neovim, Zed and VS Code.
- `new-repo-setup` skill: add a Steepfile with inline annotations enabled when it sets up a personal repository.
- `rails-architecture` skill: personal guidance becomes a one-line class summary plus inline RBS signatures. Drop "Personal: also YARD-document every method". Make `@action` / `@route` tags work-only. Adjust `references/examples.md` if it implies otherwise.
- `ruby-style` skill: align the personal documentation rule with the same guidance.

## Out of scope

- Installing or uninstalling gems or editor extensions on a machine.
- Replacing Solargraph.
- `rubocop-on-rbs` (it lints `.rbs` files, which these repositories do not keep).
- Adding a Steepfile or RBS annotations to existing repositories.
- Rewriting existing YARD comments in personal projects.
- Work YARD guidance beyond labelling `@action` / `@route` as work-only.
- The VS Code `generateYard` keybinding and the `.yardoc` entries in the global git ignore.

## Acceptance criteria

- RuboCop with the fallback config runs on a Ruby file without loading `rubocop-yard`, and reports no `YARD/*` cop.
- RuboCop with the fallback config reports an offense for a malformed inline RBS annotation, and accepts a valid RBS 4 annotation such as `#: (Integer) -> String`.
- A fresh install from `packages.conf` installs `rbs`, `steep` and `rubocop-rbs_inline`, and no longer installs `rubocop-yard`, `yard-activesupport-concern` or `yard-solargraph`. `packages.conf` does not list `yard`.
- The `dotfiles-tests` workflow installs `rubocop-rbs_inline` and not `rubocop-yard`, and `rubocop_fallback_test.rb` passes locally and in CI.
- In a project with a Steepfile that enables inline annotations, opening a file in Neovim, Zed or VS Code with a wrong `#:` type shows a Steep diagnostic, and Solargraph still gives completion.
- Solargraph shows RBS types for a standard library method, such as the return type of `String#upcase`.
- An agent that runs `new-repo-setup` for a personal repository adds a Steepfile with inline annotations enabled, and `steep check` runs in that repository.
- An agent that reads `rails-architecture` or `ruby-style` for a personal project learns the same rule: one-line class summary, inline RBS method signatures, no YARD method or `@action` / `@route` docs.
- An agent that reads the same skills for a work project still gets the existing YARD rules, including `@action` / `@route`.
- `git grep -i rubocop-yard` returns nothing outside `docs/changes/`.

## Flagged concerns

- Solargraph cannot read inline RBS, but it stays the main editor language server. Chosen side: add Steep's language server next to Solargraph. Solargraph keeps completion and gem/stdlib RBS; Steep supplies inline-type diagnostics.

## Open questions

None.
