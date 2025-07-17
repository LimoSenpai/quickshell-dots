#!/usr/bin/env bash

QUICKSHELL_CONFIG_NAME="ii"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CONFIG_DIR="$XDG_CONFIG_HOME/quickshell/$QUICKSHELL_CONFIG_NAME"
CACHE_DIR="$XDG_CACHE_HOME/quickshell"
STATE_DIR="$XDG_STATE_HOME/quickshell"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

term_alpha=100 #Set this to < 100 make all your terminals transparent
# sleep 0 # idk i wanted some delay or colors dont get applied properly
if [ ! -d "$STATE_DIR"/user/generated ]; then
  mkdir -p "$STATE_DIR"/user/generated
fi
cd "$CONFIG_DIR" || exit

colornames=''
colorstrings=''
colorlist=()
colorvalues=()

colornames=$(cat $STATE_DIR/user/generated/material_colors.scss | cut -d: -f1)
colorstrings=$(cat $STATE_DIR/user/generated/material_colors.scss | cut -d: -f2 | cut -d ' ' -f2 | cut -d ";" -f1)
IFS=$'\n'
colorlist=($colornames)     # Array of color names
colorvalues=($colorstrings) # Array of color values

apply_term() {
  # Check if terminal escape sequence template exists
  if [ ! -f "$SCRIPT_DIR/terminal/sequences.txt" ]; then
    echo "Template file not found for Terminal. Skipping that."
    return
  fi
  # Copy template
  mkdir -p "$STATE_DIR"/user/generated/terminal
  cp "$SCRIPT_DIR/terminal/sequences.txt" "$STATE_DIR"/user/generated/terminal/sequences.txt
  # Apply colors
  for i in "${!colorlist[@]}"; do
    sed -i "s/${colorlist[$i]} #/${colorvalues[$i]#\#}/g" "$STATE_DIR"/user/generated/terminal/sequences.txt
  done

  sed -i "s/\$alpha/$term_alpha/g" "$STATE_DIR/user/generated/terminal/sequences.txt"

  for file in /dev/pts/*; do
    if [[ $file =~ ^/dev/pts/[0-9]+$ ]]; then
      {
      cat "$STATE_DIR"/user/generated/terminal/sequences.txt >"$file"
      } & disown || true
    fi
  done
}

apply_qt() {
  sh "$CONFIG_DIR/scripts/kvantum/materialQT.sh"          # generate kvantum theme
  python "$CONFIG_DIR/scripts/kvantum/changeAdwColors.py" # apply config colors
}

generate_rofi_colors() {
    # Read the generated material colors
    if [ -f "$STATE_DIR/user/generated/material_colors.scss" ]; then
        # Extract colors from the SCSS file and convert to rofi format
        cat > "$STATE_DIR/user/generated/material_colors_rofi.rasi" << EOF
* {
    background: $(grep '^\$background:' "$STATE_DIR/user/generated/material_colors.scss" | cut -d: -f2 | tr -d ';' | xargs);
    surface: $(grep '^\$surface:' "$STATE_DIR/user/generated/material_colors.scss" | cut -d: -f2 | tr -d ';' | xargs);
    primary: $(grep '^\$primary:' "$STATE_DIR/user/generated/material_colors.scss" | cut -d: -f2 | tr -d ';' | xargs);
    secondary: $(grep '^\$secondary:' "$STATE_DIR/user/generated/material_colors.scss" | cut -d: -f2 | tr -d ';' | xargs);
    tertiary: $(grep '^\$tertiary:' "$STATE_DIR/user/generated/material_colors.scss" | cut -d: -f2 | tr -d ';' | xargs);
    on-surface: $(grep '^\$onSurface:' "$STATE_DIR/user/generated/material_colors.scss" | cut -d: -f2 | tr -d ';' | xargs);
    on-primary: $(grep '^\$onPrimary:' "$STATE_DIR/user/generated/material_colors.scss" | cut -d: -f2 | tr -d ';' | xargs);
    on-secondary: $(grep '^\$onSecondary:' "$STATE_DIR/user/generated/material_colors.scss" | cut -d: -f2 | tr -d ';' | xargs);
    on-tertiary: $(grep '^\$onTertiary:' "$STATE_DIR/user/generated/material_colors.scss" | cut -d: -f2 | tr -d ';' | xargs);
    surface-container: $(grep '^\$surfaceContainer:' "$STATE_DIR/user/generated/material_colors.scss" | cut -d: -f2 | tr -d ';' | xargs);
    secondary-container: $(grep '^\$secondaryContainer:' "$STATE_DIR/user/generated/material_colors.scss" | cut -d: -f2 | tr -d ';' | xargs);
    on-secondary-container: $(grep '^\$onSecondaryContainer:' "$STATE_DIR/user/generated/material_colors.scss" | cut -d: -f2 | tr -d ';' | xargs);
    on-surface-variant: $(grep '^\$onSurfaceVariant:' "$STATE_DIR/user/generated/material_colors.scss" | cut -d: -f2 | tr -d ';' | xargs);
    error: $(grep '^\$error:' "$STATE_DIR/user/generated/material_colors.scss" | cut -d: -f2 | tr -d ';' | xargs);
    error-container: $(grep '^\$errorContainer:' "$STATE_DIR/user/generated/material_colors.scss" | cut -d: -f2 | tr -d ';' | xargs);
    on-error-container: $(grep '^\$onErrorContainer:' "$STATE_DIR/user/generated/material_colors.scss" | cut -d: -f2 | tr -d ';' | xargs);
}
EOF
        echo "Generated rofi colors at $STATE_DIR/user/generated/material_colors_rofi.rasi"
    else
        echo "Warning: material_colors.scss not found, cannot generate rofi colors"
    fi
}

# Check if terminal theming is enabled in config
CONFIG_FILE="$XDG_CONFIG_HOME/illogical-impulse/config.json"
if [ -f "$CONFIG_FILE" ]; then
  enable_terminal=$(jq -r '.appearance.wallpaperTheming.enableTerminal' "$CONFIG_FILE")
  if [ "$enable_terminal" = "true" ]; then
    apply_term &
  fi
else
  echo "Config file not found at $CONFIG_FILE. Applying terminal theming by default."
  apply_term &
fi

generate_rofi_colors &

# apply_qt & # Qt theming is already handled by kde-material-colors
