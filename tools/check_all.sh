#!/bin/bash
# Verifica a sintaxe/tipos de todos os scripts GDScript
cd "$(dirname "$0")/.."
fail=0
for f in $(find src -name "*.gd"); do
  out=$(timeout 60 godot --headless --check-only --script "res://$f" 2>&1 | grep -E "SCRIPT ERROR|Parse Error" -A1)
  if [ -n "$out" ]; then echo "== $f"; echo "$out" | head -8; fail=1; fi
done
[ $fail = 0 ] && echo "ALL OK"
