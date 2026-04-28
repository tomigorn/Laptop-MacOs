# dotfiles

Personal Mac configuration. Fish shell, starship prompt, and a portable remote environment via xxh.

## What's in here

```
.config/xxh/config.xxhc          → ~/.config/xxh/config.xxhc
.config/starship.toml             → ~/.config/starship.toml
.config/fish/config.fish          → ~/.config/fish/config.fish
.config/fish/functions/xxhc.fish  → ~/.config/fish/functions/xxhc.fish
.xxh/ssh-wrapper.sh               → ~/.xxh/ssh-wrapper.sh
.xxh/xxh-config.fish              → ~/.xxh/.xxh/shells/xxh-shell-fish/build/xxh-config.fish  (see below)
```

## Setup on a new machine

```sh
# 1. clone
git clone <repo> ~/development/private/dotfiles

# 2. symlink config files
ln -sf ~/development/private/dotfiles/.config/xxh/config.xxhc ~/.config/xxh/config.xxhc
ln -sf ~/development/private/dotfiles/.config/starship.toml ~/.config/starship.toml
ln -sf ~/development/private/dotfiles/.config/fish/config.fish ~/.config/fish/config.fish
ln -sf ~/development/private/dotfiles/.config/fish/functions/xxhc.fish ~/.config/fish/functions/xxhc.fish
ln -sf ~/development/private/dotfiles/.xxh/ssh-wrapper.sh ~/.xxh/ssh-wrapper.sh

# 3. install xxh and the fish plugin
pipx install xxh-xxh
xxh +I xxh-shell-fish

# 4. wire in the custom xxh-config.fish (can't be symlinked — lives inside another git repo)
cp ~/development/private/dotfiles/.xxh/xxh-config.fish \
   ~/.xxh/.xxh/shells/xxh-shell-fish/build/xxh-config.fish

# 5. download static Linux x86-64 binaries into ~/.xxh/bin/
#    starship  → github.com/starship/starship/releases  (starship-x86_64-unknown-linux-musl.tar.gz)
#    fzf       → github.com/junegunn/fzf/releases
#    atuin     → github.com/atuinsh/atuin/releases
mkdir -p ~/.xxh/bin
chmod +x ~/.xxh/bin/starship ~/.xxh/bin/fzf ~/.xxh/bin/atuin

# 6. stage starship into the xxh build dir
mkdir -p ~/.xxh/.xxh/shells/xxh-shell-fish/build/bin
cp ~/.config/starship.toml ~/.xxh/.xxh/shells/xxh-shell-fish/build/starship.toml
cp ~/.xxh/bin/starship     ~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/starship
chmod +x ~/.xxh/.xxh/shells/xxh-shell-fish/build/bin/starship
```

## Updating

After editing `starship.toml`, sync the copy into the xxh build dir:

```sh
cp ~/.config/starship.toml ~/.xxh/.xxh/shells/xxh-shell-fish/build/starship.toml
```

After editing `xxh-config.fish`, sync it too:

```sh
cp ~/development/private/dotfiles/.xxh/xxh-config.fish \
   ~/.xxh/.xxh/shells/xxh-shell-fish/build/xxh-config.fish
```

See `terminal/terminal.md` in the Laptop-MacOs repo for the full setup guide.
