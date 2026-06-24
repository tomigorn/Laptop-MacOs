function fish_greeting
    fastfetch
    # Show the terminal-setup version (read live from the repo's SETUP_VERSION
    # file, so a bump appears in any new shell without reloading this function).
    # The file sits at terminal/SETUP_VERSION, three levels up from this function.
    set -l self (realpath (status -f) 2>/dev/null)
    if test -n "$self"
        set -l vfile (dirname $self)/../../../SETUP_VERSION
        if test -f $vfile
            echo ""
            echo -n "  "                              # indent (outside the highlight)
            set_color -b 1864ab ffffff                # highlighted badge: white on deep blue (hex, theme-proof)
            echo -n "  Tomigorn's macOS Terminal Setup — v"(cat $vfile | string trim)"  "
            set_color normal
            echo ""
        end
    end
end
