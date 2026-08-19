import 'session_memory.dart';

String? webKvGet(String key) => SessionMemory.map[key];

void webKvSet(String key, String value) => SessionMemory.map[key] = value;

void webKvRemove(String key) => SessionMemory.map.remove(key);
