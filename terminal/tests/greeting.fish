#!/opt/homebrew/bin/fish
# Characterizes fish_greeting and clearc against stubbed fastfetch/clear.
#   terminal/tests/greeting.fish
set -l here (cd (dirname (status -f)); and pwd)
set -g GREETING_SRC $here/../.config/fish/functions/fish_greeting.fish
set -g CLEARC_SRC $here/../.config/fish/functions/clearc.fish
set -g REAL_VERSION_FILE $here/../SETUP_VERSION

set -g WORK (mktemp -d)
function cleanup --on-event fish_exit
    rm -rf $WORK
end
mkdir -p $WORK/bin $WORK/terminal/.config/fish/functions
printf '#!/bin/sh\necho FASTFETCH\n' > $WORK/bin/fastfetch
printf '#!/bin/sh\necho CLEARED\n' > $WORK/bin/clear
chmod +x $WORK/bin/fastfetch $WORK/bin/clear
set -gx PATH $WORK/bin $PATH

set -g fails 0
function check -a name
    if $argv[2..-1]
        echo "PASS  $name"
    else
        echo "FAIL  $name"
        set fails (math $fails + 1)
    end
end
function not_has_setup
    string match -q "*FASTFETCH*" -- $argv; and not string match -q "*Terminal Setup*" -- $argv
end
function has_desc
    functions -v clearc | string match -q "*clear the screen, then show the greeting*"
end
function plain
    cat | string replace -ra '\e\[[0-9;?]*[A-Za-z]' ''
end

# fixture tree: functions copied next to a SETUP_VERSION three levels up
cp $GREETING_SRC $CLEARC_SRC $WORK/terminal/.config/fish/functions/
set -l fdir $WORK/terminal/.config/fish/functions

# 1. version line from SETUP_VERSION, trimmed
printf '9.9.9\n\n' > $WORK/terminal/SETUP_VERSION
source $fdir/fish_greeting.fish
set -l out (fish_greeting | plain | string collect)
check "greeting runs fastfetch" string match -q "*FASTFETCH*" -- $out
check "greeting shows version badge" string match -q "*Tomigorn's macOS Terminal Setup — v9.9.9  *" -- $out

# 2. bump is read live, no reload needed
printf '10.0.1\n' > $WORK/terminal/SETUP_VERSION
set out (fish_greeting | plain | string collect)
check "greeting reads version live" string match -q "*— v10.0.1  *" -- $out

# 3. no SETUP_VERSION: fastfetch only
rm $WORK/terminal/SETUP_VERSION
set out (fish_greeting | plain | string collect)
check "greeting without version file: fastfetch only" not_has_setup $out

# 4. the real repo file is picked up
source $GREETING_SRC
set -l real (string trim < $REAL_VERSION_FILE)
set out (fish_greeting | plain | string collect)
check "greeting shows repo SETUP_VERSION ($real)" string match -q "*— v$real  *" -- $out

# 5. clearc: clear, then greeting
source $CLEARC_SRC
set out (clearc | plain | string collect)
check "clearc clears first" string match -q "CLEARED*" -- $out
check "clearc then shows greeting" string match -q "*CLEARED*FASTFETCH*Terminal Setup*" -- $out
check "clearc has a description" has_desc

test $fails -eq 0
