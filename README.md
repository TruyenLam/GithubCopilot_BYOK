# LiteLLM BYOK — Bring Your Own Key

Run a local LiteLLM proxy with your own API keys. Supports **DeepSeek Official**, **DeepSeek via DeepInfra**, and **Google Gemini**.

---

## Requirements

- Python 3.10+
- Windows (PowerShell 5+)

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
PROFILE_1_KEY=sk-xxxxxxxxxxxx          # <-- your real key

PROFILE_2_LABEL=DeepInfra - DeepSeek V4 Pro
PROFILE_2_ENV_VAR=DEEPINFRA_API_KEY
PROFILE_2_KEY=xxxxxxxxxxxxxx

PROFILE_3_LABEL=Gemini 2.0 Flash (AI Studio)
PROFILE_3_ENV_VAR=GEMINI_API_KEY
PROFILE_3_KEY=AIzaxxxxxxxxxxxxxxxx
```

### Where to get your keys

| Provider | URL |
|----------|-----|
| DeepSeek Official | https://platform.deepseek.com/api_keys |
| DeepInfra | https://deepinfra.com/dash/api_keys |
| Google Gemini | https://aistudio.google.com/apikey |

### Adding more keys or models

Add `PROFILE_4_*`, `PROFILE_5_*`, ... to `.env`. The menu updates automatically — no code changes needed.

---

## Run

**Double-click** `start.bat`, or run in PowerShell:

```powershell
.\start.ps1
```

An interactive menu appears:

```
========================================
   LiteLLM BYOK - Select Provider/Key
========================================
  1) DeepSeek Official - deepseek-chat
  2) DeepInfra - DeepSeek V4 Pro
  3) Gemini 2.0 Flash (AI Studio)

Enter number (1-3):
```

The proxy starts at `http://127.0.0.1:4000`.

---

## Use with GitHub Copilot (BYOK)

Once the proxy is running, point Copilot to it:

```
URL:     http://127.0.0.1:4000
API Key: (value of LITELLM_MASTER_KEY in your .env)
Model:   deepseek-official | deepseek-deepinfra | gemini-flash | gemini-pro
```

---

## Available models

| Model name | Provider | Underlying model |
|------------|----------|-----------------|
| `deepseek-official` | DeepSeek | deepseek-chat |
| `deepseek-deepinfra` | DeepInfra | deepseek-ai/DeepSeek-V4-Pro |
| `gemini-flash` | Google AI Studio | gemini-2.0-flash |
| `gemini-pro` | Google AI Studio | gemini-2.5-pro |

---

## Security

- `.env` contains your real keys — **never commit it to git**
- `.env` is already listed in `.gitignore`
- Only `.env.example` (no real keys) is committed to the repository
