import 'package:flutter/material.dart';

class ColorTokens {
  // Brand colors
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryLight = Color(0xFF8B7EF0);
  static const Color primaryDark = Color(0xFF5A4BD1);

  static const Color secondary = Color(0xFF00CEC9);
  static const Color secondaryLight = Color(0xFF55EFC4);

  static const Color accent = Color(0xFFFD79A8);

  // Semantic colors
  static const Color success = Color(0xFF00B894);
  static const Color warning = Color(0xFFFDAA5E);
  static const Color error = Color(0xFFFF6B6B);
  static const Color info = Color(0xFF74B9FF);

  // HTTP method colors
  static const Color httpGet = Color(0xFF00B894);
  static const Color httpPost = Color(0xFF6C5CE7);
  static const Color httpPut = Color(0xFFFDAA5E);
  static const Color httpPatch = Color(0xFF00CEC9);
  static const Color httpDelete = Color(0xFFFF6B6B);

  // Log level colors
  static const Color logDebug = Color(0xFF636E72);
  static const Color logInfo = Color(0xFF74B9FF);
  static const Color logWarn = Color(0xFFFDAA5E);
  static const Color logError = Color(0xFFFF6B6B);

  // Status code colors
  static Color statusCodeColor(int code) {
    if (code < 200) return info;
    if (code < 300) return success;
    if (code < 400) return warning;
    if (code < 500) return error;
    return const Color(0xFFD63031);
  }

  static Color httpMethodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return httpGet;
      case 'POST':
        return httpPost;
      case 'PUT':
        return httpPut;
      case 'PATCH':
        return httpPatch;
      case 'DELETE':
        return httpDelete;
      default:
        return info;
    }
  }
}
