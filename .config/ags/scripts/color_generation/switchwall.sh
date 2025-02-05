#!/usr/bin/env bash

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
CONFIG_DIR="$XDG_CONFIG_HOME/ags"
CACHE_DIR="$XDG_CACHE_HOME/ags"

# Add --noswitch handling at the beginning
if [ "$1" == "--noswitch" ]; then
	first_monitor_wallpaper=$(swww query | awk -F 'image: ' 'NR==1 {print $2}')
	"$CONFIG_DIR"/scripts/color_generation/colorgen.sh "${first_monitor_wallpaper}" --apply --smart
	exit 0
fi

# Capture original wallpaper before any changes
original_first_wallpaper=$(swww query | awk -F 'image: ' 'NR==1 {print $2}')

switch() {
	local monitor=$1
	local imgpath=$2
	# read scale screenx screeny screensizey < <(hyprctl monitors -j | jq --arg mon "$monitor" '.[] | select(.name==$mon) | .scale, .x, .y, .height' | xargs)
	# cursorposx=$(hyprctl cursorpos -j | jq '.x' 2>/dev/null) || cursorposx=960
	# cursorposx=$(bc <<< "scale=0; ($cursorposx - $screenx) * $scale / 1")
	# cursorposy=$(hyprctl cursorpos -j | jq '.y' 2>/dev/null) || cursorposy=540
	# cursorposy=$(bc <<< "scale=0; ($cursorposy - $screeny) * $scale / 1")
	# cursorposy_inverted=$((screensizey - cursorposy))

	if [ "$imgpath" == '' ]; then
		echo "Aborted for monitor $monitor"
		return 1
	fi

	swww img "$imgpath" --outputs "$monitor" \
		--transition-step 100 --transition-fps 120 \
		--transition-type grow --transition-angle 30 --transition-duration 1 \
		# --transition-pos "$cursorposx, $cursorposy_inverted"
}

# Get list of monitors
readarray -t monitors < <(hyprctl monitors -j | jq -r '.[].name')
first_monitor_wallpaper=""

cd "$(xdg-user-dir PICTURES)" || exit 1

# Add floating rule for yad dialog
hyprctl keyword windowrule "float,^(yad)$" >/dev/null

# Handle each monitor
for monitor in "${monitors[@]}"; do
	echo "Select wallpaper for monitor: $monitor"
	imgpath=$(yad --width 1200 --height 800 --file --add-preview --large-preview --title="Choose wallpaper for $monitor")
	
	# Store first monitor's wallpaper for color generation
	if [ "$monitor" = "${monitors[0]}" ]; then
		first_monitor_wallpaper="$imgpath"
	fi
	
	switch "$monitor" "$imgpath"
done

# Remove the floating rule after we're done
hyprctl keyword windowrule "unset,^(yad)$" >/dev/null

# Generate colors only if wallpaper changed
new_first_wallpaper="${first_monitor_wallpaper:-$(swww query | awk -F 'image: ' 'NR==1 {print $2}')}"
if [ "$original_first_wallpaper" != "$new_first_wallpaper" ]; then
    "$CONFIG_DIR"/scripts/color_generation/colorgen.sh "$new_first_wallpaper" --apply --smart
fi
