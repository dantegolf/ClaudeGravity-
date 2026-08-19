<p align="center">
  <img src="assets/banner.png" alt="ClaudeGravity — Gemini и Claude в Claude Desktop" width="100%">
</p>

<h1 align="center">ClaudeGravity</h1>

<p align="center">
  <strong>Gemini и Claude внутри привычного Claude Desktop.</strong><br>
  Один проверенный bundled runtime, Google OAuth и selective Smart DNS без глобальных npm-обновлений на машине пользователя.
</p>

<p align="center">
  <a href="#-установка">Установка</a> ·
  <a href="#-что-получится">Возможности</a> ·
  <a href="#-как-это-работает">Как это работает</a> ·
  <a href="#-решение-проблем">Помощь</a>
</p>

> [!CAUTION]
> ClaudeGravity использует неофициальную интеграцию и не связан с Anthropic или Google. Доступ Google может зависеть от аккаунта, страны, IP/ASN и изменений upstream. Не используйте основной Google-аккаунт, если не принимаете этот риск.

## ✦ Что получится

- Claude Desktop с моделями Google Antigravity вместо отдельного нового клиента.
- Пять моделей по умолчанию в избранном Relay AI:
  - Gemini 3.7 Flash High;
  - Gemini 3.1 Pro High;
  - Gemini 2.5 Pro;
  - Claude Sonnet 4.6;
  - Claude Opus 4.6 Thinking.
- Дополнительные Antigravity model IDs регистрируются в локальном Relay; фактическая доступность моделей зависит от Google-аккаунта и upstream.
- Google OAuth через браузер — приложение Google Antigravity устанавливать не требуется.
- Локальный Antigravity engine и Relay AI gateway.
- Встроенный selective Smart DNS только для Antigravity / Cloud Code API-хостов.
- OAuth и остальные домены остаются на системном DNS.
- Один проверенный ClaudeGravity runtime вместо глобальных `npm @latest` компонентов.
- Одинаковая схема установки на Windows, macOS и Linux.

## ↓ Установка

### Перед началом

1. **Установите [Claude Desktop](https://claude.ai/download).**
2. **Включите Developer Mode**: **Help → Troubleshooting → Enable Developer Mode**. Без него Claude Desktop не сможет нормально подключить локальный мост и сторонние модели.
3. **Не меняйте DNS всей системы.** Selective Smart DNS уже встроен в ClaudeGravity и применяется только к целевым API-хостам.
4. Требуется **Node.js 18+**. Runtime содержит pinned proxy/Relay зависимости, но сам Node.js в bundle не входит.
   - Windows/Linux installer попробует установить Node.js штатным менеджером пакетов, если его нет.
   - На macOS автоматическая установка Node.js выполняется через Homebrew, если он уже доступен.
5. Если Google отвечает `403 Forbidden`, `User location is not supported` или запросы зависают, причина может быть в аккаунте или выходном IP/ASN. В таком случае попробуйте другой интернет-канал или VPN.

### Windows

Откройте обычный **Windows PowerShell**:

```powershell
irm https://raw.githubusercontent.com/dantegolf/ClaudeGravity-/main/install-windows.ps1 | iex
```

### macOS

Откройте **Терминал**:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dantegolf/ClaudeGravity-/main/install-macos.sh)"
```

### Linux

Откройте терминал:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/dantegolf/ClaudeGravity-/main/install-linux.sh)"
```

Linux installer поддерживает `apt`, `dnf`, `pacman` и `zypper`. `sudo` нужен только если требуется установить Node.js/curl; сам ClaudeGravity ставится в профиль пользователя.

Установщики **не скачивают proxy/Relay из npm на машине пользователя**. Они получают готовый `ClaudeGravity-runtime` только из GitHub Releases этого репозитория.

> [!IMPORTANT]
> Для bundled-схемы в GitHub Releases должны существовать `ClaudeGravity-runtime.zip` и `ClaudeGravity-runtime.tar.gz`. Workflow `Distribution` автоматически собирает и публикует их при создании тега `v*`.

## ◉ Первый запуск

Установщик создаёт:

| Платформа | Основной запуск | Проверка состояния / лимитов |
|---|---|---|
| Windows | `Документы\ClaudeGravity\ClaudeGravity.cmd` | `Check-Limits.cmd` |
| macOS | `~/Documents/ClaudeGravity/ClaudeGravity.sh` | `Check-Limits.sh` |
| Linux | `~/ClaudeGravity/ClaudeGravity.sh` и пункт меню приложений | `Check-Limits.sh` |

При первом запуске ClaudeGravity:

1. Проверяет bundled runtime и compatibility patch.
2. Подготавливает Relay AI, не удаляя другие пользовательские провайдеры и избранное.
3. Если Google-аккаунт ещё не добавлен, предложит открыть OAuth-привязку в браузере.
4. Запускает локальный Antigravity engine на `127.0.0.1:8080`.
5. Проверяет, что proxy отвечает, и только после этого запускает Relay AI для Claude Desktop.
6. В Claude Desktop переключитесь в режим **Code** и выберите нужную модель.

> [!NOTE]
> Не закрывайте окно/терминал ClaudeGravity во время работы: в нём запущен Relay AI gateway. Для проверки состояния proxy используйте `Check-Limits` рядом с основным launcher.

## ⟳ Как это работает

```text
                    GitHub Actions (только сборка)
                              │
                   pinned upstream inputs
        proxy commit 055699f… · Relay AI 0.9.5
                              │
                              ▼
                    ClaudeGravity patch
               compatibility + Smart DNS
                              │
                              ▼
                  ClaudeGravity Release
             runtime.zip / runtime.tar.gz
                              │
                 пользователь скачивает
                    только наш Release
                              │
                              ▼
Claude Desktop → bundled Relay → bundled Antigravity engine → Google APIs
                                      │
                                      ├─ OAuth → system DNS
                                      └─ Cloud Code → selective Smart DNS
```

### Почему runtime теперь bundled

Раньше launcher выполнял `npm install -g ...@latest`, поэтому новая upstream-версия могла приехать пользователю раньше, чем ClaudeGravity успевал проверить совместимость.

Теперь upstream inputs закреплены в `distribution/manifest.json`. Proxy фиксируется **полным commit SHA**, а Relay — точной package-версией. CI заранее собирает runtime, применяет compatibility + selective Smart DNS patch, запускает тесты и только затем формирует release bundle.

Пользовательская машина больше не зависит от npm-версий proxy/Relay во время установки или запуска. Повторная установка заменяет runtime целиком на последнюю опубликованную проверенную сборку, а пользовательская Relay-конфигурация хранится отдельно в `~/.relay-ai`.

Текущие pins:

- `antigravity-claude-proxy` — commit `055699fcebcac83cea64bf599546a3ce820ebcdb` (package metadata `2.7.7`);
- `@jacobbd/relay-ai` — `0.9.5`.

Почему proxy закреплён по SHA: upstream release tags и npm metadata не всегда синхронизированы, поэтому номер версии недостаточен для воспроизводимой сборки. Full commit SHA гарантирует, что ClaudeGravity тестирует и упаковывает ровно выбранное source tree.

Конкретное дерево зависимостей каждой сборки сохраняется в `runtime/package-lock.json` внутри release bundle.

### Selective Smart DNS

По умолчанию через Smart DNS резолвятся только:

- `cloudcode-pa.googleapis.com`
- `daily-cloudcode-pa.googleapis.com`
- `generativelanguage.googleapis.com`
- `antigravity-unleash.goog`

По умолчанию используются `111.88.96.50` и `111.88.96.51`. OAuth и все остальные hostname используют системный resolver. Если Smart DNS не отвечает, lookup откатывается на системный DNS.

Отключить Smart DNS для запуска:

```text
CLAUDEGRAVITY_SMART_DNS=off
```

Задать свои resolver'ы:

```text
CLAUDEGRAVITY_SMART_DNS_SERVERS=111.88.96.50,111.88.96.51
```

Переменные должны быть заданы **до запуска ClaudeGravity**, чтобы их унаследовал Antigravity engine.

## ⚙ Для разработчиков

### Собрать runtime локально

```bash
node distribution/build-runtime.mjs
node tests/distribution.mjs dist/ClaudeGravity
```

Сборщик:

1. читает точные inputs из `distribution/manifest.json`;
2. устанавливает их только в staging runtime;
3. применяет `patch-antigravity-proxy.mjs`;
4. проверяет marker selective Smart DNS;
5. валидирует pinned source в lockfile;
6. добавляет launchers, manifest и third-party notices.

### Проверки

Основные distribution-проверки:

```bash
node tests/distribution.mjs
bash tests/unix-installer.sh
```

Windows installer отдельно проверяется PowerShell-тестами в GitHub Actions.

### Опубликовать release

Workflow `.github/workflows/distribution.yml` собирает и тестирует runtime на push/PR. При теге `v*` тот же workflow публикует ZIP и tar.gz в GitHub Release.

Upstream используется **только во время нашей сборки**. Конечный пользователь получает proxy, Relay и ClaudeGravity patch одним bundle из `dantegolf/ClaudeGravity-`.

## ? Решение проблем

**Installer получает 404 на `ClaudeGravity-runtime`**  
Для bundled-схемы ещё не опубликован Release asset с ожидаемым именем. Проверьте, что после merge был опубликован тег `v*` и workflow `Distribution` создал `ClaudeGravity-runtime.zip` / `ClaudeGravity-runtime.tar.gz`.

**После обновления осталось старое поведение**  
Повторно выполните установочную команду для своей платформы. Bundled runtime будет скачан заново из последнего GitHub Release. Google OAuth и Relay-настройки хранятся отдельно от install directory.

**`User location is not supported for the API use`**  
Selective Smart DNS уже применяется к целевым API-хостам. Если ошибка сохраняется, Google может отклонять аккаунт или выходной IP/ASN. Попробуйте другой интернет-канал или VPN.

**Хочу проверить работу без Smart DNS**  
Запустите ClaudeGravity с `CLAUDEGRAVITY_SMART_DNS=off`. Если поведение меняется, проблема, вероятно, связана с выбранным resolver или сетевым маршрутом.

**Claude Desktop не показывает модели**  
Проверьте **Developer Mode**, режим **Code**, затем перезапустите ClaudeGravity и Claude Desktop. Не закрывайте launcher ClaudeGravity, пока используете модели через Relay.

**`Check-Limits` пишет, что proxy не запущен**  
Сначала откройте основной `ClaudeGravity` launcher. Проверка лимитов читает локальный health endpoint `http://127.0.0.1:8080/health` и не запускает engine сама.

**Прокси не отвечает после запуска**  
Повторно запустите ClaudeGravity. Launcher проверяет bundled engine, запускает proxy и ждёт health endpoint. Если запуск снова завершается ошибкой, переустановите ClaudeGravity последней release-сборкой.

## Лицензии и ответственность

Bundled third-party компоненты сохраняют свои upstream LICENSE-файлы внутри `runtime/node_modules`. Дополнительные сведения находятся в [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

Claude, Gemini, Google Antigravity и названия моделей являются товарными знаками соответствующих владельцев. Проект предоставляется «как есть» без гарантий доступности моделей, квот или сохранности аккаунта.
