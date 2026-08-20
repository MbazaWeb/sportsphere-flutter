// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

String? webKvGet(String key) => html.window.sessionStorage[key];

void webKvSet(String key, String value) {
  html.window.sessionStorage[key] = value;
}

void webKvRemove(String key) {
  html.window.sessionStorage.remove(key);
}
