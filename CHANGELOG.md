# Changelog

## 0.1.2 (2026-04-19)

### Bug fixes

- **restack/sync**: return to original branch after restack instead of landing on the top of the stack.
- **restack/sync**: middle branches not pushed when local SHA diverges from remote (e.g. after a manual branch restore). Now compares local vs `origin/<branch>` instead of before/after rebase.

## 0.1.1 (2026-04-19)

### Bug fixes

- **restack**: removed `ancestor?` check from merged branch detection — only GitHub's `MERGED` state is now authoritative. The previous heuristic incorrectly detected stacked branches whose commits were already reachable from main (e.g. from a prior merge on a sibling branch), causing open PRs to be closed and branches to be deleted.
- **restack**: stack comments are now always updated after a restack, not only when commits were pushed.

### Improvements

- **log**: always shows the full stack from root to tip regardless of current branch.
- **version**: added `gt version` / `gt --version` / `gt -v` command.

## 0.1.0 (2026-03-01)

Initial release.
