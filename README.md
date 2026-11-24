**English** | [中文](https://p3terx.com/archives/build-openwrt-with-github-actions.html)

# Actions-OpenWrt（kj30-n / komi-a31 / wma301）

[![LICENSE](https://img.shields.io/github/license/mashape/apistatus.svg?style=flat-square&label=LICENSE)](https://github.com/P3TERX/Actions-OpenWrt/blob/master/LICENSE)

## 新增：WMA301 V2.0（5.4 源码）

本项目在原 `Actions-OpenWrt_kj30-n_komi_a31` 基础上新增了 **TP-Link WMA301 V2.0** 的云编译工作流，与 kj30-n 共用同一套 **5.4 内核** 源码：

| 机型 | 工作流 | 配置文件 | 源码 / 分支 |
|---|---|---|---|
| WMA301 V2.0 | `wma301-237-2410-5.4.yml` | `configs/wma301-237-2410.config` | `chaoticinitiation/immortalwrt-mt798x-24.10-237` @ `2410`（内核 5.4） |

**用法**：推送到你的仓库 → Actions 页选择 `WMA301 V2.0 2410-5.4 OpenWrt Builder` → `Run workflow`，完成后在 Artifacts / Release 下载固件。

**固件特性**（config 已配好，与 kj30-n 一致）：MTK 闭源硬件加速（`kmod-mt_wifi` + HNAT + TurboACC + WED）、UPnP（MTK 特调版 `luci-app-upnp-mtk-adjust`）、ZeroTier；不含科学上网与 USB 相关组件。

**关于 DTS 注入**：5.4 源码原生不含 wma301，工作流在克隆源码后会执行 `scripts/patch-wma301.sh`，它复制源码中已验证的 `kj30n.dts` 作为基底（两者同为 MT7981 + SPI-NAND，ubi 分区均为 `0x580000` 起 114M，刷机位置一致），仅替换机型名 / LED / 按键，再向 `mt7981.mk` 追加 `tplink_wma301` 设备定义。LED / 按键 GPIO 依公开资料推算，**未经真机验证**，首次刷入请备份原厂固件并准备 TTL。

![GitHub Stars](https://img.shields.io/github/stars/P3TERX/Actions-OpenWrt.svg?style=flat-square&label=Stars&logo=github)
![GitHub Forks](https://img.shields.io/github/forks/P3TERX/Actions-OpenWrt.svg?style=flat-square&label=Forks&logo=github)

A template for building OpenWrt with GitHub Actions

## Usage

- Click the [Use this template](https://github.com/P3TERX/Actions-OpenWrt/generate) button to create a new repository.
- Generate `.config` files using [Lean's OpenWrt](https://github.com/coolsnowwolf/lede) source code. ( You can change it through environment variables in the workflow file. )
- Push `.config` file to the GitHub repository.
- Select `Build OpenWrt` on the Actions page.
- Click the `Run workflow` button.
- When the build is complete, click the `Artifacts` button in the upper right corner of the Actions page to download the binaries.

## Tips

- It may take a long time to create a `.config` file and build the OpenWrt firmware. Thus, before create repository to build your own firmware, you may check out if others have already built it which meet your needs by simply [search `Actions-Openwrt` in GitHub](https://github.com/search?q=Actions-openwrt).
- Add some meta info of your built firmware (such as firmware architecture and installed packages) to your repository introduction, this will save others' time.

## Credits

- [Microsoft Azure](https://azure.microsoft.com)
- [GitHub Actions](https://github.com/features/actions)
- [OpenWrt](https://github.com/openwrt/openwrt)
- [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede)
- [Mikubill/transfer](https://github.com/Mikubill/transfer)
- [softprops/action-gh-release](https://github.com/softprops/action-gh-release)
- [Mattraks/delete-workflow-runs](https://github.com/Mattraks/delete-workflow-runs)
- [dev-drprasad/delete-older-releases](https://github.com/dev-drprasad/delete-older-releases)
- [peter-evans/repository-dispatch](https://github.com/peter-evans/repository-dispatch)

## License

[MIT](https://github.com/P3TERX/Actions-OpenWrt/blob/main/LICENSE) © [**P3TERX**](https://p3terx.com)
