#!/bin/bash

# run_fuzz.sh <target_name> <minutes>
# Example: ./run_fuzz.sh cflow 60

set -e

if [ $# -ne 2 ]; then
    echo "Usage: $0 <target_name> <fuzz_time_in_minutes>"
    echo "Example: $0 cflow 60"
    exit 1
fi

TARGET_NAME="$1"
MINUTES="$2"
FUZZ_TIME=$((MINUTES * 60))

# Base directories
BASE_DIR="/home/zhq/experiment"
AFL_FUZZ_BIN="$BASE_DIR/ZigZagFuzz/afl-fuzz"
MATERIALS_DIR="$BASE_DIR/materials/$TARGET_NAME"

# Validate materials directory exists
if [ ! -d "$MATERIALS_DIR" ]; then
    echo "Error: Materials directory not found: $MATERIALS_DIR"
    exit 1
fi

TARGET_BIN="$MATERIALS_DIR/bin/${TARGET_NAME}.afl"
SEEDS_DIR="$MATERIALS_DIR/seeds"
DICT_FILE="$MATERIALS_DIR/dictionary/${TARGET_NAME}"
OUTPUT_DIR="$MATERIALS_DIR/output"

# Validate essential files
if [ ! -f "$TARGET_BIN" ]; then
    echo "Error: Target binary not found: $TARGET_BIN"
    exit 1
fi

if [ ! -d "$SEEDS_DIR" ] || [ -z "$(ls -A $SEEDS_DIR)" ]; then
    echo "Error: Seeds directory is missing or empty: $SEEDS_DIR"
    exit 1
fi

# Dictionary flag
if [ -f "$DICT_FILE" ]; then
    DICT_FLAG="-x $DICT_FILE"
else
    DICT_FLAG=""
    echo "Warning: Dictionary file not found: $DICT_FILE"
fi

echo "[*] Cleaning old output..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Start fuzzing instances in background
for i in {1..5}; do
    INSTANCE_OUTPUT="$OUTPUT_DIR/run_$i"
    mkdir -p "$INSTANCE_OUTPUT"
    
    LOG_FILE="$INSTANCE_OUTPUT/fuzz.log"
    
    echo "正在启动第 $i 个独立模糊测试实例，输出目录: $INSTANCE_OUTPUT"
    echo "日志将保存到: $LOG_FILE"
    
    # 构建命令（不使用 gnome-terminal）
    CMD="cd '$INSTANCE_OUTPUT' && \
         timeout '${FUZZ_TIME}s' \
	'$AFL_FUZZ_BIN' \
	-i '$SEEDS_DIR' \
	-o '$OUTPUT_DIR' \
	-K 2 \
	-a '$DICT_FILE' \
	-- '$TARGET_BIN' @@ "
    
    # 后台运行，并记录日志
    bash -c "$CMD" > "$LOG_FILE" 2>&1 &
    
    sleep 3
done

echo "5 个独立的模糊测试实例已全部在后台启动！"
echo "输出目录: $OUTPUT_DIR/run_{1..5}"
echo "查看日志: tail -f $OUTPUT_DIR/run_1/fuzz.log"
