import 'package:flutter/material.dart';
import 'package:hercules_control/core/theme/app_theme.dart';

const brandLogoAsset = 'assets/brand/logo_512.png';

/// Shield mark (navy shield, gold border and columns "H").
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      brandLogoAsset,
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Hércules Control',
      errorBuilder: (context, error, stackTrace) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: BrandColors.navy,
          border: Border.all(color: BrandColors.gold, width: 2),
          borderRadius: BorderRadius.circular(size * 0.2),
        ),
        child: Text(
          'H',
          style: TextStyle(
            color: BrandColors.gold,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.5,
          ),
        ),
      ),
    );
  }
}

/// "HÉRCULES" bold + "CONTROL" gold, letter-spaced.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({
    super.key,
    this.fontSize = 28,
    this.titleColor = BrandColors.navy,
    this.alignment = CrossAxisAlignment.start,
  });

  final double fontSize;
  final Color titleColor;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'HÉRCULES',
          style: TextStyle(
            color: titleColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: fontSize * 0.12,
            height: 1.05,
          ),
        ),
        Text(
          'CONTROL',
          style: TextStyle(
            color: BrandColors.gold,
            fontSize: fontSize * 0.46,
            fontWeight: FontWeight.w700,
            letterSpacing: fontSize * 0.3,
          ),
        ),
      ],
    );
  }
}
