# 🗂️ Tar Splitter Script

A Bash script that creates multiple uncompressed `.tar` archives from a source directory, each limited to a specified maximum size (e.g., 4 GB).  
Unlike traditional split utilities, this script **never splits individual files** — and each `.tar` archive can be extracted **independently**.

---

## ✨ Features

- ✅ **No file splitting** — each file stays whole, never broken across chunks  
- ✅ **Independent extraction** — every `.tar` can be unpacked separately  
- ✅ **Chunk size limit** — specify any max size (e.g. `4G`, `1024M`, `500M`)  
- ✅ **Safe for all filenames** — handles spaces, quotes, newlines, and non-UTF8 characters  
- ✅ **No compression** — faster and easier to inspect or copy  
- ✅ **Resumable** — skips already created archives when re-run  
- ✅ **Portable** — uses only standard GNU/Linux tools (`bash`, `find`, `tar`)

---

## 🧰 Requirements

- **Bash 5.x or later**  
- **GNU find** and **GNU tar** (default on most Linux distributions)

---

## 🚀 Usage

```bash
./tar_split.sh <source_dir> <destination_dir> <chunk_size>
```

## 🚀 Example

```bash
./tar_split.sh /mnt/data ./backups 4G
```

This will:

- Scan /mnt/data recursively
- Group files into 4 GB chunks (without splitting any file)
- Create archives such as:
```bash
    backups/part_001.tar
    backups/part_002.tar
    backups/part_003.tar
    ...
```
Each .tar can later be extracted individually:
```bash
tar -xf backups/part_002.tar
```
## ⚙️ How It Works

- Uses find to list all files with their sizes via -printf "%s\t%p\0".
- Accumulates files until the total size approaches the chunk limit.
- Writes a tar archive using:
```bash
    printf "%s\0" "${files[@]}" | tar --null -cf part_XXX.tar -T -
```
- ensuring NUL-safe handling of filenames with any characters.
- Continues until all files are included in numbered tar chunks.

## 🧩 Design Notes
- Files are never split — if one file exceeds the chunk size, it will be placed alone in its own .tar.
- The script can be safely re-run — existing matching archives are skipped.
- Works efficiently even with millions of files or paths containing special characters.

## 🧾 Example Output
```bash
==> Scanning files in /mnt/data ...
==> Writing tars of max 4G bytes to './backups'
==> Writing tar chunk: ./backups/part_001.tar (3.99 GB)
==> Writing tar chunk: ./backups/part_002.tar (3.98 GB)
✅ All done! Created 12 archives.
```
## 💡 Tips

To verify contents of a tar file:
```bash
tar -tf backups/part_001.tar | head
```
To extract in parallel:
```bash
find backups -name "*.tar" -print0 | xargs -0 -n1 -P4 tar -xf
```
