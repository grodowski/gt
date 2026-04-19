# gt

A lightweight CLI for managing stacked pull requests on GitHub. Stacked PRs let you split a large change into a logical chain of small, reviewable branches — each targeting the one below it rather than `main`.

`gt` handles the tedious parts: branching, pushing, PR creation, rebasing after upstream changes, and cleaning up merged branches.

## Requirements

- Ruby 3.2+
- Git
- [GitHub CLI (`gh`)](https://cli.github.com/) — authenticated and configured for your repo

## Installation

```sh
gem install gt-cli
```

## Quick start

```sh
# 1. Create a repo and clone it (or use an existing one)
gh repo create my-project --public --clone
cd my-project

# 2. Make an initial commit on main
echo "# my-project" > README.md
git add . && git commit -m "init"
git push -u origin main

# 3. Start stacking
gt create auth -m "add authentication"
# ... make more changes ...
gt create profile -m "add profile page"
# ... make more changes ...
gt create settings -m "add settings"

# 4. See the stack
gt log
# main
#   └─ auth
#      └─ profile
#         └─ settings *

# 5. After main gets new commits, rebase the whole stack:
gt sync
```

## Workflow

```
main
└─ feature-a       ← gt create feature-a -m "add auth"
   └─ feature-b    ← gt create feature-b -m "add profile page"
      └─ feature-c ← gt create feature-c -m "add settings"
```

Each `gt create` stages all current changes, creates a new branch from the current one, commits, pushes, and opens a PR targeting the parent branch.

## Commands

### `gt create <name> -m <message> [-p]`

Stage all changes, create a new branch, commit, push, and open a PR.

```sh
gt create my-feature -m "add new endpoint"

# Stage interactively (select hunks with git add --patch):
gt create my-feature -m "add new endpoint" -p
```

The parent branch and fork-point are stored in git config so `gt` can rebase correctly later.

---

### `gt log` / `gt ls`

Display the current stack. The current branch is marked with `*`.

```sh
gt log
# main
#   └─ feature-a
#      └─ feature-b *
```

---

### `gt restack`

Rebase each branch in the stack onto its updated parent using `git rebase --onto`. Run this after the parent branch gets new commits.

If the bottom PR has been merged on GitHub, `gt restack` prompts before deleting the branch and rebasing the rest:

```sh
gt restack
# PR 'feature-a' was merged. Delete branch and restack? y
# Deleted feature-a.
# Restack complete.
```

**Conflict handling:**

```sh
# Resolve the conflict, stage files, then:
gt restack --continue

# Or bail out:
gt restack --abort
```

---

### `gt modify` / `gt m` `[-m <message>] [-p]`

Amend the current branch's commit, force-push, and restack.

```sh
# Stage all changes and amend:
gt modify

# Change the commit message only:
gt modify -m "better commit message"

# Stage interactively, then amend:
gt modify -p

# Stage interactively and change the message:
gt modify -p -m "better commit message"
```

---

### `gt sync`

Pull the latest `main` (or configured main branch) and restack the whole stack on top of it.

```sh
gt sync
```

---

### Navigation

Move between branches in the stack without looking up branch names:

```sh
gt up                # move one level up (toward the tip)
gt down              # move one level down (toward main)
gt top               # jump to the tip of the stack
gt checkout [branch] # switch to a branch (interactive picker if no arg)
gt co feature-a      # shorthand
```

---

## Recipes

### Multiple commits per branch

`gt create` makes the first commit, but you can keep adding commits to the branch normally. `gt restack` replays all of them when rebasing.

```sh
gt create feature-a -m "initial scaffold"

# keep working on the same branch
git add .
git commit -m "fix edge case"
git commit -m "add tests"
git push origin feature-a

# child branches still stack and restack correctly
gt create feature-b -m "build on top"
gt restack
```

> `gt modify` amends the tip commit only. For multi-commit branches, use `git commit --amend` or `git rebase -i` directly, then `git push --force-with-lease` and `gt restack`.

---

### Split existing changes into multiple PRs

**From uncommitted changes** — stash everything, then slice with `-p`:

```sh
git stash
gt create feature-a -m "add auth" -p      # pick hunks for PR 1
gt create feature-b -m "add profile" -p   # pick hunks for PR 2
gt create feature-c -m "add settings" -p  # pick remaining hunks
git stash drop
```

If the branch already has an open PR, close it first:

```sh
gh pr close feature --comment "Splitting into smaller PRs"
```

**From a single large commit** — reset to unstage, then re-slice:

```sh
git reset main              # unstage all commits, keep working tree
git checkout main
gt create feature-a -m "add auth" -p
gt create feature-b -m "add profile" -p
```

**From separate commits** — cherry-pick each onto its own branch:

```sh
git log --oneline main..feature   # C1, C2, C3

git checkout main
gt create feature-a -m "add auth"    # cherry-pick / restage C1
gt create feature-b -m "add profile" # C2
gt create feature-c -m "add settings"# C3
git branch -D feature
```

---

## How squash merges work

When GitHub squash-merges a PR, the resulting commit SHA differs from anything in your local branch history. `gt` stores a **fork-point** (the parent branch tip at the time you branched) in git config. This lets `git rebase --onto` skip already-merged commits and replay only yours — regardless of how the PR was merged.

## Configuration

Set a custom main branch name (default: `main`):

```sh
git config gt.main-branch trunk
```

## Data stored in git config

`gt` stores metadata in your repo's git config (`.git/config`). No external state.

| Key | Value |
|-----|-------|
| `branch.<name>.gt-parent` | Name of the parent branch |
| `branch.<name>.gt-fork-point` | SHA of the parent tip at branch creation |

Restack progress is saved to `.git/gt-restack-state` (JSON) and cleared on completion or abort.
