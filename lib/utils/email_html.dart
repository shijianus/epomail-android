import 'package:html/parser.dart' as html_parser;

/// Defences applied to untrusted email HTML before it is rendered.
class EmailHtml {
  EmailHtml._();

  static const _linkSchemes = {'http', 'https', 'mailto', 'tel'};

  static const _mediaTags =
      'img,picture,source,video,audio,input,image,embed,object,iframe,track';

  static const _urlAttrs = {
    'src', 'srcset', 'poster', 'background', 'data', 'xlink:href', 'href', //
  };

  // Anything that is not an inline image is treated as remote, so unusual URL
  // forms (`//host`, other schemes) cannot slip by.
  static bool _isInline(String value) {
    final v = value.trim().toLowerCase();
    return v.isEmpty || v.startsWith('data:image/') || v.startsWith('cid:');
  }

  /// Works on the DOM built by the same HTML parser the renderer uses, so the
  /// check sees exactly the elements and decoded attributes that would load.
  static ({String html, bool blocked}) _scan(String html) {
    final doc = html_parser.parse(html);
    var blocked = false;
    for (final el in doc.querySelectorAll(_mediaTags)) {
      for (final key in el.attributes.keys.toList()) {
        final name = key.toString().toLowerCase();
        if (!_urlAttrs.contains(name)) continue;
        if (_isInline(el.attributes[key] ?? '')) continue;
        el.attributes.remove(key);
        blocked = true;
      }
    }
    // CSS can fetch remote resources too (background images, @import).
    for (final el in doc.querySelectorAll('[style]')) {
      if (_cssFetches(el.attributes['style'] ?? '')) {
        el.attributes.remove('style');
        blocked = true;
      }
    }
    for (final el in doc.querySelectorAll('style,link')) {
      if (el.localName == 'link' || _cssFetches(el.text)) {
        el.remove();
        blocked = true;
      }
    }
    return (html: blocked ? doc.outerHtml : html, blocked: blocked);
  }

  static bool _cssFetches(String css) {
    final c = css.toLowerCase();
    return c.contains('url') || c.contains('@import') || c.contains(r'\');
  }

  static bool hasRemoteImages(String html) => _scan(html).blocked;

  /// Neutralises remote media URLs (tracking pixels, IP disclosure) while
  /// keeping inline `data:` / `cid:` images.
  static String blockRemoteImages(String html) => _scan(html).html;

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
