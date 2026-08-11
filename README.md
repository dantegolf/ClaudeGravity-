![ClaudeGravity Banner](assets/banner.svg)

# ClaudeGravity

Простая и удобная запуск-сборка для работы в **Claude Desktop** через мощные нейросети **Gemini 3.6 Flash** и **Claude** от Google Antigravity.

---

## 🚀 Как начать за 1 минуту

### Шаг 1. Подготовка
1. Скачайте и установите приложение **[Claude Desktop](https://claude.ai/download)**.
2. Включите **VPN** *(он необходим для стабильной работы Claude и связи с серверами)*.

### Шаг 2. Быстрая установка

Вставьте одну команду в консоль и нажмите **Enter**:

- **macOS** (в программе Терминал):
  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/olegsuper338-lgtm/ClaudeGravity-/main/install-macos.sh)"
  ```

- **Windows** (в программе PowerShell):
  ```powershell
  irm https://raw.githubusercontent.com/olegsuper338-lgtm/ClaudeGravity-/main/install-windows.ps1 | iex
  ```

---

## 📂 Что появится после установки

В вашей папке `Документы/ClaudeGravity` создадутся 2 простых файла:

1. **`ClaudeGravity`** — **Основной запуск**. При первом запуске поможет привязать аккаунт Google, включит прокси и сам откроет Claude Desktop.
2. **`Check-Limits`** — Быстрый просмотр оставшихся лимитов.

---

## ⚙️ Настройка Claude Desktop (Делается 1 раз)

Когда откроется приложение **Claude Desktop**:

1. **Включите режим разработчика**:
   - В верхнем меню нажмите **Help** ➔ **Troubleshooting** ➔ **Enable Developer Mode** *(или через Settings ➔ Developer)*.
2. **Переключите режим на Code**:
   - В верхней части окна выберите режим **Code** *(вместо Cowork, чтобы экономно расходовать лимиты)*.
3. **Выберите модель**:
   - Внизу экрана в списке моделей выберите `gemini-3.6-flash-high (Antigravity) 1M`.

---

## 🛠 Полезные команды (если нужно вручную)

| Действие | Команда |
|---|---|
| Привязать ещё аккаунт Google | `acc accounts add` |
| Перезапустить прокси | `acc restart` |
| Проверить статус прокси | `acc status` |

---

## ❤️ Использованные проекты

Сборка работает на основе открытых инструментов:
- [antigravity-claude-proxy](https://www.npmjs.com/package/antigravity-claude-proxy) — прокси-сервер Google Antigravity (`acc`).
- [@jacobbd/relay-ai](https://www.npmjs.com/package/@jacobbd/relay-ai) — мост для Claude Desktop (`relay-ai`).
- [Claude Desktop](https://claude.ai/download) — клиент Anthropic.
