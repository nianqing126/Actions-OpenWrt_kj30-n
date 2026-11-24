#!/bin/bash
# ==============================================================================
# patch-wma301.sh —— 将 TP-Link WMA301 V2.0 注入到 5.4 老 SDK 源码
# ------------------------------------------------------------------------------
# 目标源码：chaoticinitiation/immortalwrt-mt798x-24.10-237 @ 2410（内核 5.4）
#
# 【重要修复 v3】依据用户真机 U-Boot 截图（板卡 mt7981-tplink_wma301v2，
# U-Boot 变体 default）还原出的权威分区表。前两版的错误：
#   v1: 照搬 kj30-n 分区（ubi@0x580000/114M，4 分区）                 → 布局不符
#   v2: 误删 nmbm、改"stock 标准分区"（ubi@0x580000/114M）            → 布局不符
# 真机截图证明：
#   - 三种布局(default/stock/256m)全部以 nmbm0: 开头 → 必须用 nmbm 包裹
#   - 分区顺序/大小：bl2(1M)+u-boot-env(1M)+fip(2M)+factory(0.5M)
#                   +art(0.5M)+stock-config(2M)+ubi(0x700000起)
#   - default 布局 ubi = 123904k(121M)，到 0x8000000 = 128MiB flash
#
# 本版据此生成 DTS：保留 nmbm_spim_nand 结构，替换其中的分区为上述真实布局，
# 并把 mk 里 IMAGE_SIZE 改为 123904k、compatible 改为 U-Boot 识别的名字。
#
# 使用位置：Clone 源码之后、make defconfig 之前执行。
# 用法：cd openwrt && $GITHUB_WORKSPACE/scripts/patch-wma301.sh
#
# ⚠ LED/按键 GPIO 依公开资料推算，未经真机验证；分区/启动链路依据真机截图。
# ==============================================================================
set -euo pipefail

DTS_DIR="target/linux/mediatek/files-5.4/arch/arm64/boot/dts/mediatek"
MK_FILE="target/linux/mediatek/image/mt7981.mk"
SRC_DTS="$DTS_DIR/mt7981-kj-kj30-n.dts"
DST_DTS="$DTS_DIR/mt7981-tplink-wma301.dts"

echo "[patch-wma301] 开始注入 WMA301 V2.0 (真机 default 布局 / nmbm)..."

if [ ! -f "$SRC_DTS" ]; then
    echo "[patch-wma301] 错误：找不到基底 DTS $SRC_DTS，源码结构可能已变更。"
    exit 1
fi
if [ ! -f "$MK_FILE" ]; then
    echo "[patch-wma301] 错误：找不到 $MK_FILE，源码结构可能已变更。"
    exit 1
fi

cp -f "$SRC_DTS" "$DST_DTS"

python3 - "$DST_DTS" <<'PYEOF'
import sys, re

path = sys.argv[1]
s = open(path, encoding="utf-8").read()

def find_block_end(src, open_brace_idx):
    """从 '{' 位置返回匹配 '}'（含紧随其后的 ';'）之后的索引。"""
    depth = 0
    for j in range(open_brace_idx, len(src)):
        c = src[j]
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                k = j + 1
                while k < len(src) and src[k] in ' \t':
                    k += 1
                if k < len(src) and src[k] == ';':
                    k += 1
                return k
    return None

def replace_node(src, node_decl, new_block):
    m = re.search(r'(\n[ \t]*)' + re.escape(node_decl) + r'[ \t]*\{', src)
    if not m:
        return src, False
    start = m.start(0)
    i = src.find('{', m.start())
    end = find_block_end(src, i)
    if end is None:
        return src, False
    indent = m.group(1)
    return src[:start] + indent + new_block.strip('\n') + src[end:], True

# --- 1) 机型标识 ---
s = s.replace('model = "KJ30-N";', 'model = "TP-Link WMA301 V2.0";')
s = s.replace('compatible = "kj,kj30-n", "mediatek,mt7981";',
              'compatible = "tplink,wma301", "mediatek,mt7981";')

# --- 2) 用真机 default 布局替换整个 nmbm_spim_nand 节点 ---
nmbm_block = '''nmbm_spim_nand {
        compatible = "generic,nmbm";
        #address-cells = <1>;
        #size-cells = <1>;

        lower-mtd-device = <&spi_nand>;
        forced-create;

        partitions {
                compatible = "fixed-partitions";
                #address-cells = <1>;
                #size-cells = <1>;

                partition@0 {
                        label = "bl2";
                        reg = <0x0000000 0x0100000>;
                        read-only;
                };

                partition@100000 {
                        label = "u-boot-env";
                        reg = <0x0100000 0x0100000>;
                };

                partition@200000 {
                        label = "fip";
                        reg = <0x0200000 0x0200000>;
                        read-only;
                };

                partition@400000 {
                        label = "factory";
                        reg = <0x0400000 0x0008000>;
                        read-only;
                };

                partition@480000 {
                        label = "art";
                        reg = <0x0480000 0x0008000>;
                        read-only;
                };

                partition@500000 {
                        label = "stock-config";
                        reg = <0x0500000 0x0200000>;
                };

                partition@700000 {
                        label = "ubi";
                        reg = <0x0700000 0x07900000>;
                };
        };
    };'''
s, ok_nmbm = replace_node(s, 'nmbm_spim_nand', nmbm_block)

# --- 3) 替换 LED / 按键 / aliases ---
led_block = '''leds {
        compatible = "gpio-leds";

        led_status_red: led-0 {
            label = "red:status";
            gpios = <&pio 14 GPIO_ACTIVE_LOW>;
        };

        led_status_green: led-1 {
            label = "green:status";
            gpios = <&pio 15 GPIO_ACTIVE_LOW>;
        };
    };'''

keys_block = '''gpio-keys {
        compatible = "gpio-keys";

        button-reset {
            label = "reset";
            linux,code = <KEY_RESTART>;
            gpios = <&pio 1 GPIO_ACTIVE_LOW>;
        };

        button-wps {
            label = "wps";
            linux,code = <KEY_WPS_BUTTON>;
            gpios = <&pio 0 GPIO_ACTIVE_LOW>;
        };
    };'''

alias_block = '''aliases {
        led-boot = &led_status_red;
        led-failsafe = &led_status_red;
        led-running = &led_status_green;
        led-upgrade = &led_status_green;
    };'''

s, ok_led   = replace_node(s, 'leds', led_block)
s, ok_keys  = replace_node(s, 'gpio-keys', keys_block)
s, ok_alias = replace_node(s, 'aliases', alias_block)

if not (ok_led and ok_keys and ok_alias):
    print(f"[patch-wma301] 警告：节点替换不全 leds={ok_led} keys={ok_keys} aliases={ok_alias}", file=sys.stderr)

open(path, "w", encoding="utf-8").write(s)
print(f"[patch-wma301] DTS 处理完成: nmbm={ok_nmbm} leds={ok_led} keys={ok_keys} aliases={ok_alias}")
PYEOF

echo "[patch-wma301] 已生成真机 default 布局 DTS: $DST_DTS"

# ---------- 在 mt7981.mk 追加设备定义 ----------
if grep -q "define Device/tplink_wma301" "$MK_FILE"; then
    echo "[patch-wma301] 源码已含 tplink_wma301 定义，跳过追加。"
else
    cat >> "$MK_FILE" <<'MK_EOF'

define Device/tplink_wma301
  DEVICE_VENDOR := TP-Link
  DEVICE_MODEL := WMA301 V2.0
  DEVICE_DTS := mt7981-tplink-wma301
  DEVICE_DTS_DIR := $(DTS_DIR)/mediatek
  SUPPORTED_DEVICES += tplink,wma301 mediatek,mt7981
  UBINIZE_OPTS := -E 5
  BLOCKSIZE := 128k
  PAGESIZE := 2048
  IMAGE_SIZE := 123904k
  KERNEL_IN_UBI := 1
  IMAGES += factory.bin
  IMAGE/factory.bin := append-ubi | check-size $$$$(IMAGE_SIZE)
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
endef
TARGET_DEVICES += tplink_wma301
MK_EOF
    echo "[patch-wma301] 已在 $MK_FILE 追加 tplink_wma301 定义（IMAGE_SIZE=123904k）。"
fi

echo "[patch-wma301] 注入完成（真机 default 布局 / nmbm）。"
