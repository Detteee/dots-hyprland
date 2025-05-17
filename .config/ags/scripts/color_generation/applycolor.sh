#!/usr/bin/env bash

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CONFIG_DIR="$XDG_CONFIG_HOME/ags"
CACHE_DIR="$XDG_CACHE_HOME/ags"
STATE_DIR="$XDG_STATE_HOME/ags"

term_alpha=96 #Set this to < 100 make all your terminals transparent
# sleep 0 # idk i wanted some delay or colors dont get applied properly
if [ ! -d "$CACHE_DIR"/user/generated ]; then
  mkdir -p "$CACHE_DIR"/user/generated
fi
cd "$CONFIG_DIR" || exit

colornames=''
colorstrings=''
colorlist=()
colorvalues=()

# wallpath=$(swww query | head -1 | awk -F 'image: ' '{print $2}')
# wallpath_png="$CACHE_DIR"/user/generated/hypr/lockscreen.png"
# convert "$wallpath" "$wallpath_png"
# wallpath_png=$(echo "$wallpath_png" | sed 's/\//\\\//g')
# wallpath_png=$(sed 's/\//\\\\\//g' <<< "$wallpath_png")

transparentize() {
  local hex="$1"
  local alpha="$2"
  local red green blue

  red=$((16#${hex:1:2}))
  green=$((16#${hex:3:2}))
  blue=$((16#${hex:5:2}))

  printf 'rgba(%d, %d, %d, %.2f)\n' "$red" "$green" "$blue" "$alpha"
}

get_light_dark() {
  lightdark=""
  if [ ! -f "$STATE_DIR/user/colormode.txt" ]; then
    echo "" >"$STATE_DIR/user/colormode.txt"
  else
    lightdark=$(sed -n '1p' "$STATE_DIR/user/colormode.txt")
  fi
  echo "$lightdark"
}

apply_fuzzel() {
  # Check if template exists
  if [ ! -f "scripts/templates/fuzzel/fuzzel.ini" ]; then
    echo "Template file not found for Fuzzel. Skipping that."
    return
  fi
  # Copy template
  mkdir -p "$CACHE_DIR"/user/generated/fuzzel
  cp "scripts/templates/fuzzel/fuzzel.ini" "$CACHE_DIR"/user/generated/fuzzel/fuzzel.ini
  # Apply colors
  for i in "${!colorlist[@]}"; do
    sed -i "s/{{ ${colorlist[$i]} }}/${colorvalues[$i]#\#}/g" "$CACHE_DIR"/user/generated/fuzzel/fuzzel.ini
  done

  cp "$CACHE_DIR"/user/generated/fuzzel/fuzzel.ini "$XDG_CONFIG_HOME"/fuzzel/fuzzel.ini
}

apply_term() {
  # Check if terminal escape sequence template exists
  if [ ! -f "scripts/templates/terminal/sequences.txt" ]; then
    echo "Template file not found for Terminal. Skipping that."
    return
  fi
  # Copy template
  mkdir -p "$CACHE_DIR"/user/generated/terminal
  cp "scripts/templates/terminal/sequences.txt" "$CACHE_DIR"/user/generated/terminal/sequences.txt
  # Apply colors
  for i in "${!colorlist[@]}"; do
    sed -i "s/${colorlist[$i]} #/${colorvalues[$i]#\#}/g" "$CACHE_DIR"/user/generated/terminal/sequences.txt
  done

  sed -i "s/\$alpha/$term_alpha/g" "$CACHE_DIR/user/generated/terminal/sequences.txt"

  for file in /dev/pts/*; do
    if [[ $file =~ ^/dev/pts/[0-9]+$ ]]; then
      cat "$CACHE_DIR"/user/generated/terminal/sequences.txt >"$file"
    fi
  done
}

apply_hyprland() {
  # Check if template exists
  if [ ! -f "scripts/templates/hypr/hyprland/colors.conf" ]; then
    echo "Template file not found for Hyprland colors. Skipping that."
    return
  fi
  # Copy template
  mkdir -p "$CACHE_DIR"/user/generated/hypr/hyprland
  cp "scripts/templates/hypr/hyprland/colors.conf" "$CACHE_DIR"/user/generated/hypr/hyprland/colors.conf
  # Apply colors
  for i in "${!colorlist[@]}"; do
    sed -i "s/{{ ${colorlist[$i]} }}/${colorvalues[$i]#\#}/g" "$CACHE_DIR"/user/generated/hypr/hyprland/colors.conf
  done

  cp "$CACHE_DIR"/user/generated/hypr/hyprland/colors.conf "$XDG_CONFIG_HOME"/hypr/hyprland/colors.conf
}

apply_hyprlock() {
  # Check if template exists
  if [ ! -f "scripts/templates/hypr/hyprlock.conf" ]; then
    echo "Template file not found for hyprlock. Skipping that."
    return
  fi
  # Copy template
  mkdir -p "$CACHE_DIR"/user/generated/hypr/
  cp "scripts/templates/hypr/hyprlock.conf" "$CACHE_DIR"/user/generated/hypr/hyprlock.conf
  # Apply colors
  # sed -i "s/{{ SWWW_WALL }}/${wallpath_png}/g" "$CACHE_DIR"/user/generated/hypr/hyprlock.conf
  for i in "${!colorlist[@]}"; do
    sed -i "s/{{ ${colorlist[$i]} }}/${colorvalues[$i]#\#}/g" "$CACHE_DIR"/user/generated/hypr/hyprlock.conf
  done

  cp "$CACHE_DIR"/user/generated/hypr/hyprlock.conf "$XDG_CONFIG_HOME"/hypr/hyprlock.conf
}

apply_ags_sourceview() {
  # Check if template file exists
  if [ ! -f "scripts/templates/ags/sourceviewtheme.xml" ]; then
    echo "Template file not found for ags sourceview. Skipping that."
    return
  fi
  # Copy template
  mkdir -p "$CACHE_DIR"/user/generated/ags
  cp "scripts/templates/ags/sourceviewtheme.xml" "$CACHE_DIR"/user/generated/ags/sourceviewtheme.xml
  cp "scripts/templates/ags/sourceviewtheme-light.xml" "$CACHE_DIR"/user/generated/ags/sourceviewtheme-light.xml
  # Apply colors
  for i in "${!colorlist[@]}"; do
    sed -i "s/{{ ${colorlist[$i]} }}/#${colorvalues[$i]#\#}/g" "$CACHE_DIR"/user/generated/ags/sourceviewtheme.xml
    sed -i "s/{{ ${colorlist[$i]} }}/#${colorvalues[$i]#\#}/g" "$CACHE_DIR"/user/generated/ags/sourceviewtheme-light.xml
  done

  cp "$CACHE_DIR"/user/generated/ags/sourceviewtheme.xml "$XDG_CONFIG_HOME"/ags/assets/themes/sourceviewtheme.xml
  cp "$CACHE_DIR"/user/generated/ags/sourceviewtheme-light.xml "$XDG_CONFIG_HOME"/ags/assets/themes/sourceviewtheme-light.xml
}

apply_lightdark() {
  lightdark=$(get_light_dark)
  if [ "$lightdark" = "light" ]; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
  else
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
  fi
}

apply_gtk() {
  # Check if template exists
  if [ ! -f "scripts/templates/gtk/gtk-colors.css" ]; then
    echo "Template file not found for gtk colors. Skipping that."
    return
  fi
  # Copy template
  mkdir -p "$CACHE_DIR"/user/generated/gtk/
  cp "scripts/templates/gtk/gtk-colors.css" "$CACHE_DIR"/user/generated/gtk/gtk-colors.css
  # Apply colors
  for i in "${!colorlist[@]}"; do
    sed -i "s/{{ ${colorlist[$i]} }}/#${colorvalues[$i]#\#}/g" "$CACHE_DIR"/user/generated/gtk/gtk-colors.css
  done

  # Apply to both gtk3 and gtk4
  cp "$CACHE_DIR"/user/generated/gtk/gtk-colors.css "$XDG_CONFIG_HOME"/gtk-3.0/gtk.css
  cp "$CACHE_DIR"/user/generated/gtk/gtk-colors.css "$XDG_CONFIG_HOME"/gtk-4.0/gtk.css

  # And set the right variant of adw gtk3
  lightdark=$(get_light_dark)
  if [ "$lightdark" = "light" ]; then
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3'
  else
    gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark
  fi
}

apply_ags() {
  agsv1 run-js "handleStyles(false);"
  agsv1 run-js 'openColorScheme.value = true; Utils.timeout(2000, () => openColorScheme.value = false);'
}

apply_qt() {
  sh "$CONFIG_DIR/scripts/kvantum/materialQT.sh"          # generate kvantum theme
  python "$CONFIG_DIR/scripts/kvantum/changeAdwColors.py" # apply config colors
}

apply_textfox_css() {
  echo "Attempting to update Firefox defaults.css" # More accurate message

  local firefox_profile_dir
  # Find the Firefox profile directory ending in .default-release
  firefox_profile_dir=$(find "$HOME/.mozilla/firefox/" -maxdepth 1 -type d -name "*.default-release" -print -quit)

  # Check if a profile directory was found
  if [ -z "$firefox_profile_dir" ]; then
    echo "Error: Could not find a Firefox profile directory ending in '.default-release'."
    echo "Please ensure Firefox has been run at least once and a profile exists."
    return
  fi

  local defaults_css_path="$firefox_profile_dir/chrome/defaults.css"
  echo "Targeting Firefox defaults.css at: $defaults_css_path" # Debug print

  # Extract the primary color from the SCSS file
  local primary_color=$(grep '$primary:' "$STATE_DIR/scss/_material.scss" | awk '{print $2}' | sed 's/;//')

  # Check if primary_color was found
  if [ -z "$primary_color" ]; then
    echo "Could not find \$primary color in $STATE_DIR/scss/_material.scss. Skipping textfox css update."
    return
  fi
  echo "Extracted primary color: $primary_color" # Debug print

  # Check if the defaults.css file exists. If not, create the directory and an empty file.
  if [ ! -f "$defaults_css_path" ]; then
    echo "Warning: defaults.css not found at $defaults_css_path."
    echo "Attempting to create the directory and file."
    mkdir -p "$(dirname "$defaults_css_path")"
    touch "$defaults_css_path"
    echo "Created directory and empty defaults.css file."
  fi
   echo "Found or created defaults.css file." # Debug print


  # Check which lines match the pattern before sed (for debugging)
  echo "Lines matching pattern '^\s*--tf-accent:.*' in $defaults_css_path:" # Debug print
  local matched_lines=$(grep -n "^\s*--tf-accent:.*" "$defaults_css_path")
  if [ -z "$matched_lines" ]; then
      echo "Pattern not found in $defaults_css_path."
      # If the pattern is not found, add the line.
      echo "Adding --tf-accent line to $defaults_css_path."
      echo "  --tf-accent: ${primary_color}; /* Accent color used, eg: color when hovering a container */" >> "$defaults_css_path"
      echo "Successfully added --tf-accent line."
  else
      echo "$matched_lines" # Print matched lines if found
      # If the pattern is found, update the line using sed.
      echo "Pattern found. Attempting to update the line."
      if sed -i "s|^\s*--tf-accent:.*|  --tf-accent: ${primary_color}; /* Accent color used, eg: color when hovering a container */|" "$defaults_css_path"; then
          echo "Successfully updated --tf-accent in $defaults_css_path to ${primary_color}"
      else
          echo "Error: sed command failed to update $defaults_css_path. Check permissions and file content."
      fi
  fi
}


colornames=$(cat $STATE_DIR/scss/_material.scss | cut -d: -f1)
colorstrings=$(cat $STATE_DIR/scss/_material.scss | cut -d: -f2 | cut -d ' ' -f2 | cut -d ";" -f1)
IFS=$'\n'
colorlist=($colornames)     # Array of color names
colorvalues=($colorstrings) # Array of color values

apply_ags &
apply_ags_sourceview &
apply_hyprland &
apply_hyprlock &
apply_lightdark &
apply_gtk &
apply_qt &
apply_fuzzel &
apply_term &
apply_textfox_css &
