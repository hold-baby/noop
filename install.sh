#!/usr/bin/env bash
# noop installer (Linux / macOS)
#   a machine (the default; joins your noop):  curl -fsSL https://raw.githubusercontent.com/huacnlee/noop/main/install.sh | bash -s -- [<noop-url>]
#   the first machine, once (the primary):     curl -fsSL https://raw.githubusercontent.com/huacnlee/noop/main/install.sh | bash -s -- --primary
set -euo pipefail

HOME_DIR="${NOOP_HOME:-$([ -d "$HOME/.agent-hub" ] && [ ! -d "$HOME/.noop" ] && echo "$HOME/.agent-hub" || echo "$HOME/.noop")}"
APP="$HOME_DIR/app"
REPO="https://github.com/huacnlee/noop.git"
RAW="https://raw.githubusercontent.com/huacnlee/noop/main/install.sh"
LOG="$HOME_DIR/install.log"
# This installer's own arguments, captured out here: inside on_fail $* would be the function's own
# (the ERR trap passes none) and under `curl | bash` $0 is just "bash", so the medic used to be handed
# a rerun command of literally "bash " — no mode, no URL, nothing it could act on.
ARGV="$*"
if [ -f "$0" ]; then RERUN="bash $0"; else RERUN="curl -fsSL $RAW | bash -s --"; fi
RERUN="$RERUN${ARGV:+ $ARGV}"
mkdir -p "$HOME_DIR" && : > "$LOG"

if [ -t 1 ]; then B=$'\e[1m'; D=$'\e[2m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'; else B= D= G= Y= R= N=; fi
step() { printf "  %s%-30s%s" "$D" "$1" "$N"; }
ok()   { printf "%s✓%s %s\n" "$G" "$N" "${1:-}"; }
warn() { printf "%s!%s %s\n" "$Y" "$N" "$1"; }
run()  { "$@" >>"$LOG" 2>&1; }  # details go to the log, not the screen

on_fail() {
  printf "%s✗%s\n\n  Something went wrong. Asking the AI medic to fix it (details: %s)\n\n" "$R" "$N" "$LOG"
  if command -v bun >/dev/null && [ -f "$APP/src/cli.ts" ]; then
    bun "$APP/src/cli.ts" fix "install.sh failed. Log: $LOG. Finish the installation by rerunning: $RERUN" || true
  elif command -v claude >/dev/null; then
    claude -p "noop install.sh failed on $(uname -a). Read $LOG, fix the cause, then rerun the installer." --permission-mode acceptEdits || true
  fi
}
trap on_fail ERR

printf "\n%snoop%s — your own AI team\n\n" "$B" "$N"

step "git";  command -v git >/dev/null || { printf "%s✗%s install git first\n" "$R" "$N"; exit 1; }; ok
step "bun";  if ! command -v bun >/dev/null; then run bash -c "curl -fsSL https://bun.sh/install | bash"; export PATH="$HOME/.bun/bin:$PATH"; fi; ok "$(bun --version)"
step "noop"
if [ -d "$APP/.git" ]; then run git -C "$APP" pull -q --ff-only || true; else run git clone -q "$REPO" "$APP"; fi
(cd "$APP" && run bun install --frozen-lockfile)
mkdir -p "$HOME/.local/bin"
ln -sf "$APP/bin/noop" "$HOME/.local/bin/noop"; ln -sf "$APP/bin/noop" "$HOME/.local/bin/hub"
ok "$(git -C "$APP" rev-parse --short HEAD)"

missing=()
for c in claude codex gh; do command -v "$c" >/dev/null || missing+=("$c"); done
step "AI tools"; if [ ${#missing[@]} -eq 0 ]; then ok "claude, codex, gh"; else warn "missing: ${missing[*]} (install and log in for full capability)"; fi
echo

export NOOP_HOME="$HOME_DIR"
# interactive: email code (joining) or Cloudflare login (--primary); the questions read the terminal, not the piped script
rc=0
if [ -r /dev/tty ]; then "$APP/bin/noop" init "$@" </dev/tty || rc=$?; else "$APP/bin/noop" init "$@" || rc=$?; fi
# exit 2 = init needs an answer only the owner has (no noop to join and no --primary, or a URL/token that
# does not work). That is not something the AI medic can diagnose, so ask the question instead of burning a run.
if [ "$rc" -eq 2 ]; then
  trap - ERR
  printf "\n  %sSetup needs one answer:%s\n\n    the first machine, which hosts your noop:\n      %scurl -fsSL %s | bash -s -- --primary%s\n\n    any machine after that, joining it:\n      %scurl -fsSL %s | bash -s -- <your-noop-url>%s\n\n" "$B" "$N" "$D" "$RAW" "$N" "$D" "$RAW" "$N"
  exit 1
fi
if [ "$rc" -ne 0 ]; then trap - ERR; on_fail; exit "$rc"; fi
step "background service"; run "$APP/bin/noop" install; ok
echo
"$APP/bin/noop" status --brief || true
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) printf "\n  %sAdd ~/.local/bin to your PATH to use the noop command.%s\n" "$D" "$N";; esac
echo
