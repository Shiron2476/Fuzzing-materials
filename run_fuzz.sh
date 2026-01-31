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
BASE_DIR="/zhq/experiment"
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

if [ ! -d "$SEEDS_DIR" ] || [ -z "$(ls -A $SEEDS_DIR/queue)" ]; then
    echo "Error: Seeds directory is missing or empty: $SEEDS_DIR"
    exit 1
fi

if [ ! -f "$DICT_FILE" ]; then
    echo "Warning: Dictionary file not found: $DICT_FILE"
else
    DICT_FLAG="-x $DICT_FILE"
fi

echo "[*] Cleaning old output..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

for i in {1..5}; do
    mkdir -p "$OUTPUT_DIR/run_$i"
    INSTANCE_OUTPUT="$OUTPUT_DIR/run_$i"
    echo "正在启动第  $i 个独立模糊测试实例，输出目录:$INSTANCE_OUTPUT"
CMD="
	cd $BASE_OUTPUT_DIR/run_$i
	mkdir -p table
	cd table
	timeout '${FUZZ_TIME}s' \
	'$AFL_FUZZ_BIN' \
	-i '$SEEDS_DIR' \
	-o '$OUTPUT_DIR' \
	-K 2 \
	-a '$DICT_FILE' \
	-- '$TARGET_BIN' @@ ;
            
        echo '';
        echo '=============================';
        echo '模糊测试已结束（或被中断）。';
        read -p '按回车键关闭此窗口...';
    "
    gnome-terminal --title="ZigZagFuzzer - Run  $i" -- bash -c " $CMD"
    
    sleep 3  # 给 AFL++ 一点时间初始化
done
echo "5 个独立的模糊测试实例已全部在新窗口中启动！"
echo "输出目录:$OUTPUT_DIR/run_{1..5}"

