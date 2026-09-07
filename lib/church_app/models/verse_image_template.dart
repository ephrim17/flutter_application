import 'package:flutter/material.dart';

/// A curated photo background. Independent of [VerseLayoutStyle] — picking
/// one never changes the other, and never touches the user's verse text or
/// highlight edits.
class VerseImageTemplate {
  const VerseImageTemplate({
    required this.id,
    required this.nameKey,
    required this.assetPath,
    required this.fontColor,
    required this.footerColor,
    this.blurIntensity = 0,
  });

  final String id;
  final String nameKey;
  final String assetPath;
  final Color fontColor;
  final Color footerColor;
  final double blurIntensity;
}

const verseImageTemplates = <VerseImageTemplate>[
  VerseImageTemplate(
    id: 'calm_ocean',
    nameKey: 'verse_share.template_calm_ocean',
    assetPath: 'assets/verse_templates/calm_ocean.jpg',
    fontColor: Color(0xFF1C2B3A),
    footerColor: Color(0xFF1C2B3A),
  ),
  VerseImageTemplate(
    id: 'starry_night',
    nameKey: 'verse_share.template_starry_night',
    assetPath: 'assets/verse_templates/starry_mountain.jpg',
    fontColor: Colors.white,
    footerColor: Colors.white,
    blurIntensity: 4,
  ),
  VerseImageTemplate(
    id: 'blue_dusk',
    nameKey: 'verse_share.template_blue_dusk',
    assetPath: 'assets/verse_templates/blue_dusk.jpg',
    fontColor: Colors.white,
    footerColor: Colors.white,
  ),
  // Christmas
  VerseImageTemplate(
    id: 'christmas_bokeh_tree',
    nameKey: 'verse_share.template_christmas_bokeh_tree',
    assetPath: 'assets/verse_templates/christmas_bokeh_tree.jpg',
    fontColor: Color(0xFF241A10),
    footerColor: Color(0xFF241A10),
  ),
  VerseImageTemplate(
    id: 'christmas_bokeh_warm',
    nameKey: 'verse_share.template_christmas_bokeh_warm',
    assetPath: 'assets/verse_templates/christmas_bokeh_warm.jpg',
    fontColor: Colors.white,
    footerColor: Colors.white,
  ),
  // Snow
  VerseImageTemplate(
    id: 'snow_branch_light',
    nameKey: 'verse_share.template_snow_branch_light',
    assetPath: 'assets/verse_templates/snow_branch_light.jpg',
    fontColor: Color(0xFF1F2A33),
    footerColor: Color(0xFF1F2A33),
  ),
  VerseImageTemplate(
    id: 'snow_bokeh_night',
    nameKey: 'verse_share.template_snow_bokeh_night',
    assetPath: 'assets/verse_templates/snow_bokeh_night.jpg',
    fontColor: Colors.white,
    footerColor: Colors.white,
  ),
  VerseImageTemplate(
    id: 'snow_bokeh_blue',
    nameKey: 'verse_share.template_snow_bokeh_blue',
    assetPath: 'assets/verse_templates/snow_bokeh_blue.jpg',
    fontColor: Colors.white,
    footerColor: Colors.white,
  ),
  // Cross
  VerseImageTemplate(
    id: 'cross_sunset_uk',
    nameKey: 'verse_share.template_cross_sunset_uk',
    assetPath: 'assets/verse_templates/cross_sunset_uk.jpg',
    fontColor: Colors.white,
    footerColor: Colors.white,
  ),
  VerseImageTemplate(
    id: 'cross_sunset_sea',
    nameKey: 'verse_share.template_cross_sunset_sea',
    assetPath: 'assets/verse_templates/cross_sunset_sea.jpg',
    fontColor: Colors.white,
    footerColor: Colors.white,
  ),
  // Fire
  VerseImageTemplate(
    id: 'fire_dark_bg',
    nameKey: 'verse_share.template_fire_dark_bg',
    assetPath: 'assets/verse_templates/fire_dark_bg.jpg',
    fontColor: Colors.white,
    footerColor: Colors.white,
  ),
  VerseImageTemplate(
    id: 'fire_embers_glow',
    nameKey: 'verse_share.template_fire_embers_glow',
    assetPath: 'assets/verse_templates/fire_embers_glow.jpg',
    fontColor: Colors.white,
    footerColor: Colors.white,
  ),
  // Heaven
  VerseImageTemplate(
    id: 'heaven_sunbeam_clouds',
    nameKey: 'verse_share.template_heaven_sunbeam_clouds',
    assetPath: 'assets/verse_templates/heaven_sunbeam_clouds.jpg',
    fontColor: Colors.white,
    footerColor: Colors.white,
    blurIntensity: 3,
  ),
  VerseImageTemplate(
    id: 'heaven_golden_clouds',
    nameKey: 'verse_share.template_heaven_golden_clouds',
    assetPath: 'assets/verse_templates/heaven_golden_clouds.jpg',
    fontColor: Color(0xFF1C2B3A),
    footerColor: Color(0xFF1C2B3A),
  ),
  // Dove
  VerseImageTemplate(
    id: 'dove_branch_plain',
    nameKey: 'verse_share.template_dove_branch_plain',
    assetPath: 'assets/verse_templates/dove_branch_plain.jpg',
    fontColor: Colors.white,
    footerColor: Colors.white,
  ),
  // White
  VerseImageTemplate(
    id: 'white_fabric_rainbow',
    nameKey: 'verse_share.template_white_fabric_rainbow',
    assetPath: 'assets/verse_templates/white_fabric_rainbow.jpg',
    fontColor: Color(0xFF1C2B3A),
    footerColor: Color(0xFF1C2B3A),
  ),
  VerseImageTemplate(
    id: 'white_fabric_folds',
    nameKey: 'verse_share.template_white_fabric_folds',
    assetPath: 'assets/verse_templates/white_fabric_folds.jpg',
    fontColor: Color(0xFF1C2B3A),
    footerColor: Color(0xFF1C2B3A),
  ),
  VerseImageTemplate(
    id: 'white_feather_soft',
    nameKey: 'verse_share.template_white_feather_soft',
    assetPath: 'assets/verse_templates/white_feather_soft.jpg',
    fontColor: Color(0xFF1C2B3A),
    footerColor: Color(0xFF1C2B3A),
  ),
  // Bible
  VerseImageTemplate(
    id: 'bible_open_light',
    nameKey: 'verse_share.template_bible_open_light',
    assetPath: 'assets/verse_templates/bible_open_light.jpg',
    fontColor: Colors.white,
    footerColor: Colors.white,
  ),
  // Fellowship
  VerseImageTemplate(
    id: 'fellowship_beach_silhouette',
    nameKey: 'verse_share.template_fellowship_beach_silhouette',
    assetPath: 'assets/verse_templates/fellowship_beach_silhouette.jpg',
    fontColor: Colors.white,
    footerColor: Colors.white,
  ),
  VerseImageTemplate(
    id: 'fellowship_hands_grey',
    nameKey: 'verse_share.template_fellowship_hands_grey',
    assetPath: 'assets/verse_templates/fellowship_hands_grey.jpg',
    fontColor: Colors.white,
    footerColor: Colors.white,
  ),
  VerseImageTemplate(
    id: 'fellowship_group_sunset',
    nameKey: 'verse_share.template_fellowship_group_sunset',
    assetPath: 'assets/verse_templates/fellowship_group_sunset.jpg',
    fontColor: Colors.white,
    footerColor: Colors.white,
  ),
];

/// How the verse text is arranged/decorated on the card — fully independent
/// of the background photo. Switching this never touches verse text,
/// highlights, or the chosen background.
enum VerseLayoutKind {
  centered,
  cornerAnchored,
  dividerPill,
  boxedFrame,
  badgeCircle,
  archBanner,
  splitCorners,
  quoteMark,
  sideBarAccent,
  stackedCards,
}

class VerseLayoutStyle {
  const VerseLayoutStyle({
    required this.kind,
    required this.nameKey,
    required this.icon,
  });

  final VerseLayoutKind kind;
  final String nameKey;
  final IconData icon;
}

const verseLayoutStyles = <VerseLayoutStyle>[
  VerseLayoutStyle(
    kind: VerseLayoutKind.centered,
    nameKey: 'verse_share.layout_centered',
    icon: Icons.format_align_center_rounded,
  ),
  VerseLayoutStyle(
    kind: VerseLayoutKind.cornerAnchored,
    nameKey: 'verse_share.layout_corner',
    icon: Icons.vertical_align_top_rounded,
  ),
  VerseLayoutStyle(
    kind: VerseLayoutKind.dividerPill,
    nameKey: 'verse_share.layout_divider_pill',
    icon: Icons.horizontal_rule_rounded,
  ),
  VerseLayoutStyle(
    kind: VerseLayoutKind.boxedFrame,
    nameKey: 'verse_share.layout_boxed',
    icon: Icons.crop_square_rounded,
  ),
  VerseLayoutStyle(
    kind: VerseLayoutKind.badgeCircle,
    nameKey: 'verse_share.layout_badge',
    icon: Icons.circle_outlined,
  ),
  VerseLayoutStyle(
    kind: VerseLayoutKind.archBanner,
    nameKey: 'verse_share.layout_arch',
    icon: Icons.bookmark_outline_rounded,
  ),
  VerseLayoutStyle(
    kind: VerseLayoutKind.splitCorners,
    nameKey: 'verse_share.layout_split',
    icon: Icons.call_split_rounded,
  ),
  VerseLayoutStyle(
    kind: VerseLayoutKind.quoteMark,
    nameKey: 'verse_share.layout_quote',
    icon: Icons.format_quote_rounded,
  ),
  VerseLayoutStyle(
    kind: VerseLayoutKind.sideBarAccent,
    nameKey: 'verse_share.layout_sidebar',
    icon: Icons.view_sidebar_rounded,
  ),
  VerseLayoutStyle(
    kind: VerseLayoutKind.stackedCards,
    nameKey: 'verse_share.layout_stacked',
    icon: Icons.filter_none_rounded,
  ),
];
