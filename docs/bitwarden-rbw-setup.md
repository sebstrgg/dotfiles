# Bitwarden + rbw Setup Runbook

SSH keys and secrets are stored in self-hosted Vaultwarden. Both macOS and Linux use the Bitwarden vault as the SSH agent — no private key files on disk in normal operation.

## Placeholders

Replace these angle-bracket tokens with your own values throughout:

| Placeholder | Example |
|---|---|
| `<your-vaultwarden-server>` | `https://vault.example.com` |
| `<your-atuin-server>` | `https://atuin.example.com` |
| `<your-email>` | `user@example.com` |

## Server

- URL: `<your-vaultwarden-server>`
- Network: HTTPS at the configured URL; clients must resolve a reachable ingress
- Backend: self-hosted Vaultwarden behind HTTPS ingress, with its admin path protected separately
- SSH Key item type enabled via: `EXPERIMENTAL_CLIENT_FEATURE_FLAGS=ssh-key-vault-item,ssh-agent`

**If the SSH Key item type disappears from the Vaultwarden UI after a container rebuild**, the env var was not carried over. Check the Vaultwarden container definition on your server and re-add the flag.

---

## Per-device setup

### Mac mini (headless, always-on)

1. Install Bitwarden Desktop (in Brewfile)
2. Log in to `<your-vaultwarden-server>`
3. Settings → Security → enable **SSH Agent**
4. Settings → Security → set lock to **Never** (headless, always trusted)
5. System Settings → General → Login Items → add Bitwarden so it starts at boot
6. Verify: `launchctl list | grep -i bitwarden` — app should be listed

SSH authorization prompts auto-approve because the vault stays unlocked.

### Mac laptop

1. Install Bitwarden Desktop (in Brewfile)
2. Log in to `<your-vaultwarden-server>`
3. Settings → Security → enable **SSH Agent**
4. Keep the default lock timeout — Touch ID unlocks the agent when a session needs it
5. System Settings → General → Login Items → add Bitwarden

Each SSH connection triggers a Bitwarden approval prompt; approve with Touch ID.

### WSL / Linux and headless agent hosts

The vault owner unlocks both clients over an SSH terminal. Neither stores
his master password or automatically unlocks. Configure each client once:

```bash
bw-vault config server <your-vaultwarden-server>
rbw config set email <your-email>
rbw config set base_url <your-vaultwarden-server>
rbw config set pinentry pinentry-curses
rbw config set lock_timeout 43200
rbw login
```

For each working session, in the SSH terminal:

```bash
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export GPG_TTY="$(tty)"
bw-bridge       # interactive CLI login/unlock; default 12 hours
rbw unlock      # separate interactive unlock for SSH keys
ln -sfn "$XDG_RUNTIME_DIR/rbw/ssh-agent-socket" "$HOME/.bitwarden-ssh-agent.sock"
export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"
bw-vault status # reports unlocked, without printing the session
ssh-add -l      # fingerprints only
```

`bw-bridge HOURS` changes the CLI cache lifetime. Set rbw's `lock_timeout`
separately to the desired number of seconds. The socket symlink survives
reboots; the socket and both unlocks do not. Set the T3 user service's
`SSH_AUTH_SOCK=%h/.bitwarden-ssh-agent.sock` and include `%h/.local/bin` in
its PATH; shell initialization alone does not configure systemd services.
Never replace an existing socket or file at that path without inspecting it.

The Linux CLI session lives in `$XDG_RUNTIME_DIR/bw-bridge/session` (0600,
private 0700 directory). The bridge requires an owned 0700 runtime directory
on tmpfs and falls back to `/run/user/UID` when SSH omits the variable.
This shares one explicit unlock with non-interactive systemd user services,
without relying on SSH's session keyring. tmpfs can be swapped; encrypted swap
or disabled swap is a host concern. Processes running as the same user and
root can read this session; it is not isolation from those processes.

Every cache read checks expiry; a transient systemd user timer also locks the
CLI and removes expired state. Timer creation failure closes the bridge.
`bw-vault` loads this cache automatically on Linux. The narrow `bin/security`
adapter supports only the infrastructure Tools' exact session read/delete
calls and forwards unchanged to Apple's tool on macOS. It never supports
storing credentials through command arguments. Keep the helpers together on
PATH. The macOS-only `bw-ssh` helper still uses Apple's absolute tool path.

Close early with `tools/access/bitwarden-session close` in personal-infra,
and `rbw lock` for SSH keys. Agents never invoke interactive `bw-bridge` or
`rbw unlock`. Linux regression: `bash tests/bw-bridge.test.sh`.

---

## Migration: moving existing SSH keys into the vault

1. **Inventory existing keys** on each machine:
   ```bash
   ls -la ~/.ssh/
   ```
   Note every private key file (`id_*`, `*.pem`, etc.).

2. **Add each key to Bitwarden:**
   - Open Bitwarden Desktop (Mac) or the Vaultwarden web UI (Linux via Tailscale)
   - New item → type **SSH Key** → paste the private key contents
   - Name the item clearly: `ssh/github`, `ssh/my-server`, etc.
   - Create a folder `ssh/` if it does not exist; move items into it
   - Save

3. **Verify the key is visible via the agent:**
   - Mac: `ssh-add -L` — lists vault keys once Desktop is running with SSH agent enabled
   - Linux: `rbw unlock && ssh-add -L` — lists vault keys

4. **Test a real connection:**
   ```bash
   ssh git@github.com       # should succeed with a Bitwarden approval prompt
   ```

5. **Archive the file-based keys** (only after confirming agent-based SSH works):
   ```bash
   mkdir -p ~/.ssh-archive
   chmod 0700 ~/.ssh-archive
   mv ~/.ssh/id_* ~/.ssh/*.pem ~/.ssh-archive/
   ```
   Do not delete outright — keep as recovery fallback until you are confident in the agent setup.

---

## Atuin credentials

Store Atuin credentials as a single vault item so any new device can onboard
without a key file.

- **Login item** named `atuin`:
  - username: your Atuin username
  - password: your Atuin password
  - notes: the encryption key returned by `atuin key`

Retrieval on a new device:

**macOS:** Open Bitwarden Desktop → find the `atuin` item → copy username, copy
password, reveal notes and copy the encryption key. Paste each into the
`atuin login` command.

**Linux / WSL:**

```bash
rbw get --field username atuin      # username
rbw get atuin                       # password
rbw get --field notes atuin         # encryption key
```

Older installs may still have a separate `atuin-key` vault item — the
installer's login flow falls back to reading that for backwards compatibility.
Clean up by copying the key into the main `atuin` item's notes field and
deleting the standalone `atuin-key` item.

---

## Unlock behavior

| Platform | Agent | Lock behavior |
|----------|-------|--------------|
| Mac mini | Bitwarden Desktop | Never locks (configured in Settings) |
| Mac laptop | Bitwarden Desktop | Locks per timeout; Touch ID to unlock |
| Linux / WSL | rbw-agent | Locks after `lock_timeout` seconds (default 3600) |

To extend rbw lock timeout on trusted Linux machines:
```bash
rbw config set lock_timeout 28800   # 8 hours
```

---

## Troubleshooting

**`ssh: no agent` / `Could not open a connection to your authentication agent`**

Check the socket:
```bash
echo $SSH_AUTH_SOCK
ls -la "$SSH_AUTH_SOCK"
```

On Linux, if the socket is missing: rbw-agent is not running. Run `rbw unlock` to start it. If it previously crashed: `rbw stop-agent && rbw unlock`.

**Vaultwarden UI does not show SSH Key item type**

The container is missing `EXPERIMENTAL_CLIENT_FEATURE_FLAGS=ssh-key-vault-item,ssh-agent`. Check the Vaultwarden deployment on your server and add the env var.

**Passphrase-protected keys fail to import**

Known upstream limitation. Workaround: remove the passphrase before importing.
```bash
ssh-keygen -p -N "" -f <keyfile>   # decrypt in-place
```
Import the decrypted key into the vault. Optionally re-add a passphrase to the archived copy.

---

## Key hygiene

- Never paste a private key into any web form over an untrusted network. Always use Tailscale when accessing `<your-vaultwarden-server>`.
- Rotate SSH keys annually. Generate a new key in Bitwarden Desktop (or `ssh-keygen` + import), update `~/.ssh/authorized_keys` on each remote server, delete the old vault item.
