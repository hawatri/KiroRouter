# Claude Code + Kiro Gateway setup (Windows)

Author: **Hawatri**

This folder sets up Claude Code on Windows to work with two accounts side by side:

| Command   | Uses                          | Billing                     |
|-----------|-------------------------------|-----------------------------|
| `claude`  | Your Claude Pro login         | Your Claude Pro plan        |
| `kclaude` | Kiro, through `kiro-gateway`  | Your free Kiro subscription |

The two setups no longer share settings, so switching between them doesn't break the other.

---

## 1. What you need

- Windows 10 or 11
- **Claude Code** installed with npm:
  ```bash
  npm install -g @anthropic-ai/claude-code@latest
  ```
- **Python** with the gateway's dependencies. This setup uses Anaconda at `C:\ProgramData\anaconda3\python.exe`.
- A **Kiro** account, logged in through the Kiro IDE or `kiro-cli`, so the gateway can find your Kiro token.
- This repository cloned to `E:\Opus\kiro-gateway`. If it lives somewhere else, see [Using a different folder](#using-a-different-folder).

## 2. Getting started

### Step 1: Install the gateway's Python packages

```bash
cd E:\Opus\kiro-gateway
```
```bash
C:\ProgramData\anaconda3\python.exe -m pip install -r requirements.txt
```

### Step 2: Create the gateway's `.env`

```bash
copy .env.example .env
```

Open `.env` and set these two values:

```ini
# A password you make up. kclaude reads it from here automatically.
PROXY_API_KEY="pick-any-long-secret-string"

# Where your Kiro login token lives (Kiro IDE default)
KIRO_CREDS_FILE="~/.aws/sso/cache/kiro-auth-token.json"
```

`.env` is in `.gitignore`, so the key never gets committed.

### Step 3: Install the `kclaude` and `kiro-gw` commands

```bash
E:\Opus\kiro-gateway\claude-setup\install.cmd
```

This copies both commands into `%USERPROFILE%\.local\bin`, which is already on your PATH. Open a new terminal afterwards.

### Step 4: Keep the global Claude settings clean

`C:\Users\<you>\.claude\settings.json` must **not** contain any gateway settings. It should look like this:

```json
{
  "model": "claude-opus-5-5",
  "theme": "dark"
}
```

Gateway variables in this file (`ANTHROPIC_BASE_URL`, `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`) apply to every Claude Code session. They break your Pro login and hide features in the Desktop app. `kclaude` sets them only for its own window.

Also make sure none of them are saved as Windows environment variables:

```bash
powershell -Command "Get-ChildItem Env:ANTHROPIC*"
```

If anything shows up, remove it in **Settings → System → About → Advanced system settings → Environment Variables**.

### Step 5: Log in to Claude Pro once

```bash
claude /login
```

Choose your Claude.ai (Pro) account.

## 3. Daily use

**Kiro.** In any terminal and any folder:

```bash
kclaude
```

`kclaude` does the following:
1. Checks whether `kiro-gateway` is answering on `http://127.0.0.1:8000/health`.
2. If not, starts `python main.py` in its own window and waits until it's ready.
3. Reads `PROXY_API_KEY` from the gateway's `.env`, so the key can never get out of sync.
4. Starts Claude Code pointed at the gateway, with Opus, Sonnet and Haiku mapped to the 5.5 models.

Anything you pass is forwarded to Claude, for example `kclaude --model sonnet` or `kclaude -p "explain this repo"`.

**Claude Pro:**

```bash
claude
```

**Gateway only** (for other tools such as Cursor):

```bash
kiro-gw
```

## 4. Claude Desktop app (gateway mode)

In the Desktop app's developer mode, choose the custom gateway and enter:

- **Base URL:** `http://127.0.0.1:8000`
- **API key:** the `PROXY_API_KEY` value from `.env`

The model picker shows only the models listed in the app's gateway config:

```
%LOCALAPPDATA%\Claude-3p\configLibrary\<id>.json
```

Copy the `inferenceModels` list from [`desktop-gateway-models.example.json`](desktop-gateway-models.example.json) into that file. Don't touch `inferenceGatewayApiKey`, which is stored encrypted. Then quit the app fully (right-click the tray icon, then **Quit**) and reopen it.

Start the gateway (`kiro-gw`) before you open the Desktop app.

## 5. Models available through Kiro

| Works                                                  | Doesn't work                                    |
|--------------------------------------------------------|-------------------------------------------------|
| `claude-opus-5-5`, `claude-sonnet-5-5`, `claude-haiku-5-5` | `claude-fable-5-1` ("insufficient subscription level") |
| `claude-opus-4.7`, `claude-sonnet-4.6`, `claude-haiku-4.5` |                                                 |

Both dash and dot forms work (`claude-opus-5-5` and `claude-opus-5.5`). The gateway converts them.

## 6. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `401 Invalid or missing API key` | The key sent doesn't match `PROXY_API_KEY` | Use `kclaude`, which reads the key from `.env`. If you edited `.env`, restart the gateway window. |
| Warning: "Both ANTHROPIC_AUTH_TOKEN and ANTHROPIC_API_KEY set" | One of them is in `settings.json` or saved as a Windows variable | Remove it (see Step 4). |
| `claude` uses Kiro instead of Pro | Gateway settings in global `settings.json` | Remove them (see Step 4). |
| "Port 8000 is taken by another program" | Another app is using port 8000 | Close it, or use `taskkill /PID <pid> /F` with the PID that `kiro-gw` prints. |
| The gateway window closes right away | Missing Python packages or a bad `.env` | Run `python main.py` by hand in the gateway folder to see the error. |
| Desktop app shows only one model | The gateway config lists only one model | See section 4. |
| Desktop app is missing the browser, effort levels or model options | `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` in global settings | Remove it (see Step 4). Check **Settings → Claude Code → Browser**. |
| Claude Code is stuck on an old version | Two installs: `~/.local/bin/claude.exe` and npm | Delete `~/.local/bin/claude.exe` and keep the npm version. |
| `<thinking_mode>` tags appear in messages | The gateway's `FAKE_REASONING` setting | Expected. Set `FAKE_REASONING=false` in `.env` to turn it off. |

## Using a different folder

The commands default to `E:\Opus\kiro-gateway` and Anaconda's Python. To change either, set these user environment variables:

```bash
setx KIRO_GATEWAY_DIR "D:\path\to\kiro-gateway"
```
```bash
setx KIRO_GATEWAY_PYTHON "C:\path\to\python.exe"
```

---

## Changelog: what was changed and why (2026-10-30)

The original setup kept failing in four ways. This is everything that was changed to fix it.

### Problems found

1. **Pro and Kiro conflicted.** `~/.claude/settings.json` had the gateway URL and key in its `env` block, so *every* Claude Code session went through the gateway, including the Pro login and the Desktop app.
2. **401 errors.** The key used by Claude Code was retyped by hand in several places and ended up 10 characters shorter than `PROXY_API_KEY` in `.env`. Both `ANTHROPIC_API_KEY` and `ANTHROPIC_AUTH_TOKEN` were also set at different times.
3. **Desktop app missing features.** `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` in global settings blocked the feature flags and model catalog that drive the model picker, effort levels and browser tools.
4. **Only one model in the Desktop picker.** The Desktop gateway config listed only `claude-opus-5.5`.

An old native `claude.exe` (2.1.235) also shadowed the newer npm install. It was removed earlier, and only the npm install remains.

### Changes

| File | Change |
|---|---|
| `C:\Users\hawatri\.claude\settings.json` | Removed the whole `env` block (gateway URL, API key, `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`, `ANTHROPIC_DEFAULT_OPUS_MODEL`). Only `model` and `theme` remain. Saved as UTF-8 without a BOM. |
| `%USERPROFILE%\.local\bin\kclaude.cmd` | **New.** Starts the gateway if needed, reads the key from `.env` and runs Claude Code through the gateway. Source: `claude-setup/bin/kclaude.cmd`. |
| `%USERPROFILE%\.local\bin\kiro-gw.cmd` | **New.** Starts `kiro-gateway` with Anaconda Python and waits for `/health`. Detects a blocked port 8000. Source: `claude-setup/bin/kiro-gw.cmd`. |
| `%LOCALAPPDATA%\Claude-3p\configLibrary\476007a6-….json` | `inferenceModels` now lists Opus 5.5, Sonnet 5.5 and Haiku 5.5 instead of only Opus 5.5. |
| `E:\Opus\kiro-gateway\claude-setup\` | **New.** This README, the two commands, `install.cmd` and the Desktop model list example. |

Nothing in the gateway's Python code or its `.env` was changed.

Backups of the original files are in `C:\Users\hawatri\.claude\backups\kiro-fix-20261030-190951\`.
