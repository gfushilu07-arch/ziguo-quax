enum ContentAccessCode {
  authRequired,
  forbidden,
  rateLimited,
  networkError,
  sourceMissing,
  sourceChanged,
  sourceIncomplete,
  unsupported,
}

final class ContentAccessException implements Exception {
  final ContentAccessCode code;
  final DateTime? retryAt;
  const ContentAccessException(this.code, {this.retryAt});

  String get message => switch (code) {
    ContentAccessCode.authRequired => '请先登录 X，或重新登录已过期的账户。',
    ContentAccessCode.forbidden => '当前 X 账户没有访问这条内容的权限。',
    ContentAccessCode.rateLimited => 'X 暂时限制了请求，请稍后重试。',
    ContentAccessCode.networkError => '连接 X 失败，请检查网络后重试。',
    ContentAccessCode.sourceMissing => '来源已不可读，请打开原帖核对。',
    ContentAccessCode.sourceChanged => '来源与目录引用不一致，请重新解析并选择内容。',
    ContentAccessCode.sourceIncomplete => 'X 未返回完整内容，暂时无法阅读。',
    ContentAccessCode.unsupported => '这类 X 内容尚未通过当前版本的读取验证。',
  };

  @override
  String toString() => 'ContentAccessException(${code.name})';
}
