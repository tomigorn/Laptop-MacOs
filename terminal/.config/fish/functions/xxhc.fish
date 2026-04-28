function xxhc --description "xxh with SSH alias forwarded to remote prompt"
    set -l target $argv[1]
    set -l host_db ~/.xxh/history/$target.db
    set -l remote_preseed /tmp/.xxh_atuin_pre_$target.db
    set -l remote_db /tmp/.xxh_atuin_$target.db
    set -l local_db ~/.local/share/atuin/history.db
    set -l tmp_db /tmp/.xxh_atuin_$target\_local.db

    # Pre-seed remote with this host's accumulated history.
    # Validate it has a history table, then send a clean WAL-free single-file copy.
    if test -f $host_db
        set -l has_table (sqlite3 $host_db "SELECT name FROM sqlite_master WHERE type='table' AND name='history';" 2>/dev/null)
        if test "$has_table" = history
            set -l clean_preseed /tmp/.xxh_atuin_pre_clean_$target.db
            sqlite3 $host_db "VACUUM INTO '$clean_preseed';" 2>/dev/null
            and scp -q -o ControlMaster=no -o ControlPath=none $clean_preseed "$target:$remote_preseed" 2>/dev/null
            rm -f $clean_preseed
        end
    end

    set -l start (date +%s)
    env RSYNC_RSH=~/.xxh/ssh-wrapper.sh xxh $target \
        +e "XXH_SSH_ALIAS=$target" \
        +e "XXH_CONNECT_START=$start" \
        $argv[2..-1]

    # Retrieve remote atuin DB — fetch main file plus WAL files (SQLite WAL mode
    # keeps recent writes in the -wal file; without it the DB appears empty).
    if scp -q -o ControlMaster=no -o ControlPath=none "$target:$remote_db" $tmp_db 2>/dev/null
        scp -q -o ControlMaster=no -o ControlPath=none "$target:$remote_db-wal" $tmp_db-wal 2>/dev/null
        scp -q -o ControlMaster=no -o ControlPath=none "$target:$remote_db-shm" $tmp_db-shm 2>/dev/null

        # Checkpoint WAL into the main DB file so all data is in one place.
        # Without this, the main file may have no schema (it's all in the WAL)
        # and subsequent ATTACH and VACUUM INTO operations see an empty DB.
        sqlite3 $tmp_db "PRAGMA wal_checkpoint(FULL);" 2>/dev/null

        # sqlite3 now reads the fully checkpointed main file
        sqlite3 $local_db "
            ATTACH '$tmp_db' AS remote;
            INSERT OR IGNORE INTO main.history SELECT * FROM remote.history;
            DETACH remote;
        " 2>/dev/null
        and echo "  History from $target merged into local atuin"

        # Accumulate per-host history for future connects.
        # Use VACUUM INTO to produce a clean single-file DB (no WAL artifacts).
        mkdir -p ~/.xxh/history
        if test -f $host_db
            sqlite3 $host_db "
                ATTACH '$tmp_db' AS new_session;
                INSERT OR IGNORE INTO main.history SELECT * FROM new_session.history;
                DETACH new_session;
            " 2>/dev/null
        else
            sqlite3 $tmp_db "VACUUM INTO '$host_db';" 2>/dev/null
        end

        ssh -q -o ControlMaster=no -o ControlPath=none $target \
            "rm -f $remote_db $remote_db-wal $remote_db-shm $remote_preseed" 2>/dev/null
        rm -f $tmp_db $tmp_db-wal $tmp_db-shm
    end

    # Verify xxh cleaned up ~/.xxh on the remote — if it's still there, other users can see it
    if ssh -q -o ControlMaster=no -o ControlPath=none -o ConnectTimeout=10 $target "test -d ~/.xxh" 2>/dev/null
        set_color --bold red
        echo ""
        echo "  ╔══════════════════════════════════════════════════════════════╗"
        echo "  ║                    CLEANUP FAILURE                           ║"
        echo "  ║                                                              ║"
        printf "  ║  ~/.xxh was NOT removed on %-34s║\n" "$target "
        echo "  ║  Other users on this shared host can see your files.         ║"
        echo "  ║                                                              ║"
        printf "  ║  Fix now:  ssh %s \"rm -rf ~/.xxh\"\n" $target
        echo "  ║                                                              ║"
        echo "  ╚══════════════════════════════════════════════════════════════╝"
        echo ""
        set_color normal
    end
end
