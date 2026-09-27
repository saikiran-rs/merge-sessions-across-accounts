# merge-sessions-across-accounts

A small script for the Claude desktop app on macOS. It's unofficial and not affiliated with Anthropic.

The app keeps a separate Claude Code session list for each account. If you use more than one account on the same Mac, each account only shows its own sessions. This script merges them so that every account shows all of your sessions.

## How to run

First, sign in to the Claude desktop app with your other account. Then run this in Terminal:

```sh
git clone https://github.com/saikiran-rs/merge-sessions-across-accounts.git
cd merge-sessions-across-accounts
./merge-sessions.zsh -n   # optional: preview what would change (changes nothing)
./merge-sessions.zsh      # quits Claude, merges the sessions, reopens Claude
```

When Claude reopens, every account shows all of your sessions.

Each time you switch accounts after that, run `./merge-sessions.zsh` again from the same folder.

Use Terminal (or another terminal app), not the terminal inside the Claude app. The script has to quit Claude, which would close that terminal too.

## What it does

- If Claude is open, it quits it first so the app can't save old copies over the merge, then reopens it when done.
- Copies every session to every account. If a session was changed in more than one account, the newest copy wins.
- If you delete a session in one account, the script removes it from the others too, unless it was used again after you deleted it.
- Before changing anything, it backs up the whole sessions folder to `~/.claude/backups/claude-code-sessions-<date>-<time>/`. If nothing needs to change, it does nothing.
- It only merges session files. Scheduled tasks and other per-account data are left alone.

## Notes

- macOS only. It needs nothing beyond the built-in `zsh`.
- Sessions are stored in `~/Library/Application Support/Claude/claude-code-sessions/<account>/<org>/`.
- To undo a run, quit the app (⌘Q), then copy the files from the backup folder back into that folder.
- It relies on how the app stores sessions, which could change in an update. Tested with version 2.9939.2 of the app.
- If one of your accounts belongs to your employer, merging copies its sessions into your other accounts. Check that this is allowed first.
- `./test.zsh` runs the tests against a temporary folder, never your real sessions.

## License

Public domain ([Unlicense](LICENSE)). You're free to use, modify or share it however you like, with no attribution needed.
