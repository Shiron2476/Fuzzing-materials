#!/bin/bash
# run_fuzz.sh <target_name> <minutes>
# 功能：启动模糊测试，如果检测到之前运行过，会自动计算剩余时间以补足到1441分钟。
# 注意：虽然保留了<minutes>参数以兼容原逻辑，但核心逻辑现在强制对齐1441分钟的目标。

set -e

# ================= 配置区域 =================
# 目标总运行时间：1441 分钟 (转换为秒)
TARGET_TOTAL_MINUTES=1441
TARGET_TOTAL_SECONDS=$((TARGET_TOTAL_MINUTES * 60))
# =============================================

if [ $# -ne 1 ]; then
    echo "Usage: $0 <target_name> "
    echo "Example: $0 cflow"
    echo "Note: Script calculates remaining time to reach ${TARGET_TOTAL_MINUTES} mins total."
    exit 1
fi

TARGET_NAME="$1"

# Base directories
BASE_DIR="/home/zhq/experiment"
AFL_FUZZ_BIN="$BASE_DIR/ZigZagFuzz/afl-fuzz"
MATERIALS_DIR="$BASE_DIR/materials/Fuzzing-materials/$TARGET_NAME"

# Validate materials directory exists
if [ ! -d "$MATERIALS_DIR" ]; then
    echo "Error: Materials directory not found: $MATERIALS_DIR"
    exit 1
fi

TARGET_BIN="$MATERIALS_DIR/bin/${TARGET_NAME}.afl"
SEEDS_DIR="$MATERIALS_DIR/seeds"
DICT_FILE="$MATERIALS_DIR/dictionary/${TARGET_NAME}"
OUTPUT_DIR="$MATERIALS_DIR/output"
AFL_SESSION_NAME="${TARGET_NAME}_run_"

# Validate essential files
if [ ! -f "$TARGET_BIN" ]; then
    echo "Error: Target binary not found: $TARGET_BIN"
    exit 1
fi

if [ ! -d "$SEEDS_DIR" ] || [ -z "$(ls -A $SEEDS_DIR/queue 2>/dev/null)" ]; then
    echo "Error: Seeds directory is missing or empty: $SEEDS_DIR"
    exit 1
fi

if [ ! -f "$DICT_FILE" ]; then
    echo "Warning: Dictionary file not found: $DICT_FILE"
    DICT_FLAG=""
else
    DICT_FLAG="-x $DICT_FILE"
fi

# 如果输出目录不存在，先创建（避免检查 run_time 时报错）
mkdir -p "$OUTPUT_DIR"

# 函数：获取指定 run 目录的已运行时间
get_elapsed_time() {
    local stats_file="$1/fuzzer_stats"
    local r_time=0

    if [ -f "$stats_file" ]; then
        # 2. 读取 run_time
        # 使用 awk 读取第二列，并 +0 强制转为数字
        r_time=$(grep "run_time" "$stats_file" | cut -d ':' -f 2 | tr -d ' \r')
        if [ -z "$r_time" ]; then
            r_time=0
        fi
    else
        # 4. 调试打印：文件不存在 (输出到屏幕)
        echo "   [调试数值] 文件不存在，返回默认值 0" >&2
        r_time=0
    fi

    # 5. 关键：只返回纯数字 (作为函数返回值)
    echo "$r_time"
}
echo "[*] 检查旧输出并计算剩余时间..."
# 注意：这里不再强制 rm -rf，否则无法读取之前的 run_time。
# 如果你希望每次彻底重来，请取消下面这行的注释：
# rm -rf "$OUTPUT_DIR"
# mkdir -p "$OUTPUT_DIR"

for i in {1..5}; do
    INSTANCE_OUTPUT="$OUTPUT_DIR/run_$i"
    mkdir -p "$INSTANCE_OUTPUT"
    ACTUAL_AFL_DIR="$INSTANCE_OUTPUT/${AFL_SESSION_NAME}${i}"
    # 1. 获取已经运行的时间
    ELAPSED=$(get_elapsed_time "$ACTUAL_AFL_DIR")
    echo "   [调试] 读取到的已运行时间为: $ELAPSED 秒"
    # 2. 计算剩余需要运行的时间
    REMAINING=$((TARGET_TOTAL_SECONDS - ELAPSED))

    # 3. 判断是否已经完成
    if [ $REMAINING -le 0 ]; then
        echo "=> 实例 run_$i 已达到目标时间 (${ELAPSED}s >= ${TARGET_TOTAL_SECONDS}s)，跳过。"
        continue
    fi

    echo "正在启动/恢复第 $i 个实例..."
    echo "   已运行: ${ELAPSED}s, 剩余目标: ${REMAINING}s (目标总计: ${TARGET_TOTAL_MINUTES}m)"

    cd "$INSTANCE_OUTPUT"
    mkdir -p table
    cd table

    # 使用计算出的 REMAINING 时间作为 timeout 参数
    # 如果 REMAINING 很大，timeout 依然有效；如果任务意外退出，脚本不会无限重试，但这里逻辑是单次启动
    timeout "${REMAINING}s" \
        "$AFL_FUZZ_BIN" \
        -i - \
        -o "$INSTANCE_OUTPUT" \
        -M "${AFL_SESSION_NAME}${i}" \
        -K 2 \
        -a "$DICT_FILE" \
        -- "$TARGET_BIN" @@ \
        > "$INSTANCE_OUTPUT/fuzz.log" 2>&1 &

    echo " => PID: $!"
    sleep 3  # 给 AFL++ 一点时间初始化
done

echo "模糊测试实例检查完毕。"
echo "输出目录: $OUTPUT_DIR/run_{1..5}"
