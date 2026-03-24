#!/bin/bash
# continue_fuzz.sh <target_name>
# Predefined fuzz time: 1441 minutes (24 hours + 1 minute)
# Continues fuzzing if current runtime is less than 95% of predefined time

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <target_name>"
    echo "Example: $0 tcpdump"
    exit 1
fi

TARGET_NAME="$1"
PREDEFINED_MINUTES=1441
CONTINUE_THRESHOLD_PERCENT=95
CONTINUE_THRESHOLD_MINUTES=$((PREDEFINED_MINUTES * CONTINUE_THRESHOLD_PERCENT / 100))  # 1368 minutes

FUZZ_TIME=$((PREDEFINED_MINUTES * 60))  # Total fuzz time in seconds

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
OUTPUT_DIR="$MATERIALS_DIR/output"

# Validate essential files
if [ ! -f "$TARGET_BIN" ]; then
    echo "Error: Target binary not found: $TARGET_BIN"
    exit 1
fi

if [ ! -d "$OUTPUT_DIR" ] || [ ! -f "$OUTPUT_DIR/fuzzer_stats" ]; then
    echo "Error: Output directory or fuzzer_stats file not found. Please run initial fuzzing first."
    exit 1
fi

# Read current run_time from fuzzer_stats (in seconds)
CURRENT_RUN_TIME_SECONDS=$(grep "^run_time" "$OUTPUT_DIR/fuzzer_stats" | cut -d':' -f2 | tr -d ' ')
if [ -z "$CURRENT_RUN_TIME_SECONDS" ]; then
    echo "Error: Could not read run_time from fuzzer_stats"
    exit 1
fi

CURRENT_RUN_TIME_MINUTES=$((CURRENT_RUN_TIME_SECONDS / 60))
echo "[*] Current run time: ${CURRENT_RUN_TIME_MINUTES} minutes"
echo "[*] Continue threshold: ${CONTINUE_THRESHOLD_MINUTES} minutes (95% of ${PREDEFINED_MINUTES} minutes)"

# Check if we should continue
if [ "$CURRENT_RUN_TIME_MINUTES" -lt "$CONTINUE_THRESHOLD_MINUTES" ]; then
    echo "[*] Continuing fuzzing..."
    
    # Find dictionary file (same logic as original script)
    DICT_FILE="$MATERIALS_DIR/dictionary/${TARGET_NAME}"
    if [ ! -f "$DICT_FILE" ]; then
        echo "Warning: Dictionary file not found: $DICT_FILE"
        DICT_FLAG=""
    else
        DICT_FLAG="-x $DICT_FILE"
    fi
    
    # Launch 5 instances with -i - for continuation
    for i in {1..5}; do
        INSTANCE_OUTPUT="$OUTPUT_DIR/run_$i"
        if [ ! -d "$INSTANCE_OUTPUT" ]; then
            mkdir -p "$INSTANCE_OUTPUT"
        fi
        
        echo "正在启动第 $i 个独立模糊测试实例（继续模式），输出目录:$INSTANCE_OUTPUT"
        CMD="cd '$INSTANCE_OUTPUT'
timeout '${FUZZ_TIME}s' '$AFL_FUZZ_BIN' \\
-i - \\
-o '$OUTPUT_DIR' \\
-K 2 \\
$DICT_FLAG \\
-- '$TARGET_BIN' @@ ; echo ''; echo '============================='; echo '模糊测试已结束（或被中断）。'; read -p '按回车键关闭此窗口...'; "
        
        gnome-terminal --title="ZigZagFuzzer - Run $i (Continue)" -- bash -c "$CMD"
        sleep 3
    done
    
    echo "5 个独立的模糊测试实例已全部在新窗口中启动（继续模式）！"
    echo "输出目录:$OUTPUT_DIR/run_{1..5}"
else
    echo "[*] Current run time (${CURRENT_RUN_TIME_MINUTES} minutes) >= threshold (${CONTINUE_THRESHOLD_MINUTES} minutes)"
    echo "[*] Fuzzing completed or nearly completed. No continuation needed."
    exit 0
fi
