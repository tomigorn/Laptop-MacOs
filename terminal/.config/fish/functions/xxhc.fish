# ── Remote-clock skew estimate ──────────────────────────────────────────────
# The connect timer is stamped on the Mac but subtracted on the remote, so a
# remote clock that is off by N seconds shifts the reported figure by N. A host
# whose clock ran ~7 min fast reported "Connected in 422.3s" for a ~2s connect.
#
# Estimate the offset the way NTP does: bracket one remote timestamp between two
# local ones and take the local midpoint as "when the remote said that". What is
# left is bounded by half the probe round trip (a fraction of a second through a
# jump host, biased slightly low because the remote's shell spawn sits on the
# outbound leg) rather than by however far the remote's clock has wandered.
#
# Prints 0 if any input is unusable. That is exactly the old, uncorrected
# behaviour, and it is the correct answer whenever the clocks are in sync.
function _xxhc_clock_skew -a remote_clock local_before local_after \
        --description "estimate how far a remote clock is ahead of this Mac"
    # `date +%s.%N` on a host without %N support prints e.g. "1787308450.N".
    # Keep the whole-second part rather than throwing the measurement away —
    # the remote greeting falls back to whole seconds on those hosts too.
    if not string match -qr '^[0-9]+(\.[0-9]+)?$' -- "$remote_clock"
        set remote_clock (string match -r '^[0-9]+' -- "$remote_clock")
    end
    for t in "$remote_clock" "$local_before" "$local_after"
        if not string match -qr '^[0-9]+(\.[0-9]+)?$' -- "$t"
            echo 0
            return
        end
    end
    set -l raw (math "$remote_clock - ($local_before + $local_after) / 2")

    # Deadband: the estimate is only good to half the probe round trip, so a
    # "skew" smaller than that is indistinguishable from zero. Report 0 there —
    # a well-synced host (the common case) then keeps exactly the accuracy it
    # had before, instead of having round-trip noise injected into its figure.
    # Corrections only kick in for skew large enough to be certainly real.
    if test (math -s0 "(abs($raw) - ($local_after - $local_before) / 2) * 1000") -le 0
        echo 0
        return
    end
    echo $raw
end

function xxhc --description "xxh with SSH alias forwarded to remote prompt"
    # ── Connect timer: start it on the very first line ──────────────────────────
    # This must come before ANY work. Everything below — the ControlMaster setup
    # (which dials through ProxyJump on jump-hosted targets), the `-O check`, the
    # arch probe, the staging-dir probe, and the history pre-seed VACUUM + scp —
    # runs before `xxh` is ever invoked, and all of it is wall-clock the user waits
    # through. Starting the timer just above the `xxh` call hid those seconds and
    # made the greeting under-report by 2-3s.
    #
    # `%N` gives sub-second precision (supported by both GNU date and macOS date);
    # the guard falls back to whole seconds on anything that doesn't support it.
    set -l start (date +%s.%N 2>/dev/null)
    string match -qr '^[0-9]+(\.[0-9]+)?$' -- "$start"; or set start (date +%s)

    set -l target $argv[1]
    set -l host_db ~/.xxh/history/$target.db
    set -l local_db ~/.local/share/atuin/history.db
    set -l tmp_db /tmp/.xxh_atuin_$target\_local.db
    set -l cm_path ~/.ssh/cm/xxh-$target
    # Unique per-session id so concurrent xxhc sessions to the SAME host don't
    # clobber each other's history-export file ($fish_pid differs per terminal).
    set -l sid $fish_pid
    # Terminal-setup version (terminal/SETUP_VERSION, three levels up from this
    # file), forwarded to the remote greeting so it shows the same version as the
    # Mac. NB: do NOT use a variable named `version` — that's reserved in fish (the
    # fish version), and `set -l version` fails, leaking fish's version downstream.
    set -l self (realpath (status -f) 2>/dev/null)
    set -l setup_version (cat (dirname $self)/../../../SETUP_VERSION 2>/dev/null | string trim)

    # Establish a ControlMaster tunnel before anything else.
    # This handles ProxyJump (and any other SSH config) once upfront so all
    # subsequent SSH/SCP calls — including xxh's own bundle upload — reuse the
    # same connection. Without this, every operation creates a fresh tunnel
    # through the jump host, which is slow and can fail for hosts behind ProxyJump.
    mkdir -p ~/.ssh/cm
    ssh -o ControlMaster=auto -o ControlPath=$cm_path -o Compression=yes -fN -o ConnectTimeout=30 $target 2>/dev/null
    # Non-fatal: if the master didn't come up, the next call with ControlMaster=auto
    # adopts the role instead and ControlPersist (~/.ssh/config) keeps it alive, so
    # reuse still happens — just one connection setup later. Warn so the extra
    # round-trip on the ProxyJump path is visible rather than silent.
    if not ssh -q -o ControlPath=$cm_path -O check $target 2>/dev/null
        set_color yellow
        echo "  xxhc: ControlMaster pre-setup failed — a later call will establish the tunnel instead."
        set_color normal
    end

    # ── Detect remote architecture and stage matching binaries ──────────────────
    # The bundle ships native binaries; uploading the wrong arch fails at exec
    # time ("Exec format error"). Detect over the ControlMaster tunnel, then copy
    # the matching store into the xxh build dir before xxh uploads it.
    #
    # The same probe carries the remote's `date` back, so the clock-skew estimate
    # below costs no extra round trip. Local timestamps bracket the ssh call so
    # the midpoint dates the remote reading (see _xxhc_clock_skew).
    set -l probe_t0 (date +%s.%N 2>/dev/null)
    set -l probe (ssh -o ControlMaster=auto -o ControlPath=$cm_path -o Compression=yes -o ConnectTimeout=10 $target 'date +%s.%N; uname -m' 2>/dev/null)
    set -l probe_t1 (date +%s.%N 2>/dev/null)
    # uname is last so it survives a remote `date` that printed nothing; the
    # clock line only counts when both came back.
    set -l remote_uname $probe[-1]
    set -l remote_clock ""
    test (count $probe) -ge 2; and set remote_clock $probe[1]
    set -l arch
    switch $remote_uname
        case x86_64 amd64
            set arch x86_64
        case aarch64 arm64
            set arch aarch64
        case '*'
            set_color --bold red
            if test -z "$remote_uname"
                echo "  xxhc: could not detect remote architecture on $target (connection failed?)."
            else
                echo "  xxhc: unsupported remote architecture '$remote_uname' on $target."
                echo "  Supported: x86_64, aarch64."
            end
            echo "  Aborting — no binaries uploaded."
            set_color normal
            ssh -q -o ControlPath=$cm_path -O stop $target 2>/dev/null
            return 1
    end

    # Rebase the connect-timer start onto the REMOTE's clock, so the greeting's
    # subtraction is honest even when that clock is minutes off. Without this the
    # remote's skew is added straight onto the reported connect time.
    set -l skew (_xxhc_clock_skew "$remote_clock" "$probe_t0" "$probe_t1")
    set -l start_remote (math "$start + $skew")
    # A clock that far out is worth knowing about in its own right (it breaks
    # certificate validity, `make`, and log correlation), so say so once.
    if test (math -s0 "abs($skew)") -ge 2
        set -l direction "ahead of"
        string match -qr '^-' -- $skew; and set direction "behind"
        set_color brblack
        echo "  xxhc: $target's clock is "(math -s1 "abs($skew)")"s $direction this Mac — connect timer corrected for it."
        set_color normal
    end

    # Each arch has its own pre-built xxh home (see setup.sh step 8) with that
    # arch's binaries already staged. Pointing `+lh` at the matching home means
    # concurrent connects to different-arch hosts never share a build dir — no
    # race — and there's no per-connect binary copy.
    set -l lxh ~/.xxh-homes/$arch
    if not test -f $lxh/.xxh/shells/xxh-shell-fish/build/fish-portable/bin/fish
        set_color --bold red
        echo "  xxhc: xxh home for $arch is missing or incomplete at $lxh"
        echo "  Run terminal/setup.sh to build it."
        set_color normal
        ssh -q -o ControlPath=$cm_path -O stop $target 2>/dev/null
        return 1
    end

    # Per-user private staging dir on the remote for history-transfer files.
    # Prefer $XDG_RUNTIME_DIR (mode 0700, auto-removed by systemd on logout); fall
    # back to a 0700 dir in /tmp. Keeps your command history out of world-readable
    # shared /tmp and leaves nothing behind even if the connection later drops.
    set -l stage (ssh -o ControlPath=$cm_path -o Compression=yes -o ConnectTimeout=10 $target \
        'd="${XDG_RUNTIME_DIR:-/tmp/.xxh-$(id -u)}"; mkdir -p "$d" && chmod 700 "$d" && printf %s "$d"' 2>/dev/null)
    test -z "$stage"; and set stage /tmp
    set -l remote_preseed "$stage/xxh_atuin_pre_$target.db"
    set -l remote_db "$stage/xxh_atuin_$target-$sid.db"

    # Pre-seed remote with this host's accumulated history.
    # Validate it has a history table, then send a clean WAL-free single-file copy.
    if test -f $host_db
        set -l has_table (sqlite3 $host_db "SELECT name FROM sqlite_master WHERE type='table' AND name='history';" 2>/dev/null)
        if test "$has_table" = history
            set -l clean_preseed /tmp/.xxh_atuin_pre_clean_$target.db
            rm -f $clean_preseed                                  # VACUUM INTO errors if the dest exists
            sqlite3 $host_db "VACUUM INTO '$clean_preseed';" 2>/dev/null
            and scp -q -o ControlPath=$cm_path -o Compression=yes $clean_preseed "$target:$remote_preseed" 2>/dev/null
            rm -f $clean_preseed
        end
    end

    env RSYNC_RSH=~/.xxh/ssh-wrapper.sh xxh $target \
        +lh $lxh \
        +e "TERM=xterm-256color" \
        +e "XXH_SSH_ALIAS=$target" \
        +e "XXH_CONNECT_START=$start_remote" \
        +e "XXH_STAGE_DIR=$stage" \
        +e "XXH_STAGE_ID=$sid" \
        +e "XXH_SETUP_VERSION=$setup_version" \
        $argv[2..-1]

    # Belt-and-suspenders: remove ~/.xxh if the fish_exit handler didn't (e.g. fish was SIGKILL'd).
    ssh -q -o ControlMaster=auto -o ControlPath=$cm_path -o Compression=yes $target "rm -rf ~/.xxh 2>/dev/null" 2>/dev/null

    # Retrieve the remote atuin DB. The remote folds its WAL into the main file when
    # it has sqlite3; when it doesn't, the -wal/-shm sidecars carry the recent rows,
    # so we fetch them too and checkpoint here (the Mac always has sqlite3). Either
    # way the merge below reads a single consolidated file.
    if scp -q -o ControlPath=$cm_path -o Compression=yes "$target:$remote_db" $tmp_db 2>/dev/null
        scp -q -o ControlPath=$cm_path -o Compression=yes "$target:$remote_db-wal" $tmp_db-wal 2>/dev/null
        scp -q -o ControlPath=$cm_path -o Compression=yes "$target:$remote_db-shm" $tmp_db-shm 2>/dev/null
        sqlite3 $tmp_db "PRAGMA wal_checkpoint(TRUNCATE);" 2>/dev/null

        # Columns are named explicitly (not SELECT *) so a schema column-order
        # change between the remote and local atuin versions can't silently
        # misalign data. sqlite errors are intentionally NOT hidden here — a failed
        # merge should be visible, not silently drop history.
        set -l cols id,timestamp,duration,exit,command,cwd,session,hostname,deleted_at
        sqlite3 $local_db "
            ATTACH '$tmp_db' AS remote;
            INSERT OR IGNORE INTO main.history ($cols) SELECT $cols FROM remote.history;
            DETACH remote;
        "
        and echo "  History from $target merged into local atuin"

        # Accumulate per-host history for future connects.
        mkdir -p ~/.xxh/history
        if test -f $host_db
            sqlite3 $host_db "
                ATTACH '$tmp_db' AS new_session;
                INSERT OR IGNORE INTO main.history ($cols) SELECT $cols FROM new_session.history;
                DETACH new_session;
            "
        else
            rm -f $host_db                                       # VACUUM INTO errors if the dest exists
            sqlite3 $tmp_db "VACUUM INTO '$host_db';"
        end

        ssh -q -o ControlPath=$cm_path -o Compression=yes $target "rm -f $remote_db $remote_db-wal $remote_db-shm $remote_preseed" 2>/dev/null
        rm -f $tmp_db $tmp_db-wal $tmp_db-shm
    end

    # Verify ~/.xxh was removed. Ask the remote to report PRESENT/ABSENT explicitly
    # so a *failed* SSH (e.g. the connection is already gone) can't be misread as
    # "verified clean" — that earlier bug printed the green all-clear on any ssh error.
    set -l xxh_state (ssh -q -o ControlPath=$cm_path -o Compression=yes -o ConnectTimeout=10 $target \
        "test -d ~/.xxh && echo PRESENT || echo ABSENT" 2>/dev/null)
    if test "$xxh_state" = PRESENT
        set_color --bold red
        echo ""
        echo "  ╔════════════════════════ CLEANUP FAILURE ════════════════════════╗"
        echo "  ║  ~/.xxh was NOT removed on $target"
        echo "  ║  Other users on this shared host can see your files."
        echo "  ║  Fix now:  ssh $target \"rm -rf ~/.xxh\""
        echo "  ╚══════════════════════════════════════════════════════════════════╝"
        echo ""
        set_color normal
    else if test "$xxh_state" = ABSENT
        set_color green
        echo "  ✓ Remote cleanup verified — ~/.xxh removed from $target, no trace left behind."
        set_color normal
    else
        # Neither token came back → the verification SSH itself failed.
        set_color yellow
        echo "  ⚠ Could not verify remote cleanup on $target (connection closed?)."
        echo "    Check later with:  ssh $target \"ls -ld ~/.xxh\""
        set_color normal
    end

    # Tear down the ControlMaster now that all operations are done
    ssh -q -o ControlPath=$cm_path -O stop $target 2>/dev/null

    # Print the local greeting so it's unmistakable you're back on the Mac
    # (the remote session shows the remote's fastfetch; this shows the local one).
    if functions -q fish_greeting
        echo ""
        fish_greeting
    end
end
