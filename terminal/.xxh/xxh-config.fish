#!/usr/bin/env fish
# xxh Fish Shell configuration file that loads xxh plugins.
set -U fish_greeting ""
set CURRENT_DIR (dirname (realpath (status current-filename)))

set -l dirs $CURRENT_DIR/../../../plugins/*/build
for pluginrc_file in (find $dirs -type f -name '*pluginrc.fish' -printf '%f\t%p\n' 2>/dev/null | sort -k1 | cut -f2)
  if  test  -f $pluginrc_file 
    set plugin_name (basename (dirname (dirname $pluginrc_file)))

    # Load plugin
    if test "$XXH_VERBOSE" = "1" -o "$XXH_VERBOSE" = "2"
      echo Load plugin $pluginrc_file
    end
    source $pluginrc_file
  end
end

# Ghostty (and other terminals) set TERM to a value the remote may not have
# terminfo for. Override to xterm-256color which is universally available and
# fully compatible — without this, fish can't position the cursor correctly and
# tab completion corrupts the display.
set -x TERM xterm-256color

if test -f $CURRENT_DIR/bin/starship; or test -f $CURRENT_DIR/bin/fastfetch; or test -f $CURRENT_DIR/bin/atuin
    set -x PATH $CURRENT_DIR/bin $PATH
end

if test -f $CURRENT_DIR/bin/starship
    set -x STARSHIP_CONFIG $CURRENT_DIR/starship.toml
    starship init fish | source
end

if test -f $CURRENT_DIR/bin/fastfetch
    function fish_greeting
        if set -q XXH_CONNECT_START; and test -n "$XXH_CONNECT_START"
            set -l elapsed (math (date +%s) - $XXH_CONNECT_START)
            printf "  Connected in %ss\n\n" $elapsed
        end
        fastfetch
    end
end

if test -f $CURRENT_DIR/bin/atuin
    # Seed atuin DB with history from previous sessions on this host
    mkdir -p $XDG_DATA_HOME/atuin
    set -l preseed /tmp/.xxh_atuin_pre_$XXH_SSH_ALIAS.db
    if test -f $preseed
        cp $preseed $XDG_DATA_HOME/atuin/history.db
        rm $preseed
    end

    mkdir -p $XDG_CONFIG_HOME/atuin
    printf 'auto_sync = false\nsearch_mode = "fuzzy"\n' > $XDG_CONFIG_HOME/atuin/config.toml
    atuin init fish | source

    function _xxhc_export_history --on-event fish_exit
        # Export atuin history to /tmp so xxhc can retrieve it after disconnect
        if set -q XXH_SSH_ALIAS; and test -n "$XXH_SSH_ALIAS"
            set -l db $XDG_DATA_HOME/atuin/history.db
            set -l dst /tmp/.xxh_atuin_$XXH_SSH_ALIAS
            if test -f $db
                cp $db $dst.db 2>/dev/null
                test -f $db-shm && cp $db-shm $dst.db-shm 2>/dev/null
                test -f $db-wal && cp $db-wal $dst.db-wal 2>/dev/null
            end
        end

        # Remove fish's generated_completions before xxh's +hhr cleanup runs.
        # On NFS home directories, files open during completion generation leave
        # .nfsXXXX stubs that cause rm to fail with "Directory not empty".
        # Removing this dir here lets xxh's chmod + rm -rf succeed cleanly.
        rm -rf $XDG_DATA_HOME/fish 2>/dev/null
    end
end

cd ~
