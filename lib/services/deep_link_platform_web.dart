import 'dart:html' as html;

Uri? getCurrentUri() {
  return Uri.parse(html.window.location.href);
}

void clearBrowserUrl() {
  html.window.history.replaceState(
    {},
    '',
    html.window.location.pathname,
  );
}