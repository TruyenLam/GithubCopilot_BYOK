# LiteLLM BYOK — Bring Your Own Key

> **Use your own AI API keys with GitHub Copilot in Visual Studio 2026 — no subscription required.**

Run a local LiteLLM proxy that bridges GitHub Copilot to your own API keys.  
Supports **DeepSeek Official**, **DeepSeek via DeepInfra**, and **Google Gemini**.

---

## ✨ Visual Studio 2026 + GitHub Copilot BYOK

Visual Studio 2026 introduced **Bring Your Own Key (BYOK)** support for GitHub Copilot,  
allowing you to plug in any OpenAI-compatible endpoint instead of using Copilot's default models.

**This tool lets you:**
- Use **DeepSeek**, **Gemini**, or any provider — inside GitHub Copilot chat and completions
- Pay only for what you use (no Copilot subscription needed for the AI calls)
- Switch between providers in seconds via an interactive menu
- Run **all providers simultaneously** or pick one at startup
- Keep all your keys local — nothing is sent anywhere except the provider you choose

### How to connect in Visual Studio 2026

1. Start the proxy (see [Run](#run) below)
2. Open Visual Studio 2026 → **Tools → Options → GitHub Copilot → BYOK / Custom Endpoint**
3. Set:
   ```
   Endpoint URL : http://127.0.0.1:4000
   API Key      : (leave empty or any value — no auth required for local use)
   Model        : deepseek-official-chat | deepseek-official-v4-flash
                  deepseek-deepinfra-v4-pro | deepseek-deepinfra-v4-flash
                  gemini-flash | gemini-pro
   ```
4. Save and start chatting with Copilot using your own key

---

## Requirements

- Python 3.10+
- Windows (PowerShell 5+)
- Visual Studio 2026 with GitHub Copilot extension

---

## Installation

```bash
# 1. Clone the repo
git clone https://github.com/TruyenLam/GithubCopilot_BYOK.git
cd GithubCopilot_BYOK

# 2. Create a virtual environment and install LiteLLM
python -m venv .venv
.venv\Scripts\python.exe -m pip install "litellm[proxy]"

# 3. Create your .env file from the template
copy .env.example .env
```

---

## Configure your API keys

Open `.env` and fill in your keys:

```ini
PROFILE_1_LABEL=DeepSeek Official - deepseek-chat
PROFILE_1_ENV_VAR=DEEPSEEK_API_KEY
PROFILE_1_KEY=sk-xxxxxxxxxxxx

PROFILE_2_LABEL=DeepInfra - DeepSeek V4 Pro
PROFILE_2_ENV_VAR=DEEPINFRA_API_KEY
PROFILE_2_KEY=xxxxxxxxxxxxxx

PROFILE_3_LABEL=Gemini 2.0 Flash (AI Studio)
PROFILE_3_ENV_VAR=GEMINI_API_KEY
PROFILE_3_KEY=AIzaxxxxxxxxxxxxxxxx

# No master key needed — this proxy runs locally only
```

### Where to get your keys

| Provider | URL |
|----------|-----|
| DeepSeek Official | https://platform.deepseek.com/api_keys |
| DeepInfra | https://deepinfra.com/dash/api_keys |
| Google Gemini | https://aistudio.google.com/apikey |

### Adding more keys or models

Add `PROFILE_4_*`, `PROFILE_5_*`, ... to `.env`. The menu updates automatically — no code changes needed.

To add a new model, add an entry to `config.yaml` referencing the appropriate env var.  
It will appear automatically in the model detail output at startup.

---

## Run

**Double-click** `start.bat`, or run in PowerShell:

```powershell
.\start.ps1
```

### Interactive menu

```
========================================
   LiteLLM BYOK - Select Provider/Key
========================================
  0) ALL providers (use all keys at once)
  1) DeepSeek Official - deepseek-chat
  2) DeepInfra - DeepSeek V4 Pro
  3) Gemini 2.0 Flash (AI Studio)

Enter number (0 = all, 1-3 = single):
```

**Option `0` — All providers**

Sets all keys at once. Every model in `config.yaml` is available in the same session:

```
Selected : ALL providers
  [OK] DeepSeek Official - deepseek-chat
  [OK] DeepInfra - DeepSeek V4 Pro
  [OK] Gemini 2.0 Flash (AI Studio)
Proxy    : http://127.0.0.1:4000
```

**Option `1-N` — Single provider**

Sets only that provider's key and shows exactly which models from `config.yaml` will be active:

```
Selected : DeepSeek Official - deepseek-chat
Env var  : DEEPSEEK_API_KEY
Models available via this key:
  - deepseek-official-chat              (deepseek/deepseek-chat)
  - deepseek-official-v4-flash          (deepseek/deepseek-v4-flash)
Proxy    : http://127.0.0.1:4000
```

The proxy starts at `http://127.0.0.1:4000`.

---

## Test all models

With the proxy running, **double-click `test.bat`** or run:

```powershell
.\test.ps1
```

The script fetches the model list from the proxy automatically and sends a test message to each one:

```
========================================
   LiteLLM BYOK - Test All Models
========================================
Proxy : http://127.0.0.1:4000

Found 6 model(s): deepseek-official-chat, deepseek-official-v4-flash, ...

Testing [deepseek-official-chat]... OK  (1243ms)
     I am DeepSeek-V3, an AI assistant created by DeepSeek.

Testing [deepseek-official-v4-flash]... OK  (876ms)
     I am DeepSeek-V4-Flash, an AI assistant made by DeepSeek.

Testing [gemini-flash]... OK  (612ms)
     I am Gemini, a large language model made by Google.
...

========================================
Summary
========================================
[OK  ] deepseek-official-chat
[OK  ] deepseek-official-v4-flash
[OK  ] deepseek-deepinfra-v4-pro
[OK  ] deepseek-deepinfra-v4-flash
[OK  ] gemini-flash
[OK  ] gemini-pro

Passed: 6 / 6   Failed: 0
```

---

## Available models

| Model name | Provider | Underlying model |
|------------|----------|-----------------|
| `deepseek-official-chat` | DeepSeek Official | deepseek/deepseek-chat |
| `deepseek-official-v4-flash` | DeepSeek Official | deepseek/deepseek-v4-flash |
| `deepseek-deepinfra-v4-pro` | DeepInfra | deepinfra/deepseek-ai/DeepSeek-V4-Pro |
| `deepseek-deepinfra-v4-flash` | DeepInfra | deepinfra/deepseek-ai/DeepSeek-V4-0-Flash |
| `gemini-flash` | Google AI Studio | gemini/gemini-3.1-flash-lite |
| `gemini-pro` | Google AI Studio | gemini/gemini-2.5-pro |

---

## Security

- `.env` contains your real keys — **never commit it to git**
- `.env` is already listed in `.gitignore`
- Only `.env.example` (no real keys) is committed to the repository
- The proxy runs locally — your keys never leave your machine
