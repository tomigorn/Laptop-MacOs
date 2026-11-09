complete -c mac-outdated -f
complete -c mac-outdated -n 'test (count (commandline -opc)) -eq 1' -l install -d 'Install every update (needs admin from Privileges)'
complete -c mac-outdated -n 'test (count (commandline -opc)) -eq 1' -s h -l help -d 'Usage and examples'
