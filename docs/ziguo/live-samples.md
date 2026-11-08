# P0 公开测试样本

这些链接来自 QuaX 自身的公开测试账号和源码 fixture。它们用于证明视频、正文与图片读取能力，不代表已经验收真实短剧、小说或漫画作品；在线可用性以实际运行结果为准。

| 用途 | 公开帖子 |
| --- | --- |
| 视频 | https://x.com/quax_tests/status/2095920036523172091 |
| 顺序正文 1 | https://x.com/quax_tests/status/2095916385209651546 |
| 顺序正文 2 | https://x.com/quax_tests/status/2095916387017408802 |
| 多图帖 1 | https://x.com/quax_tests/status/2095922394959421815 |
| 多图帖 2 | https://x.com/quax_tests/status/2095918939641356306 |

在线集成测试默认跳过，只有显式 `--dart-define=ZIGUO_LIVE_X=true` 才请求 X。测试复用设备上的应用会话；不要将 Cookie 或账户数据放进命令、仓库或 CI secrets。

```bash
fvm flutter test integration_test/ziguo/content_probe_test.dart \
  -d DEVICE_ID --dart-define=ZIGUO_LIVE_X=true
```

视频必须实际播放并推进至少 500 毫秒，图片必须成功解码，正文必须完整非空，所有样本类型都通过才算在线测试通过。只打印帖子 ID、内容类型、状态和项目数量；不打印正文或媒体直链。
