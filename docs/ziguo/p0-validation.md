# P0 验证记录

日期：2026-11-08（Asia/Shanghai）。当前为实施中的记录，未完成的检查保留“待完成”。

| 项目 | 当前结果 |
| --- | --- |
| 原始 QuaX 静态检查 | 通过，基线 d27c7b0c |
| 原始 QuaX 单元与组件测试 | 1,116 项通过 |
| 原始 QuaX Android debug 构建 | 通过，原始上游代码，arm/arm64/x64 debug APK |
| 自有引用、适配、顺序读取、播放器生命周期测试 | 31 项通过（含截断正文、跨层引用、组件操作与播放器生命周期） |
| 自有完整回归与 APK | 1,147 项测试通过；静态检查通过；arm64 debug APK 构建、安装、冷启动通过 |
| 真实 X 视频播放 | 未通过：第二台设备已收到 X 响应，但返回 authRequired，待正常登录 |
| 真实 X 顺序正文 | 未验证：首台设备 networkError，第二台待登录后复测 |
| 真实 X 跨帖多图 | 未验证：首台设备 networkError，第二台待登录后复测 |
| 上游合并及回滚演练 | 通过，独立工作区合并与回滚均核对 Git tree |

公开测试样本见 [live-samples.md](live-samples.md)。用户已同意先用公开帖子验证读取链路；这不表示真实短剧／小说／漫画作品已验收。普通 CI 和 fixture 测试通过不会替代在线结果。

当前 fork：`https://github.com/gfushilu07-arch/ziguo-quax`。客户端内容不会发送到自有 API；本阶段没有自有 API 或媒体服务器。

## 上游同步演练

产品代码提交：`147bbaf8388c09a4c6f17b060b4efdbf4d5507b5`。在独立 worktree 从上游父提交 `3f3ca7c8c2f601bb6d3814400604f629325f3dcb` 应用两项子果提交，再合并锁定的上游 `d27c7b0c`。

- 合并提交：`0a292b03ce0c5dbbc9d601d5e9c768770ea9ef40`，无冲突，合并后 Git tree 与产品提交完全一致。
- 使用 `git revert -m 1` 的回滚提交：`1755745c732ebb39072a908c072597ff3afc84f9`，回滚后 Git tree 与演练合并前完全一致。
- 演练覆盖历史保留、产品补丁保留与可逆合并；本次上游差异为发布 workflow，不能据此承诺未来协议变更无冲突。相同产品树使用本记录中的构建和回归结果。

## 可复现性与设备

- 产品代码基准：`147bbaf8388c09a4c6f17b060b4efdbf4d5507b5`；后续文档提交不改变应用代码。
- 工具链：Flutter 3.47.9 / Dart 3.13.7；Java 25；Android SDK 37.0 / Build Tools 37.0.0 / NDK 29.0.14206865。
- 设备：Xiaomi 2107119DC（lisa），Android 14，arm64。
- 构建：`./tool/ziguo/build_android.sh --no-pub --target-platform android-arm64`。产物包名 `com.ziguo.client.debug`，应用名“子果 P0”，调试版本，不是发行包。
- APK SHA-256：`fbc093c6a2622fadefac17383f17a5c8f1074dc593e5bddcda148269d4d5cea0`。
- 原版构建未加入业务代码，arm/arm64/x64 debug APK 成功；上游编译器仍有 API 37.0 与 KGP 迁移提示，本次没有升级上游构建配置。
- 独立目录从本地主仓库递归 clone，客户端从 GitHub HTTPS 拉取固定提交；运行 `prepare.sh` 后客户端仍干净，版本锁检查通过。
- 主仓库版本检查器 7 项测试通过；Markdown 本地链接检查通过。全部在线结果另记，不将上述离线结果作为 X 可读的证明。

## 在线执行结果（访客会话）

执行 `fvm flutter test integration_test/ziguo/content_probe_test.dart -d DEVICE_ID --no-pub --dart-define=ZIGUO_LIVE_X=true --reporter expanded`，真实设备测试断言失败。没有替换为模拟接口或本地 fixture。设备尚未建立 X 登录会话；所有请求均返回 networkError，因此不能判断登录后的接口可用性，也不能据此判断帖子被删除。

| 帖子 ID | 类型 | 结果 |
| --- | --- | --- |
| 2095920036523172091 | video | networkError |
| 2095916385209651546 | text | networkError |
| 2095916387017408802 | text | networkError |
| 2095922394959421815 | image | networkError |
| 2095918939641356306 | image | networkError |

需先让设备能够正常访问 X，并在应用内完成正常登录，再复跑在线验证。当前没有通过三类内容可行性门槛，P0 尚未完成，不进入 P1。断网、登出与失效来源的设备交互组合仍未完成；相应错误分类和生命周期只有离线测试证据。未进行带凭据抓包，未将正文、媒体或会话发送到自有服务。

## 第二台设备复测（访客会话）

用户更换为能够访问 X 的 Huawei NOH-AN50（Android 12，arm64）。相同 APK 安装与冷启动通过，真实请求在约 2 秒内返回 `authRequired`。首个视频样本要求登录后测试即停止，正文／图片没有继续请求；这证明当前设备可收到 X 响应，但尚未证明三类内容可以读取。下一步是用户在设备内正常登录后继续同一组测试。
