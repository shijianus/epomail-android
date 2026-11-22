/// Defences applied to untrusted email HTML before it is rendered.
class EmailHtml {
  EmailHtml._();

  static const _linkSchemes = {'http', 'https', 'mailto', 'tel'};

  static final _remoteSrc = RegExp(
    r'''(<(?:img|source|video|audio|input|image)\b[^>]*?\s)(src|srcset|poster|background|xlink:href|href)(\s*=\s*)("\s*(?:https?:)?//[^"]*"|'\s*(?:https?:)?//[^']*'|(?:https?:)?//[^\s>]+)''',
    caseSensitive: false,
  );

  static bool hasRemoteImages(String html) => _remoteSrc.hasMatch(html);

  /// Neutralises remote media URLs (tracking pixels, IP disclosure) while
  /// keeping inline `data:` / `cid:` images.
  static String blockRemoteImages(String html) {
    var out = html;
    // An element can carry several remote attributes; repeat until stable.
    for (var i = 0; i < 8 && _remoteSrc.hasMatch(out); i++) {
      out = out.replaceAllMapped(
          _remoteSrc, (m) => '${m[1]}data-blocked-${m[2]}${m[3]}""');
    }
    return out;
  }

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
