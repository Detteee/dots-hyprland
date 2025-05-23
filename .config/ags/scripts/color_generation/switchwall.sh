#!/usr/bin/env bash

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
CONFIG_DIR="$XDG_CONFIG_HOME/ags"
CACHE_DIR="$XDG_CACHE_HOME/ags"

THUMBNAIL_DIR="/tmp/mpvpaper_thumbnails"
CUSTOM_DIR="$XDG_CONFIG_HOME/hypr/custom" # Adjust if your custom script dir is different
RESTORE_SCRIPT_DIR="$CUSTOM_DIR/scripts"
RESTORE_SCRIPT_PATH="$RESTORE_SCRIPT_DIR/__restore_mixed_wallpapers.sh" # Renamed for clarity
VIDEO_OPTS="no-audio loop hwdec=auto scale=bilinear interpolation=no video-sync=display-resample panscan=1.0 video-scale-x=1.0 video-scale-y=1.0 video-align-x=0.5 video-align-y=0.5"

mkdir -p "$THUMBNAIL_DIR"
mkdir -p "$RESTORE_SCRIPT_DIR"

# --- Helper Functions ---
is_video() {
    local filename="$1"
    local extension="${filename##*.}"
    extension="${extension,,}" # to lowercase
    [[ "$extension" == "mp4" || "$extension" == "mkv" || "$extension" == "webm" ]] && return 0 || return 1
}

kill_all_mpvpaper_instances() {
    echo "Stopping all existing mpvpaper instances..."
    pkill -f -9 mpvpaper || true
}

kill_mpvpaper_on_monitor() {
    local monitor_name_arg="$1"
    echo "Checking for mpvpaper on monitor: $monitor_name_arg"
    # Attempt to find and kill mpvpaper processes associated with this specific monitor.
    # This relies on the monitor name being an argument to mpvpaper that can be grepped.
    # Example mpvpaper command: mpvpaper -o "opts" "DP-1" "/path/to/video.mp4"
    # We look for lines from 'ps' that contain 'mpvpaper' and the specific monitor name, then kill the process.
    local pids_to_kill=$(ps -eo pid,cmd | grep '[m]pvpaper' | grep -w -- "$monitor_name_arg" | awk '{print $1}')
    if [ -n "$pids_to_kill" ]; then
        echo "Stopping mpvpaper (PID(s): $pids_to_kill) on monitor $monitor_name_arg."
        echo "$pids_to_kill" | xargs -r kill -9
    else
        echo "No mpvpaper instance found specifically for monitor $monitor_name_arg to stop."
    fi
}

apply_static_wallpaper() {
    local monitor="$1"
    local imgpath="$2"

    if [ -z "$imgpath" ]; then
        echo "No image path provided for monitor $monitor. Skipping."
        return 1
    fi
    if [ ! -f "$imgpath" ]; then
        echo "Image path does not exist for monitor $monitor: $imgpath. Skipping."
        return 1
    fi

    echo "Applying static wallpaper '$imgpath' to monitor '$monitor'"
    kill_mpvpaper_on_monitor "$monitor" # Ensure video is not running on this monitor

    if ! pgrep -f swww-daemon > /dev/null; then
        echo "swww-daemon not running. Attempting to start it..."
        (swww init &)
        sleep 1
        if ! pgrep -f swww-daemon > /dev/null; then
            echo "Error: Failed to start swww-daemon. Cannot set static wallpaper."
            return 1
        fi
    fi

    swww img "$imgpath" --outputs "$monitor" \
        --transition-step 100 --transition-fps 120 \
        --transition-type grow --transition-angle 30 --transition-duration 1
}

# --- --noswitch Handling ---
if [ "$1" == "--noswitch" ]; then
    echo "Running --noswitch: Applying colorgen to current wallpaper..."
    current_wallpaper_path=""
    source_for_colorgen=""

    if pgrep -f mpvpaper > /dev/null; then
        # Try to get path of any video wallpaper; uses last argument assumed to be path with extension
        current_wallpaper_path=$(ps -eo cmd | grep '[m]pvpaper' | grep -E '\.mp4|\.mkv|\.webm' | awk '{print $NF}' | head -n 1)
        if [ -n "$current_wallpaper_path" ] && [ -f "$current_wallpaper_path" ]; then
            echo "Detected video wallpaper: $current_wallpaper_path (using this for colorgen)"
            thumbnail_path="$THUMBNAIL_DIR/$(basename "$current_wallpaper_path").jpg" # Consistent name
            if [ ! -f "$thumbnail_path" ] || [ "$current_wallpaper_path" -nt "$thumbnail_path" ]; then
                ffmpeg -y -i "$current_wallpaper_path" -vframes 1 "$thumbnail_path" 2>/dev/null
            fi
            if [ -f "$thumbnail_path" ]; then
                source_for_colorgen="$thumbnail_path"
            else
                echo "Error: Cannot create/find thumbnail for video wallpaper in --noswitch."
            fi
        else
             echo "Warning: mpvpaper is running but could not reliably determine a video path for colorgen."
        fi
    elif pgrep -f swww-daemon > /dev/null; then
        current_wallpaper_path=$(swww query | awk -F 'image: ' 'NR==1 {print $2}') # Wallpaper from first monitor
        if [ -n "$current_wallpaper_path" ] && [ -f "$current_wallpaper_path" ]; then
            echo "Detected static wallpaper on first monitor: $current_wallpaper_path"
            source_for_colorgen="$current_wallpaper_path"
        else
            echo "Warning: swww-daemon is running but could not determine wallpaper path for colorgen."
        fi
    else
        echo "No known wallpaper manager (mpvpaper or swww-daemon) active for --noswitch."
    fi

    if [ -n "$source_for_colorgen" ]; then
        echo "Applying color scheme from: $source_for_colorgen"
        "$CONFIG_DIR"/scripts/color_generation/colorgen.sh "$source_for_colorgen" --apply --smart
    else
        echo "Could not determine wallpaper for colorgen in --noswitch mode."
    fi
    exit 0
fi

# --- Main Script Logic ---
hyprctl keyword windowrule "float,^(yad)$" >/dev/null 2>&1
cd "$(xdg-user-dir PICTURES)/Wallpapers" || cd "$(xdg-user-dir PICTURES)" || {
    echo "Error: Could not navigate to a suitable Pictures directory."
    hyprctl keyword windowrule "unset,^(yad)$" >/dev/null 2>&1
    exit 1
}

kill_all_mpvpaper_instances # Start with a clean slate from any previous mpvpaper instances

# Initialize/clear the restore script for video wallpapers
echo "#!/bin/bash" > "$RESTORE_SCRIPT_PATH"
echo "# Generated by wallpaper switcher - $(date)" >> "$RESTORE_SCRIPT_PATH"
echo "# This script restores video wallpapers set by the script." >> "$RESTORE_SCRIPT_PATH"
echo "echo 'Restoring video wallpapers...'" >> "$RESTORE_SCRIPT_PATH"
echo "pkill -f -9 mpvpaper || true # Kill any existing mpvpaper instances before restoring specific ones" >> "$RESTORE_SCRIPT_PATH"
echo "" >> "$RESTORE_SCRIPT_PATH"
chmod +x "$RESTORE_SCRIPT_PATH"
video_was_set_on_any_monitor=false

readarray -t monitors < <(hyprctl monitors -j | jq -r '.[].name')
if [ ${#monitors[@]} -eq 0 ]; then
    echo "Error: No monitors detected by Hyprland."
    hyprctl keyword windowrule "unset,^(yad)$" >/dev/null 2>&1
    exit 1
fi

source_for_colorgen="" # Will hold path to image/thumbnail from the first monitor

for i in "${!monitors[@]}"; do
    monitor_name="${monitors[$i]}"
    echo "Select wallpaper for monitor: $monitor_name (${i+1}/${#monitors[@]})"
    imgpath=$(yad --width 1200 --height 800 --file --add-preview --large-preview --title="Choose wallpaper for $monitor_name")

    if [ -z "$imgpath" ]; then
        echo "No file selected for $monitor_name. Skipping."
        if [ "$i" -eq 0 ] && [ -z "$source_for_colorgen" ]; then # If first monitor skipped
             # Try to get existing wallpaper on first monitor if user skips selection for it
            if pgrep -f swww-daemon > /dev/null; then
                source_for_colorgen=$(swww query | awk -F 'image: ' 'NR==1 {print $2}')
            fi
        fi
        continue
    fi
    if [ ! -f "$imgpath" ]; then
        echo "Error: Selected file for $monitor_name does not exist: $imgpath. Skipping."
        continue
    fi

    if is_video "$imgpath"; then
        echo "Setting video wallpaper for $monitor_name: $imgpath"
        kill_mpvpaper_on_monitor "$monitor_name" # Kill any old video specifically on this monitor.

        missing_deps=()
        if ! command -v mpvpaper &> /dev/null; then missing_deps+=("mpvpaper"); fi
        if ! command -v ffmpeg &> /dev/null; then missing_deps+=("ffmpeg"); fi
        if [ ${#missing_deps[@]} -gt 0 ]; then
            yad --error --text="Missing dependencies for video: ${missing_deps[*]}.\nPlease install them. Video for $monitor_name will be skipped." --width=400 --height=100
            echo "Warning: Missing video dependencies. Cannot set video for $monitor_name."
            continue # Skip setting video for this monitor
        fi
        
        mpvpaper -o "$VIDEO_OPTS" "$monitor_name" "$imgpath" &
        # Add command to restore script, ensuring paths with spaces are quoted.
        echo "mpvpaper -o '$VIDEO_OPTS' '$monitor_name' '$imgpath' & # Wallpaper for $monitor_name" >> "$RESTORE_SCRIPT_PATH"
        video_was_set_on_any_monitor=true

        if [ "$i" -eq 0 ]; then # If this is the first monitor
            # Consistent thumbnail name for --noswitch and simplicity
            thumbnail_path="$THUMBNAIL_DIR/$(basename "$imgpath").jpg"
            ffmpeg -y -i "$imgpath" -vframes 1 "$thumbnail_path" 2>/dev/null
            if [ -f "$thumbnail_path" ]; then
                source_for_colorgen="$thumbnail_path"
            else
                echo "Warning: Could not generate thumbnail for video on first monitor: $monitor_name."
            fi
        fi
    else # It's an image
        echo "Setting static wallpaper for $monitor_name: $imgpath"
        # apply_static_wallpaper already calls kill_mpvpaper_on_monitor for this monitor
        apply_static_wallpaper "$monitor_name" "$imgpath"
        if [ "$i" -eq 0 ]; then # If this is the first monitor
            source_for_colorgen="$imgpath"
        fi
    fi
done

# Finalize restore script
if ! "$video_was_set_on_any_monitor"; then
    echo "No video wallpapers were set. Video restore script will be minimal."
    # Overwrite with a minimal script if no videos were actually set.
    echo "#!/bin/bash" > "$RESTORE_SCRIPT_PATH"
    echo "# Generated by wallpaper switcher - $(date)" >> "$RESTORE_SCRIPT_PATH"
    echo "# No video wallpapers were set in the last run." >> "$RESTORE_SCRIPT_PATH"
    chmod +x "$RESTORE_SCRIPT_PATH"
else
    echo "Video wallpapers were set. Restore script at: $RESTORE_SCRIPT_PATH"
fi

# Apply color generation based on the first monitor's selection
if [ -n "$source_for_colorgen" ] && [ -f "$source_for_colorgen" ]; then
    echo "Applying color scheme from first monitor's effective wallpaper: $source_for_colorgen"
    "$CONFIG_DIR"/scripts/color_generation/colorgen.sh "$source_for_colorgen" --apply --smart
elif [ -n "$source_for_colorgen" ]; then # Path might be set, but file (like thumbnail) failed
    echo "Warning: Source for colorgen was set to '$source_for_colorgen', but the file was not found. Skipping colorgen."
else
    echo "No wallpaper definitively set on the first monitor or failed to get source for colorgen. Skipping colorgen."
fi

hyprctl keyword windowrule "unset,^(yad)$" >/dev/null 2>&1
echo "Wallpaper setup complete."
exit 0
