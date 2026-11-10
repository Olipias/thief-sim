# 发布 / 部署

游戏是 Godot 4.7.2 项目。推荐导出 **Web 版**，发一个 itch.io 链接：老师同学用浏览器打开就能玩，不用安装。

## 1. 构建

需要：

- Godot 4.7.2（本机 `~/.local/bin/godot`）
- 对应版本的导出模板：`~/.local/share/godot/export_templates/4.7.2.stable/`
  - 下载 `Godot_v4.7.2-stable_export_templates.tpz`，解压后把 `templates/` 里的文件放进该目录。
- 项目根目录的 `export_presets.cfg` 已包含 Web / Windows / Linux 三套预设。

一键构建（导入、导出、压缩）：

```bash
./tools/export.sh
```

产物：

| 文件 | 用途 | 约 |
| --- | --- | --- |
| `build/web/index.html` 等 | 本地预览 / 静态托管 | 45 MB |
| `build/thief-sim-web.zip` | itch.io 上传（HTML 游戏） | 16 MB |
| `build/windows/thief-sim.exe` | 单文件 Windows 版（内嵌 pck） | 111 MB |
| `build/thief-sim-windows.zip` | Windows 下载包 | 43 MB |
| `build/linux/thief-sim.x86_64` | Linux 版 | 77 MB |
| `build/thief-sim-linux.zip` | Linux 下载包 | 34 MB |

`build/` 已在 `.gitignore` 中，构建产物不提交；同学下载的是 zip 或网页，不需要源码。

## 2. 推荐：itch.io（Web 版）

1. 登录 <https://itch.io>，**Create new project**。
2. **Kind of project** 选 **HTML**。
3. 上传 `build/thief-sim-web.zip`。
4. 勾选 **This file will be played in the browser**。
5. Embed options：尺寸填 `960 × 540`，打开 **Fullscreen button**；Mobile friendly 可以关（键鼠操作）。
6. 保存。Visibility 选 **Unlisted**（只有拿到链接的人能看）或 Public。
7. 复制页面链接发给老师/同学。

同一个页面可以再加一个 **Downloadable** 文件：上传 `build/thief-sim-windows.zip`，给不想用浏览器的人。

Web 版关闭了线程（`variant/thread_support=false`），不需要 `SharedArrayBuffer` 或 COOP/COEP 头，所以 itch.io、GitHub Pages、Netlify Drop 都能直接托管。

## 3. 备选托管

- **GitHub Release**：在仓库 Releases 里新建版本，上传 `thief-sim-web.zip` / `thief-sim-windows.zip`，发下载链接。
- **Netlify Drop**：把 `build/web/` 整个文件夹拖到 <https://app.netlify.com/drop>，得到一个临时网址。适合学校网络屏蔽 itch.io 时用。
- **GitHub Pages**：把 `build/web/` 推到 `gh-pages` 分支并开启 Pages。wasm 较大，建议用 Release 而不是把构建产物提交进主仓库。
- **Windows zip**：解压后运行 `thief-sim.exe`，无需安装。未签名，SmartScreen 会提示，点“更多信息 → 仍要运行”。

## 4. 已知限制

- **声音**：浏览器要求先有一次点击才允许播放音频；点标题页按钮后正常。
- **存档**：Web 版存在浏览器的 IndexedDB 里，换浏览器/无痕模式就是新档，不和桌面版共用。
- **WebGL2**：很老的浏览器/显卡可能跑不起来；建议 Chrome / Edge / Firefox 最新版。
- **macOS 原生包**：未签名/未公证会被 Gatekeeper 拦；课堂分享用 Web 版即可。
- **Windows 杀毒误报**：Godot 导出的未签名 exe 偶尔会被误报；可以只发 Web 链接，或让同学用 itch.io 的浏览器版。

## 5. 发布页文案与署名

游戏内「声明与说明」已有真实文物来源、虚构说明、3D 资产说明和字体许可。itch.io 页面建议再写：

> 学生项目 / 数字历史 capstone。游戏中的青铜人面具与商代双羊尊为真实文物，具体来源与史实/演绎分界见游戏内「声明与说明」。3D 资产由腾讯混元（Hunyuan3D）生成，仅作展示性再现。字体为 Fusion Pixel（OFL）。

封面图为作者提供；公开发布前请确认你有权再分发。
