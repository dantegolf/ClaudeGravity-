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
- Отдельный запускатель для просмотра состояния прокси и лимитов.
- Одинаковая схема работы на Windows, macOS и Linux.

## ↓ Установка

### Перед началом

1. **Установите [Claude Desktop](https://claude.ai/download)** (на Linux используйте официальный Claude Desktop для поддерживаемого дистрибутива).
2. **Включите режим разработчика (Developer Mode)** в Claude Desktop:
   - Без режима разработчика Claude Desktop не сможет подключать локальный мост и сторонние модели.
   - В верхнем меню приложения (в строке меню macOS или в меню окна Windows/Linux) выберите: **Help** ➔ **Troubleshooting** ➔ **Enable Developer Mode**.
3. **Сетевые ограничения, блокировки IP со стороны Google и рекомендации:**
   - По недавним новостям Google начал активно блокировать и фильтровать IP-адреса многих хостингов, дата-центров и определённых провайдеров (возникают ошибки авторизации `403 Forbidden`, `User location is not supported` или таймауты).
   - **Как решить проблемы с подключением:**
     - **Качественный VPN**: включайте VPN перед запуском. Рекомендуются локации в США (US) или Западной Европе. При возникновении ошибок смените сервер или протокол.
     - **Смена DNS**: многие сетевые сбои и блокировки устраняются сменой DNS на уровне системы или роутера:
       - **[Xbox DNS](https://xbox-dns.ru/)** (популярный Smart DNS для стабильного доступа к сервисам и API без потери скорости):
         - Основной DNS: `111.88.96.50`
         - Дополнительный DNS: `111.88.96.51`
       - **Cloudflare DNS** (`1.1.1.1` и `1.0.0.1` или WARP), **Google Public DNS** (`8.8.8.8` и `8.8.4.4`), **Control D** или **AdGuard DNS**.
       - Включение **DNS-over-HTTPS (DoH)** в браузере или настройках сети.

### Windows

Откройте обычный **Windows PowerShell** и выполните:

```powershell
irm https://raw.githubusercontent.com/olegsuper338-lgtm/ClaudeGravity-/main/install-windows.ps1 | iex
```

### macOS

Откройте **Терминал** и выполните:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/olegsuper338-lgtm/ClaudeGravity-/main/install-macos.sh)"
```

### Linux

Откройте терминал и выполните:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/olegsuper338-lgtm/ClaudeGravity-/main/install-linux.sh)"
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
2. В Claude Desktop включите **Help → Troubleshooting → Enable Developer Mode**.
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
      │ Google OAuth
      ▼
Google Antigravity / Cloud Code models
```

ClaudeGravity при установке и каждом запуске проверяет npm и автоматически ставит актуальные версии:

- [`antigravity-claude-proxy`](https://www.npmjs.com/package/antigravity-claude-proxy)
- [`@jacobbd/relay-ai`](https://www.npmjs.com/package/@jacobbd/relay-ai)

Если проверка обновлений недоступна из-за сети, запуск продолжается с уже установленными версиями.

После обновления ClaudeGravity автоматически применяет проверяемый compatibility patch для протокола Antigravity 2.8. Он синхронизирует hub User-Agent, metadata и формат запросов Gemini 3.7. Если структура новой версии proxy неизвестна, запуск останавливается с понятной ошибкой вместо небезопасной правки неподходящих файлов.

Конфигурация Relay AI хранится в `~/.relay-ai`. Установщик сохраняет другие провайдеры и пользовательское избранное, а стандартный набор моделей добавляет только один раз.

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
Это ответ Google Cloud Code, а не ошибка преобразования ClaudeGravity. Проверьте тот же аккаунт в официальном Antigravity и смените выходной IP/ASN VPN. Поддерживаемая страна сама по себе не гарантирует доступ: сервер может отклонять адреса хостинговых и дата-центровых сетей.

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
