import 'dart:html' as html;

String getWebOrigin() => html.window.location.origin;

String getWebFullUrl() => html.window.location.href;

String getWebPathName() => html.window.location.pathname ?? '';

void clearWebUrlParams() {
  html.window.history.replaceState(
    {},
    '',
    html.window.location.pathname,
  );
}