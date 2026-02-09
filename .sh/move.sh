#!/bin/bash

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <target_name>"
    echo "Example: $0 cflow"
    exit 1
fi

TARGET_NAME="$1"

MATERIALS_DIR="/home/zhq/experiment/materials/$TARGET_NAME"
SOURCE_OUTPUT_BASE="$MATERIALS_DIR/output"
DEST_BASE="/home/zhq/experiment/ZigZagFuzz_experiment"
DEST_TARGET_DIR="$DEST_BASE/$TARGET_NAME"

mkdir -p "$DEST_TARGET_DIR"

echo "[*] Copying selected data for '$TARGET_NAME'..."

for i in {1..5}; do
    # 源路径：run_i/${target}_run_i/
    ACTUAL_SRC="$SOURCE_OUTPUT_BASE/run_$i/${TARGET_NAME}_run_$i"
    DEST_RUN_DIR="$DEST_TARGET_DIR/${TARGET_NAME}_run_$i"

    if [ ! -d "$ACTUAL_SRC" ]; then
        echo "  -> Warning: Source not found: $ACTUAL_SRC, skipping run_$i"
        continue
    fi

    echo "  -> Copying from: $ACTUAL_SRC"

    # 创建目标目录
    mkdir -p "$DEST_RUN_DIR"

    # 要复制的目录
    DIRS=("crashes" "crashes_argvs" "hangs" "hangs_argvs" "queue" "queue_argvs")
    # 要复制的文件
    FILES=("cmdline" "fastresume.bin" "fuzz_bitmap" "shrink_log" "fuzzer_setup" "plot_data" "stage_finds" "fuzzer_stats" "target_hash")

    # 复制目录
    for dir in "${DIRS[@]}"; do
        if [ -d "$ACTUAL_SRC/$dir" ]; then
            cp -r "$ACTUAL_SRC/$dir" "$DEST_RUN_DIR/"
            echo "    + copied directory: $dir"
        fi
    done

    # 复制文件
    for file in "${FILES[@]}"; do
        if [ -f "$ACTUAL_SRC/$file" ]; then
            cp "$ACTUAL_SRC/$file" "$DEST_RUN_DIR/"
            echo "    + copied file: $file"
        fi
    done
done

echo "[*] Done! Results saved to: $DEST_TARGET_DIR"
