# Third-party notices

ClaudeGravity distributes pinned third-party components inside its release bundle. Their upstream LICENSE files remain inside `runtime/node_modules` and are part of the distributed archive.

## antigravity-claude-proxy

- Upstream: https://github.com/badrisnarayanan/antigravity-claude-proxy
- Pinned source commit: `055699fcebcac83cea64bf599546a3ce820ebcdb`
- Package metadata version at that commit: `2.7.7`
- License: MIT
- Copyright: 2024 Badri Narayanan S
- ClaudeGravity applies its own compatibility and selective Smart DNS patch during the build.

## @jacobbd/relay-ai 0.9.5

- Upstream: https://github.com/jacob-bd/relay-ai
- License: MIT
- Copyright: 2026 Jacob Ben David

## Alpine.js 3.16.2

- Package: `alpinejs`
- Upstream: https://github.com/alpinejs/alpine
- License: MIT
- ClaudeGravity vendors the browser build into the local WebUI so dashboard rendering does not depend on a public CDN.

## Chart.js 4.5.1

- Package: `chart.js`
- Upstream: https://github.com/chartjs/Chart.js
- License: MIT
- ClaudeGravity vendors the UMD browser build into the local WebUI so charts load from the same loopback origin.

ClaudeGravity is independent and is not affiliated with Anthropic or Google. Product and model names belong to their respective owners.
