# Repository Guidelines

## Project Structure & Module Organization
- Source: Top-level contains ESPHome device configs (`*.yml`) such as `mobile-11.yml`, `curebox6.yml`, and grow-room profiles.
- Backups: Historical variants end with `_bu`, `_buYYYYMMDD`, or `_orig` (e.g., `mobile-18_bu20250316.yml`). Prefer a single dated backup per change.
- Templates: Files named `*_TEMPLATE.*` guide new configs (e.g., `fullGrw_TEMPLATE.yml`).
- Automations: Node-RED assets like `flows.json` and small JS helpers (`camera.js`, `intake_fan_rules.js`).

## Build, Test, and Development Commands
- `esphome config <file.yml>`: Validate YAML and references without compiling.
- `esphome compile <file.yml>`: Generate firmware to catch build-time issues.
- `esphome upload <file.yml>`: Flash over serial or OTA. Example: `esphome upload mobile-11.yml`.
- `esphome logs <file.yml>`: Stream logs for live verification.
- `esphome run <file.yml>`: Compile, upload, then tail logs in one step.

## Coding Style & Naming Conventions
- YAML: 2-space indent; place keys in common ESPHome order: `esphome`, MCU (`esp32`/`esp8266`), `wifi`, `logger`, `api`, `ota`, then sensors/actors.
- Filenames: Kebab-case, device-prefixed (e.g., `mobile-25.yml`). Use dated backups like `_buYYYYMMDD` and clean obsolete ones when merged.
- Comments: Prefer concise `# why` above non-obvious blocks.
- JS helpers: 2-space indent, semicolons, small pure functions.

## Testing Guidelines
- Validation: Run `esphome config` for every change; ensure compile succeeds.
- On-device check: Use `esphome logs` to verify sensors, switches, and automations.
- Scope: Keep changes device-specific; avoid side effects across unrelated configs.

## Commit & Pull Request Guidelines
- Messages: Imperative, scope-first. Example: `mobile-11: raise fan hysteresis to 2°C`.
- Include: Brief rationale, affected files, and validation notes (config/compile/logs).
- PRs: Small, focused diffs; link related issue or device context; add screenshots of logs when helpful.

## Security & Configuration Tips
- Secrets: Use `!secret` for credentials and tokens; keep `secrets.yaml` untracked (add to `.gitignore`). Example:
  ```yaml
  wifi:
    ssid: !secret wifi_ssid
    password: !secret wifi_password
  ```
- Sanitization: Avoid committing IPs, MACs, or tokens in backups; scrub before push.

