#!/usr/bin/env bash
# IP guardrail (DESIGN §2): fails if distinctive franchise terms appear in game content.
# docs/ is excluded on purpose (the guardrail docs name what we avoid).
source "$(dirname "$0")/lib/common.sh"

DENY='pip-?boy|vault-?tec|nuka|s\.p\.e\.c\.i\.a\.l|brotherhood of steel|v\.a\.t\.s|deathclaw|super ?mutant|rad-?away|rad-x|stimpak|mentats|fusion core|minutem[ae]n|vault ?boy|dogmeat|mr\.? handy|power armou?r|bottle ?caps?|bethesda|fallout'
DIRS=(src data translations assets)
existing=()
for d in "${DIRS[@]}"; do [[ -d "$ROOT/$d" ]] && existing+=("$d"); done

# Relative paths: the repository's own directory name must not trigger the check.
cd "$ROOT"
hits="$(grep -rniE "$DENY" "${existing[@]}" --include='*.gd' --include='*.tres' --include='*.tscn' \
  --include='*.csv' --include='*.json' --include='*.dlg' --include='*.gdshader' --include='*.cfg' || true)"
names="$(find "${existing[@]}" -type f | grep -iE "$DENY" || true)"
if [[ -n "$hits$names" ]]; then
  printf '%s\n%s\n' "$hits" "$names" >&2
  die "IP denylist hit — use our own names (docs/DESIGN.md §2)"
fi
ok "IP check clean (${existing[*]})"
