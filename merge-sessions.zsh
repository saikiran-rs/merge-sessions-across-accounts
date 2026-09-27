#!/bin/zsh
# Merge Claude Desktop's Claude Code sessions across every account signed in on this Mac,
# so each account's session list shows all of them. Unofficial, not affiliated with Anthropic.
# https://github.com/saikiran-rs/merge-sessions-across-accounts
#
#   ./merge-sessions.zsh -n   dry run: show what would change
#   ./merge-sessions.zsh      quit Claude, merge (backs up first), reopen Claude
#
# Every session file is copied to every account folder, and the newest copy wins.
# Deletes sync too: the app leaves a deleted_<id> file when you delete a session, so the session
# is removed from every account instead of being copied back (unless it was used again later).

APP=${MERGE_SESSIONS_APP:-Claude}   # overridable so the tests never touch the real app

main() {
  emulate -L zsh
  local dry=0 reopen=0 rc usage="usage: merge-sessions.zsh [-n]   (-n = dry run: show what would change)"
  [[ $1 == (-h|--help) ]] && { echo "$usage"; return 0 }
  [[ $1 == -n ]] && { dry=1; shift }
  (( $# )) && { echo "$usage" >&2; return 2 }
  # quit the app first so its in-memory copies are saved now, not over the merge later.
  # pgrep skips our own ancestors unless -a, so a match only with -a means we run inside the app.
  if (( ! dry )) && pgrep -axq "$APP"; then
    pgrep -xq "$APP" || { echo "Run this from Terminal, not from inside $APP: it has to quit $APP." >&2; return 1 }
    echo "Quitting $APP..."
    osascript -e "quit app \"$APP\"" >/dev/null || { echo "Couldn't quit $APP; nothing changed." >&2; return 1 }
    local i
    for i in {1..30}; do pgrep -xq "$APP" || break; sleep 1; done
    pgrep -xq "$APP" && { echo "$APP didn't quit; nothing changed." >&2; return 1 }
    reopen=1
  fi
  merge; rc=$?
  (( reopen )) && { echo "Reopening $APP."; open -a "$APP" }
  return $rc
}

merge() {
  setopt local_options extended_glob null_glob
  local BASE="$HOME/Library/Application Support/Claude/claude-code-sessions"
  [[ -d "$BASE" ]] || { echo "No claude-code-sessions dir found." >&2; return 1 }
  local dirs=( "$BASE"/*/*(/) )
  # session records + delete tombstones (never the app's half-written *.tmp* files)
  local files=( "$BASE"/*/*/(local_*.json|deleted_[^.]##)(.) )
  (( ${#files} )) || { echo "No sessions found."; return 0 }
  # canonical (newest-by-mtime) copy of each file, keyed by filename
  local f b d dest i live=0
  typeset -A newest gone
  for f in $files; do
    b=${f:t}
    [[ -z "${newest[$b]}" || "$f" -nt "${newest[$b]}" ]] && newest[$b]="$f"
  done
  # a session is deleted if its tombstone is at least as new as its newest copy
  for b in ${(k)newest}; do
    [[ $b == local_*.json ]] || continue
    f=${newest[deleted_${${b#local_}%.json}]}
    if [[ -n "$f" && ! "${newest[$b]}" -nt "$f" ]]; then gone[$b]=$f; else (( ++live )); fi
  done
  # plan: remove deleted sessions everywhere, put the newest copy of everything else everywhere
  local -a cp_src cp_dst rm_dst
  for d in $dirs; do
    for b in ${(k)newest}; do
      dest="$d/$b"
      if (( ${+gone[$b]} )); then
        [[ -e "$dest" ]] && rm_dst+=("$dest")
      elif [[ ! -e "$dest" || "${newest[$b]}" -nt "$dest" ]]; then
        cp_src+=("${newest[$b]}"); cp_dst+=("$dest")
      fi
    done
  done
  if (( ! ${#cp_dst} && ! ${#rm_dst} )); then
    echo "Already in sync: $live session(s) in each of ${#dirs} account folder(s)."
    return 0
  fi
  if (( dry )); then
    for (( i = 1; i <= ${#cp_dst}; i++ )); do echo "copy    ${cp_dst[i]:t} -> ${${cp_dst[i]:h}#$BASE/}"; done
    for f in $rm_dst; do echo "remove  ${f:t} from ${${f:h}#$BASE/} (deleted)"; done
    echo "Dry run: would copy ${#cp_dst} and remove ${#rm_dst} file(s); nothing changed."
    return 0
  fi
  # back up only when something changes; keep mtimes so a restored backup still merges right
  local bak="$HOME/.claude/backups/claude-code-sessions-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "${bak:h}" && cp -Rp "$BASE" "$bak" || { echo "Backup failed; nothing changed." >&2; return 1 }
  # write via temp file + rename so the app never reads a half-copied session, and
  # re-check each file first in case the app wrote it since the plan was made
  local tmp n=0 r=0
  for (( i = 1; i <= ${#cp_dst}; i++ )); do
    [[ ! -e "${cp_dst[i]}" || "${cp_src[i]}" -nt "${cp_dst[i]}" ]] || continue
    tmp="${cp_dst[i]:h}/.${cp_dst[i]:t}.merging"
    if cp -p "${cp_src[i]}" "$tmp" && mv -f "$tmp" "${cp_dst[i]}"; then (( ++n )); else rm -f "$tmp"; fi
  done
  for f in $rm_dst; do
    [[ ! "$f" -nt "${gone[${f:t}]}" ]] && rm -f "$f" && (( ++r ))
  done
  local msg="Synced $n new/updated file(s)"
  (( r )) && msg+="; removed $r copy(ies) of ${#gone} deleted session(s)"
  echo "$msg; $live session(s) now in each of ${#dirs} account folder(s)."
  echo "Backup: $bak"
  (( reopen )) || echo "Open $APP to see them."
}

main "$@"
