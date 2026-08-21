# ssh — the `~/.ssh/config.d/` layout

The SSH config is split into ordered include files. This document explains the
ordering rule, what lives in each file, and how to debug it.

> The config files themselves are **not** in this repo. They contain ETH internal
> hostnames, the jumphost topology and admin usernames, and this repository is
> public. Only this documentation is tracked.

## The two rules that drive everything

**1. `Include` splices, it doesn't append.** When ssh hits an `Include`, it reads
that file's contents *at that exact position*, as if pasted there. The position of
the `Include` line is the position of everything inside it.

**2. First match wins, per keyword.** For each keyword ssh takes the *first* value
it sees reading top-to-bottom and ignores every later one. Not the most specific —
the first.

Therefore `~/.ssh/config` lists its includes **specific → general**, with the
`Host *` defaults last.

```
~/.ssh/
├── config                    the only file ssh opens directly:
│                             the ordered Include list + Host * defaults
├── config.d/
│   ├── private.config        homelab: fastpi, beefy, tower
│   ├── jumphosts.config      every jump host, each with ProxyJump none
│   ├── exceptions.config     hosts that break their family's rules
│   ├── aliases.config        short name -> HostName. Nothing else.
│   ├── s4d.config            root*, id-s4d-*, mtec-*      (patterns)
│   ├── tik.config            ee-tik-*                     (patterns)
│   ├── legacy.config         virt*, cpuvm*, pc-*          (patterns)
│   └── eth.config            git forges, ETH central
├── keys/                     key material, grouped by scope (see below)
├── agent/  cm/               sockets and ControlMaster state
├── backup/                   dated restore points
└── known_hosts(.old)
```

Everything under `~/.ssh` is now read by ssh itself. Notably, the git signing
trust lists (`allowed_signers-*`) used to live here and do **not** any more —
nothing in ssh ever opened them, only git does via `ssh-keygen -Y verify`. They
are in `~/.config/git/`; see the Git section of the [README](../README.md).

## Where the keys live

Key files are grouped by scope under `~/.ssh/keys/`, so the top level of
`~/.ssh` holds only config, state and directories. Filenames are historical and
deliberately unchanged.

```
~/.ssh/keys/
├── eth/       tmilata.ethServers        nethz account, ETH-wide
│              tmilata.4ea.ethServers    tmil4ea, S4D admin
│              tmilata.4la.ethServers    tmil4la, ITET/TIK admin
│              sysadmin                  shared local account, legacy TIK boxes
├── homelab/   fastpi.EthMac  beefy.EthMac  tower
└── git/       gitHub-Tomigorn  gitLab-ETH
```

All nine are ED25519; there are no RSA keys. The three `*.ethServers` keys and
`sysadmin` are passphrase-protected; the homelab and git keys are not.

Moving or renaming keys is a local-only operation — `authorized_keys` on the
remote stores the public key, not the filename — but every reference has to move
with it. Beyond `config.d/`, key paths appear in `~/.gitconfig-private` and
`~/.gitconfig-work` (both `user.signingkey` and `core.sshCommand`), and in this
repo's `README.md` and `multiple-git-accounts/` templates.

To check nothing dangles after such a change:

```sh
ssh -G <host> | grep -i identityfile     # per host
```

Note that a key already loaded in the agent will keep authenticating even if the
file path is wrong, which hides the mistake. Force the file to be used:

```sh
env -u SSH_AUTH_SOCK ssh -T -o IdentityAgent=none git@github.com
```

## Two mechanics that make the pattern files work

Both are load-bearing; changing either breaks the design.

**`Match host` matches the RESOLVED hostname.** `Host` matches only the name you
typed on the command line. `Match host` matches after `HostName` substitution.
That is why `aliases.config` can set *only* `HostName` and let the family rules in
`tik.config` supply user, key and routing:

```sshconfig
# aliases.config
Host chouffe
    HostName ee-tik-nsgsrv01.ethz.ch

# tik.config -- matches because the RESOLVED name is ee-tik-nsgsrv01.ethz.ch
Match host "ee-tik-*"
    User                tmil4la
    IdentityFile        ~/.ssh/keys/eth/tmilata.4la.ethServers
    IdentitiesOnly      yes
```

`ssh chouffe` therefore inherits the whole `ee-tik-*` ruleset. It also means an
alias that resolves *out* of a namespace stops matching it: `pc-10921` resolves to
`ee-tik-nsgsrv01.ethz.ch`, so it no longer matches `legacy.config`'s `pc-*` rule
and correctly picks up the TIK rules instead.

**`IdentityFile` accumulates.** Unlike almost every other keyword, every
`IdentityFile` seen is appended to a list, and `IdentitiesOnly yes` does **not**
drop config-supplied entries — it only stops the *agent* volunteering extras.

A global `IdentityFile` in `Host *` is therefore appended to every host on the
machine, costing one auth attempt against the server's `MaxAuthTries` (commonly 6)
everywhere — including `git push`. There is deliberately **no** `IdentityFile` in
`Host *`; every host names its own key.

## What goes in which file

| File | Contains | Rule |
|---|---|---|
| `private.config` | homelab hosts and their Wake-on-LAN hooks | see [ssh.md](ssh.md) |
| `jumphosts.config` | every jump host | each needs its **own** block with `User`, `IdentityFile`, `IdentitiesOnly` and `ProxyJump none` |
| `exceptions.config` | hosts whose family pattern would be wrong | every block states **why**; if the reason expires, delete the block |
| `aliases.config` | `Host <name>` + `HostName <fqdn>` | **`HostName` only.** No `User`, no `IdentityFile`, no `ProxyJump` |
| `s4d/tik/legacy` | `Match host` pattern rules | identity + routing for whole families |
| `eth.config` | git forges and ETH central services | most general, included last |

`jumphosts.config` must precede the pattern files: the wildcards there would
otherwise hand a jump host a `ProxyJump` to itself.

The FQDN-completion rules at the **bottom** of `aliases.config` append `.ethz.ch`
to bare machine names. They must stay last in that file, because `HostName` is
first-match-wins and the specific aliases above them have to win. The `ee-tik-*`
rule carries a `!*.*` negation because `*` matches dots too — without it an
already-qualified name would be rewritten to `…ethz.ch.ethz.ch`.

## Debugging

```sh
ssh -G <host>     # the fully resolved answer for every keyword
ssh -vvv <host>   # which files were read, in what order
```

`ssh -G` is the authority. Read down the `Include` list in `~/.ssh/config` and
stop at the first file that matches.

To check a change didn't alter anything you didn't intend, diff the resolved
output before and after:

```sh
diff <(ssh -G somehost) <(ssh -G -F /path/to/old/config somehost)
```

## Gotchas worth remembering

- **`Host x ; HostName y` is not valid.** ssh has no statement separator; the `;`
  and everything after it are parsed as further *host patterns*, and `HostName` is
  never set. One directive per line.
- **Trailing words on a `Host` line are patterns, not comments.**
  `Host virt35 - nokey.xyz` defines three host patterns. Put annotations on their
  own `#` line.
- **Every jump host needs `IdentitiesOnly`.** A jump host without its own block
  falls through to `Host *`, which supplies neither the right `User` (it defaults
  to the local macOS username) nor `IdentitiesOnly`, and the hop dies with "Too
  many authentication failures".
- **Some hosts refuse `ProxyJump`.** `root-itet` has `AllowTcpForwarding`
  disabled, so `-W` is refused with "administratively prohibited". Use a netcat
  `ProxyCommand` instead, which runs in a real shell on the jump host:
  `ProxyCommand ssh -q root-itet exec nc %h %p`.
- **Local SOCKS ports collide.** `DynamicForward` values are documented in the
  header of `exceptions.config`. Two hosts sharing a port only matters if both are
  connected at once.
- **fail2ban.** `itet-hvl-503` runs fail2ban/sshguard; repeated failed logins ban
  the source for ~10 min (TCP/22 dropped while ICMP still works). Fix the
  key/account first, then test once. Do not loop over many hosts to "test" the
  config — use `ssh -G`, which touches no network at all.

## Backups

The pre-rewrite state is kept at
`~/.ssh/backup/2026-08-21-cleanup/`, with a complete snapshot in
`pre-rewrite-snapshot/` and rollback steps in `RESTORE.md`. Nothing under
`backup/` is ever read by ssh: the config uses explicit
`Include ~/.ssh/config.d/<name>.config` lines, never a glob.
