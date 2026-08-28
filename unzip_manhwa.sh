#!/data/data/com.termux/files/usr/bin/bash
#
# Manhwa Zip Password Remover
# Interactively removes password protection from zip archives.
# Works in Termux (Android). Requires: p7zip, zip
#
# Usage: ./unzip_manhwa.sh

DEFAULT_START=~/storage/shared

# ---------- helpers ----------
#
# NOTE: browse_folder() and search_folder() are called as
#   TARGET="$(browse_folder ...)"
# Command substitution $(...) captures EVERYTHING the function writes
# to stdout. So every line that is just UI (menus, headers, lists)
# must be sent to stderr (>&2) instead — only the final selected path
# should go to stdout. `read -p` prompts already go to stderr by
# default, which is why they showed up before even though the rest of
# the screen did not.

# Interactive folder browser.
# Lets the user navigate directories one level at a time, like a file
# manager: pick a subfolder by number, go up a level, or confirm the
# current folder as the target.
browse_folder() {
    local current="$1"

    while true; do
        clear >&2
        {
            echo "=================================="
            echo "   Select Folder"
            echo "=================================="
            echo "Current path:"
            echo "  $current"
            echo "----------------------------------"
        } >&2

        mapfile -t SUBDIRS < <(find "$current" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)

        if [ ${#SUBDIRS[@]} -eq 0 ]; then
            echo "  (no subfolders here)" >&2
        else
            local i=1
            for d in "${SUBDIRS[@]}"; do
                echo "  $i) ${d##*/}/" >&2
                i=$((i+1))
            done
        fi

        {
            echo "----------------------------------"
            echo "  0) Select THIS folder"
        } >&2
        if [ "$current" != "/" ]; then
            echo "  b) Go back (parent folder)" >&2
        fi
        {
            echo "  q) Cancel"
            echo
        } >&2

        read -p "Choice: " choice

        case "$choice" in
            0)
                echo "$current"
                return 0
                ;;
            b|B)
                current="$(dirname "$current")"
                ;;
            q|Q)
                return 1
                ;;
            ''|*[!0-9]*)
                # invalid input, just redraw
                ;;
            *)
                idx=$((choice-1))
                if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#SUBDIRS[@]}" ]; then
                    current="${SUBDIRS[$idx]}"
                fi
                ;;
        esac
    done
}

# Search for folders by keyword anywhere under a root, let the user pick.
search_folder() {
    local root="$1"
    read -p "Enter part of the folder name: " KEYWORD
    echo >&2
    echo "Searching..." >&2
    mapfile -t MATCHES < <(find "$root" -type d -iname "*$KEYWORD*" 2>/dev/null | sort)

    if [ ${#MATCHES[@]} -eq 0 ]; then
        echo "No matching folder found." >&2
        return 1
    fi

    echo >&2
    echo "Folders found:" >&2
    for i in "${!MATCHES[@]}"; do
        echo "  $((i+1))) ${MATCHES[$i]}" >&2
    done
    echo >&2
    read -p "Enter the number of the folder you want: " CHOICE
    idx=$((CHOICE-1))
    if [ -z "${MATCHES[$idx]}" ]; then
        echo "Invalid choice." >&2
        return 1
    fi
    echo "${MATCHES[$idx]}"
    return 0
}

# ---------- main ----------

clear
echo "=================================="
echo "   Manhwa Zip Password Remover"
echo "=================================="
echo

read -s -p "Enter the zip password: " PASSWORD
echo
echo

echo "What do you want to run this on?"
echo "  1) Browse folders (like a file manager, step by step)"
echo "  2) Search folder name across the whole storage"
echo "  3) Enter a full path manually"
read -p "Choice (1/2/3): " MODE
echo

case "$MODE" in
    1)
        TARGET="$(browse_folder "$DEFAULT_START")"
        [ $? -ne 0 ] && echo "Cancelled." && exit 1
        ;;
    2)
        TARGET="$(search_folder "$DEFAULT_START")"
        [ $? -ne 0 ] && exit 1
        ;;
    3)
        read -p "Enter the full folder path: " TARGET
        ;;
    *)
        echo "Invalid option."
        exit 1
        ;;
esac

if [ ! -d "$TARGET" ]; then
    echo "Not a valid folder: $TARGET"
    exit 1
fi

clear
echo "=================================="
echo "Processing: $TARGET"
echo "=================================="
echo

DONE_COUNT=0
FAILED_COUNT=0
SKIPPED_COUNT=0

while IFS= read -r f; do
    if 7z l -slt -p"$PASSWORD" "$f" 2>/dev/null | grep -q "Encrypted = +"; then
        dir=$(dirname "$f")
        name=$(basename "$f" .zip)
        tmpdir="$dir/__tmp_$name"
        mkdir -p "$tmpdir"
        if 7z x -p"$PASSWORD" -o"$tmpdir" -y "$f" > /dev/null 2>&1; then
            rm "$f"
            (cd "$tmpdir" && zip -r -0 "../$name.zip" . > /dev/null)
            rm -rf "$tmpdir"
            echo "[DONE] $(basename "$f")"
            DONE_COUNT=$((DONE_COUNT+1))
        else
            echo "[FAILED - wrong password?] $(basename "$f")"
            rm -rf "$tmpdir"
            FAILED_COUNT=$((FAILED_COUNT+1))
        fi
    else
        echo "[SKIP - not encrypted] $(basename "$f")"
        SKIPPED_COUNT=$((SKIPPED_COUNT+1))
    fi
done < <(find "$TARGET" -type f -iname "*.zip")

echo
echo "=================================="
echo "Finished."
echo "  Done:    $DONE_COUNT"
echo "  Failed:  $FAILED_COUNT"
echo "  Skipped: $SKIPPED_COUNT"
echo "=================================="
