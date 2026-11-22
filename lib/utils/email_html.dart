/// Defences applied to untrusted email HTML before it is rendered.
class EmailHtml {
  EmailHtml._();

  static const _linkSchemes = {'http', 'https', 'mailto', 'tel'};

  static final _mediaOpen = RegExp(
    r'<(img|picture|source|video|audio|input|image|embed|object|iframe|track)(?=[\s/>])',
    caseSensitive: false,
  );

  static const _urlAttrs = {
    'src', 'srcset', 'poster', 'background', 'data', 'xlink:href', 'href', //
  };

  // Anything that is not an inline image is treated as remote, so encoded or
  // unusual URL forms (`https&#58;//…`, `//host`, other schemes) cannot slip by.
  static bool _isInline(String value) {
    final v = value.trim().toLowerCase();
    return v.isEmpty || v.startsWith('data:image/') || v.startsWith('cid:');
  }

  static bool _isSpace(int c) =>
      c == 0x20 || c == 0x09 || c == 0x0a || c == 0x0c || c == 0x0d;

  /// Rewrites media tags attribute by attribute, the way an HTML parser reads
  /// them, so quoted text can never be mistaken for an attribute.
  static ({String html, bool blocked}) _scan(String html) {
    final out = StringBuffer();
    var blocked = false;
    var pos = 0;
    for (final m in _mediaOpen.allMatches(html)) {
      if (m.start < pos) continue; // inside a tag that was already consumed
      out.write(html.substring(pos, m.end));
      var i = m.end;
      final n = html.length;
      while (i < n) {
        final ws = i;
        while (i < n && (_isSpace(html.codeUnitAt(i)) || html[i] == '/')) {
          i++;
        }
        out.write(html.substring(ws, i));
        if (i >= n || html[i] == '>') break;

        final nameStart = i;
        // A leading '=' is part of the name (HTML attribute-name state).
        if (html[i] == '=') i++;
        while (i < n &&
            !_isSpace(html.codeUnitAt(i)) &&
            html[i] != '=' &&
            html[i] != '>' &&
            html[i] != '/') {
          i++;
        }
        final name = html.substring(nameStart, i);

        var j = i;
        while (j < n && _isSpace(html.codeUnitAt(j))) {
          j++;
        }
        if (j >= n || html[j] != '=') {
          out.write(name); // attribute without a value
          continue;
        }
        j++;
        while (j < n && _isSpace(html.codeUnitAt(j))) {
          j++;
        }
        final String value;
        if (j < n && (html[j] == '"' || html[j] == "'")) {
          final close = html.indexOf(html[j], j + 1);
          final end = close < 0 ? n : close;
          value = html.substring(j + 1, end);
          i = close < 0 ? n : close + 1;
        } else {
          final vs = j;
          while (j < n && !_isSpace(html.codeUnitAt(j)) && html[j] != '>') {
            j++;
          }
          value = html.substring(vs, j);
          i = j;
        }

        if (_urlAttrs.contains(name.toLowerCase()) && !_isInline(value)) {
          blocked = true;
          out.write('data-blocked-$name=""');
        } else {
          out.write(html.substring(nameStart, i));
        }
      }
      pos = i;
    }
    out.write(html.substring(pos));
    return (html: out.toString(), blocked: blocked);
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
