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
- Network: Tailscale-only (not reachable from the public internet)
- Backend: Vaultwarden (self-hosted, behind Traefik IPAllowList)
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

### WSL / Linux

rbw provides both a Bitwarden CLI and a built-in SSH agent that speaks the full SSH agent protocol. No ssh-add piping needed.

```bash
# Configure rbw (interactive — do not automate these)
rbw config set email <your-email>
rbw config set base_url <your-vaultwarden-server>
rbw config set pinentry pinentry-curses

# Authenticate and unlock
rbw login           # enter master password via pinentry
rbw unlock          # starts rbw-agent; SSH keys become available

# Verify
ssh-add -L          # should list your vault SSH keys
```

The `.zshrc` SSH_AUTH_SOCK block picks up the rbw socket automatically after `rbw unlock`. See `rbw/config.json.example` for a reference config (copy to `~/.config/rbw/config.json` and edit the email field).

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

Store Atuin credentials in the vault so any new device can onboard without the key file.

- **Login item** named `atuin`: username = atuin username, password = atuin password
- **Login item** named `atuin-key`: password field = the sync encryption key from `atuin key`

Retrieval on a new device:

**macOS:** Open Bitwarden Desktop → find the `atuin` item → copy username (⌘⇧C), copy password; find `atuin-key` → copy password (the encryption key). Paste into the `atuin login` command.

**Linux / WSL:**
```bash
rbw get atuin                       # password
rbw get --field=username atuin      # username
rbw get atuin-key                   # the encryption key
```

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
