<p align="center">
  <img src="assets/banner.png" alt="ClaudeGravity — Gemini и Claude в Claude Desktop" width="100%">
</p>

<h1 align="center">ClaudeGravity</h1>

<p align="center">
  Gemini и Claude в Claude Desktop через локальный ClaudeGravity gateway и WebUI.
</p>

<p align="center">
  <a href="https://github.com/dantegolf/ClaudeGravity-/actions/workflows/installers.yml"><img alt="Installers" src="https://github.com/dantegolf/ClaudeGravity-/actions/workflows/installers.yml/badge.svg"></a>
  <a href="https://github.com/dantegolf/ClaudeGravity-/actions/workflows/distribution.yml"><img alt="Distribution" src="https://github.com/dantegolf/ClaudeGravity-/actions/workflows/distribution.yml/badge.svg"></a>
</p>

ClaudeGravity настраивает Claude Desktop для работы с моделями Google Antigravity. Внутри используются pinned Antigravity proxy и Relay AI, но пользователю не нужно запускать их отдельно или работать с их CLI.

После запуска ClaudeGravity работает в фоне и автоматически открывает локальный интерфейс:

```text
http://127.0.0.1:18080/
```

Основной Anthropic-compatible endpoint для Claude Desktop остаётся один:

```text
http://127.0.0.1:17645/anthropic
```

Поддерживаются Windows, macOS и Linux.

> [!CAUTION]
> Проект использует неофициальную интеграцию и не связан с Anthropic или Google. Доступ к Google Antigravity зависит от аккаунта, региона, сети и текущих ограничений со стороны Google. Для тестов разумнее использовать отдельный Google-аккаунт.

## Что теперь происходит при запуске

ClaudeGravity больше не требует постоянно открытого Terminal или PowerShell.

Supervisor:

1. проверяет bundled runtime и compatibility patch;
2. останавливает старый detached proxy от предыдущих версий;
3. запускает внутренний Antigravity engine на `127.0.0.1:18080`;
4. запускает Relay AI gateway на `127.0.0.1:17645`;
5. временно настраивает Claude Desktop на `http://127.0.0.1:17645/anthropic`;
6. открывает Claude Desktop;
7. открывает ClaudeGravity WebUI в браузере;
8. работает в фоне, пока пользователь не нажмёт **Stop** в WebUI.

stdout/stderr обоих engines больше не выводятся в терминал. Они объединяются в WebUI **Logs** и сохраняются в:

```text
~/.claudegravity/claudegravity.log
```

На Windows это соответствует `%USERPROFILE%\.claudegravity\claudegravity.log`.

## WebUI

Интерфейс основан на bundled WebUI Antigravity Proxy, но патчится при сборке под ClaudeGravity: название, `CG` badge, cyan/violet accents и собственные controls.

В интерфейсе доступны:

- **Dashboard** — состояние аккаунтов и квот;
- **Models** — доступные модели;
- **Accounts** — добавление и управление Google-аккаунтами через OAuth;
- **Logs** — объединённые live-логи Antigravity + Relay;
- **Settings** — настройки engine;
- **Open Claude** — открыть Claude Desktop;
- **Restart** — перезапустить оба managed engine;
- **Stop** — корректно остановить ClaudeGravity и восстановить предыдущую конфигурацию Claude Desktop.

В верхней панели отображается отдельный статус ClaudeGravity gateway: `STARTING`, `READY` или `OFFLINE`.

Повторный запуск ClaudeGravity не создаёт второй proxy/supervisor. Уже запущенный экземпляр обнаруживается автоматически, после чего просто открывается существующий WebUI и Claude Desktop.

## Установка

Перед установкой:

1. Установите [Claude Desktop](https://claude.ai/download).
2. В Claude Desktop включите **Help → Troubleshooting → Enable Developer Mode**.
3. Убедитесь, что установлен **Node.js 18 или новее**.

Менять DNS всей системы не требуется. ClaudeGravity использует отдельный resolver только для нескольких Antigravity / Cloud Code API-хостов.

### Windows

Откройте обычный **Windows PowerShell** и выполните:

```powershell
irm https://raw.githubusercontent.com/dantegolf/ClaudeGravity-/main/install-windows.ps1 | iex
```

Установка выполняется в:

```text
Документы\ClaudeGravity
```

На рабочем столе создаётся ярлык **ClaudeGravity**. Он запускает background supervisor через скрытое окно PowerShell, поэтому после установки терминал для обычной работы не нужен.

Также создаётся `Check-Limits` для отдельной диагностики.

### macOS

Откройте **Terminal** только для установки и выполните:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dantegolf/ClaudeGravity-/main/install-macos.sh)"
```

Файлы устанавливаются в:

```text
~/Documents/ClaudeGravity
```

На рабочем столе создаётся **ClaudeGravity.app** — небольшой системный launcher, собранный через macOS `osacompile`. Он запускает background supervisor без Terminal.

В каталоге установки также остаётся `ClaudeGravity.command` как fallback для ручной диагностики, а на Desktop создаётся `Check-Limits.command`.

### Linux

Откройте терминал и выполните:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/dantegolf/ClaudeGravity-/main/install-linux.sh)"
```

Поддерживаются `apt`, `dnf`, `pacman` и `zypper`. Права `sudo` нужны только если требуется установить Node.js или `curl`. Сам ClaudeGravity устанавливается в пользовательский каталог.

`ClaudeGravity.sh` запускает supervisor через `nohup` и сразу возвращает управление терминалу.

## Первый запуск и Google OAuth

При отсутствии Google-аккаунта ClaudeGravity больше не блокирует скрытый background process терминальным prompt.

Откройте вкладку **Accounts** в WebUI и добавьте аккаунт через OAuth. После авторизации Dashboard покажет состояние аккаунта и квоты.

После этого используйте Claude Desktop в режиме **Code** и выбирайте нужную модель.

## Сетевые адреса

| Назначение | Адрес |
|---|---|
| ClaudeGravity WebUI / internal Antigravity | `http://127.0.0.1:18080/` |
| Public Anthropic gateway | `http://127.0.0.1:17645/anthropic` |
| Supervisor control API | `http://127.0.0.1:17646` |

Все три сервиса bind'ятся только на loopback. Порт `17646` используется WebUI для status/actions/live logs и не предназначен для внешней сети.

Старый пользовательский proxy на `:8080` больше не является частью схемы запуска.

## Архитектура

```text
Browser
  │
  └── ClaudeGravity WebUI ────────────────┐
      127.0.0.1:18080                    │
                                          ▼
Claude Desktop                     ClaudeGravity supervisor
      │                            control: 127.0.0.1:17646
      ▼                                   │
127.0.0.1:17645/anthropic                 ├── logs / status / actions
      │                                   ├── Open Claude
      ▼                                   ├── Restart
Relay AI                                  └── Stop + restore config
      │
      ▼
Antigravity proxy
127.0.0.1:18080
      │
      ├── OAuth и обычные домены ──→ системный DNS
      │
      └── Cloud Code API ──────────→ selective Smart DNS
                                      │
                                      ▼
                                  Google APIs
```

## Модели

По умолчанию в избранное Relay AI добавляются:

- Gemini 3.7 Flash High
- Gemini 3.1 Pro High
- Gemini 2.5 Pro
- Claude Sonnet 4.6
- Claude Opus 4.6 Thinking

Relay также получает дополнительные Antigravity model IDs. Наличие модели в списке не означает, что конкретный Google-аккаунт обязательно имеет к ней доступ — доступность и квоты определяются на стороне Google.

## Bundled engines

Proxy и Relay AI заранее собираются в GitHub Actions и попадают в `ClaudeGravity-runtime.zip` и `ClaudeGravity-runtime.tar.gz`. На машине пользователя нет необходимости отдельно устанавливать `antigravity-claude-proxy` или Relay AI через npm.

Текущие версии зафиксированы в `distribution/manifest.json`:

- `antigravity-claude-proxy` — commit `055699fcebcac83cea64bf599546a3ce820ebcdb` (package metadata `2.7.7`)
- `@jacobbd/relay-ai` — `0.9.5`

Antigravity Proxy закреплён по полному commit SHA. Его MIT WebUI сохраняется внутри bundled package и патчится ClaudeGravity во время сборки/runtime compatibility check. Условия сторонних лицензий сохраняются в `THIRD_PARTY_NOTICES.md` и bundled packages.

## Selective Smart DNS

ClaudeGravity не меняет системные DNS-настройки.

Отдельный resolver используется только для:

```text
cloudcode-pa.googleapis.com
daily-cloudcode-pa.googleapis.com
generativelanguage.googleapis.com
antigravity-unleash.goog
```

По умолчанию:

```text
111.88.96.50
111.88.96.51
```

OAuth, `accounts.google.com` и остальные домены продолжают использовать системный DNS. Если отдельный resolver не отвечает, запрос возвращается к системному DNS.

Отключить Smart DNS для диагностики:

```bash
CLAUDEGRAVITY_SMART_DNS=off
```

Указать другие resolver'ы:

```bash
CLAUDEGRAVITY_SMART_DNS_SERVERS=111.88.96.50,111.88.96.51
```

## Диагностика

### Проверить gateway и квоты

Используйте `Check-Limits` для своей платформы. Он проверяет `http://127.0.0.1:17645/health`, затем получает квоты из `http://127.0.0.1:18080/account-limits`.

### Запустить supervisor в foreground

Обычный пользовательский запуск должен быть background. Для разработки/диагностики можно вернуть вывод в terminal.

macOS/Linux:

```bash
CLAUDEGRAVITY_FOREGROUND=1 ./ClaudeGravity.sh
```

или:

```bash
./ClaudeGravity.sh --foreground
```

Windows PowerShell:

```powershell
.\ClaudeGravity.ps1 -Foreground
```

### Claude Desktop не показывает модели

Проверьте:

1. включён **Developer Mode**;
2. выбран режим **Code**;
3. в WebUI статус gateway — `READY`;
4. Google-аккаунт добавлен во вкладке **Accounts**;
5. при необходимости нажмите **Restart** в WebUI.

### `User location is not supported for the API use`

Selective Smart DNS помогает только с DNS-маршрутизацией выбранных API-хостов. Он не снимает ограничения, которые Google применяет к аккаунту или внешнему IP-адресу.

## Обновление

Чтобы получить последнюю опубликованную версию, повторно запустите установочную команду для своей системы.

Установщик заменит каталог ClaudeGravity свежим runtime из последнего GitHub Release. Настройки Relay AI и Google OAuth хранятся отдельно и при обычной переустановке не удаляются.

После успешного push в `main` workflow **Distribution** автоматически собирает и публикует свежий runtime release, поэтому `releases/latest/download` соответствует актуальной версии `main`.

## Проверки

GitHub Actions проверяет:

- Windows PowerShell 5.1;
- PowerShell 7;
- macOS;
- Ubuntu;
- Node syntax;
- Antigravity compatibility + Smart DNS patch;
- ClaudeGravity WebUI branding patch;
- live-log bridge из обоих child processes;
- отсутствие engine stdout/stderr в terminal supervisor;
- duplicate-launch handoff;
- WebUI `Stop` lifecycle и восстановление Claude Desktop config;
- реальную сборку pinned Antigravity + Relay runtime;
- наличие branded WebUI внутри собранного ZIP/tar.gz;
- компиляцию `ClaudeGravity.app` через `osacompile` на macOS CI.

Основные локальные проверки:

```bash
node tests/distribution.mjs
node tests/unified-gateway.mjs
bash tests/unix-installer.sh
```

## Для разработчиков

Собрать runtime:

```bash
node distribution/build-runtime.mjs
node tests/distribution.mjs dist/ClaudeGravity
```

Runtime build содержит:

```text
ClaudeGravity-runtime.zip
ClaudeGravity-runtime.tar.gz
```

Именно эти файлы скачивают установщики Windows, macOS и Linux через `releases/latest/download`.

## Лицензии и ответственность

Лицензии сторонних компонентов сохраняются внутри `runtime/node_modules`. Дополнительная информация находится в [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

Claude, Gemini, Google Antigravity и названия моделей принадлежат соответствующим владельцам товарных знаков.

Проект предоставляется «как есть». Автор проекта не может гарантировать доступность конкретных моделей, квот или неизменность поведения сторонних сервисов.
