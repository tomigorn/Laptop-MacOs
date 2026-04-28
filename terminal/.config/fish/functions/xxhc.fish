function xxhc --description "xxh with SSH alias forwarded to remote prompt"
    set -l target $argv[1]
    set -l host_db ~/.xxh/history/$target.db
    set -l remote_preseed /tmp/.xxh_atuin_pre_$target.db
    set -l remote_db /tmp/.xxh_atuin_$target.db
    set -l local_db ~/.local/share/atuin/history.db
    set -l tmp_db /tmp/.xxh_atuin_$target\_local.db

    # Pre-seed remote with this host's accumulated history from previous sessions.
    # Only send if the DB has a history table — an empty/corrupt DB is useless.
    if test -f $host_db
        set -l has_table (sqlite3 $host_db "SELECT name FROM sqlite_master WHERE type='table' AND name='history';" 2>/dev/null)
        if test "$has_table" = history
            scp -q -o ControlMaster=no -o ControlPath=none $host_db "$target:$remote_preseed" 2>/dev/null
        end
    end

    set -l start (date +%s)
    env RSYNC_RSH=~/.xxh/ssh-wrapper.sh xxh $target \
        +e "XXH_SSH_ALIAS=$target" \
        +e "XXH_CONNECT_START=$start" \
        $argv[2..-1]

    # Retrieve remote atuin history, merge into local DB, and save per-host copy
    if scp -q -o ControlMaster=no -o ControlPath=none "$target:$remote_db" $tmp_db 2>/dev/null
        sqlite3 $local_db "
            ATTACH '$tmp_db' AS remote;
            INSERT OR IGNORE INTO main.history SELECT * FROM remote.history;
            DETACH remote;
        " 2>/dev/null
        and echo "  History from $target merged into local atuin"

        # Accumulate per-host history so future connects get all previous sessions.
        mkdir -p ~/.xxh/history
        if test -f $host_db
            sqlite3 $host_db "
                ATTACH '$tmp_db' AS new_session;
                INSERT OR IGNORE INTO main.history SELECT * FROM new_session.history;
                DETACH new_session;
            " 2>/dev/null
        else
            cp $tmp_db $host_db
        end

        ssh -q -o ControlMaster=no -o ControlPath=none $target "rm -f $remote_db $remote_preseed" 2>/dev/null
        rm -f $tmp_db
    end

    # Verify xxh cleaned up ~/.xxh on the remote — if it's still there, other users can see it
    if ssh -q -o ControlMaster=no -o ControlPath=none -o ConnectTimeout=10 $target "test -d ~/.xxh" 2>/dev/null
        set_color --bold red
        echo ""
        echo "  ╔══════════════════════════════════════════════════════════════╗"
        echo "  ║                    CLEANUP FAILURE                          ║"
        echo "  ║                                                              ║"
        printf "  ║  ~/.xxh was NOT removed on %-34s║\n" "$target "
        echo "  ║  Other users on this shared host can see your files.        ║"
        echo "  ║                                                              ║"
        printf "  ║  Fix now:  ssh %s \"rm -rf ~/.xxh\"\n" $target
        echo "  ║                                                              ║"
        echo "  ╚══════════════════════════════════════════════════════════════╝"
        echo ""
        set_color normal
    end
end
