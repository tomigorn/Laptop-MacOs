function xxhc --description "xxh with SSH alias forwarded to remote prompt"
    set -l target $argv[1]
    set -l start (date +%s)
    env RSYNC_RSH=~/.xxh/ssh-wrapper.sh xxh $target \
        +e "XXH_SSH_ALIAS=$target" \
        +e "XXH_CONNECT_START=$start" \
        $argv[2..-1]

    # Retrieve remote atuin history and merge into local DB
    set -l remote_db /tmp/.xxh_atuin_$target.db
    set -l local_db ~/.local/share/atuin/history.db
    set -l tmp_db /tmp/.xxh_atuin_$target\_local.db

    if scp -q -o ControlMaster=no -o ControlPath=none "$target:$remote_db" $tmp_db 2>/dev/null
        sqlite3 $local_db "
            ATTACH '$tmp_db' AS remote;
            INSERT OR IGNORE INTO main.history SELECT * FROM remote.history;
            DETACH remote;
        " 2>/dev/null
        and echo "  History from $target merged into local atuin"
        ssh -q -o ControlMaster=no -o ControlPath=none $target "rm -f $remote_db" 2>/dev/null
        rm -f $tmp_db
    end
end
