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

# xxhc passes TERM=xterm-256color via +e so fish sees the right value before it
# starts (preventing the "unknown terminal" warning). This line is a fallback for
# anyone running xxh directly without xxhc.
set -x TERM xterm-256color

# ── Attach to the host's persistent ssh-agent ───────────────────────────────
# xxh runs a portable fish that never sources /etc/profile.d, so it misses the
# system ssh-key-handler that normal SSH logins use to attach to (or start) an
# ssh-agent. Without it, onward hops (e.g. `ssh opennebula`) and key-dependent
# commands re-prompt for the key passphrase on every connection.
#
# Replicate that handler: find an agent socket owned by us and attach; load keys
# if the agent is empty; start a fresh agent only if none exists. Mirrors the
# find/attach logic of /etc/profile.d/03-ssh-key-handler.sh on ETH s4d hosts.
# (ssh-add -l exit codes: 0 = has keys, 1 = reachable but empty, 2 = stale socket.)
if not set -q SSH_AUTH_SOCK; or not test -S "$SSH_AUTH_SOCK"
    set -l got_agent 0
    for sock in (find /tmp -maxdepth 2 -type s -user (whoami) -path '/tmp/ssh-*/agent.*' 2>/dev/null)
        set -gx SSH_AUTH_SOCK $sock
        ssh-add -l >/dev/null 2>&1
        set -l rc $status
        if test $rc -eq 0
            set got_agent 1; break                              # has keys — reuse, no prompt
        else if test $rc -eq 1
            test -f ~/.ssh/id_ed25519; and ssh-add ~/.ssh/id_ed25519
            test -f ~/.ssh/id_rsa; and ssh-add ~/.ssh/id_rsa
            set got_agent 1; break                              # was empty — loaded keys
        end
        # rc == 2: stale socket, try the next one
    end
    if test $got_agent -eq 0
        # No usable agent — start one (its socket lives in /tmp and survives the
        # ~/.xxh cleanup, so later logins reuse it, same as the system handler).
        set -e SSH_AUTH_SOCK
        for line in (ssh-agent -s 2>/dev/null)
            set -l kv (string match -r '^(SSH_AUTH_SOCK|SSH_AGENT_PID)=([^;]+);' -- $line)
            test (count $kv) -ge 3; and set -gx $kv[2] $kv[3]
        end
        test -f ~/.ssh/id_ed25519; and ssh-add ~/.ssh/id_ed25519
        test -f ~/.ssh/id_rsa; and ssh-add ~/.ssh/id_rsa
    end
end

if test -f $CURRENT_DIR/bin/starship; or test -f $CURRENT_DIR/bin/fastfetch; or test -f $CURRENT_DIR/bin/atuin; or test -f $CURRENT_DIR/bin/bat
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

    # clearc = clear + greeting. Shows fastfetch but not the stale
    # "Connected in Xs" line — that timer is only meaningful at connect time.
    # Plain `clear` is left alone for a fully blank screen.
    function clearc --description "clear the screen, then show the greeting"
        command clear
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

# Runs on both clean exit and SIGHUP (VPN drop, terminal crash, lost connection).
# Deletes ~/.xxh immediately so other users can't see it even if local xxhc never runs.
# Safe to delete while running: open file descriptors hold the inodes alive until exit.
function _xxhc_cleanup_home --on-event fish_exit
    rm -rf ~/.xxh 2>/dev/null
end

cd ~
