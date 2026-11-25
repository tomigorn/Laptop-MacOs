complete -c ssh-why -f
complete -c ssh-why -s c -l connect -d 'Also connect once per hop, show the accepted key'
complete -c ssh-why -s h -l help -d 'Usage'
complete -c ssh-why -s V -l version -d 'Print the version'
# fish lists options only after a typed dash; offer them on a bare tab too
complete -c ssh-why -n 'not string match -q -- "-*" (commandline -ct)' -a '--connect' -d 'Also connect once per hop, show the accepted key'
complete -c ssh-why -n 'not string match -q -- "-*" (commandline -ct)' -a '--help' -d 'Usage'
complete -c ssh-why -n 'not string match -q -- "-*" (commandline -ct)' -a '--version' -d 'Print the version'
complete -c ssh-why -a '(__fish_print_hostnames)' -d 'Host'
