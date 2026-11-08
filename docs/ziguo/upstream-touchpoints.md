# 子果接入台账

基线：QuaX `d27c7b0c904a1dab769dae7d827599f2fcb9b1ce`；Flutter 3.47.9 / Dart 3.13.7。

## 原有文件的必要改动

| 路径 | 改动原因 | 验证与后续处理 |
| --- | --- | --- |
| `lib/home/home_screen.dart` | 在编译开关开启时注册内容验证入口 | 原有导航测试；P0 真机导航；正式频道由 P2 替代 |
| `lib/main.dart` | P0 开启时关闭原有 QuaX APK 更新提示 | 子果不得推荐安装 QuaX APK；P3 接自己的更新通道 |
| `android/app/build.gradle` | applicationId 改为 `com.ziguo.client`，debug 为 `com.ziguo.client.debug` | 与原 QuaX 独立安装；Kotlin namespace 保持上游 |
| `pubspec.yaml` / `pubspec.lock` | 增加 Flutter SDK 自带 integration_test 开发依赖 | 手动开启设备测试；普通 CI 不访问真实 X |
| `lib/client/client.dart` | 保留 legacy 的 `truncated` 标记，防止预览被当成完整正文 | GraphQL 解析回归测试；上游等价修复后移除此补丁 |
| `android/app/src/debug/res/values/string.xml` | debug 应用名改为“子果 P0” | 真机安装识别 |

新增业务、类型和适配均在 `lib/ziguo/`；新增测试在 `test/ziguo/` 与 `integration_test/ziguo/`。上游模型仅有上述一行标记保留修复；X 请求、会话、数据库迁移和播放器实现沿用上游。

## P0 具体决策

- 公共 `XContentGateway.resolve` 返回设备内存中的内容，`XContentInspector.inspectPost` 只返回可选引用。媒体由用户明确选择，避免默认取第一项。
- P0 普通帖子正文已实现；长帖与 Article 返回 unsupported，待独立在线验证后开启。
- 复用 QuaX 已有 BetterPlayer Plus 依赖。诊断页管理单个播放器，关闭磁盘缓存；来源访问错误最多重新解析一次，解码错误不重建播放器。
- 验证入口使用 `--dart-define=ZIGUO_CONTENT_PROBE=true` 开启，默认关闭以保留上游行为和测试基线。
- 后台、服务器、上传、支付等均未引入。X 会话只在设备端使用。

## 构建

需要 FVM、Python 3、Cairo、Android SDK、Java；跟随当前 `.fvmrc`。本次环境使用 Java 25、Android 平台 37.0、构建工具 37.0.0、NDK 29.0.14206865。实际结果见 `p0-validation.md`。

```bash
fvm install
fvm use
./tool/ziguo/prepare.sh
fvm flutter analyze
fvm flutter test
fvm dart run tool/ziguo/check_boundaries.dart
./tool/ziguo/build_android.sh
```

`prepare.sh` 保留 README／商店图标文件的现有字节，避免仅运行上游图标生成器就产生文档资源 diff。macOS Homebrew 的 Cairo 通过局部的动态库路径提供，不修改系统配置。

## 合并与回滚

上游修复仍通过 `upstream/master` 合并指定 SHA。自有提交集中且保留上游祖先关系，禁止重写产品 main。发布时父仓库同时锁定客户端 SHA 与上游 SHA。具体演练记录后续写入 `p0-validation.md`，未记录通过就不能视为已演练。
