/// The D2 Armory brand marks as inline SVG source.
///
/// These mirror the files in `assets/branding/` (still declared in pubspec and
/// kept as the design source of truth). They are embedded as string constants
/// and rendered with `SvgPicture.string` rather than `SvgPicture.asset` so no
/// runtime asset-bundle read happens: flutter_svg's background-isolate bundle
/// read intermittently threw "Unable to load asset … empty data" during the
/// app's heavy startup (manifest download + facet-warm isolate + profile
/// fetch). Parsing from memory removes that race entirely. If the brand marks
/// change, update both the asset files and these constants together.
library;

/// The hexagonal compass icon (assets/branding/logo-icon-transparent.svg).
const String kArmoryIconSvg = '''
<svg width="180" height="180" viewBox="0 0 180 180" xmlns="http://www.w3.org/2000/svg" role="img">
<title>D2 Armory icon</title>
<defs>
<linearGradient id="steel" x1="0%" y1="0%" x2="100%" y2="100%">
<stop offset="0%" stop-color="#3a4552"/>
<stop offset="100%" stop-color="#1c232b"/>
</linearGradient>
</defs>
<g transform="translate(90,90)">
<polygon points="0,-85 74,-42 74,42 0,85 -74,42 -74,-42" fill="url(#steel)" stroke="#c98a3c" stroke-width="2.5"/>
<polygon points="0,-65 57,-32 57,32 0,65 -57,32 -57,-32" fill="none" stroke="#5a6672" stroke-width="1"/>
<circle cx="0" cy="0" r="30" fill="#12161b" stroke="#c98a3c" stroke-width="2.5"/>
<circle cx="0" cy="0" r="8" fill="#c98a3c"/>
<line x1="0" y1="-30" x2="0" y2="-16" stroke="#c98a3c" stroke-width="4"/>
<line x1="0" y1="30" x2="0" y2="16" stroke="#c98a3c" stroke-width="4"/>
<line x1="-30" y1="0" x2="-16" y2="0" stroke="#c98a3c" stroke-width="4"/>
<line x1="30" y1="0" x2="16" y2="0" stroke="#c98a3c" stroke-width="4"/>
<line x1="21" y1="-21" x2="12" y2="-12" stroke="#c98a3c" stroke-width="3"/>
<line x1="-21" y1="-21" x2="-12" y2="-12" stroke="#c98a3c" stroke-width="3"/>
<line x1="21" y1="21" x2="12" y2="12" stroke="#c98a3c" stroke-width="3"/>
<line x1="-21" y1="21" x2="-12" y2="12" stroke="#c98a3c" stroke-width="3"/>
</g>
</svg>
''';

/// The "D2 ARMORY" wordmark lockup
/// (assets/branding/logo-wordmark-transparent.svg).
const String kArmoryWordmarkSvg = '''
<svg width="460" height="110" viewBox="0 0 460 110" xmlns="http://www.w3.org/2000/svg" role="img">
<title>D2 Armory wordmark</title>
<text x="20" y="60" font-family="Arial, sans-serif" font-size="52" font-weight="700" letter-spacing="2" fill="#c98a3c">D2</text>
<text x="95" y="60" font-family="Arial, sans-serif" font-size="52" font-weight="700" letter-spacing="4" fill="#eceff2">ARMORY</text>
<text x="22" y="95" font-family="Arial, sans-serif" font-size="16" font-weight="400" letter-spacing="5" fill="#8a95a1">DESTINY 2 LOADOUT MANAGER</text>
</svg>
''';
