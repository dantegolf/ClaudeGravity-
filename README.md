<p align="center">
  <img src="assets/banner.png" alt="ClaudeGravity — локальный gateway для Claude Desktop" width="100%">
</p>

<h1 align="center">ClaudeGravity</h1>

<p align="center">
  <strong>Локальный managed gateway для Claude Desktop с Google Antigravity, WebUI и воспроизводимым bundled runtime.</strong>
</p>

<p align="center">
  <a href="https://github.com/dantegolf/ClaudeGravity-/actions/workflows/installers.yml"><img alt="Installers" src="https://github.com/dantegolf/ClaudeGravity-/actions/workflows/installers.yml/badge.svg"></a>
  <a href="https://github.com/dantegolf/ClaudeGravity-/actions/workflows/distribution.yml"><img alt="Distribution" src="https://github.com/dantegolf/ClaudeGravity-/actions/workflows/distribution.yml/badge.svg"></a>
</p>

<p align="center">
  <a href="#возможности">Возможности</a> ·
  <a href="#установка">Установка</a> ·
  <a href="#модели-relay-ai">Модели</a> ·
  <a href="#архитектура">Архитектура</a> ·
  <a href="#webui">WebUI</a> ·
  <a href="#cg-agent">CG-Agent</a> ·
  <a href="#диагностика">Диагностика</a>
</p>

ClaudeGravity объединяет Claude Desktop, Relay AI и Antigravity Proxy в один управляемый локальный runtime. Пользователю не нужно отдельно устанавливать или запускать engine-компоненты: проект собирает проверенный bundle в GitHub Actions, запускает процессы через собственный supervisor и предоставляет один Anthropic-compatible endpoint для Claude Desktop.

После запуска ClaudeGravity работает в фоне и открывает локальный WebUI:

```text
http://127.0.0.1:18080/
```

Claude Desktop подключается к единой внешней точке входа:

```text
http://127.0.0.1:17645/anthropic
```

Поддерживаются Windows, macOS и Linux.

> [!IMPORTANT]
> ClaudeGravity — независимый неофициальный проект. Он не связан с Anthropic, Google, Relay AI или авторами Antigravity Proxy. Доступ к моделям, OAuth, квотам и API определяется сторонними сервисами и может меняться независимо от ClaudeGravity.

> [!CAUTION]
> Интеграция использует неофициальный путь доступа к Google Antigravity. Перед использованием оцените риски для аккаунта, региона и сети. Для экспериментов разумно использовать отдельный Google-аккаунт.

## Возможности

- **Один managed runtime.** Antigravity Proxy и Relay AI запускаются и останавливаются одним ClaudeGravity supervisor.
- **Один endpoint для Claude Desktop.** Публичная локальная точка входа — `127.0.0.1:17645/anthropic`.
- **Локальный WebUI.** Статус, аккаунты, модели, квоты, live-логи и lifecycle actions доступны в браузере.
- **Фоновый запуск.** На Windows и macOS обычная работа не требует постоянно открытого PowerShell или Terminal.
- **Восстановление Claude Desktop config.** Предыдущая конфигурация сохраняется и восстанавливается при штатной остановке; stale-состояние обрабатывается при следующем запуске.
- **Pinned distribution.** Пользователь получает заранее собранный runtime вместо установки случайных `npm @latest` версий.
- **Selective Smart DNS.** Отдельный resolver применяется только к выбранным Antigravity / Cloud Code API-хостам и не меняет системный DNS.
- **Cross-platform CI.** Инсталляторы, runtime bundle, lifecycle supervisor и compatibility patch проверяются в GitHub Actions.
- **CG-Agent.** Опциональный Gemini coding worker для делегирования реализации под контролем внешнего supervisor.

## Как это работает

При обычном запуске ClaudeGravity:

1. проверяет bundled runtime и compatibility patch;
2. убирает legacy detached-процессы предыдущих версий;
3. запускает внутренний Antigravity engine на `127.0.0.1:18080`;
4. запускает Relay AI gateway на `127.0.0.1:17645`;
5. временно направляет Claude Desktop на `http://127.0.0.1:17645/anthropic`;
6. поднимает control API на `127.0.0.1:17646`;
7. открывает Claude Desktop и локальный WebUI;
8. собирает stdout/stderr обоих engine’ов в общий лог вместо вывода в пользовательский терминал.

Повторный запуск не создаёт второй экземпляр supervisor: уже работающий ClaudeGravity обнаруживается автоматически, после чего открываются существующие WebUI и Claude Desktop.

## Установка

### Требования

Перед установкой:

1. установите [Claude Desktop](https://claude.ai/download);
2. в Claude Desktop включите **Help → Troubleshooting → Enable Developer Mode**;
3. убедитесь, что установлен **Node.js 18+**.

Основные engine-зависимости отдельно через npm устанавливать не требуется — они входят в release bundle ClaudeGravity.

### Windows

Откройте обычный **Windows PowerShell**:

```powershell
irm https://raw.githubusercontent.com/dantegolf/ClaudeGravity-/main/install-windows.ps1 | iex
```

Runtime устанавливается в пользовательский каталог `Documents\ClaudeGravity`.

После установки создаются ярлыки:

- **ClaudeGravity** — запускает background supervisor через скрытое окно PowerShell;
- **Check-Limits** — проверяет состояние gateway и квоты.

Установщик предпочитает системные `curl.exe` и `tar.exe`, сохраняя PowerShell-compatible fallback для загрузки и распаковки.

### macOS

Откройте **Terminal** только для установки:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dantegolf/ClaudeGravity-/main/install-macos.sh)"
```

Runtime устанавливается в:

```text
~/Documents/ClaudeGravity
```

На Desktop создаётся **ClaudeGravity.app**, собранный через системный `osacompile`. Он запускает supervisor без постоянного окна Terminal. В каталоге установки остаётся `.command`-launcher для ручной диагностики.

### Linux

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/dantegolf/ClaudeGravity-/main/install-linux.sh)"
```

Поддерживаются `apt`, `dnf`, `pacman` и `zypper`. `sudo` используется только если системе требуется установить Node.js или `curl`; сам ClaudeGravity устанавливается в пользовательский каталог.

`ClaudeGravity.sh` запускает supervisor через `nohup` и возвращает управление терминалу.

## Первый запуск

После запуска дождитесь статуса **READY** в WebUI.

Если Google-аккаунт ещё не добавлен:

1. откройте вкладку **Accounts**;
2. запустите OAuth-вход;
3. после авторизации проверьте состояние аккаунта и квоты на Dashboard;
4. откройте Claude Desktop, включите режим **Code** и выберите доступную модель.

Доступность конкретных model ID и квот определяется Google и вашим аккаунтом. Наличие модели в локальном registry не гарантирует её доступность на стороне сервиса.

## Модели Relay AI

ClaudeGravity получает актуальный список моделей из Antigravity (`/v1/models`) при запуске и при **Restart** в WebUI, до запуска Relay AI. Поэтому модели, доступные вашему аккаунту в Antigravity, появляются и в каталоге для Claude Desktop — включая Gemini 3.8 Flash (Low, Medium, High, Tiered), когда API их возвращает.

При недоступности API сохраняется последний успешно полученный каталог. Только при первой установке без сохранённого каталога используется стартовый список из 22 model ID:

- Gemini 3.7 Flash: Low, Medium и High;
- Gemini 3.6 Flash: Low, Medium, High и Tiered;
- Gemini 3.5 Flash: Extra Low и Low;
- Gemini 3.1 Pro: Low и High; Gemini 3.1 Flash: Image и Lite;
- Gemini 3 Flash, Gemini 3 Flash Agent и Gemini Pro Agent;
- Gemini 2.5 Pro, Flash, Flash Lite и Flash Thinking;
- Claude Sonnet 4.6 и Claude Opus 4.6 Thinking.

При первой настройке в избранное добавляются Gemini 3.7 Flash High, Gemini 3.1 Pro High, Gemini 2.5 Pro, Claude Sonnet 4.6 и Claude Opus 4.6 Thinking. Последующие пользовательские изменения избранного сохраняются.

Если новая модель уже видна в WebUI, но ещё отсутствует в Claude Desktop, нажмите **Restart** в WebUI, дождитесь **READY** и заново откройте выбор модели в Claude Desktop. Если Desktop продолжает показывать старый каталог, полностью закройте и откройте его. После первого OAuth-входа также нажмите **Restart**, чтобы обновить каталог Relay.

## WebUI

ClaudeGravity использует WebUI bundled Antigravity Proxy, который патчится при сборке под интерфейс ClaudeGravity.

Основные разделы:

| Раздел | Назначение |
|---|---|
| **Dashboard** | состояние runtime, аккаунтов и квот |
| **Models** | модели, доступные через engine |
| **Accounts** | Google OAuth и управление аккаунтами |
| **Logs** | live-поток объединённых логов Antigravity + Relay |
| **Settings** | настройки engine |

В верхней панели доступны lifecycle actions:

- **Open Claude** — открыть Claude Desktop;
- **Restart** — перезапустить managed engine-процессы;
- **Stop** — корректно остановить ClaudeGravity и восстановить предыдущую конфигурацию Claude Desktop.

Общий disk log хранится в:

```text
~/.claudegravity/claudegravity.log
```

На Windows:

```text
%USERPROFILE%\.claudegravity\claudegravity.log
```

## Архитектура

```text
                         ┌──────────────────────────────┐
                         │     ClaudeGravity WebUI      │
                         │     127.0.0.1:18080          │
                         └──────────────┬───────────────┘
                                        │ status / logs / actions
                                        ▼
┌────────────────┐             ┌─────────────────────────┐
│ Claude Desktop │             │ ClaudeGravity supervisor│
└───────┬────────┘             │ control: 127.0.0.1:17646│
        │                      └────────────┬────────────┘
        │ Anthropic API                     │ owns lifecycle
        ▼                                   │
127.0.0.1:17645/anthropic                  │
        │                                   │
        ▼                                   │
┌────────────────┐                          │
│    Relay AI    │◄─────────────────────────┘
└───────┬────────┘
        │
        ▼
┌──────────────────────┐
│  Antigravity Proxy   │
│  127.0.0.1:18080     │
└──────────┬───────────┘
           │
           ├── OAuth / обычные домены ──► системный DNS
           │
           └── Cloud Code API ──────────► selective Smart DNS
                                           │
                                           ▼
                                      Google APIs
```

### Локальные порты

| Назначение | Адрес | Доступ |
|---|---|---|
| WebUI + internal Antigravity engine | `127.0.0.1:18080` | loopback only |
| Public Anthropic gateway | `127.0.0.1:17645/anthropic` | loopback only |
| Supervisor control API | `127.0.0.1:17646` | loopback only |

Старый пользовательский proxy на `:8080` не является частью текущей схемы запуска.

## Bundled runtime

ClaudeGravity не полагается на `npm @latest` на машине пользователя. GitHub Actions собирает runtime из зафиксированных upstream inputs, применяет compatibility patch, выполняет тесты и упаковывает результат в release assets.

Compatibility patch идемпотентно добавляет поддержку протокола Antigravity 2.8, selective Smart DNS, брендинг WebUI и мост live-логов supervisor. Для запросов он синхронизирует hub User-Agent, metadata, labels и request ID, включает validated tool calls, учитывает лимит вывода Gemini 3.7 в 65 536 токенов и thinking budget Gemini 3.7 Flash Medium. Если upstream уже поддерживает протокол нативно, protocol-часть пропускается; неизвестная структура исходников завершает сборку ошибкой вместо частичной правки.

Текущие pinned inputs определены в [`distribution/manifest.json`](distribution/manifest.json):

| Компонент | Версия / ref | Лицензия |
|---|---|---|
| `antigravity-claude-proxy` | package `2.7.7`, source commit `055699fcebcac83cea64bf599546a3ce820ebcdb` | MIT |
| `@jacobbd/relay-ai` | `0.9.5` | MIT |

Release runtime публикуется в двух форматах:

```text
ClaudeGravity-runtime.zip
ClaudeGravity-runtime.tar.gz
```

При push в `main` workflow **Distribution** пересобирает runtime и публикует новый release; `v*` tags также создают release с соответствующим тегом.

## Selective Smart DNS

ClaudeGravity не меняет DNS-настройки операционной системы.

Маршрутизация ограничена двумя Cloud Code API-хостами из `distribution/manifest.json`:

```text
cloudcode-pa.googleapis.com
daily-cloudcode-pa.googleapis.com
```

OAuth, `generativelanguage.googleapis.com`, `antigravity-unleash.goog` и остальные домены используют обычный сетевой путь приложения.

По умолчанию первым используется DNS-over-HTTPS через HTTP/2:

```text
https://dns.dns-ai.ru/dns-query
```

Резервные группы DNS: `111.88.96.50,111.88.96.51` (xbox-dns.ru), `83.220.169.155,212.109.195.93,195.133.25.16` (comss.one), `45.155.204.190,37.230.192.51` (geohide.ru). Последний резерв — системный DNS, в том числе для работающего VPN.

Если соединение не удалось установить или Google вернул `400 User location is not supported`, runtime пробует следующий маршрут. Неудачный маршрут пропускается для этого хоста на минуту. Другие HTTP-ошибки, обрывы уже установленного соединения, отменённые запросы и потоковые тела запросов не повторяются этим слоем.

DNS-ответы кэшируются не дольше их TTL и 60 секунд; параллельные запросы используют одно разрешение имени. DoH ограничен 2,5 секундами, UDP — одной попыткой с таймаутом 1 секунда на сервер, установление соединения Smart DNS — 5 секундами. Эти ограничения не обрывают уже работающий поток ответа модели. TLS проверяет исходное имя хоста; сертификаты и системные DNS-настройки не меняются.

### Свой прокси

Если в окружении запуска заданы `HTTPS_PROXY` / `https_proxy` (либо `HTTP_PROXY` / `http_proxy`), Cloud Code использует их с учётом `NO_PROXY` / `no_proxy`. Поддерживаются HTTP/HTTPS CONNECT-прокси; нижний регистр имеет приоритет по правилам Undici. Пример для запуска из shell:

```bash
HTTPS_PROXY=http://127.0.0.1:7890 ./ClaudeGravity.sh
```

При ошибке пользовательского прокси runtime возвращает ошибку, сохраняя выбранный пользователем маршрут. Адрес и пароль прокси не выводятся сетевым слоем в лог. Настройки окружения других программ не изменяются. После изменения окружения перезапустите ClaudeGravity; ярлык использует окружение, которое получил при запуске.

### Настройки DNS

Отключить только Smart DNS (явно заданный прокси продолжает действовать):

```bash
CLAUDEGRAVITY_SMART_DNS=off
```

Задать собственные DNS-серверы **вместо всех публичных DNS/DoH-провайдеров**:

```bash
CLAUDEGRAVITY_SMART_DNS_SERVERS=111.88.96.50,111.88.96.51
```

Некорректная настройка не мешает запуску: используется системный DNS. Доступность публичных маршрутов зависит от провайдера и региона; успешное разрешение имени само по себе не подтверждает доступ к моделям.

Сопоставление изменений с Antigravity Unlocker: [проверка от 5 сентября 2026](docs/antigravity-update-2026-09-05.md).

## CG-Agent

CG-Agent — **опциональный developer-инструмент**, а не обязательная часть пользовательского ClaudeGravity runtime.

Он запускает Gemini как implementation worker с ограниченным набором инструментов для выбранного репозитория:

- `read_file`;
- `write_file`;
- `list_files`;
- `search_text`;
- `shell`.

CG-Agent работает через уже запущенный managed Antigravity engine на `127.0.0.1:18080`; он намеренно **не запускает `acc` и не создаёт второй proxy-процесс**.

Команды публикации и наиболее разрушительные git-операции блокируются внутри worker runtime: `git commit`, `git push`, `git reset --hard` и force-clean должны оставаться под контролем внешнего supervisor или разработчика.

### Установка CG-Agent

Сначала установите и запустите обычный ClaudeGravity, затем дождитесь **READY** в WebUI.

Windows:

```powershell
irm https://raw.githubusercontent.com/dantegolf/ClaudeGravity-/main/install-cg-agent.ps1 | iex
```

macOS / Linux:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/dantegolf/ClaudeGravity-/main/install-cg-agent.sh)"
```

Пример запуска:

```bash
CG-Agent.sh --repo /path/to/project --task "Проверь архитектуру и реализуй задачу"
```

Windows:

```powershell
CG-Agent.cmd --repo C:\Projects\app --task "Проверь архитектуру и реализуй задачу"
```

Для длинных заданий можно использовать `--task-file`.

> [!NOTE]
> Отчёт worker’а не заменяет review. После выполнения задачи независимо проверьте `git diff`, `git status`, тесты, lint/typecheck/build и только затем принимайте изменения.

## Безопасность и границы доверия

ClaudeGravity старается держать локальную поверхность минимальной:

- пользовательские сервисы bind’ятся только на loopback;
- supervisor владеет lifecycle дочерних процессов;
- engine stdout/stderr не выводится в скрытый launcher, а направляется в локальный log stream;
- release bundle собирается из pinned inputs;
- compatibility patch проходит автоматические regression checks;
- системные DNS-настройки не изменяются.

При этом ClaudeGravity не может контролировать:

- изменения API и политики Google / Anthropic;
- доступность конкретных моделей и квот;
- блокировки аккаунтов, регионов, IP или ASN;
- безопасность upstream-компонентов за пределами версии, зафиксированной и проверенной текущей сборкой.

## Диагностика

### Gateway не становится READY

Проверьте `Check-Limits` и файл:

```text
~/.claudegravity/claudegravity.log
```

Также можно запустить supervisor в foreground.

macOS / Linux:

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

Проверьте последовательно:

1. включён **Developer Mode**;
2. выбран режим **Code**;
3. WebUI показывает `READY`;
4. Google-аккаунт добавлен через **Accounts**;
5. public gateway доступен на `127.0.0.1:17645`;
6. при необходимости выполните **Restart** из WebUI.

### `User location is not supported for the API use`

Это ограничение upstream-сервиса. Selective Smart DNS решает только DNS-маршрутизацию выбранных API-хостов и не отменяет ограничения аккаунта, региона или внешнего IP.

### Повторная установка

Чтобы обновить ClaudeGravity, повторно выполните установочную команду для своей платформы. Установщик заменит runtime свежим release bundle. Пользовательские Relay AI / OAuth данные хранятся отдельно от каталога runtime и не должны удаляться при обычном обновлении.

## Проверки и CI

Проект использует два основных workflow:

- **Installers** — cross-platform проверки Windows, macOS и Linux;
- **Distribution** — source validation, сборка pinned runtime, проверка готового bundle и публикация release assets.

Среди regression checks:

- Windows PowerShell 5.1 и PowerShell 7;
- macOS и Ubuntu installer paths;
- Node syntax;
- compatibility + selective Smart DNS patch;
- branded WebUI patch;
- unified gateway lifecycle;
- `17645` / `18080` / `17646` endpoint wiring;
- live-log capture;
- отсутствие engine output в terminal supervisor;
- duplicate-launch handoff;
- WebUI Stop + восстановление Claude Desktop config;
- наличие необходимых runtime-файлов внутри итогового ZIP/tar.gz.

Основные локальные проверки:

```bash
node tests/distribution.mjs
node tests/unified-gateway.mjs
bash tests/unix-installer.sh
```

Сборка runtime вручную:

```bash
node distribution/build-runtime.mjs
node tests/distribution.mjs dist/ClaudeGravity
```

## Структура репозитория

```text
.github/workflows/       CI и release automation
distribution/            manifest и сборка bundled runtime
docs/                    дополнительная документация
launchers/                пользовательские и developer launchers
launchers/scripts/        supervisor, patch/config helpers, CG-Agent
tests/                    integration и installer regression tests
install-windows.ps1       Windows installer
install-macos.sh          macOS installer
install-linux.sh          Linux installer
install-cg-agent.*        опциональный CG-Agent installer
THIRD_PARTY_NOTICES.md    сведения о сторонних компонентах
```

## Для разработчиков

Изменения в runtime-архитектуре желательно сопровождать тестом на соответствующем уровне:

- launcher / installer behavior → installer tests;
- lifecycle / ports / Claude Desktop config → `tests/unified-gateway.mjs`;
- runtime composition / manifest → `tests/distribution.mjs`;
- Antigravity compatibility / DNS / WebUI patch → proxy compatibility tests.

Не полагайтесь только на успешный локальный запуск: финальный bundle строится из pinned upstream sources и должен проходить тот же validation path, что используется в CI.

## Сторонние компоненты и ответственность

Информация о bundled third-party software находится в [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md). Лицензионные файлы зависимостей также сохраняются внутри runtime bundle.

Claude, Claude Desktop, Gemini, Google Antigravity и другие упомянутые названия принадлежат соответствующим правообладателям.

Проект предоставляется без гарантий доступности сторонних сервисов, моделей, квот или совместимости с будущими изменениями upstream API.
