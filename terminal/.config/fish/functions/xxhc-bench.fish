function _xxhc_bench_now
    set -l t (date +%s.%N 2>/dev/null)
    string match -qr '^[0-9]+(\.[0-9]+)?$' -- "$t"; or set t (date +%s)
    echo $t
end

function _xxhc_bench_connect_secs --description "seconds from the last 'Connected in Xs' line on stdin"
    cat | string replace -ra '\e\[[0-9;?]*[A-Za-z]' '' | string match -r --groups-only 'Connected in ([0-9]+(?:\.[0-9]+)?)s' | tail -n 1
end

function _xxhc_bench_route -a host
    if ssh -G $host 2>/dev/null | string match -qr '^proxyjump (?!none$)'
        echo jump
    else
        echo direct
    end
end

function _xxhc_bench_fmt
    printf '%.1f\n' $argv
end

function xxhc-bench --description "time xxhc connects per host and log them to terminal/benchmarks.md"
    set -l usage "Usage: xxhc-bench [-n N] [--net LABEL] [host…]

Connects N times to each host with 'xxhc <host> +hc fish_greeting' and appends one row per host to terminal/benchmarks.md.

  -n N           runs per host (default 5)
  --net LABEL    network the run was made on, e.g. office, vpn, home (default -)
  -h, --help     this help

Hosts default to root6 (jump host) and itet-ifa-comp01 (direct).

Examples:
  xxhc-bench --net office
  xxhc-bench -n 3 --net vpn root6"

    argparse 'h/help' 'n=' 'net=' -- $argv 2>/dev/null
    or begin
        echo "xxhc-bench: unknown or incomplete option" >&2
        echo "  try: xxhc-bench --help" >&2
        return 2
    end
    if set -q _flag_help
        echo $usage
        return 0
    end

    set -l runs 5
    if set -q _flag_n
        if not string match -qr '^[1-9][0-9]*$' -- $_flag_n
            echo "xxhc-bench: -n needs a whole number of 1 or more, got '$_flag_n'" >&2
            echo "  try: xxhc-bench --help" >&2
            return 2
        end
        set runs $_flag_n
    end
    set -l net -
    set -q _flag_net; and set net $_flag_net
    set -l hosts $argv
    test (count $hosts) -eq 0; and set hosts root6 itet-ifa-comp01

    set -l repo_terminal (realpath (dirname (realpath (status -f)))/../../..)
    set -l file $repo_terminal/benchmarks.md
    set -q XXHC_BENCH_FILE; and set file $XXHC_BENCH_FILE
    set -l setup_version (string trim < $repo_terminal/SETUP_VERSION 2>/dev/null)
    test -n "$setup_version"; or set setup_version '?'
    set -l today (date +%Y-%m-%d)

    if not test -s $file
        printf '%s\n' \
            '# xxhc benchmarks' \
            '' \
            'One row per host and `xxhc-bench` run (`terminal/terminal.md`, "Benchmark"). Times in seconds; failed runs count in Runs but not in the times.' \
            '' \
            '- Connect: the greeting'"'"'s `Connected in`, until the prompt would appear.' \
            '- Total: the whole `xxhc` call, connect and teardown.' \
            '' \
            '| Date | Version | Host | Route | Net | Runs | Connect avg | Connect min | Connect max | Total avg |' \
            '|---|---|---|---|---|---|---|---|---|---|' > $file
    end

    set -l failed_hosts
    for host in $hosts
        set -l route (_xxhc_bench_route $host)
        set -l connects
        set -l totals
        for i in (seq $runs)
            set -l t0 (_xxhc_bench_now)
            set -l secs (xxhc $host +hc fish_greeting 2>&1 | _xxhc_bench_connect_secs)
            set -l t1 (_xxhc_bench_now)
            set -l total (math "$t1 - $t0")
            if test -n "$secs"
                set -a connects $secs
                set -a totals $total
                echo "  $host $i/$runs: connect "(_xxhc_bench_fmt $secs)" s, total "(_xxhc_bench_fmt $total)" s"
            else
                set_color yellow
                echo "  $host $i/$runs: failed (no 'Connected in' line)"
                set_color normal
            end
        end

        set -l ok (count $connects)
        set -l cells – – – –
        if test $ok -gt 0
            set -l sorted (printf '%s\n' $connects | sort -n)
            set cells (_xxhc_bench_fmt (math "("(string join + $connects)") / $ok") $sorted[1] $sorted[-1] (math "("(string join + $totals)") / $ok"))
        else
            set -a failed_hosts $host
        end
        echo "| $today | $setup_version | $host | $route | $net | $ok/$runs | "(string join ' | ' $cells)" |" >> $file
    end

    echo
    echo "  Results: open $file"
    if test (count $failed_hosts) -gt 0
        set_color yellow
        for h in $failed_hosts
            echo "  No connect to $h succeeded; try it by hand: xxhc $h"
        end
        set_color normal
        return 1
    end
end
