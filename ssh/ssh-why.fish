function ssh-why --description "Show which ssh config files, blocks and key are used to reach a host"
    argparse c/connect h/help -- $argv
    or return 1

    if set -q _flag_help; or test (count $argv) -ne 1
        echo "usage: ssh-why [-c|--connect] <host>"
        echo
        echo "  Explains how ssh resolves <host>: which config files it reads, which"
        echo "  blocks actually apply, what they resolve to, and the full ProxyJump"
        echo "  chain. Think 'ssh -vvv' with the 99% that is not about files removed."
        echo
        echo "  Offline by default -- parses config only, touches no network, ~10ms."
        echo
        echo "  -c, --connect   also open one real connection per hop (multiplexing"
        echo "                  disabled) and report which key the server accepted."
        echo "                  Costs one login per hop -- mind fail2ban on hosts"
        echo "                  that ban repeated failures."
        echo
        echo "  NOTE: 'Match ... exec' blocks run their command during config"
        echo "  parsing, so they fire even in offline mode. 'ssh-why beefy' will"
        echo "  send beefy a Wake-on-LAN packet and power the machine on."
        return 1
    end

    set -l target $argv[1]

    # ── Walk the ProxyJump chain ────────────────────────────────────────────
    # ssh -G reports the jump for one host only, so follow it ourselves.
    set -l chain
    set -l hop $target
    while test -n "$hop"
        if contains -- $hop $chain
            set_color red
            echo "  ProxyJump loop: '$hop' already in the chain. Stopping."
            set_color normal
            return 1
        end
        set chain $hop $chain          # prepend: ends up in connection order
        set -l next (ssh -G $hop 2>/dev/null | string match -r '^proxyjump (.*)' | tail -1)
        set next (string replace -r '^proxyjump ' '' -- $next)
        if test -z "$next"; or test "$next" = none
            set hop ""
        else
            set hop $next
        end
    end

    echo
    set_color --bold; echo "ssh $target"; set_color normal

    set -l i 0
    for h in $chain
        set i (math $i + 1)
        _ssh_why_hop $h $i (count $chain) $target
    end

    if set -q _flag_connect
        echo
        set_color --bold; echo "  KEY ACTUALLY ACCEPTED (one real login per hop)"; set_color normal
        for h in $chain
            _ssh_why_probe $h
        end
    end
    echo
end

function _ssh_why_hop --description "internal: report one hop of an ssh-why chain"
    set -l h $argv[1]; set -l idx $argv[2]; set -l total $argv[3]; set -l target $argv[4]

    # stderr goes to a FILE, never a pipe: with ControlPersist a backgrounded
    # master inherits the fd and a pipe would never see EOF.
    set -l log (mktemp -t ssh-why-prov)
    ssh -G -vvv $h >/dev/null 2>$log

    echo
    if test $idx -lt $total
        set_color cyan; printf '  ── hop %d/%d  %s  (jump host)\n' $idx $total $h
    else
        set_color green; printf '  ── hop %d/%d  %s  (target)\n' $idx $total $h
    end
    set_color normal

    # ── resolved essentials ────────────────────────────────────────────────
    ssh -G $h 2>/dev/null | awk '
        $1=="hostname"      {hn=$2}
        $1=="user"          {u=$2}
        $1=="port"          {p=$2}
        $1=="identitiesonly"{io=$2}
        $1=="proxyjump"     {pj=$2}
        $1=="identityfile"  {k[++n]=$2}
        $1=="proxycommand"  {$1=""; pc=substr($0,2)}
        END{
            printf "       %-14s %s@%s:%s\n", "connects to", u, hn, p
            for(j=1;j<=n;j++) printf "       %-14s %s\n", (j==1?"key":""), k[j]
            printf "       %-14s %s\n", "identitiesonly", io
            if(pj!="" && pj!="none") printf "       %-14s %s\n", "via", pj
            if(pc!=""){
                printf "       %-14s %s\n", "proxycommand", pc
                printf "       %-14s %s\n", "", "(chain not followed: the hop is inside a shell command)"
            }
        }'

    # ── which blocks applied, in read order ────────────────────────────────
    echo
    printf '       blocks that applied:\n'
    awk -v home="$HOME" '
        # Host blocks that matched
        /^debug1: .*: Applying options for / {
            line=$0
            sub(/^debug1: /,"",line)
            split(line, a, " line ")
            file=a[1]
            split(a[2], b, ": Applying options for ")
            gsub(home,"~",file)
            printf "         %-46s Host  %s\n", file ":" b[1], b[2]
        }
        # Match blocks that matched (only reported at debug3).
        # The negative form is "... : not matched \'host ...\'", so exclude it
        # explicitly -- "matched" is a substring of "not matched".
        /: matched .host / && !/not matched/ {
            line=$0
            sub(/^debug3: /,"",line)
            split(line, a, " line ")
            file=a[1]
            split(a[2], b, ": matched ")
            gsub(home,"~",file)
            printf "         %-46s Match %s\n", file ":" b[1], prevpat
        }
        /^debug2: checking match for / {
            prevpat=$0
            sub(/^debug2: checking match for .host /,"",prevpat)
            sub(/. host .*$/,"",prevpat)
            gsub(/^"|"$/,"",prevpat)
        }
    ' $log

    # ── every file read, in order ──────────────────────────────────────────
    echo
    printf '       files read, in order:\n'
    awk -v home="$HOME" '
        /^debug1: Reading configuration data / {
            f=$0; sub(/^debug1: Reading configuration data /,"",f)
            gsub(home,"~",f)
            if(f!=last){ printf "         %s\n", f; last=f }
        }' $log

    rm -f $log
end

function _ssh_why_probe --description "internal: one real login to report the accepted key"
    set -l h $argv[1]
    set -l log (mktemp -t ssh-why-conn)
    # ControlMaster/Path off so authentication really happens; a reused mux
    # session performs no key exchange and would report nothing at all.
    ssh -v -o BatchMode=yes -o ControlMaster=no -o ControlPath=none \
        -o ConnectTimeout=15 -o ConnectionAttempts=1 $h true </dev/null >/dev/null 2>$log
    set -l rc $status
    # The last "Server accepts key" belongs to this hop: any jump-host lines
    # from the proxy child are printed before it.
    set -l key (grep 'Server accepts key:' $log | tail -1 | sed 's/.*Server accepts key: //' | awk '{print $1" "$2}')
    set -l mux (grep -c 'auto-mux: Trying existing master' $log)
    printf '       %-22s ' $h
    if test $rc -eq 0; and test -n "$key"
        set_color green; printf 'OK  '; set_color normal
        echo (string replace -- "$HOME" '~' "$key")
    else if test $rc -eq 0
        set_color yellow; printf 'OK  '; set_color normal
        echo "authenticated, but no key line (agent-only, or reused a mux session)"
    else
        set_color red; printf 'FAIL '; set_color normal
        grep -m1 -iE 'permission denied|host key verification|could not resolve|connection (refused|timed out|closed)' $log \
          | sed 's/^/ /' | cut -c1-70
    end
    rm -f $log
end
