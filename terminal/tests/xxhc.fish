#!/opt/homebrew/bin/fish
# Characterizes xxhc helpers and its early-abort paths; ssh and xxh are stubs, nothing connects.
#   terminal/tests/xxhc.fish
set -l here (cd (dirname (status -f)); and pwd)
set -g XXHC_SRC $here/../.config/fish/functions/xxhc.fish
set -g XXHCONF_SRC $here/../.xxh/xxh-config.fish

set -g WORK (mktemp -d)
function cleanup --on-event fish_exit
    rm -rf $WORK
end
mkdir -p $WORK/bin $WORK/home
set -gx HOME $WORK/home
set -gx TMPDIR $WORK
set -g SSH_LOG $WORK/ssh.log

printf '%s\n' \
    '#!/bin/sh' \
    'printf "%s\n" "$*" >> "$SSH_LOG"' \
    'case "$*" in' \
    '  *"uname -m"*) [ -n "$STUB_PROBE" ] && printf "%b\n" "$STUB_PROBE"; exit 0 ;;' \
    '  *"-O check"*) exit "${STUB_CHECK_RC:-1}" ;;' \
    'esac' \
    'exit 1' > $WORK/bin/ssh
printf '#!/bin/sh\necho XXH-CALLED >> "$SSH_LOG"\nexit 1\n' > $WORK/bin/xxh
chmod +x $WORK/bin/ssh $WORK/bin/xxh
set -gx PATH $WORK/bin $PATH
set -gx SSH_LOG $SSH_LOG

set -g fails 0
function check -a name
    if $argv[2..-1]
        echo "PASS  $name"
    else
        echo "FAIL  $name"
        set fails (math $fails + 1)
    end
end
function plain
    cat | string replace -ra '\e\[[0-9;?]*[A-Za-z]' ''
end
function has -a text pattern
    string match -q -- "*$pattern*" $text
end
function lacks -a text pattern
    not string match -q -- "*$pattern*" $text
end
function eq -a got want
    test "$got" = "$want"
end

source $XXHC_SRC

# _xxhc_clock_skew: remote_clock local_before local_after
check "skew: synced clocks -> 0" eq (_xxhc_clock_skew 1000 998 1000) 0
check "skew: remote ahead" eq (_xxhc_clock_skew 1010 998 1000) 11
check "skew: remote behind" eq (_xxhc_clock_skew 980 998 1000) -19
check "skew: inside round-trip deadband -> 0" eq (_xxhc_clock_skew 999.5 998 1000) 0
check "skew: fractional inputs" eq (_xxhc_clock_skew 1010.5 998.5 1000.5) 11
check "skew: garbage remote -> 0" eq (_xxhc_clock_skew abc 998 1000) 0
check "skew: empty remote -> 0" eq (_xxhc_clock_skew "" 998 1000) 0
check "skew: garbage local -> 0" eq (_xxhc_clock_skew 1000 x 1000) 0
check "skew: remote 'N' suffix keeps whole seconds" eq (_xxhc_clock_skew 1010.N 998 1000) 11

# _xxhc_stage_dir lives in the remote-side config; extract just that function
awk '/^function _xxhc_stage_dir/{p=1} p{print} p&&/^end/{exit}' $XXHCONF_SRC > $WORK/stage.fish
check "stage_dir function extracted" test -s $WORK/stage.fish
source $WORK/stage.fish
set -e XXH_STAGE_DIR XDG_RUNTIME_DIR
check "stage_dir: falls back to /tmp" eq (_xxhc_stage_dir) /tmp
set -gx XDG_RUNTIME_DIR /run/user/1000
check "stage_dir: XDG_RUNTIME_DIR" eq (_xxhc_stage_dir) /run/user/1000
set -gx XXH_STAGE_DIR /stage
check "stage_dir: XXH_STAGE_DIR wins" eq (_xxhc_stage_dir) /stage
set -gx XXH_STAGE_DIR ""
check "stage_dir: empty XXH_STAGE_DIR ignored" eq (_xxhc_stage_dir) /run/user/1000
set -e XXH_STAGE_DIR XDG_RUNTIME_DIR

# _xxhc_release_master: last claim out stops the master
set -l cm $WORK/cm; set -l users $cm.users
mkdir -p $users; touch $users/s1 $users/s2
: > $SSH_LOG
_xxhc_release_master host1 $cm $users s1
check "release: peer claim keeps master" test ! -s $SSH_LOG
check "release: own claim removed" test ! -e $users/s1
_xxhc_release_master host1 $cm $users s2
check "release: last claim stops master" eq (cat $SSH_LOG) "-q -o ControlPath=$cm -O stop host1"
check "release: claim dir removed" test ! -e $users

# xxhc: unreachable host -> arch detection fails, abort before xxh
: > $SSH_LOG
set -gx STUB_PROBE ""
set -l out (xxhc nohost 2>&1 | plain | string collect)
xxhc nohost >/dev/null 2>&1
check "xxhc: no arch -> exit 1" test $status -eq 1
check "xxhc: no arch message" has $out "could not detect remote architecture on nohost"
check "xxhc: aborts before upload" has $out "Aborting — no binaries uploaded."
check "xxhc: master pre-setup warning" has $out "ControlMaster pre-setup failed"
check "xxhc: xxh never run" lacks (cat $SSH_LOG | string collect) XXH-CALLED
check "xxhc: claim dir cleaned" test ! -e $HOME/.ssh/cm/xxh-nohost.users

# unsupported architecture
set -gx STUB_PROBE '1000.0\nriscv64'
set out (xxhc riscvhost 2>&1 | plain | string collect)
check "xxhc: unsupported arch message" has $out "unsupported remote architecture 'riscv64' on riscvhost."
check "xxhc: lists supported archs" has $out "Supported: x86_64, aarch64."

# supported arch but no local xxh home
set -gx STUB_PROBE '1000.0\narm64'
set out (xxhc armhost 2>&1 | plain | string collect)
xxhc armhost >/dev/null 2>&1
check "xxhc: missing home -> exit 1" test $status -eq 1
check "xxhc: arm64 maps to aarch64 home" has $out "xxh home for aarch64 is missing or incomplete at $HOME/.xxh-homes/aarch64"
check "xxhc: points at setup.sh" has $out "Run terminal/setup.sh to build it."
set -gx STUB_PROBE '1000.0\namd64'
set out (xxhc amdhost 2>&1 | plain | string collect)
check "xxhc: amd64 maps to x86_64 home" has $out "xxh home for x86_64 is missing"
check "xxhc: xxh still never run" lacks (cat $SSH_LOG | string collect) XXH-CALLED

# a remote clock far off is reported before the home check
set -gx STUB_PROBE '5000.0\nx86_64'
set out (xxhc skewhost 2>&1 | plain | string collect)
check "xxhc: large skew reported" has $out "skewhost's clock is"
check "xxhc: skew says behind" has $out "behind this Mac — connect timer corrected for it."

set -gx STUB_PROBE '9999999999.0\nx86_64'
set out (xxhc aheadhost 2>&1 | plain | string collect)
check "xxhc: skew says ahead" has $out "ahead of this Mac — connect timer corrected for it."

test $fails -eq 0
