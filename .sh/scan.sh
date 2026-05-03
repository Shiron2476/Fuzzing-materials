#!/bin/bash

# 检查是否传入了目标名称
if [ $# -ne 1 ]; then
    echo "Usage: $0 <target_name>"
    echo "Example: $0 cflow"
    exit 1
fi

TARGET_NAME="$1"

# ================= 基础路径配置 =================
BASE_DIR="/home/zhq/experiment"
MATERIALS_DIR="$BASE_DIR/materials/Fuzzing-materials/$TARGET_NAME"
OUTPUT_DIR="$MATERIALS_DIR/output"
AFL_SESSION_NAME="${TARGET_NAME}_run_"
# ===============================================

# 检查输出目录是否存在
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Error: Output directory not found: $OUTPUT_DIR"
    exit 1
fi

echo "----------------------------------------"
echo "目标: $TARGET_NAME"
echo "扫描目录: $OUTPUT_DIR"
echo "----------------------------------------"

# 函数：获取已运行时间
get_elapsed_time() {
    local stats_file="$1"
    local r_time=0

    if [ -f "$stats_file" ]; then
        # 提取 run_time 并清理非数字字符
        r_time=$(grep "run_time" "$stats_file" | cut -d ':' -f 2 | tr -d ' \r')
        if [ -z "$r_time" ]; then
            r_time=0
        fi
    fi
    echo "$r_time"
}

# 遍历 1 到 5 号实例
for i in {1..5}; do
    INSTANCE_OUTPUT="$OUTPUT_DIR/run_$i"
    # 构造 AFL 实际的工作子目录路径
    ACTUAL_AFL_DIR="$INSTANCE_OUTPUT/${AFL_SESSION_NAME}${i}"
    STATS_FILE="$ACTUAL_AFL_DIR/fuzzer_stats"

    # 获取时间
    ELAPSED=$(get_elapsed_time "$STATS_FILE")

    # 格式化输出
    if [ "$ELAPSED" -eq 0 ] && [ ! -f "$STATS_FILE" ]; then
        # 如果文件不存在，标记为未找到
        printf "run_%-1d : %-10s (文件未找到)\n" "$i" "0s"
    else
        # 正常输出秒数
        printf "run_%-1d : %-10s 秒\n" "$i" "$ELAPSED"
    fi
done

echo "----------------------------------------"
