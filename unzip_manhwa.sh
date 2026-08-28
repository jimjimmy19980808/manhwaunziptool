#!/data/data/com.termux/files/usr/bin/bash
#
# Manhwa Zip Password Remover
# Interactively removes password protection from zip archives.
# Works in Termux (Android). Requires: p7zip, zip
#
# Usage: ./unzip_manhwa.sh

DEFAULT_START=~/storage/shared

# ---------- helpers ----------

pause() {
    read -p "برای ادامه Enter بزنید..." _
}

# Interactive folder browser.
# Lets the user navigate directories one level at a time, like a file
# manager: pick a subfolder by number, go up a level, or confirm the
# current folder as the target.
browse_folder() {
    local current="$1"

    while true; do
        clear
        echo "=================================="
        echo "   انتخاب پوشه"
        echo "=================================="
        echo "مسیر فعلی:"
        echo "  $current"
        echo "----------------------------------"

        # List subfolders only
        mapfile -t SUBDIRS < <(find "$current" -mindepth 1 -maxdepth 1 -type d | sort)

        local i=1
        for d in "${SUBDIRS[@]}"; do
            echo "  $i) ${d##*/}/"
            i=$((i+1))
        done

        echo "----------------------------------"
        echo "  0) ✔ همین پوشه رو انتخاب کن"
        if [ "$current" != "/" ]; then
            echo "  b) برگرد به پوشه بالاتر"
        fi
        echo "  q) لغو"
        echo

        read -p "انتخاب شما: " choice

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
    read -p "بخشی از اسم پوشه رو بنویسید: " KEYWORD
    echo
    echo "در حال جستجو..."
    mapfile -t MATCHES < <(find "$root" -type d -iname "*$KEYWORD*" 2>/dev/null | sort)

    if [ ${#MATCHES[@]} -eq 0 ]; then
        echo "هیچ پوشه‌ای با این نام پیدا نشد."
        return 1
    fi

    echo
    echo "پوشه‌های پیدا شده:"
    for i in "${!MATCHES[@]}"; do
        echo "  $((i+1))) ${MATCHES[$i]}"
    done
    echo
    read -p "شماره پوشه مورد نظر رو وارد کنید: " CHOICE
    idx=$((CHOICE-1))
    if [ -z "${MATCHES[$idx]}" ]; then
        echo "انتخاب نامعتبر."
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

read -s -p "رمز زیپ فایل‌ها رو وارد کنید: " PASSWORD
echo
echo

echo "می‌خواید روی چی اجرا بشه؟"
echo "  1) مرور پوشه‌ها (مثل فایل‌منیجر، پوشه به پوشه)"
echo "  2) جستجوی نام پوشه در کل حافظه"
echo "  3) وارد کردن مسیر کامل به‌صورت دستی"
read -p "انتخاب (1/2/3): " MODE
echo

case "$MODE" in
    1)
        TARGET="$(browse_folder "$DEFAULT_START")"
        [ $? -ne 0 ] && echo "لغو شد." && exit 1
        ;;
    2)
        TARGET="$(search_folder "$DEFAULT_START")"
        [ $? -ne 0 ] && exit 1
        ;;
    3)
        read -p "مسیر کامل پوشه رو وارد کنید: " TARGET
        ;;
    *)
        echo "گزینه نامعتبر."
        exit 1
        ;;
esac

if [ ! -d "$TARGET" ]; then
    echo "این مسیر پوشه معتبری نیست: $TARGET"
    exit 1
fi

clear
echo "=================================="
echo "در حال پردازش: $TARGET"
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
            echo "✔ done: $(basename "$f")"
            DONE_COUNT=$((DONE_COUNT+1))
        else
            echo "✘ failed (wrong password?): $(basename "$f")"
            rm -rf "$tmpdir"
            FAILED_COUNT=$((FAILED_COUNT+1))
        fi
    else
        echo "○ skip (not encrypted): $(basename "$f")"
        SKIPPED_COUNT=$((SKIPPED_COUNT+1))
    fi
done < <(find "$TARGET" -type f -iname "*.zip")

echo
echo "=================================="
echo "تمام شد."
echo "  انجام‌شده: $DONE_COUNT"
echo "  ناموفق:   $FAILED_COUNT"
echo "  رد شده:   $SKIPPED_COUNT"
echo "=================================="
