# merge-sessions-across-accounts

A small script for the Claude desktop app on macOS. It's unofficial and not affiliated with Anthropic.

The app keeps a separate Claude Code session list for each account. If you use more than one account on the same Mac, each account only shows its own sessions. This script merges them so that every account shows all of your sessions.

## How to run

```sh
git clone https://github.com/saikiran-rs/merge-sessions-across-accounts.git
cd merge-sessions-across-accounts
```

1. Quit the Claude desktop app (⌘Q).
2. Preview what would change (this changes nothing): `./merge-sessions.zsh -n`
3. Merge: `./merge-sessions.zsh`
4. Open the app again. Every account now shows all of your sessions.

Run it again whenever you've used a different account.

## What it does

- Copies every session to every account. If a session was changed in more than one account, the newest copy wins.
- If you delete a session in one account, the script removes it from the others too, unless it was used again after you deleted it.
- Before changing anything, it backs up the whole sessions folder to `~/.claude/backups/claude-code-sessions-<date>-<time>/`. If nothing needs to change, it does nothing.
- It only merges session files. Scheduled tasks and other per-account data are left alone.

## Notes

- macOS only. It needs nothing beyond the built-in `zsh`.
- Sessions are stored in `~/Library/Application Support/Claude/claude-code-sessions/<account>/<org>/`.
- To undo a run, quit the app, then copy the files from the backup folder back into that folder.
- It relies on how the app stores sessions, which could change in an update. Tested with version 2.9939.2 of the app.
- If one of your accounts belongs to your employer, merging copies its sessions into your other accounts. Check that this is allowed first.
- `./test.zsh` runs the tests against a temporary folder, never your real sessions.

## License

Public domain ([Unlicense](LICENSE)). You're free to use, modify or share it however you like, with no attribution needed.
