# Manhwa Zip Password Remover

A Termux (Android) bash script that interactively strips the password
protection from zip archives inside a folder (and all its subfolders) —
you enter the password once, and every archive under that folder gets
processed with it.

The script's output is in English on purpose: Termux's terminal does
not render right-to-left (Persian/Arabic) text correctly, so English
avoids garbled output.

## Features

- Password entry is hidden (like a login prompt, never shown on screen)
- Three ways to pick the target folder:
  1. **Browse folders** — navigate step by step, like a file manager
  2. **Search** — type part of a folder name and pick from the matches
  3. **Manual path** — type the full path directly
- Automatically detects which zip files are actually encrypted (files
  that already have no password are left untouched)
- Final summary: how many files were done / failed / skipped

## Requirements (install in Termux)

```bash
pkg update -y
pkg install -y p7zip zip unzip termux-api git
termux-setup-storage
```

After running `termux-setup-storage`, approve the storage permission
prompt on your phone.

## Install

```bash
git clone https://github.com/jimjimmy19980808/manhwaunziptool.git
cd manhwaunziptool
chmod +x unzip_manhwa.sh
```

## Usage

```bash
./unzip_manhwa.sh
```

The script first asks for the password, then how you want to pick the
folder, and finally rebuilds every encrypted zip under that folder
(and its subfolders) without a password.

## Important notes

- The original (encrypted) zip file is **deleted** after a successful
  conversion and replaced by the password-free version. Back up your
  folder first if you need to keep the originals.
- If the password is wrong or a file is corrupted, that file is
  reported as `FAILED` and left untouched.
- Files that already have no password are reported as `SKIP`.

## License

MIT
