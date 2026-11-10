import 'package:intl/intl.dart';

// Builds the master prompt a person pastes into ChatGPT or Gemini to make a
// Daily Bible-verse poster themselves. Modelled on the "Daily Bible Verse
// Poster — Master Prompt Builder" (tcsong.com/prompteasy/DBVPoster1.html).
//
// The option lists below are prompt vocabulary, not app copy: each string is
// pasted verbatim into an English instruction to an image model, so it stays
// English whatever the app's UI language is, exactly as the dropdowns show it.

const versePosterTopStyles = [
  'small elegant uppercase label with thin gold lines on each side',
  'bold ribbon banner across the top',
  'rounded pill badge, centred',
  'handwritten script, left-aligned',
  'stacked logo-style wordmark with a small cross icon',
  'subtle watermark-style text, 60% opacity',
  'gold embossed metallic letters on a dark ribbon, centred',
  'elegant calligraphy script with a small cross flourish above it',
  'glass-effect frosted bar across the top with white text',
  'arched text curving over a small logo-style emblem',
  'bold uppercase sans with a thin gold underline',
  'hand-lettered brush text with a paint-stroke background',
  'vintage badge / seal style with a circular border and stars',
  'neon sign style glowing text',
  'minimal small-caps text with wide letter spacing, no decoration',
  'banner scroll ribbon with folded ends',
];

enum VersePosterDateFormat { long, short, numeric, monthFirst }

const versePosterDatePlacements = [
  'small pill badge in the top-right corner',
  'small pill badge in the top-left corner',
  'thin line directly under the top name',
  'calendar-tear style block in the top-left',
  'small text in the footer beside the contact',
];

const versePosterTitleStyles = [
  "bold display type in the theme's accent colour, larger than the reference but smaller than the verse",
  'elegant script with a gold underline flourish',
  'uppercase letter-spaced label inside a thin outlined box',
  'brush-stroke painted band with white text',
  'two-tone: first word in gold, rest in white',
  '3D extruded letters with soft shadow',
];

/// Dropdown label → the size phrase the prompt carries.
const versePosterVerseSizes = {
  'Small': 'small — about 4% of the poster height, refined and quiet',
  'Medium': 'medium — about 6% of the poster height, comfortable reading',
  'Large': 'large — about 8% of the poster height, bold and commanding',
  'Extra Large':
      'extra large — about 11% of the poster height, the verse IS the design',
};

const versePosterVersePositions = [
  'centred in the upper-middle of the poster',
  'centred in the exact middle',
  'lower third, above the footer',
  'left-aligned on the left half, leaving the right half for the image',
  'right-aligned on the right half, leaving the left half for the image',
];

/// Dropdown label → the language/script phrase the prompt carries.
const versePosterLanguages = {
  'English': 'English',
  'Tamil (தமிழ்)': 'Tamil (Tamil script)',
  'Hindi (हिन्दी)': 'Hindi (Devanagari script)',
  'Malayalam (മലയാളം)': 'Malayalam (Malayalam script)',
  'Telugu (తెలుగు)': 'Telugu (Telugu script)',
  'Kannada (ಕನ್ನಡ)': 'Kannada (Kannada script)',
  'Marathi (मराठी)': 'Marathi (Devanagari script)',
  'Gujarati (ગુજરાતી)': 'Gujarati (Gujarati script)',
  'Bengali (বাংলা)': 'Bengali (Bengali script)',
  'Punjabi (ਪੰਜਾਬੀ)': 'Punjabi (Gurmukhi script)',
  'Odia (ଓଡ଼ିଆ)': 'Odia (Odia script)',
  'Assamese (অসমীয়া)': 'Assamese (Bengali-Assamese script)',
  'Urdu (اردو)': 'Urdu (Nastaliq script, right-to-left)',
  'Konkani': 'Konkani',
  'Nepali (नेपाली)': 'Nepali (Devanagari script)',
  'Mizo': 'Mizo (Latin script)',
  'Khasi': 'Khasi (Latin script)',
  'Naga': 'Naga languages (Latin script)',
  'Malay (Bahasa Melayu)': 'Malay / Bahasa Melayu (Latin script)',
  'Sinhala (සිංහල)': 'Sinhala (Sinhala script)',
  'Other': 'other language exactly as typed',
};

const versePosterEnglishLanguage = 'English';
const versePosterTamilLanguage = 'Tamil (தமிழ்)';

const versePosterTextStyles = [
  'pure white serif with a soft black drop shadow',
  'metallic gold serif with embossed highlights',
  'deep navy bold sans on a light panel',
  'crimson red bold serif with a thin white outline',
  'ivory cream classic serif, letterpress pressed into paper',
  'rose gold modern sans with a faint glow',
  'emerald green serif with gold inline details',
  'royal purple serif with silver outer stroke',
  'black bold condensed sans, high-contrast poster style',
  'sky blue to white vertical gradient text',
  'sunset gradient text (orange → pink → purple)',
  'gold to copper gradient text with shine',
  'neon glowing text (cyan or magenta) on dark',
  'chalk-white handwritten text, chalkboard feel',
  'elegant white calligraphy script with gold flourishes',
  '3D extruded gold letters with depth and shadow',
  'glass-effect transparent letters with white edges',
  'vintage distressed cream type, worn print texture',
  'wood-carved letters with natural grain',
  'stained-glass-coloured letters with black leading',
  'soft pastel lavender rounded sans, gentle feel',
  'bold yellow sans with black outline, high visibility',
  'silver chrome letters with reflections',
  'white type inside a semi-transparent dark rounded panel for maximum readability',
  'pearl white letters with a soft inner glow',
  'burnished bronze serif with a warm highlight',
  'deep maroon bold serif on a cream parchment panel',
  'golden yellow bold sans with a deep brown outline',
  'turquoise to white gradient text with a fresh feel',
  'fire-gradient text (yellow → orange → red) with a soft glow',
  'emerald to gold gradient serif with a metallic finish',
  'white thin modern sans, wide letter spacing, clean minimal look',
  'black elegant serif on a translucent white frosted panel',
  'embroidered / stitched thread letters on fabric',
  'sand-written letters on a beach texture',
  'ice-crystal letters with frosty edges',
  'paper-cut layered letters with soft shadows',
  'neon pink and blue double-glow letters',
  'marble-engraved letters on a stone slab',
  'handwritten pen-ink text in dark blue on light paper',
];

const versePosterReferenceStyles = [
  'gold small caps in a thin pill below the verse',
  'crimson bold italic, right-aligned under the verse',
  'white on a small maroon rounded label',
  'navy blue on a gold underline bar',
  'emerald green with a small leaf ornament',
  'silver italic serif, centred, with em-dashes on each side',
  'orange handwritten style, slightly tilted',
  'sky-blue thin uppercase, letter-spaced',
  'black bold inside a yellow highlight stripe',
  'rose-gold with two tiny crosses flanking it',
  'white bold text in a gold-bordered rounded rectangle',
  'gold italic serif with a thin line above and below',
  'crimson small caps inside a soft white pill',
  'turquoise bold uppercase with a tiny dove icon',
  'purple elegant script, centred under the verse',
  'black text on a gold ribbon with notched ends',
  'bright yellow bold text with a dark shadow',
  'white thin text with a small gold cross before it',
  'emerald-green label with white text and rounded corners',
  'copper-coloured serif inside a double-line frame',
];

const versePosterThemes = [
  'Golden Sunrise — warm gold, amber, soft peach',
  'Royal Blue & Gold — deep navy, cobalt, metallic gold',
  'Crimson & Ivory — rich red, maroon, cream',
  'Emerald & Gold — forest green, emerald, brass',
  'Purple Majesty — royal purple, violet, gold',
  'Ocean Teal — teal, aqua, white foam',
  'Sunset Blaze — orange, magenta, deep purple',
  'Pastel Heaven — baby blue, blush pink, mint, cream',
  'Midnight Stars — black-blue night, silver, tiny gold stars',
  'Olive & Linen — olive green, sand, warm white',
  'Rose Garden — rose pink, dusty rose, green leaves',
  'Monochrome Gold — black, charcoal, gold accents',
  'Fresh Spring — lime green, yellow, sky blue',
  'Autumn Harvest — rust, pumpkin, mustard, brown',
  'Icy Winter — ice blue, white, pale silver',
  'Desert Sand — terracotta, sand, dusty orange',
  'Lavender Dawn — lavender, lilac, soft gold',
  'Coral Reef — coral, turquoise, sand',
  'Tricolour Hope — saffron, white, green',
  'Classic Parchment — aged paper, sepia, dark brown ink',
  'Heavenly Clouds — white, sky blue, soft gold light',
  'Mountain Dawn — slate blue, lilac, peach horizon',
  'Forest Calm — deep green, moss, soft sunlight yellow',
  'Burgundy Wine — burgundy, rose gold, blush cream',
  'Sapphire Night — sapphire blue, indigo, silver stars',
  'Tropical Bloom — hot pink, orange, leaf green',
  'Honey Amber — honey gold, caramel, warm brown',
  'Mint Fresh — mint green, white, pale aqua',
  'Sunrise Pink — soft pink, apricot, light gold',
  'Charcoal & Red — charcoal black, crimson accent, white text',
  'Peacock — peacock blue, emerald, gold',
  'Violet Twilight — violet, deep blue, pink glow',
  'Wheat Field — wheat gold, sky blue, soft green',
  'Cherry Blossom — pale pink, white, soft brown branches',
  'Navy & Coral — navy blue, coral, cream',
  'Earth Tones — clay brown, olive, sand, cream',
  'Rainbow Promise — soft rainbow gradient over a calm sky',
  'Silver Moonlight — silver, pale blue, deep night sky',
  'Fire & Glory — deep red, orange, gold flames of light',
  'Pure White & Gold — clean white, champagne gold, subtle shadows',
];

const versePosterRenderStyles = [
  'Cinematic photoreal — film lighting, depth of field, volumetric rays',
  '3D rendered — Pixar-style soft 3D with realistic materials',
  '2D flat illustration — clean vector shapes, flat colours',
  'Watercolour painting — soft washes, paper texture',
  'Oil painting — classical brush strokes, rich texture',
  'Digital painting — concept-art style, painterly light',
  'Anime / manga illustration',
  'Paper-cut layered art — stacked paper layers with shadows',
  'Stained glass — bold black leading, luminous colour panes',
  'Minimal modern — lots of clean space, one accent colour',
  'Vintage poster — retro print, grain, halftone',
  'Chalkboard — chalk drawings and lettering on dark board',
  'Neon night — glowing lights on dark city or sky',
  'Low-poly geometric — faceted 3D shapes',
  'Line art — fine ink lines with light colour washes',
  'Collage / mixed media — torn paper, textures, photos',
  'Fantasy epic — dramatic, heavenly, glowing clouds',
  'Realistic photo — natural, like a real photograph',
  'Cinematic epic — anamorphic lens flares, dramatic sky, film colour grade',
  'Soft 3D clay / plasticine look',
  'Isometric 3D illustration',
  "Gouache / children's-book illustration",
  'Pencil and charcoal sketch with light colour',
  'Pixel art — retro game style',
  'Papercraft diorama — miniature layered scene',
  'Double-exposure photography — landscape blended into a silhouette',
  'Glassmorphism — frosted glass panels over a blurred colourful scene',
  'Gradient mesh abstract — flowing colour blends, no objects',
  'Pop-art / comic halftone style',
  'Realistic macro photography — shallow depth of field, close-up nature',
];

const versePosterRatios = [
  'Portrait 9:16 (1080 × 1920) — WhatsApp status, Reels, Stories',
  'Square 1:1 (1080 × 1080) — Instagram, Facebook post',
  'Portrait 4:5 (1080 × 1350) — Instagram feed',
  'Landscape 16:9 (1920 × 1080) — YouTube, TV screen',
  'A4 portrait — printing',
];

const versePosterMoods = [
  'peaceful and hopeful',
  'powerful and triumphant',
  'warm and comforting',
  'joyful and bright',
  'solemn and reverent',
  'fresh morning energy',
];

const versePosterFooterStyles = [
  'thin elegant strip with logo left, name centre, contact right',
  "full-width curved arch band in the theme's dark colour, gold text",
  'centred stack: logo above ministry name above contact',
  'minimal — small text only, no band',
  'rounded floating card with soft shadow',
  'dark translucent glass bar with white text and the logo on the left',
  'gold-bordered ribbon strip with the ministry name centred',
  'two-column layout: logo and name on the left, contact on the right',
  'stacked centred text with thin divider lines above and below',
  "curved wave-shaped band in the theme's accent colour",
  'solid dark band with gold text and small icons for phone / web / social',
  'floating pill-shaped bar with a soft shadow',
  'corner badge — logo in the bottom-left, contact in the bottom-right, no band',
  'ornamental vintage frame around the ministry name and contact',
  'gradient fade from the background into a dark footer area',
];

/// The scene the reference builder starts with — a sensible default the
/// person is expected to overwrite with their own idea.
const versePosterDefaultBackground =
    'Green pasture beside still waters at sunrise, a shepherd silhouette in '
    'the distance, soft golden light rays.';

/// The date as the prompt will spell it. Always English: it is part of the
/// instruction to the image model, not the app's UI.
String formatVersePosterDate(DateTime date, VersePosterDateFormat format) {
  switch (format) {
    case VersePosterDateFormat.long:
      return DateFormat('EEEE, d MMMM yyyy', 'en_US').format(date);
    case VersePosterDateFormat.short:
      return DateFormat('dd MMM yyyy', 'en_US').format(date);
    case VersePosterDateFormat.numeric:
      return DateFormat('dd-MM-yyyy', 'en_US').format(date);
    case VersePosterDateFormat.monthFirst:
      return '${DateFormat('MMM', 'en_US').format(date).toUpperCase()} '
          '${date.day} · ${DateFormat('EEEE', 'en_US').format(date)}';
  }
}

/// Every choice the prompt builder screen offers, as plain values so the
/// prompt can be built (and tested) without a widget tree.
class VersePosterPromptOptions {
  const VersePosterPromptOptions({
    required this.verseText,
    required this.reference,
    this.topName = '',
    this.topStyle = 0,
    this.useDate = false,
    this.dateText = '',
    this.datePlacement = 0,
    this.useTitle = false,
    this.title = '',
    this.titleStyle = 0,
    this.verseSize = 'Large',
    this.versePosition = 0,
    this.language = versePosterEnglishLanguage,
    this.textStyle = 0,
    this.referenceStyle = 0,
    this.background = versePosterDefaultBackground,
    this.theme = 0,
    this.renderStyle = 0,
    this.ratio = 0,
    this.mood = 0,
    this.useFooter = false,
    this.ministry = '',
    this.contact = '',
    this.useLogo = false,
    this.footerStyle = 0,
  });

  final String verseText;
  final String reference;
  final String topName;
  final int topStyle;
  final bool useDate;
  final String dateText;
  final int datePlacement;
  final bool useTitle;
  final String title;
  final int titleStyle;
  final String verseSize;
  final int versePosition;
  final String language;
  final int textStyle;
  final int referenceStyle;
  final String background;
  final int theme;
  final int renderStyle;
  final int ratio;
  final int mood;
  final bool useFooter;
  final String ministry;
  final String contact;
  final bool useLogo;
  final int footerStyle;
}

String buildVersePosterPrompt(VersePosterPromptOptions o) {
  const exactly = ', reading exactly: ';
  // Line breaks are kept (the prompt tells the model to honour them) but
  // stray indentation and blank lines from pasting are not.
  final verse = o.verseText
      .trim()
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .join('\n');
  final topName = o.topName.trim();
  final title = o.title.trim();
  final dateText = o.dateText.trim();
  final ministry = o.ministry.trim();
  final contact = o.contact.trim();
  final background = o.background.trim();

  final b = StringBuffer()
    ..writeln(
      'You are a world-class senior graphic designer. Create ONE finished '
      'daily Bible-verse poster.',
    )
    ..writeln()
    ..writeln('FORMAT')
    ..writeln(
      '• ${versePosterRatios[o.ratio]}. Full-bleed, print-quality, sharp and '
      'readable on a phone.',
    )
    ..writeln(
      '• Render style: ${versePosterRenderStyles[o.renderStyle]}. '
      'Mood: ${versePosterMoods[o.mood]}.',
    )
    ..writeln(
      '• No watermark, no extra text, no stickers, no border frame unless '
      'described below.',
    )
    ..writeln()
    ..writeln('BACKGROUND')
    ..writeln('• Colour theme: ${versePosterThemes[o.theme]}.');
  if (background.isNotEmpty) b.writeln('• Scene: $background');
  b.writeln(
    '• Keep the area behind the verse calm and uncluttered so the text is '
    'perfectly legible.',
  );

  final showDate = o.useDate && dateText.isNotEmpty;
  if (topName.isNotEmpty || showDate) {
    b
      ..writeln()
      ..writeln('TOP OF POSTER');
    if (topName.isNotEmpty) {
      b.writeln('• ${versePosterTopStyles[o.topStyle]}$exactly$topName');
    }
    if (showDate) {
      b.writeln(
        '• Date — ${versePosterDatePlacements[o.datePlacement]}$exactly'
        '$dateText',
      );
    }
  }

  if (o.useTitle && title.isNotEmpty) {
    b
      ..writeln()
      ..writeln('TITLE (directly above the verse)')
      ..writeln('• ${versePosterTitleStyles[o.titleStyle]}$exactly$title');
  }

  b
    ..writeln()
    ..writeln('THE VERSE (main element)')
    ..writeln(
      '• Language: ${versePosterLanguages[o.language] ?? o.language}. '
      'Font size: ${versePosterVerseSizes[o.verseSize] ?? o.verseSize}.',
    )
    ..writeln('• Position: ${versePosterVersePositions[o.versePosition]}.')
    ..writeln('• Text style: ${versePosterTextStyles[o.textStyle]}.')
    ..writeln('• Verse text, line breaks EXACTLY as written:')
    ..writeln(verse)
    ..writeln(
      '• Reference in a DIFFERENT colour from the verse — '
      '${versePosterReferenceStyles[o.referenceStyle]}$exactly'
      '${o.reference.trim()}',
    );

  if (o.useFooter) {
    b
      ..writeln()
      ..writeln('FOOTER (bottom of poster)')
      ..writeln('• ${versePosterFooterStyles[o.footerStyle]}.');
    if (ministry.isNotEmpty) b.writeln('• Ministry name exactly: $ministry');
    if (contact.isNotEmpty) b.writeln('• Contact exactly: $contact');
    if (o.useLogo) {
      b.writeln(
        '• I have attached my logo: place it in the footer at its original '
        'colours and proportions, unchanged, not redrawn.',
      );
    }
  }

  b
    ..writeln()
    ..writeln('EXACT TEXT — CRITICAL')
    ..writeln(
      'Every word above must be rendered letter-for-letter exactly as given, '
      'in the given language and script — same spelling, vowel signs, '
      'punctuation and line breaks. Do NOT translate, transliterate, shorten, '
      '"correct", repeat or add any word. Verify each line before finishing; '
      'if a character cannot be drawn perfectly, redraw that line rather than '
      'approximate it.',
    )
    ..writeln()
    ..writeln('DESIGN QUALITY')
    ..write(
      'Clear hierarchy (verse > reference > top name > footer), balanced '
      'grid, consistent theme colours, text never over faces, no cropped '
      'glyphs. Professional, premium, world-class finish.',
    );
  return b.toString();
}
