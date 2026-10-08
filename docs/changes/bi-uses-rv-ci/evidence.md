# Evidence: bi in a real Rails app

Plan step 12, run 2026-10-08 for review round 1, finding 5.

## Setup

- rv 0.7.1, Bundler 4.1.0.beta1, Rails 8.1.4, Ruby 4.0.7.
- App: `rails new bi-evidence --no-rc --minimal --skip-bundle --skip-git` in a scratch directory, so it starts without a Gemfile.lock.
- `bi` from this branch, by putting `ruby/.local/bin` first on PATH instead of a restow.
- `bin/dev` customised before the first run: one comment line appended.
- Every run had standard input from `/dev/null`, as for an agent or a hook.

## Runs

| Run | Started in | State before | Exit | Time | Result |
| --- | --- | --- | --- | --- | --- |
| 1 | app root | no Gemfile.lock | 0 | 7 s | Bundler wrote Gemfile.lock; `rv ci` installed 1 gem and skipped 69 already installed. |
| 2 | `app/models` | `gem "ostruct"` added to the Gemfile | 0 | 4 s | Bundler locked `ostruct`; `rv ci` ran from the app root. |
| 3 | app root | lockfile up to date | 0 | 2 s | Gemfile.lock byte-identical to its copy from before the run. |

In every run:

- `bin/rails app:update:bin` reported `conflict bin/dev`, then `skip bin/dev`, with no wait for input. `bin/dev` stayed byte-identical to the customised copy.
- The other binstubs were reported `identical`.
- `solargraph gems` ran last and reported "Documentation cached for all 955 gems."
- No run printed "rv ci failed", so none fell back to `bundle install`.

## Not covered here

- `command -v bi` in a Claude and a Codex session. That waits on `stow -R -t "$HOME" ruby`.
