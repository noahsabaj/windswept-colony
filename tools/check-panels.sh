#!/usr/bin/env bash
#
# check-panels.sh -- cross-repo unregistered-panel guard.
#
# Fails if any custom "ws*" VGUI panel is instantiated (vgui.Create / :Add) or used as a base
# class (3rd arg of vgui.Register) but is never registered via vgui.Register across the given
# repo roots. This catches the class of bug where one repo references a panel that a co-loaded
# repo is supposed to provide, but none does -- e.g. the wsBirthDatePicker char-creation crash,
# where the framework's appearance plugin did container:Add("wsBirthDatePicker") but the schema
# had stopped registering it. luacheck cannot catch this: the panel name is a plain string.
#
# Cross-repo by design: pass EVERY repo that ships and loads together (framework + schema + any
# addon that registers panels) so a framework reference resolved by a schema registration is not
# a false positive. Run from the directory that contains the repo roots.
#
#   Usage: tools/check-panels.sh <repo-root> [<repo-root> ...]   (defaults to ".")
#
set -euo pipefail

roots=("$@")
if [ "${#roots[@]}" -eq 0 ]; then roots=("."); fi

registered="$(mktemp)"
referenced="$(mktemp)"
trap 'rm -f "$registered" "$referenced"' EXIT

for root in "${roots[@]}"; do
	if [ ! -d "$root" ]; then
		echo "check-panels: WARNING -- root '$root' not found, skipping" >&2
		continue
	fi

	# Panels that ARE registered (1st arg of vgui.Register)
	grep -rhoE 'vgui\.Register\(\s*"ws[A-Za-z0-9_]+"' "$root" --include='*.lua' 2>/dev/null \
		| grep -oE 'ws[A-Za-z0-9_]+' >> "$registered" || true

	# Panels REFERENCED via vgui.Create(...) or :Add(...)
	grep -rhoE '(vgui\.Create|:Add)\(\s*"ws[A-Za-z0-9_]+"' "$root" --include='*.lua' 2>/dev/null \
		| grep -oE 'ws[A-Za-z0-9_]+' >> "$referenced" || true

	# Panels REFERENCED as a base class (3rd arg of vgui.Register("name", PANEL, "wsBase"))
	grep -rhE 'vgui\.Register\(' "$root" --include='*.lua' 2>/dev/null \
		| sed -nE 's/.*vgui\.Register\(\s*"ws[A-Za-z0-9_]+"\s*,[^,]*,\s*"(ws[A-Za-z0-9_]+)".*/\1/p' >> "$referenced" || true
done

missing="$(comm -23 <(sort -u "$referenced") <(sort -u "$registered") | grep -E '^ws' || true)"

if [ -n "$missing" ]; then
	echo "check-panels: FAIL"
	echo "These custom panels are instantiated but never vgui.Register'd across the checked repos"
	echo "(they resolve to NULL at runtime and break whatever creates them):"
	echo "$missing" | sed 's/^/  - /'
	echo ""
	echo "Fix: register the panel, or also pass the repo that defines it as an argument."
	exit 1
fi

reg_count="$(sort -u "$registered" | grep -cE '^ws' || true)"
ref_count="$(sort -u "$referenced" | grep -cE '^ws' || true)"
echo "check-panels: OK -- every referenced ws* panel is registered (${reg_count} registered, ${ref_count} referenced)."
