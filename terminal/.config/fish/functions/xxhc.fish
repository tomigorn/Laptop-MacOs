function xxhc --description "xxh with SSH alias forwarded to remote prompt"
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
    ssh -o ControlMaster=auto -o ControlPath=$cm_path -fN -o ConnectTimeout=30 $target 2>/dev/null
    # Non-fatal: if the master didn't come up, later calls fall back to direct
    # connections (slower). Warn rather than silently degrading the ProxyJump path.
    if not ssh -q -o ControlPath=$cm_path -O check $target 2>/dev/null
        set_color yellow
        echo "  xxhc: ControlMaster tunnel not established — continuing without connection reuse (slower)."
        set_color normal
    end

    # ── Detect remote architecture and stage matching binaries ──────────────────
    # The bundle ships native binaries; uploading the wrong arch fails at exec
    # time ("Exec format error"). Detect over the ControlMaster tunnel, then copy
    # the matching store into the xxh build dir before xxh uploads it.
    set -l remote_uname (ssh -o ControlMaster=auto -o ControlPath=$cm_path -o ConnectTimeout=10 $target uname -m 2>/dev/null)
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
    set -l stage (ssh -o ControlPath=$cm_path -o ConnectTimeout=10 $target \
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
            and scp -q -o ControlPath=$cm_path $clean_preseed "$target:$remote_preseed" 2>/dev/null
            rm -f $clean_preseed
        end
    end

    set -l start (date +%s)
    env RSYNC_RSH=~/.xxh/ssh-wrapper.sh xxh $target \
        +lh $lxh \
        +e "TERM=xterm-256color" \
        +e "XXH_SSH_ALIAS=$target" \
        +e "XXH_CONNECT_START=$start" \
        +e "XXH_STAGE_DIR=$stage" \
        +e "XXH_STAGE_ID=$sid" \
        +e "XXH_SETUP_VERSION=$setup_version" \
        $argv[2..-1]

    # Belt-and-suspenders: remove ~/.xxh if the fish_exit handler didn't (e.g. fish was SIGKILL'd).
    ssh -q -o ControlMaster=auto -o ControlPath=$cm_path $target "rm -rf ~/.xxh 2>/dev/null" 2>/dev/null

    # Retrieve the remote atuin DB. The remote folds its WAL into the main file when
    # it has sqlite3; when it doesn't, the -wal/-shm sidecars carry the recent rows,
    # so we fetch them too and checkpoint here (the Mac always has sqlite3). Either
    # way the merge below reads a single consolidated file.
    if scp -q -o ControlPath=$cm_path "$target:$remote_db" $tmp_db 2>/dev/null
        scp -q -o ControlPath=$cm_path "$target:$remote_db-wal" $tmp_db-wal 2>/dev/null
        scp -q -o ControlPath=$cm_path "$target:$remote_db-shm" $tmp_db-shm 2>/dev/null
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

        ssh -q -o ControlPath=$cm_path $target "rm -f $remote_db $remote_db-wal $remote_db-shm $remote_preseed" 2>/dev/null
        rm -f $tmp_db $tmp_db-wal $tmp_db-shm
    end

    # Verify ~/.xxh was removed. Ask the remote to report PRESENT/ABSENT explicitly
    # so a *failed* SSH (e.g. the connection is already gone) can't be misread as
    # "verified clean" — that earlier bug printed the green all-clear on any ssh error.
    set -l xxh_state (ssh -q -o ControlPath=$cm_path -o ConnectTimeout=10 $target \
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
