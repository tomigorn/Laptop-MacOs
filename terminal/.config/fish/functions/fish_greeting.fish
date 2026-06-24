function fish_greeting
    fastfetch
    # Show the terminal-setup version (read live from the repo's VERSION file, so a
    # bump appears in any new shell without reloading this function). The file sits
    # at terminal/VERSION, three levels up from this function's repo location.
    set -l self (realpath (status -f) 2>/dev/null)
    if test -n "$self"
        set -l vfile (dirname $self)/../../../VERSION
        if test -f $vfile
            echo ""
            set_color brmagenta
            echo "  Tomigorn's macOS Terminal Setup — v"(cat $vfile | string trim)
            set_color normal
        end
    end
end
