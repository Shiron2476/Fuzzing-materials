#!/bin/bash

# move.sh <target_name>
# Example: ./move.sh cflow

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <target_name>"
    echo "Example: $0 cflow"
    exit 1
fi

TARGET_NAME="$1"

# 源基础目录
MATERIALS_DIR="/home/zhq/experiment/materials/$TARGET_NAME"
SOURCE_OUTPUT_BASE="$MATERIALS_DIR/output"

# 目标目录
DEST_BASE="/home/zhq/experiment/ZigZagFuzz_experiment"
DEST_TARGET_DIR="$DEST_BASE/$TARGET_NAME"

# 检查源 output 是否存在
if [ ! -d "$SOURCE_OUTPUT_BASE" ]; then
    echo "Error: Source output directory not found: $SOURCE_OUTPUT_BASE"
    exit 1
fi

# 创建目标主目录
mkdir -p "$DEST_TARGET_DIR"

echo "[*] Starting to copy selected data for '$TARGET_NAME'..."

# 遍历 run_1 到 run_5
for i in {1..5}; do
    SRC_RUN_DIR="$SOURCE_OUTPUT_BASE/run_$i"
    DEST_RUN_DIR="$DEST_TARGET_DIR/${TARGET_NAME}_run_$i"

    if [ ! -d "$SRC_RUN_DIR" ]; then
        echo "Warning: Source run directory not found: $SRC_RUN_DIR, skipping..."
        continue
    fi

    echo "  -> Copying run_$i to $DEST_RUN_DIR"

    # 创建目标实例目录
    mkdir -p "$DEST_RUN_DIR"

    # 复制指定的文件夹（如果存在）
    for dir in crashes crashes_argvs hangs hangs_argvs queue queue_argvs; do
        if [ -d "$SRC_RUN_DIR/$dir" ]; then
            cp -r "$SRC_RUN_DIR/$dir" "$DEST_RUN_DIR/"
        fi
    done

    # 复制指定的文件（如果存在）
    for file in cmdline fastresume.bin fuzz_bitmap shrink_log fuzzer_setup plot_data stage_finds fuzzer_stats target_hash; do
        if [ -f "$SRC_RUN_DIR/$file" ]; then
            cp "$SRC_RUN_DIR/$file" "$DEST_RUN_DIR/"
        fi
    done
done

echo "[*] Done! Results saved to: $DEST_TARGET_DIR"
echo "    Contains ${TARGET_NAME}_run_{1..5} with selected files/folders only."
