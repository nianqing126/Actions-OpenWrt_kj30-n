#!/bin/bash
# ==============================================================================
# patch-wma301.sh —— 将 TP-Link WMA301 V2.0 注入到 5.4 老 SDK 源码
# ------------------------------------------------------------------------------
# 目标源码：chaoticinitiation/immortalwrt-mt798x-24.10-237 @ 2410（内核 5.4）
#
# 设计思路（稳妥优先）：
#   1) WMA301 V2.0 与 KJ30-N 同为 MT7981 + SPI-NAND，原厂分区布局完全一致
#      （BL2 1M + u-boot-env 0.5M + Factory 2M + FIP 2M + ubi 114M），
#      ubi 均从 0x580000 起、大小 0x7200000（114M）。系统固件写入位置相同，
#      刷机 / sysupgrade 层面兼容。
#   2) 不重写 DTS，而是直接复制源码中已验证可编译的 kj30n.dts 作为基底，
#      仅替换机型名、LED、按键这几处机型相关信息，其余（nmbm 分区、eth、
#      hnat、spi、pio pinmux）全部沿用，确保与老 SDK 5.4 binding 100% 兼容。
#   3) 在 mt7981.mk 追加 tplink_wma301 设备定义（IMAGE_SIZE 与 kj30-n 相同）。
#
# 使用位置：Clone 源码之后、make defconfig 之前执行。
# 用法：cd openwrt && $GITHUB_WORKSPACE/scripts/patch-wma301.sh
#
# ⚠ 提示：LED/按键 GPIO 依据公开资料推算，未经真机验证。分区与启动链路沿用
#   已验证模板，风险较低；首次刷入请备份原厂固件并准备 TTL。
# ==============================================================================
set -euo pipefail

DTS_DIR="target/linux/mediatek/files-5.4/arch/arm64/boot/dts/mediatek"
MK_FILE="target/linux/mediatek/image/mt7981.mk"
SRC_DTS="$DTS_DIR/mt7981-kj-kj30-n.dts"
DST_DTS="$DTS_DIR/mt7981-tplink-wma301.dts"

echo "[patch-wma301] 开始注入 WMA301 V2.0 支持..."

# ---------- 前置检查 ----------
if [ ! -f "$SRC_DTS" ]; then
    echo "[patch-wma301] 错误：找不到基底 DTS $SRC_DTS，源码结构可能已变更。"
    exit 1
fi
if [ ! -f "$MK_FILE" ]; then
    echo "[patch-wma301] 错误：找不到 $MK_FILE，源码结构可能已变更。"
    exit 1
fi

# ---------- 1) 复制已验证的 kj30-n DTS 作为基底 ----------
cp -f "$SRC_DTS" "$DST_DTS"

# ---------- 2) 用 Python 精确替换机型相关信息 ----------
python3 - "$DST_DTS" <<'PYEOF'
import sys, re

path = sys.argv[1]
s = open(path, encoding="utf-8").read()

# model / compatible
s = s.replace('model = "KJ30-N";', 'model = "TP-Link WMA301 V2.0";')
s = s.replace('compatible = "kj,kj30-n", "mediatek,mt7981";',
              'compatible = "tplink,wma301", "mediatek,mt7981";')

# 替换一个节点块（按大括号配对定位到对应的 "};"）
def replace_node(src, node_name, new_block):
    m = re.search(r'(\n\s*)' + re.escape(node_name) + r'\s*\{', src)
    if not m:
        return src, False
    start = m.start(0)
    i = src.find('{', m.start())
    depth = 0
    end = None
    for j in range(i, len(src)):
        if src[j] == '{':
            depth += 1
        elif src[j] == '}':
            depth -= 1
            if depth == 0:
                end = j + 1
                # 吞掉结尾的分号
                k = end
                while k < len(src) and src[k] in ' \t':
                    k += 1
                if k < len(src) and src[k] == ';':
                    end = k + 1
                break
    if end is None:
        return src, False
    indent = m.group(1)
    block = indent + new_block.strip('\n')
    return src[:start] + block + src[end:], True

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

s, ok_led  = replace_node(s, 'leds', led_block)
s, ok_keys = replace_node(s, 'gpio-keys', keys_block)
s, ok_alias = replace_node(s, 'aliases', alias_block)

if not (ok_led and ok_keys and ok_alias):
    print(f"[patch-wma301] 警告：部分节点未替换 leds={ok_led} keys={ok_keys} aliases={ok_alias}",
          file=sys.stderr)

open(path, "w", encoding="utf-8").write(s)
print("[patch-wma301] DTS 机型信息替换完成。")
PYEOF

echo "[patch-wma301] 已生成 DTS: $DST_DTS"

# ---------- 3) 在 mt7981.mk 追加设备定义 ----------
if grep -q "define Device/tplink_wma301" "$MK_FILE"; then
    echo "[patch-wma301] 源码已含 tplink_wma301 定义，跳过追加。"
else
    cat >> "$MK_FILE" <<'MK_EOF'

define Device/tplink_wma301
  DEVICE_VENDOR := TP-Link
  DEVICE_MODEL := WMA301 V2.0
  DEVICE_DTS := mt7981-tplink-wma301
  DEVICE_DTS_DIR := $(DTS_DIR)/mediatek
  SUPPORTED_DEVICES := tplink,wma301
  UBINIZE_OPTS := -E 5
  BLOCKSIZE := 128k
  PAGESIZE := 2048
  IMAGE_SIZE := 116736k
  KERNEL_IN_UBI := 1
  IMAGES += factory.bin
  IMAGE/factory.bin := append-ubi | check-size $$$$(IMAGE_SIZE)
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
endef
TARGET_DEVICES += tplink_wma301
MK_EOF
    echo "[patch-wma301] 已在 $MK_FILE 追加 tplink_wma301 定义。"
fi

echo "[patch-wma301] 注入完成。"
