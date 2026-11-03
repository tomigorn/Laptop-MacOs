#!/opt/homebrew/bin/fish
# Characterizes ssh-why in offline mode against a fixture ssh config (never -c/--connect).
#   ssh/tests/ssh-why.fish
set -l here (cd (dirname (status -f)); and pwd)
set -g SSHWHY_SRC $here/../ssh-why.fish

set -g WORK (mktemp -d)
function cleanup --on-event fish_exit
    rm -rf $WORK
end
mkdir -p $WORK/bin $WORK/home/.ssh
set -gx HOME $WORK/home
set -gx TMPDIR $WORK

printf '#!/bin/sh\nexec /usr/bin/ssh -F "%s" "$@"\n' $HOME/.ssh/config-test > $WORK/bin/ssh
chmod +x $WORK/bin/ssh
set -gx PATH $WORK/bin $PATH

printf '%s\n' \
    'Host jump' \
    '  HostName jump.example.com' \
    '  User jumper' \
    '  Port 2222' \
    "  IdentityFile $HOME/.ssh/id_jump" \
    '  IdentitiesOnly yes' \
    'Host inner' \
    '  HostName inner.example.com' \
    '  User jane' \
    '  ProxyJump jump' \
    "  IdentityFile $HOME/.ssh/id_inner" \
    'Match host inner.example.com' \
    '  Port 2200' \
    'Match originalhost inner' \
    '  Compression yes' \
    'Match exec "true"' \
    '  ServerAliveInterval 7' \
    'Match exec "false"' \
    '  ServerAliveInterval 9' \
    'Host loopa' \
    '  ProxyJump loopb' \
    'Host loopb' \
    '  ProxyJump loopa' \
    'Host viacmd' \
    '  HostName cmd.example.com' \
    '  ProxyCommand nc %h %p' > $HOME/.ssh/config-test

set -g fails 0
set -g AT @
function check -a name
    if $argv[2..-1]
        echo "PASS  $name"
    else
        echo "FAIL  $name"
        set fails (math $fails + 1)
    end
end
function plain
    cat | string replace -ra '\e\[[0-9;?]*[A-Za-z]' ''
end
function lacks -a text pattern
    not string match -q -- "*$pattern*" $text
end
function has -a text pattern
    string match -q -- "*$pattern*" $text
end

source $SSHWHY_SRC

# usage / args
set -l out (ssh-why 2>&1 | plain | string collect)
check "no host: usage" has $out "usage: ssh-why [-c|--connect] <host>"
ssh-why >/dev/null 2>&1
check "no host: exit 1" test $status -eq 1
ssh-why --help >/dev/null 2>&1
check "--help: exit 1" test $status -eq 1
set out (ssh-why --help | plain | string collect)
check "--help mentions offline default" has $out "Offline by default"
check "--help warns about Match exec" has $out "Match ... exec"
ssh-why a b >/dev/null 2>&1
check "two hosts: exit 1" test $status -eq 1
ssh-why --bogus x >/dev/null 2>&1
check "unknown flag: exit 1" test $status -eq 1

# single host
set out (ssh-why jump | plain | string collect)
check "single host: header" has $out "ssh jump"
check "single host: target hop" has $out "hop 1/1  jump  (target)"
check "single host: connects-to line" has $out "jumper"$AT"jump.example.com:2222"
check "single host: key listed" has $out "$HOME/.ssh/id_jump"
check "single host: identitiesonly yes" has $out "identitiesonly yes"
check "single host: no via line" lacks $out "via "
check "single host: Host block with ~ path" has $out "~/.ssh/config-test:1"
check "single host: files read listed" has $out "files read, in order:"

# ProxyJump chain, Match block
set out (ssh-why inner | plain | string collect)
check "chain: jump hop first" has $out "hop 1/2  jump  (jump host)"
check "chain: target hop second" has $out "hop 2/2  inner  (target)"
check "chain: target resolved" has $out "jane"$AT"inner.example.com:2200"
check "chain: via jump" has $out "via"
check "chain: Host block reported" has $out "Host  inner"
check "chain: Match host reported (resolved HostName)" has $out 'Match host "inner.example.com"'
check "chain: Match originalhost reported" has $out 'Match originalhost "inner"'
check "chain: Match exec that matched reported" has $out 'Match exec "true"'
check "chain: Match exec that did not match omitted" lacks $out 'exec "false"'
check "chain: order jump before target" string match -rq 'hop 1/2.*hop 2/2' -- (string replace -a \n ' ' -- $out)

# loop
set out (ssh-why loopa 2>&1 | plain | string collect)
ssh-why loopa >/dev/null 2>&1
check "loop: exit 1" test $status -eq 1
check "loop: message" has $out "ProxyJump loop: 'loopa' already in the chain. Stopping."

# ProxyCommand
set out (ssh-why viacmd | plain | string collect)
check "proxycommand shown" has $out "proxycommand   nc"
check "proxycommand: chain not followed note" has $out "chain not followed"

test $fails -eq 0
