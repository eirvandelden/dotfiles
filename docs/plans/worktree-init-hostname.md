# Make worktree-init work for repositories whose name is not a hostname

A handoff plan. Read it whole before touching anything; it is the only context you get.

## Why

`git worktree-init` is the one command that makes a fresh worktree usable: it symlinks `.env` and
`master.key` and wires up local serving. The agent workflow in `WORKTREES.md` tells every agent to
run it after creating a worktree.

In any repository whose directory name is not a valid hostname label it refuses to do anything:

```
Detecting project type...
  Type: rails
  Name: grocery-basket
  Main worktree: false

Loading configuration...
error: Invalid puma-dev name: journal_administration (must contain only lowercase letters, numbers, dots, and hyphens)
```

`journal_administration` has an underscore. Underscores are perfectly legal in directory names and
illegal in hostnames, so the check is right about hostnames but wrong to give up: the name it is
complaining about is one the tool derived itself, not one anybody typed.

The consequence is quiet and annoying: worktrees for that repository get no `.env` and no
`master.key`, and nothing tells you except an error most people scroll past. Every agent following
`WORKTREES.md` hits it.

## Root cause

In `git/.config/git/worktree-tools/lib/config.rb`:

- `build_puma_dev_name` derives the default name from the project root directory:
  `project_root_name(@path) || @detector.project_info[:name]`.
- `validate!` then rejects it unless it matches `/^[a-z0-9.-]+$/`, raising the `ConfigError` above.

So for any such repository the derived default can never pass its own validation. Check
`build_caddy_name` in the same file: it almost certainly derives a name the same way and has the same
flaw for Conductor workspaces.

## The fix, and the question it raises

Sanitise the name where it is derived, and keep the validation strict as a guard against a bad name
written by hand in a config file. Downcase, replace every run of characters outside `[a-z0-9.-]` with
a single hyphen, and trim hyphens from the ends. `journal_administration` becomes
`journal-administration`, and the app is served at `journal-administration.test`.

**Decide with the owner before starting:**

- **Is `journal-administration.test` the URL they want?** The alternative is naming it explicitly per
  project in that project's worktree config, and leaving the tool to fail loudly when it cannot
  derive one. Sanitising is the friendlier default; their call.
- **Does anything already exist under the old name?** Look in `~/.puma-dev` for entries containing
  underscores. If any exist, the change renames the URL for that project and the old symlink should
  be removed. For `journal_administration` there is nothing to break: the tool never got far enough
  to create it.

## Steps

The tool is plain Ruby with Minitest files under `test/`, run directly:

```
ruby test/config_test.rb
```

### Step 1 — a project whose name is not a hostname still gets served

RED, in `test/config_test.rb`, following the shape of the tests already there (they build temporary
directories with `Dir.mktmpdir` and clear the `CONDUCTOR_*` environment variables):

| Test | Asserts |
| --- | --- |
| `a project name with an underscore becomes a usable hostname` | for a project directory named `journal_administration`, the derived puma-dev name is `journal-administration` |
| `loading the configuration no longer refuses such a project` | `load!` does not raise for that project |
| `a name written by hand is still validated` | a config that sets `puma_dev.name` to something with an underscore still raises `ConfigError` |

Watch the first two fail with the real `ConfigError` before writing any fix.

GREEN: sanitise inside `build_puma_dev_name`, and give `build_caddy_name` the same treatment if it
shares the flaw — write its test first too. Keep the sanitising in one small private method so both
callers use the same rule.

Commit: `fix(worktree-tools): turn a project name into a hostname it can actually use`.

### Step 2 — prove it end to end

Automated tests will not catch a broken derivation of the real path, so check it for real:

1. In a repository whose name contains an underscore, create a throwaway worktree.
2. Run `git worktree-init` in it.
3. It should complete, report the puma-dev name it chose, and leave `.env` and `master.key` symlinks
   behind.
4. Remove the throwaway worktree.

**Be careful here.** These files are stowed into `~/.config/git/worktree-tools` by symlink, so editing
them in this repository changes the live command immediately, for every repository, before anything is
committed. A broken edit breaks worktree creation everywhere. Run the tests before you try the command
by hand, and do not leave the tree in a half-edited state.

If `README.md` documents the naming rule, update it in the same commit as the behaviour.

## Files this touches

- `git/.config/git/worktree-tools/lib/config.rb`
- `git/.config/git/worktree-tools/test/config_test.rb`
- `git/.config/git/worktree-tools/README.md`, if it documents the naming
- Possibly `git/.config/git/worktree-tools/lib/caddy.rb`, if the Caddy name is derived there instead

## How to verify

```
ruby test/config_test.rb
```

from `git/.config/git/worktree-tools`, plus any other test file you touched, plus the manual check in
step 2. Run the whole test directory if a runner exists for it.

Work in a worktree under `.worktrees/`, never in the main checkout, and never commit to `main`. Do not
run `stow` — these files are already symlinked, so your edits are live without it.

## Out of scope

- Renaming any repository to avoid the problem.
- Anything about stow packages, ports, or Caddy beyond the name derivation.
- The separate matter that `~/.rubocop.yml` and this machine's Ruby version management occasionally
  disagree with a project's own configuration; unrelated to this bug.
