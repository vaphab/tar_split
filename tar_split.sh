#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="${1:-.}"
DEST_DIR="${2:-.}"
CHUNK_SIZE="${3:-4G}"

# --- Convert CHUNK_SIZE to bytes ---
case "$CHUNK_SIZE" in
  *G) CHUNK_SIZE_BYTES=$(( ${CHUNK_SIZE%G} * 1024 * 1024 * 1024 ));;
  *M) CHUNK_SIZE_BYTES=$(( ${CHUNK_SIZE%M} * 1024 * 1024 ));;
  *K) CHUNK_SIZE_BYTES=$(( ${CHUNK_SIZE%K} * 1024 ));;
  *)  CHUNK_SIZE_BYTES=$CHUNK_SIZE;;
esac

# --- Handle destination path ---
CALL_DIR="$(pwd)"
if [[ "$DEST_DIR" == "./" || "$DEST_DIR" == "." ]]; then
    DEST_DIR="$CALL_DIR"
else
    [[ "$DEST_DIR" != /* ]] && DEST_DIR="$CALL_DIR/$DEST_DIR"
    DEST_DIR="$(realpath -m "$DEST_DIR")"
fi
mkdir -p "$DEST_DIR"
cd "$SRC_DIR"

echo "==> Scanning '$SRC_DIR'"
echo "==> Writing tars of max $CHUNK_SIZE_BYTES bytes to '$DEST_DIR'"

# --- Helper: compare tar contents to file list ---
check_tar_matches() {
    local tarfile="$1"; shift
    local -n expect_arr=$1
    [[ ! -f "$tarfile" ]] && return 1
    local tmp_tar_list tmp_exp_list
    tmp_tar_list=$(mktemp)
    tmp_exp_list=$(mktemp)
    tar -tf "$tarfile" 2>/dev/null | sort >"$tmp_tar_list" || { rm -f "$tmp_tar_list" "$tmp_exp_list"; return 1; }
    printf "%s\n" "${expect_arr[@]}" | sort >"$tmp_exp_list"
    diff -q "$tmp_tar_list" "$tmp_exp_list" >/dev/null
    local rc=$?
    rm -f "$tmp_tar_list" "$tmp_exp_list"
    return $rc
}

# --- Initialize state ---
chunk_num=1
current_size=0
file_count=0
files=()
# --- Main loop (no subshells) ---
while IFS=$'\t' read -r -d '' size f; do
    [[ "$size" =~ ^[0-9]+$ ]] || { echo "⚠️ Skipping bad size for '$f' ($size)"; continue; }

    file_count=$((file_count+1))
    # If adding file would exceed limit
    if (( current_size + size > CHUNK_SIZE_BYTES && ${#files[@]} > 0 )); then
	tar_name="$DEST_DIR/$(basename "$SRC_DIR")_part_${chunk_num}.tar"
        if check_tar_matches "$tar_name" files; then
            echo -e "✅ Skipping identical $tar_name"
        else
            printf "%s\0" "${files[@]}" | tar --null -cf "$tar_name" -T -
            echo "✅ Finished writing $tar_name"
        fi

        ((chunk_num++))
        current_size=0
        files=()
    fi

    files+=("$f")
    ((current_size += size))
done < <(find . -type f -printf "%s\t%p\0")

# --- Final chunk ---
if (( ${#files[@]} > 0 )); then
    tar_name="$DEST_DIR/$(basename "$SRC_DIR")_part_${chunk_num}.tar"
    if check_tar_matches "$tar_name" files; then
        echo "✅ Skipping identical $tar_name"
    else
        printf "%s\0" "${files[@]}" | tar --null -cf "$tar_name" -T -
        echo "✅ Finished writing $tar_name"
    fi
fi

echo -e "\n✅ All chunks done and verified in '$DEST_DIR'."

