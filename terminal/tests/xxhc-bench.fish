#!/opt/homebrew/bin/fish
# xxhc-bench offline: xxhc, ssh and the clock are stubs, nothing connects.
#   terminal/tests/xxhc-bench.fish
set -l here (cd (dirname (status -f)); and pwd)
set -g BENCH_SRC $here/../.config/fish/functions/xxhc-bench.fish
set -g COMPL_SRC $here/../.config/fish/completions/xxhc-bench.fish
set -g SETUP_VERSION (string trim < $here/../SETUP_VERSION)

set -g WORK (mktemp -d)
function cleanup --on-event fish_exit
    rm -rf $WORK
end
mkdir -p $WORK/bin
set -gx XXHC_BENCH_FILE $WORK/benchmarks.md

# ssh -G: root6 goes through a jump host, everything else is direct
printf '%s\n' \
    '#!/bin/sh' \
    'case "$*" in' \
    '  *root6*) printf "hostname root6\nproxyjump j2admin\n" ;;' \
    '  *) printf "hostname x\nproxyjump none\n" ;;' \
    'esac' > $WORK/bin/ssh
chmod +x $WORK/bin/ssh
set -gx PATH $WORK/bin $PATH

set -g fails 0
function check -a name
    if $argv[2..-1]
        echo "PASS  $name"
    else
        echo "FAIL  $name"
        set fails (math $fails + 1)
    end
end
function eq -a got want
    if test "$got" != "$want"
        echo "      got:  $got"
        echo "      want: $want"
        return 1
    end
end

source $BENCH_SRC

# connect time from the greeting
set -l esc (printf '\e')
check "parse: plain line" eq (printf 'x\n  Connected in 2.8s\ny\n' | _xxhc_bench_connect_secs) 2.8
check "parse: coloured line" eq (printf '%s[90m  Connected in 12.4s\n%s[0m' $esc $esc | _xxhc_bench_connect_secs) 12.4
check "parse: whole seconds" eq (printf '  Connected in 3s\n' | _xxhc_bench_connect_secs) 3
check "parse: last line wins" eq (printf '  Connected in 1.0s\n  Connected in 2.0s\n' | _xxhc_bench_connect_secs) 2.0
check "parse: no line -> nothing" eq (printf 'Permission denied\n' | _xxhc_bench_connect_secs | count) 0

# route from ssh -G
check "route: proxyjump -> jump" eq (_xxhc_bench_route root6) jump
check "route: proxyjump none -> direct" eq (_xxhc_bench_route itet-ifa-comp01) direct

# end to end: xxhc and the clock are stubbed; each stub run takes 5 s of wall time
set -g STUB_OUT
set -g CLOCK 1000
function _xxhc_bench_now
    set CLOCK (math $CLOCK + 5)
    echo $CLOCK
end
set -g XXHC_CALLS
function xxhc
    set -a XXHC_CALLS "$argv"
    set -l out $STUB_OUT[1]
    set -e STUB_OUT[1]
    printf '%s\n' $out
end
set -l today (date +%Y-%m-%d)

set STUB_OUT 'Connected in 2.0s' 'Connected in 3.0s' 'Connected in 4.0s' 'Connected in 1.0s' 'Connected in 5.0s'
xxhc-bench --net office root6 >/dev/null
check "run: exit 0" eq $status 0
check "run: 5 calls by default" eq (count $XXHC_CALLS) 5
check "run: the real connect command" eq "$XXHC_CALLS[1]" "root6 +hc fish_greeting"
check "file: header on a new file" string match -q '# xxhc benchmarks*' (head -n 1 $XXHC_BENCH_FILE)
check "file: table header" string match -q -- '| Date | Version | Host | Route | Net | Runs |*' (cat $XXHC_BENCH_FILE)
check "row: averages over 5 runs" eq (tail -n 1 $XXHC_BENCH_FILE) "| $today | $SETUP_VERSION | root6 | jump | office | 5/5 | 3.0 | 1.0 | 5.0 | 5.0 |"

set XXHC_CALLS
set STUB_OUT 'Connected in 2.0s' 'ssh: connect timed out' 'Connected in 4.0s'
xxhc-bench -n 3 itet-ifa-comp01 >/dev/null
check "run: -n 3 runs 3 times" eq (count $XXHC_CALLS) 3
check "row: failed run left out, net defaults to -" eq (tail -n 1 $XXHC_BENCH_FILE) "| $today | $SETUP_VERSION | itet-ifa-comp01 | direct | - | 2/3 | 3.0 | 2.0 | 4.0 | 5.0 |"
check "file: header written once" eq (grep -c '^| Date' $XXHC_BENCH_FILE) 1

set XXHC_CALLS
set STUB_OUT x y
set -l out (xxhc-bench -n 2 itet-ifa-comp01 2>&1)
check "run: all failed -> exit 1" eq $status 1
check "row: all failed -> dashes" eq (tail -n 1 $XXHC_BENCH_FILE) "| $today | $SETUP_VERSION | itet-ifa-comp01 | direct | - | 0/2 | – | – | – | – |"
check "run: failure hint names a manual connect" string match -q '*xxhc itet-ifa-comp01*' "$out"

set XXHC_CALLS
set STUB_OUT a b c d e f g h i j
set out (xxhc-bench 2>&1)
check "run: no hosts -> root6 and itet-ifa-comp01" eq "$XXHC_CALLS[1] / $XXHC_CALLS[6]" "root6 +hc fish_greeting / itet-ifa-comp01 +hc fish_greeting"
check "run: end hint opens the file" string match -q "*open $XXHC_BENCH_FILE*" "$out"

# arguments
set XXHC_CALLS
set out (xxhc-bench --help 2>&1)
check "help: exit 0" eq $status 0
check "help: usage line" string match -q '*xxhc-bench [-n N] [--net LABEL] [host…]*' "$out"
check "help: -h too" string match -q '*Usage*' (xxhc-bench -h 2>&1)
set out (xxhc-bench -n zero 2>&1)
check "args: bad -n -> exit 2" eq $status 2
check "args: bad -n hint" string match -q '*xxhc-bench --help*' "$out"
xxhc-bench --bogus >/dev/null 2>&1
check "args: unknown flag -> exit 2" eq $status 2
check "args: nothing connected on bad args" eq (count $XXHC_CALLS) 0

# completion
complete -e -c xxhc-bench
source $COMPL_SRC
set -l bare (complete -C'xxhc-bench ')
check "completion: bare tab lists flags" string match -q -- '--net*' $bare
check "completion: flags have descriptions" string match -qr -- '^-n\t.+' $bare
check "completion: dash lists --help" string match -q -- '--help*' (complete -C'xxhc-bench --')

echo
if test $fails -eq 0
    echo "all passed"
else
    echo "$fails failed"
    exit 1
end
