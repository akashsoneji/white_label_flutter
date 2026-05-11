import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SvgColorHelper {
  static Future<Widget> loadSvgWithColor({
    required String assetPath,
    required Color targetColor,
    required String colorToReplace, // e.g. "#FF0000"
    double? height,
    double? width,
  }) async {
    String svgString = await rootBundle.loadString(assetPath);

    svgString = svgString.replaceAll(
      colorToReplace.toUpperCase(),
      _colorToHex(targetColor),
    );
    svgString = svgString.replaceAll(
      colorToReplace.toLowerCase(),
      _colorToHex(targetColor),
    );

    return SvgPicture.string(svgString, height: height, width: width);
  }

  static Future<Widget> loadSvgWithTwoColors({
    required String assetPath,
    required Color targetColor1,
    required String colorToReplace1, // e.g. "#FF0000"
    required Color targetColor2,
    required String colorToReplace2, // e.g. "#00FF00"
    double? height,
    double? width,
  }) async {
    String svgString = await rootBundle.loadString(assetPath);

    svgString = svgString.replaceAll(
      colorToReplace1.toUpperCase(),
      _colorToHex(targetColor1),
    );
    svgString = svgString.replaceAll(
      colorToReplace1.toLowerCase(),
      _colorToHex(targetColor1),
    );

    svgString = svgString.replaceAll(
      colorToReplace2.toUpperCase(),
      _colorToHex(targetColor2),
    );
    svgString = svgString.replaceAll(
      colorToReplace2.toLowerCase(),
      _colorToHex(targetColor2),
    );

    return SvgPicture.string(svgString, height: height, width: width);
  }

  static Future<Widget> loadSvgWithColorReplacements({
    required String assetPath,
    required Color targetColor,
    required List<String> colorsToReplace, // e.g. ["#FF0000", "#00FF00"]
    double? height,
    double? width,
  }) async {
    String svgString = await rootBundle.loadString(assetPath);
    final replacement = _colorToHex(targetColor);

    for (final colorToReplace in colorsToReplace) {
      svgString = svgString.replaceAll(colorToReplace.toUpperCase(), replacement);
      svgString = svgString.replaceAll(colorToReplace.toLowerCase(), replacement);
    }

    return SvgPicture.string(svgString, height: height, width: width);
  }

  static String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }
}

