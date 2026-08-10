![ClaudeGravity Banner](assets/banner.svg)

# ClaudeGravity

Один быстрый setup для запуска **Claude Desktop** через **Relay AI** и **Antigravity Claude Proxy**.

```text
Claude Desktop -> Relay AI -> Antigravity Proxy -> Gemini / Claude models
```

![macOS](https://img.shields.io/badge/macOS-supported-black)
![Windows](https://img.shields.io/badge/Windows-supported-blue)
![Node.js](https://img.shields.io/badge/Node.js-auto--installed-green)

## Использованные проекты и компоненты

Данная сборка объединяет и автоматизирует работу следующих открытых инструментов и сервисов:

- [antigravity-claude-proxy](https://www.npmjs.com/package/antigravity-claude-proxy) — локальный обратный прокси для работы протокола Claude с аккаунтами Google Antigravity (управляется утилитой `acc`).
- [@jacobbd/relay-ai](https://www.npmjs.com/package/@jacobbd/relay-ai) — реле-сервер, связывающий приложение Claude Desktop с пользовательскими локальными API-эндпоинтами (`relay-ai`).
- [Claude Desktop](https://claude.ai/download) — официальное десктопное приложение Anthropic Claude для macOS и Windows.
- **Google DeepMind Antigravity** — платформа доступа к нейросетям Gemini 3.6 Flash / Claude от Google.

## Предварительные требования (Перед установкой)

1. **Установите Claude Desktop**: Загрузите и установите официальное приложение [Claude Desktop](https://claude.ai/download).
2. **Включите надёжный VPN**: Убедитесь, что у вас включён качественный VPN. Он необходим для стабильного подключения к сервисам Anthropic и Google Antigravity, а также корректной работы прокси без гео-блокировок.
3. После выполнения первых двух шагов можно переходить к установке скрипта ниже.

## Установка

### macOS

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/olegsuper338-lgtm/ClaudeGravity-/main/install-macos.sh)"
```

### Windows PowerShell

```powershell
irm https://raw.githubusercontent.com/olegsuper338-lgtm/ClaudeGravity-/main/install-windows.ps1 | iex
```

Скрипты установят нужные npm-пакеты и создадут готовые launchers в папке:

```text
Documents/ClaudeGravity
```

## Что появится

macOS:

```text
ClaudeGravity.command
ClaudeGravity-Limits.command
```

Windows:

```text
ClaudeGravity.ps1
ClaudeGravity.cmd
ClaudeGravity-Limits.ps1
ClaudeGravity-Limits.cmd
```

## Первый запуск

1. Добавь Antigravity/Google аккаунт:

   ```bash
   acc accounts add
   ```

2. Запусти `ClaudeGravity` launcher из `Documents/ClaudeGravity`.

3. В Claude Desktop включи **Developer Mode**, выбери режим **Code** и модель Antigravity внизу окна (подробности ниже).

## Пошаговое руководство: Developer Mode & Code Mode в Claude Desktop

Чтобы Claude Desktop корректно перенаправлял запросы через Relay AI и Antigravity Proxy, выполни следующие шаги:

### 1. Включение Developer Mode (Режим разработчика)

1. Открой **Claude Desktop**.
2. В верхнем меню выбери **Help** ➔ **Troubleshooting** ➔ **Enable Developer Mode** (Включить режим разработчика).
   - *Альтернативно*: Открой **Settings** (`Cmd + ,` на macOS или `Ctrl + ,` на Windows) ➔ раздел **Developer** ➔ переключатель **Developer Mode**.
3. Перезапусти Claude Desktop, если приложение запросит перезагрузку.

### 2. Переключение в режим Code mode

1. В главном интерфейсе Claude Desktop найди переключатель рабочих режимов (в верхней части экрана или рядом с полем ввода).
2. Переключи режим с **Cowork** (Совместная работа) на **Code** (Код / Программирование).

> ⚠️ **Почему важен Code mode:**
> - **Cowork mode** активнее фоново вызывает дополнительные инструменты, создает автономные под-агенты и циклы. Это мгновенно увеличивает расход токенов и приводит к частым временным ошибкам лимитов/кулдауна (`isRateLimited: true`).
> - **Code mode** предназначен для прямого интерактивного парного программирования с файлами и консолью, работая стабильнее и экономя лимиты.

### 3. Выбор модели

1. Нажми на выпадающий список выбора моделей внизу поля ввода сообщения (рядом с кнопкой отправки).
2. Выбери кастомную модель Antigravity, например:

   ```text
   gemini-3.6-flash-high (Antigravity) 1M
   ```

3. Теперь вы готовы к работе через локальный прокси!

## Лимиты без открытия Antigravity

macOS:

```bash
~/Documents/ClaudeGravity/ClaudeGravity-Limits.command
```

Windows:

```powershell
.\ClaudeGravity-Limits.ps1
```

Или вручную:

```bash
curl -s http://127.0.0.1:8080/health | jq
```

Windows без `jq`:

```powershell
Invoke-RestMethod http://127.0.0.1:8080/health | ConvertTo-Json -Depth 20
```

## Если что-то сломалось

Перезапустить proxy:

```bash
acc restart
```

Остановить proxy:

```bash
acc stop
```

Открыть локальную панель proxy:

```bash
acc ui
```

Проверить локальные cooldown-флаги:

```bash
curl -s http://127.0.0.1:8080/health | jq '.accounts[0].modelRateLimits'
```

Если `models` показывает нормальный лимит, но `modelRateLimits` содержит `isRateLimited: true`, значит это локальный cooldown proxy. Обычно проще подождать reset или сделать `acc restart`.
