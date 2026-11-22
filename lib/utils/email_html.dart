/// Defences applied to untrusted email HTML before it is rendered.
class EmailHtml {
  EmailHtml._();

  static const _linkSchemes = {'http', 'https', 'mailto', 'tel'};

  static final _mediaTag = RegExp(
    r'<(?:img|picture|source|video|audio|input|image|embed|object|iframe|track)\b[^>]*>',
    caseSensitive: false,
  );

  static final _urlAttr = RegExp(
    r'''(\s)(src|srcset|poster|background|data|xlink:href|href)(\s*=\s*)("[^"]*"|'[^']*'|[^\s>]+)''',
    caseSensitive: false,
  );

  // Anything that is not an inline image is treated as remote, so encoded or
  // unusual URL forms (`https&#58;//…`, `//host`, other schemes) cannot slip by.
  static bool _isInline(String quoted) {
    var v = quoted;
    if (v.length >= 2 && (v.startsWith('"') || v.startsWith("'"))) {
      v = v.substring(1, v.length - 1);
    }
    v = v.trim().toLowerCase();
    return v.isEmpty || v.startsWith('data:image/') || v.startsWith('cid:');
  }

  static bool hasRemoteImages(String html) => _mediaTag
      .allMatches(html)
      .any((t) => _urlAttr.allMatches(t[0]!).any((a) => !_isInline(a[4]!)));

  /// Neutralises remote media URLs (tracking pixels, IP disclosure) while
  /// keeping inline `data:` / `cid:` images.
  static String blockRemoteImages(String html) => html.replaceAllMapped(
        _mediaTag,
        (t) => t[0]!.replaceAllMapped(
          _urlAttr,
          (a) => _isInline(a[4]!)
              ? a[0]!
              : '${a[1]}data-blocked-${a[2]}${a[3]}""',
        ),
      );

  /// The URI to open for a tapped link, or null when its scheme is not one a
  /// mail reader should hand to the OS (`intent:`, `file:`, `javascript:`…).
  static Uri? safeLink(String? url) {
    if (url == null) return null;
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !_linkSchemes.contains(uri.scheme.toLowerCase())) {
      return null;
    }
    if ((uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isEmpty) {
      return null;
    }
    return uri;
  }
}
