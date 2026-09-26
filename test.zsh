#!/bin/zsh
# Scenario tests for merge-sessions.zsh. Runs against a throwaway HOME, never your real sessions.
emulate -L zsh
setopt null_glob
SCRIPT=${0:A:h}/merge-sessions.zsh
T=$(mktemp -d) || exit 1
trap 'rm -rf -- "$T"' EXIT
export HOME=$T
B="$HOME/Library/Application Support/Claude/claude-code-sessions"
A1="$B/acct1111-0000/org11111"; A2="$B/acct2222-0000/org22222"
mkdir -p "$A1" "$A2"
pass=0 fail=0
ok()   { if eval "$2"; then (( ++pass )); print "  ok   $1"; else (( ++fail )); print "  FAIL $1   [$2]"; fi }
mk()   { print -r -- "$3" > "$1/$2"; touch -t "$4" "$1/$2" }          # dir name content time
nbak() { local b=( "$HOME"/.claude/backups/claude-code-sessions-*(/) ); print ${#b} }
run()  { print "\$ merge-sessions.zsh $*"; zsh "$SCRIPT" "$@" | sed 's/^/    /' }

print "== 1. new session in one account is copied; unchanged ones are left alone"
for s in s1 s2 s3; do mk $A1 local_$s.json "$s v1" 202609010900.00; cp -p $A1/local_$s.json $A2/; done
mk $A2 local_s4.json "s4 v1" 202609011000.00
mk $A1 archived-sessions.idx '{"v":1,"archived":[]}' 202609010900.00
mk $A1 local_s9.json.tmp "partial write" 202609011200.00            # app temp files: ignored
mk $A1 deleted_zz.tmp "123" 202609011200.00
mk $A1 deleted_zz.tmp.4f2a "123" 202609011200.00
run
ok "s4 copied to acct1"            '[[ -f $A1/local_s4.json ]]'
ok "copy kept mtime"               '[[ ! $A1/local_s4.json -nt $A2/local_s4.json && ! $A2/local_s4.json -nt $A1/local_s4.json ]]'
ok "temp files not propagated"     '[[ ! -e $A2/local_s9.json.tmp && ! -e $A2/deleted_zz.tmp && ! -e $A2/deleted_zz.tmp.4f2a ]]'
ok "idx / other files untouched"   '[[ ! -e $A2/archived-sessions.idx ]]'
ok "no leftover .merging files"    '[[ -z $(print -l $B/*/*/.*.merging(N)) ]]'
ok "one backup taken"              '[[ $(nbak) == 1 ]]'
ok "backup kept mtimes"            '[[ ! $A1/local_s1.json -nt $(print $HOME/.claude/backups/*(/[1]))/acct1111-0000/org11111/local_s1.json ]]'

print "== 2. second run is a no-op and takes no backup"
sleep 1
run
ok "still one backup"              '[[ $(nbak) == 1 ]]'

print "== 3. newer edit wins, both directions"
mk $A1 local_s1.json "s1 v2 (edited in acct1)" 202609021000.00
mk $A2 local_s2.json "s2 v2 (edited in acct2)" 202609021100.00
sleep 1; run
ok "s1 v2 reached acct2"           '[[ $(<$A2/local_s1.json) == "s1 v2 (edited in acct1)" ]]'
ok "s2 v2 reached acct1"           '[[ $(<$A1/local_s2.json) == "s2 v2 (edited in acct2)" ]]'

print "== 4. session deleted in acct1 (app removes file + writes tombstone) is removed everywhere"
rm $A1/local_s3.json
mk $A1 deleted_s3 1788339600000 202609031000.00                    # app writes Date.now() as content
mk $A1 deleted_cli-of-s3 1788339600000 202609031000.00             # ...and one per CLI transcript id
print "  dry run first:"; before=$(ls -lTR $B | shasum)
run -n
ok "dry run changed nothing"       '[[ $(ls -lTR $B | shasum) == $before ]]'
sleep 1; run
ok "s3 gone from acct2"            '[[ ! -e $A2/local_s3.json ]]'
ok "s3 not resurrected in acct1"   '[[ ! -e $A1/local_s3.json ]]'
ok "tombstones propagated"         '[[ -f $A2/deleted_s3 && -f $A2/deleted_cli-of-s3 ]]'
ok "removed copy is in backup"     '[[ -n $(print -l $HOME/.claude/backups/*/acct2222-0000/org22222/local_s3.json(N)) ]]'
sleep 1; run
ok "stable afterwards (no-op)"     '[[ $(nbak) == 3 ]]'

print "== 5. deleted in acct1 but used again in acct2 afterwards: newer session wins, kept"
rm $A1/local_s4.json; mk $A1 deleted_s4 1788426000000 202609041000.00
mk $A2 local_s4.json "s4 v2 (used after delete)" 202609041030.00
sleep 1; run
ok "s4 kept in acct2"              '[[ -f $A2/local_s4.json ]]'
ok "s4 v2 restored to acct1"       '[[ $(<$A1/local_s4.json) == "s4 v2 (used after delete)" ]]'

print "== 6. brand-new (empty) account folder receives everything, nothing is deleted"
A3="$B/acct3333-0000/org33333"; mkdir -p "$A3"
sleep 1; run
ok "acct3 has all live sessions"   '[[ -f $A3/local_s1.json && -f $A3/local_s2.json && -f $A3/local_s4.json ]]'
ok "acct3 has no deleted session"  '[[ ! -e $A3/local_s3.json ]]'
ok "acct1 kept its sessions"       '[[ -f $A1/local_s1.json && -f $A1/local_s2.json ]]'

print "== 7. backup failure aborts before any change"
mk $A2 local_s5.json "s5" 202609051000.00
chmod 500 $HOME/.claude/backups
sleep 1; run
chmod 700 $HOME/.claude/backups
ok "s5 not copied when backup fails" '[[ ! -e $A1/local_s5.json ]]'

print "== 8. arguments"
run --dry-run; ok "unknown option rejected, nothing copied" '[[ ! -e $A1/local_s5.json ]]'
ok "-h prints usage and exits 0"   'zsh $SCRIPT -h | grep -q usage'

print "\n$pass passed, $fail failed"
(( fail == 0 ))
