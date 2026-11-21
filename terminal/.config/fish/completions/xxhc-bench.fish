complete -c xxhc-bench -f
complete -c xxhc-bench -s n -x -d 'Runs per host (default 5)'
complete -c xxhc-bench -l net -x -a 'office vpn home' -d 'Network the run was made on'
complete -c xxhc-bench -s h -l help -d 'Usage and examples'
# fish lists options only after a typed dash; offer them on a bare tab too
complete -c xxhc-bench -n 'not string match -q -- "-*" (commandline -ct)' -a '-n' -d 'Runs per host (default 5)'
complete -c xxhc-bench -n 'not string match -q -- "-*" (commandline -ct)' -a '--net' -d 'Network the run was made on'
complete -c xxhc-bench -n 'not string match -q -- "-*" (commandline -ct)' -a '--help' -d 'Usage and examples'
complete -c xxhc-bench -n 'not string match -q -- "-*" (commandline -ct)' -a '-h' -d 'Usage and examples'
complete -c xxhc-bench -a '(__fish_print_hostnames)' -d 'Host'
