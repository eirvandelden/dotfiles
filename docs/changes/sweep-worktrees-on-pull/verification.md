# Verification: Sweep merged worktrees on pull

Plan step 12, run by hand on 2026-10-09 against the branch at `ff5c89ff` (lefthook 2.2.1, git 2.54.0, macOS).

## Setup

A scratch `HOME` makes the branch's files the ones the hooks use, as a restow would:

- `$SCRATCH/home/Developer/dotfiles/lefthook.yml`: a copy of the branch's `lefthook.yml`, the fallback config the shims load.
- `$SCRATCH/home/.config/git/worktree-tools`: a link to the branch's `git/.config/git/worktree-tools`.
- `$SCRATCH/hooks`: a copy of the branch's `git/.config/git/hooks`, set as `core.hooksPath` in a scratch global gitconfig with `pull.rebase = true`.
- `gh` is real but logged out under the scratch `HOME`, so the sweep decides on the ancestor rule; herdr is real.

The script, run as `env S=$SCRATCH HOME=$SCRATCH/home GIT_CONFIG_GLOBAL=$SCRATCH/gitconfig GIT_CONFIG_NOSYSTEM=1 sh run.sh`:

```sh
set -e
cd "$S"
git init -q --bare origin.git
git clone -q origin.git seed && cd seed && echo initial > README && git add README && git commit -q -m initial && git push -q --no-verify origin main && cd ..
git clone -q origin.git repo && cd repo
echo .worktrees > .git/info/exclude
echo '$ git worktree add .worktrees/foo -b foo origin/main; commit; git push -u origin foo'
git worktree add -q .worktrees/foo -b foo origin/main
echo foo > .worktrees/foo/foo.txt && git -C .worktrees/foo add foo.txt && git -C .worktrees/foo commit -q -m "foo work"
git -C .worktrees/foo push -q -u origin foo
echo "$ (elsewhere, as GitHub does) git merge --no-ff origin/foo; git push origin main"
git -C ../seed fetch -q origin && git -C ../seed -c user.name=GitHub -c user.email=noreply@github.com merge -q --no-ff -m "Merge pull request #1 from foo" origin/foo && git -C ../seed push -q --no-verify origin main
echo '$ git worktree list'
git worktree list
echo '$ time git pull'
start=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
git pull 2>&1 | grep -vE '^\s*$' | sed 's/\x1b\[[0-9;]*m//g'
end=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
echo "pull returned after $(echo "$end - $start" | bc) s"
echo '$ git worktree list   # right after the prompt returns'
git worktree list
for i in $(seq 1 100); do [ -d .worktrees/foo ] || break; sleep 0.1; done
echo "\$ git worktree list   # after $(echo "$i * 0.1" | bc) s more"
git worktree list
echo '$ git branch --list foo'
git branch --list foo
echo '$ cat .git/worktree-sweep.lock exists?'; ls .git/worktree-sweep.lock
```

The two pushes to `main` use `--no-verify` because they stand in for GitHub's merge, and the global `no-push-to-main` hook would refuse them.

## Output

Hook banners from the setup steps are left out.

```text
$ (elsewhere, as GitHub does) git merge --no-ff origin/foo; git push origin main
$ git worktree list
$SCRATCH/repo                68ec25e [main]
$SCRATCH/repo/.worktrees/foo 2acbcea [foo]
$ time git pull
From $SCRATCH/origin
   68ec25e..7d48ba3  main       -> origin/main
Updating 68ec25e..7d48ba3
Fast-forward
 foo.txt | 1 +
 1 file changed, 1 insertion(+)
 create mode 100644 foo.txt
╭─────────────────────────────────────────╮
│ 🥊 lefthook  v2.2.1   hook:  post-merge │
╰─────────────────────────────────────────╯
┃  sweep-worktrees ❯ 
┃  migrations ❯ 
╭─────────────────────────────────────────╮
│ 🥊 lefthook  v2.2.1   hook:  migrations │
╰─────────────────────────────────────────╯
│  bundle (skip) no files for inspection
│  migrate (skip) no files for inspection
│  client-dependencies (skip) no files for inspection
  ────────────────────────────────────
summary: (done in 0.00 seconds)
  ────────────────────────────────────
summary: (done in 0.25 seconds)
✔️ sweep-worktrees (0.19 seconds)
✔️ migrations (0.23 seconds)
pull returned after .772 s
$ git worktree list   # right after the prompt returns
$SCRATCH/repo                7d48ba3 [main]
$SCRATCH/repo/.worktrees/foo 2acbcea [foo]
$ git worktree list   # after .6 s more
$SCRATCH/repo 7d48ba3 [main]
$ git branch --list foo
$ cat .git/worktree-sweep.lock exists?
.git/worktree-sweep.lock
```

The prompt came back after 0.77 s with `.worktrees/foo` still listed. 0.6 s later the worktree and the local branch `foo` were gone.

## Observed along the way

- With a fast-forward merge (`--ff-only`) instead of a merge commit, `foo` and `origin/main` point at the same commit. With `gh` logged out, the sweep's existing "fresh, nothing committed yet" rule keeps such a worktree. GitHub's merge button makes a merge commit, so the run above uses `--no-ff`.
- A pull whose new commits change no files (only `--allow-empty` commits) skips `sweep-worktrees` with "no files for inspection". The hook-level `files:` list that `migrations` uses is empty, and lefthook then skips every command of the hook.
