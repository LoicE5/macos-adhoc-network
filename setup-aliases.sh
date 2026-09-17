#!/usr/bin/env zsh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ALIASES_FILE="$HOME/.zsh_aliases"
START="# Ad-hoc network aliases"
END="# End ad-hoc network aliases"

touch "$ALIASES_FILE"
sed -i '' "/^$START$/,/^$END$/d" "$ALIASES_FILE"

echo "$START" >> "$ALIASES_FILE"
for script in "$SCRIPT_DIR"/*.sh; do
    [ "$(basename "$script")" = "setup-aliases.sh" ] && continue
    echo "alias $(basename "$script" .sh)='$script'" >> "$ALIASES_FILE"
done
echo "$END" >> "$ALIASES_FILE"

echo "Aliases updated in $ALIASES_FILE"
