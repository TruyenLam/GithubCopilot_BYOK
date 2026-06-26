# LiteLLM BYOK — Bring Your Own Key

Chạy LiteLLM proxy local với key của bạn. Hỗ trợ **DeepSeek chính chủ**, **DeepSeek qua DeepInfra**, và **Google Gemini**.

---

## Yêu cầu

- Python 3.10+
- Windows (PowerShell 5+)

---

## Cài đặt

```bash
# 1. Clone repo
git clone https://github.com/TruyenLam/GithubCopilot_BYOK.git
cd GithubCopilot_BYOK

# 2. Tạo virtual env và cài LiteLLM
python -m venv .venv
.venv\Scripts\python.exe -m pip install "litellm[proxy]"

# 3. Tạo file .env từ template
copy .env.example .env
```

---

## Cấu hình key

Mở file `.env` và điền API key của bạn vào:

```ini
PROFILE_1_LABEL=DeepSeek Official - deepseek-chat
PROFILE_1_ENV_VAR=DEEPSEEK_API_KEY
PROFILE_1_KEY=sk-xxxxxxxxxxxx          # <-- key thật của bạn

PROFILE_2_LABEL=DeepInfra - DeepSeek V4 Pro
PROFILE_2_ENV_VAR=DEEPINFRA_API_KEY
PROFILE_2_KEY=xxxxxxxxxxxxxx

PROFILE_3_LABEL=Gemini 2.0 Flash (AI Studio)
PROFILE_3_ENV_VAR=GEMINI_API_KEY
PROFILE_3_KEY=AIzaxxxxxxxxxxxxxxxx
```

### Lấy key ở đâu?

| Provider | Link |
|----------|------|
| DeepSeek chính chủ | https://platform.deepseek.com/api_keys |
| DeepInfra | https://deepinfra.com/dash/api_keys |
| Google Gemini | https://aistudio.google.com/apikey |

### Thêm nhiều key / nhiều model

Chỉ cần thêm `PROFILE_4_*`, `PROFILE_5_*`, ... vào `.env`. Script tự động hiển thị trong menu.

---

## Chạy

**Double-click** `start.bat` hoặc chạy trong PowerShell:

```powershell
.\start.ps1
```

Menu xuất hiện:

```
========================================
   LiteLLM BYOK - Chon Provider / Key
========================================
  1) DeepSeek Official - deepseek-chat
  2) DeepInfra - DeepSeek V4 Pro
  3) Gemini 2.0 Flash (AI Studio)

Nhap so (1-3):
```

Proxy chạy tại `http://127.0.0.1:4000`.

---

## Dùng với GitHub Copilot (BYOK)

Sau khi proxy đang chạy, cấu hình endpoint trong Copilot:

```
URL:     http://127.0.0.1:4000
API Key: (giá trị LITELLM_MASTER_KEY trong .env)
Model:   deepseek-official | deepseek-deepinfra | gemini-flash | gemini-pro
```

---

## Models có sẵn

| Model Name | Provider | Model thật |
|------------|----------|-----------|
| `deepseek-official` | DeepSeek | deepseek-chat |
| `deepseek-deepinfra` | DeepInfra | deepseek-ai/DeepSeek-V4-Pro |
| `gemini-flash` | Google AI Studio | gemini-2.0-flash |
| `gemini-pro` | Google AI Studio | gemini-2.5-pro |

---

## Bảo mật

- File `.env` chứa key thật — **không bao giờ commit lên git**
- `.env` đã được thêm vào `.gitignore` tự động
- Chỉ commit `.env.example` (không có key thật)
