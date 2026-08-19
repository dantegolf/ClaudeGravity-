<p align="center">
  <img src="assets/banner.png" alt="ClaudeGravity — несколько AI-моделей в Claude Desktop" width="100%">
</p>

<h1 align="center">ClaudeGravity</h1>

<p align="center">
  <strong>Gemini и Claude внутри привычного Claude Desktop.</strong><br>
  Один установщик, один Google-аккаунт, переключение моделей прямо в интерфейсе.
</p>

<p align="center">
  <a href="#-установка">Установка</a> ·
  <a href="#-что-получится">Возможности</a> ·
  <a href="#-как-это-работает">Как это работает</a> ·
  <a href="#-решение-проблем">Помощь</a>
</p>

> [!CAUTION]
> ClaudeGravity использует неофициальный прокси и не связан с Anthropic или Google. Разработчики прокси предупреждают о риске ограничений или блокировки Google-аккаунта. Не используйте основной аккаунт и продолжайте только если принимаете этот риск.

## ✦ Что получится

- Claude Desktop с моделями Google Antigravity вместо отдельного нового клиента.
- Пять подготовленных моделей в переключателе: Gemini 3.7 Flash High, Gemini 3.1 Pro High, Gemini 2.5 Pro, Claude Sonnet 4.6 и Claude Opus 4.6 Thinking.
- Автоматический запуск локального прокси и восстановление повреждённой конфигурации.
- Привязка Google-аккаунта через браузер; приложение Google Antigravity устанавливать необязательно.
- Встроенный selective Smart DNS: только Antigravity / Cloud Code API-хосты могут резолвиться через Smart DNS, а OAuth и остальные домены продолжают использовать обычный системный DNS.
- Отдельный запускатель для просмотра состояния прокси и лимитов.
- Одинаковая схема работы на Windows, macOS и Linux.

## ↓ Установка

### Перед началом

1. **Установите [Claude Desktop](https://claude.ai/download)** (на Linux используйте официальный Claude Desktop для поддерживаемого дистрибутива).
2. **Включите режим разработчика (Developer Mode)** в Claude Desktop:
   - Без режима разработчика Claude Desktop не сможет подключать локальный мост и сторонние модели.
   - В верхнем меню приложения (в строке меню macOS или в меню окна Windows/Linux) выберите: **Help** ➔ **Troubleshooting** ➔ **Enable Developer Mode**.
3. **Обычную смену DNS всей системы делать не нужно.** ClaudeGravity по умолчанию включает собственный selective Smart DNS для Antigravity / Cloud Code API и использует `111.88.96.50` и `111.88.96.51` только для целевых API-хостов.
4. Если Google всё равно возвращает `403 Forbidden`, `User location is not supported` или таймауты, проблема может быть связана с выходным IP/ASN. В таком случае попробуйте другой интернет-канал или VPN. Smart DNS не гарантирует доступ для аккаунтов или IP-адресов, которые Google блокирует отдельно.

> [!IMPORTANT]
> Команды ниже явно закрепляют источник установщика и всех скачиваемых launcher/patch-файлов на этом репозитории: `dantegolf/ClaudeGravity-`.

### Windows

Откройте обычный **Windows PowerShell** и выполните:

```powershell
$env:CLAUDEGRAVITY_RAW_BASE='https://raw.githubusercontent.com/dantegolf/ClaudeGravity-/main'; irm "$env:CLAUDEGRAVITY_RAW_BASE/install-windows.ps1" | iex
```

### macOS

Откройте **Терминал** и выполните:

```bash
CLAUDEGRAVITY_RAW_BASE="https://raw.githubusercontent.com/dantegolf/ClaudeGravity-/main" /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dantegolf/ClaudeGravity-/main/install-macos.sh)"
```

### Linux

Откройте терминал и выполните:

```bash
CLAUDEGRAVITY_RAW_BASE="https://raw.githubusercontent.com/dantegolf/ClaudeGravity-/main" bash -c "$(curl -fsSL https://raw.githubusercontent.com/dantegolf/ClaudeGravity-/main/install-linux.sh)"
```

Linux-установщик поддерживает `apt`, `dnf`, `pacman` и `zypper`. При необходимости он попросит `sudo` только для установки Node.js, npm и curl; сами компоненты ClaudeGravity устанавливаются в профиль пользователя.

## ◉ Первый запуск

Установщик создаёт два запускаемых файла:

| Платформа | Основной запуск | Проверка лимитов |
|---|---|---|
| Windows | `Документы\ClaudeGravity\ClaudeGravity.cmd` | `Check-Limits.cmd` |
| macOS | `Документы/ClaudeGravity/ClaudeGravity.command` | `Check-Limits.command` |
| Linux | `~/ClaudeGravity/ClaudeGravity.sh` и пункт меню приложений | `Check-Limits.sh` |

При первом запуске:

1. Разрешите привязку Google-аккаунта в браузере.
2. В Claude Desktop после аутентификации в любой аккаунт не забудьте включить **Help → Troubleshooting → Enable Developer Mode**.
3. Переключитесь в режим **Code**.
4. Выберите модель в нижнем меню Claude.
5. Не закрывайте окно ClaudeGravity: в нём работает временный Relay AI gateway.

## ⟳ Как это работает

```text
Claude Desktop
      │ Anthropic-compatible API
      ▼
Relay AI gateway
      │ localhost:8080
      ▼
Antigravity Claude Proxy
      │
      ├── OAuth / accounts.google.com ─────────→ системный DNS
      │
      └── Antigravity / Cloud Code API ───────→ selective Smart DNS
                         │                       111.88.96.50 / 111.88.96.51
                         ▼
              Google Antigravity / Cloud Code models
```

ClaudeGravity при установке и каждом запуске проверяет npm и автоматически ставит актуальные версии:

- [`antigravity-claude-proxy`](https://www.npmjs.com/package/antigravity-claude-proxy)
- [`@jacobbd/relay-ai`](https://www.npmjs.com/package/@jacobbd/relay-ai)

Если проверка обновлений недоступна из-за сети, запуск продолжается с уже установленными версиями.

После обновления ClaudeGravity автоматически применяет проверяемый compatibility patch для протокола Antigravity 2.8. Он синхронизирует hub User-Agent, metadata и формат запросов Gemini 3.7. Если структура новой версии proxy неизвестна, запуск останавливается с понятной ошибкой вместо небезопасной правки неподходящих файлов.

Тот же patch добавляет selective Smart DNS в сетевой слой proxy. По умолчанию через Smart DNS резолвятся только:

- `cloudcode-pa.googleapis.com`
- `daily-cloudcode-pa.googleapis.com`
- `generativelanguage.googleapis.com`
- `antigravity-unleash.goog`

OAuth и все остальные хосты остаются на системном DNS. Если Smart DNS не отвечает или задан некорректно, ClaudeGravity автоматически возвращается к системному DNS для запроса.

Конфигурация Relay AI хранится в `~/.relay-ai`. Установщик сохраняет другие провайдеры и пользовательское избранное, а стандартный набор моделей добавляет только один раз.

### Управление Smart DNS

По умолчанию ничего настраивать не нужно.

Отключить selective Smart DNS для текущего запуска:

```text
CLAUDEGRAVITY_SMART_DNS=off
```

Задать собственные DNS-серверы:

```text
CLAUDEGRAVITY_SMART_DNS_SERVERS=111.88.96.50,111.88.96.51
```

Переменные должны быть заданы в окружении **до запуска ClaudeGravity**, чтобы их унаследовал `antigravity-claude-proxy`.

## ⌘ Полезные команды

| Действие | Команда |
|---|---|
| Добавить Google-аккаунт | `acc accounts add` |
| Проверить аккаунты | `acc accounts list` |
| Проверить прокси | `acc status` |
| Перезапустить прокси | `acc restart` |
| Восстановить Claude после аварийного закрытия | `relay-ai claude-app --restore` |

## ? Решение проблем

**После обновления осталась старая ошибка**  
Повторно выполните установочную команду для своей платформы. Установщики идемпотентны: они обновят запускатели и сохранят аккаунты и настройки.

**`User location is not supported for the API use`**  
Это ответ Google Cloud Code, а не ошибка преобразования ClaudeGravity. Встроенный Smart DNS уже применяется к целевым API-хостам. Если ошибка сохраняется, попробуйте другой выходной IP/ASN или VPN. Поддерживаемая страна сама по себе не гарантирует доступ: сервер может отклонять адреса хостинговых и дата-центровых сетей.

**Хочу проверить работу без Smart DNS**  
Запустите ClaudeGravity с `CLAUDEGRAVITY_SMART_DNS=off`. Если после этого поведение меняется, проблема, вероятно, связана с маршрутом до Smart DNS или выбранным DNS-сервером.

**Claude Desktop не показывает модели**  
Убедитесь, что включён Developer Mode, выбран режим Code, а окно ClaudeGravity остаётся открытым. Затем полностью перезапустите Claude Desktop.

**Прокси не отвечает**

```bash
acc restart
acc status
```

**Relay AI сообщает о незавершённой сессии**

```bash
relay-ai claude-app --restore
```

## Лицензии и ответственность

ClaudeGravity — установочная обвязка над сторонними открытыми инструментами. Claude, Gemini, Google Antigravity и названия моделей являются товарными знаками соответствующих владельцев. Проект предоставляется «как есть» без гарантий доступности моделей, квот или сохранности аккаунта.
