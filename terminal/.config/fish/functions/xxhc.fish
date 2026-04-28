function xxhc --description "xxh with SSH alias forwarded to remote prompt"
    set -l target $argv[1]
    env RSYNC_RSH=~/.xxh/ssh-wrapper.sh xxh $target +e "XXH_SSH_ALIAS=$target" $argv[2..-1]
end
