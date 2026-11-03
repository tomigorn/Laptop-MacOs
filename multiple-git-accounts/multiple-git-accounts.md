# Multiple git accounts (GitHub / GitLab)

| Path | What |
|---|---|
| `.gitconfig`, `.gitconfig-private`, `.gitconfig-work` | templates for `~/`: routing by folder, identity and signing key per account |
| `.config/git/allowed_signers-*` | public keys for local signature verification |
| `.ssh/keys/git/` | example key pair names (no secrets) |
| `development/` | sample repo folders showing where each identity applies |

Install: copy the templates to the matching place under `~/`. Tests: none. Details below.

setup for multiple git accounts to automatically use a certain user when cloning a repo into a specific directory:

`~/.gitconfig` deliberately has **no `[user]` block**. It only routes by path:

```gitconfig
[includeIf "gitdir:~/development/private/"]
    path = ~/.gitconfig-private
[includeIf "gitdir:~/development/work/"]
    path = ~/.gitconfig-work
```

A commit made outside those two trees therefore fails on purpose, rather than silently picking the wrong identity: move the repo into one of them, don't set `user.name`/`user.email`.

Each included file sets five things, and all five switch together:

| | `~/development/private/` | `~/development/work/` |
|---|---|---|
| name / email | tomigorn / private-email@example.com | Jane Doe / work-email@example.com |
| signs with | `~/.ssh/keys/git/gitHub-Tomigorn.pub` | `~/.ssh/keys/git/gitLab-ETH.pub` |
| pushes with | `~/.ssh/keys/git/gitHub-Tomigorn` | `~/.ssh/keys/git/gitLab-ETH` |
| verifies against | `~/.config/git/allowed_signers-private` | `~/.config/git/allowed_signers-work` |
| `commit.gpgsign` | true | true |

**`allowed_signers-*` is the verification half.** With `gpg.format = ssh` there
are no keyservers and no web of trust, so verifying a signature needs a local
file mapping an identity to a public key — that is what `ssh-keygen -Y verify`
consumes. It contains **public** keys only, no secrets.

Format is `<identity> <options> <keytype> <key>`; `namespaces="git"` stops a
signature made over a plain file from being replayed as a commit signature.

Two consequences worth knowing:

- These files are used for **verification only**. Signing needs just
  `user.signingkey`. If they are missing or wrong, commits keep signing fine and
  you only notice when `git log --show-signature` starts reporting `U`
  (untrusted) instead of `G`.
- Each file lists only that identity's own key, so you cannot verify your work
  commits from a private repo or vice versa. To trust a colleague's signatures,
  append one line per person to the relevant file.
- GitHub's and GitLab's "Verified" badges do **not** use these files — those come
  from the public key uploaded to your account there. `allowed_signers-*` only
  affects verification on this Mac.

They live in `~/.config/git/` rather than `~/.ssh/` because nothing in ssh reads
them; only git does, via `ssh-keygen`.

`includeIf "gitdir:"` only takes effect **inside a git repository** — checking
`git config user.email` in a plain directory under `~/development/private/`
returns nothing, which looks broken but is expected.




```
~/
├── .gitconfig                  no [user] block: routes by path only
├── .gitconfig-private          identity + key + trust list for private work
├── .gitconfig-work             identity + key + trust list for work
├── .config/
│   └── git/
│       ├── allowed_signers-private   who may sign, private identity
│       └── allowed_signers-work      who may sign, work identity
├── .ssh/
│   └── keys/
│       └── git/
│           ├── gitHub-Tomigorn       signs AND pushes, private
│           ├── gitHub-Tomigorn.pub
│           ├── gitLab-ETH            signs AND pushes, work
│           └── gitLab-ETH.pub
└── development/
  ├── private/
  │   └── sample-1-private-repo/
  │   └── second-2-repo-from-private-github/
  └── work/
      └── 2-lots-of-work-repo/
      └── work-example-1-repo/
```

## Secret scan before push
[gitleaks](https://github.com/gitleaks/gitleaks) scans the commits about to be pushed.

```fish
brew install gitleaks
gitleaks git --log-opts="origin/main..HEAD"
```
