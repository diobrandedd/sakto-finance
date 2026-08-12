import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../platform/file_support.dart';
import '../theme/app_theme.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError('SharedPreferences must be overridden in main().');
});

final appearanceProvider =
    StateNotifierProvider<AppearanceController, Appearance>(
      (ref) => AppearanceController(ref.watch(sharedPreferencesProvider)),
    );

class ThemePreset {
  const ThemePreset({
    required this.id,
    required this.name,
    required this.colors,
  });

  final String id;
  final String name;
  final SaktoColors colors;
}

const themePresets = [
  ThemePreset(id: 'sakto', name: 'Sakto', colors: SaktoColors.light),
  ThemePreset(
    id: 'night',
    name: 'Night',
    colors: SaktoColors(
      background: Color(0xFF121418),
      surface: Color(0xFF1C1F26),
      text: Color(0xFFF4F4F5),
      muted: Color(0xFFA1A1AA),
      border: Color(0xFF2A2E38),
      accent: Color(0xFF2DD4BF),
      accentLight: Color(0xFF134E4A),
    ),
  ),
  ThemePreset(
    id: 'ocean',
    name: 'Ocean',
    colors: SaktoColors(
      background: Color(0xFFEFF6FF),
      surface: Color(0xFFFFFFFF),
      text: Color(0xFF0F172A),
      muted: Color(0xFF64748B),
      border: Color(0xFFDBEAFE),
      accent: Color(0xFF2563EB),
      accentLight: Color(0xFFDBEAFE),
    ),
  ),
  ThemePreset(
    id: 'forest',
    name: 'Forest',
    colors: SaktoColors(
      background: Color(0xFFF1F8F4),
      surface: Color(0xFFFFFFFF),
      text: Color(0xFF14532D),
      muted: Color(0xFF6B7280),
      border: Color(0xFFD1FAE5),
      accent: Color(0xFF15803D),
      accentLight: Color(0xFFDCFCE7),
    ),
  ),
  ThemePreset(
    id: 'sunset',
    name: 'Sunset',
    colors: SaktoColors(
      background: Color(0xFFFFF7ED),
      surface: Color(0xFFFFFFFF),
      text: Color(0xFF431407),
      muted: Color(0xFF9A3412),
      border: Color(0xFFFED7AA),
      accent: Color(0xFFEA580C),
      accentLight: Color(0xFFFFEDD5),
    ),
  ),
  ThemePreset(
    id: 'lavender',
    name: 'Lavender',
    colors: SaktoColors(
      background: Color(0xFFF5F3FF),
      surface: Color(0xFFFFFFFF),
      text: Color(0xFF1E1B4B),
      muted: Color(0xFF6B7280),
      border: Color(0xFFEDE9FE),
      accent: Color(0xFF7C3AED),
      accentLight: Color(0xFFEDE9FE),
    ),
  ),
];

class Appearance {
  const Appearance({
    this.presetId = 'sakto',
    this.backgroundHex,
    this.surfaceHex,
    this.accentHex,
    this.textHex,
    this.imagePath,
    this.imageDim = 0.40,
  });

  final String presetId;
  final String? backgroundHex;
  final String? surfaceHex;
  final String? accentHex;
  final String? textHex;
  final String? imagePath;
  final double imageDim;

  ThemePreset get preset => themePresets.firstWhere(
    (preset) => preset.id == presetId,
    orElse: () => themePresets.first,
  );

  bool get hasImage => localFileExists(imagePath);

  SaktoColors get colors {
    final base = preset.colors;
    return base.copyWith(
      background: backgroundHex == null ? null : hexColor(backgroundHex!),
      surface: surfaceHex == null ? null : hexColor(surfaceHex!),
      accent: accentHex == null ? null : hexColor(accentHex!),
      accentLight: accentHex == null
          ? null
          : hexColor(accentHex!).withValues(alpha: 0.18),
      text: textHex == null ? null : hexColor(textHex!),
    );
  }

  Appearance copyWith({
    String? presetId,
    String? backgroundHex,
    String? surfaceHex,
    String? accentHex,
    String? textHex,
    String? imagePath,
    double? imageDim,
    bool clearBackground = false,
    bool clearSurface = false,
    bool clearAccent = false,
    bool clearText = false,
    bool clearImage = false,
  }) => Appearance(
    presetId: presetId ?? this.presetId,
    backgroundHex: clearBackground ? null : backgroundHex ?? this.backgroundHex,
    surfaceHex: clearSurface ? null : surfaceHex ?? this.surfaceHex,
    accentHex: clearAccent ? null : accentHex ?? this.accentHex,
    textHex: clearText ? null : textHex ?? this.textHex,
    imagePath: clearImage ? null : imagePath ?? this.imagePath,
    imageDim: imageDim ?? this.imageDim,
  );
}

class AppearanceController extends StateNotifier<Appearance> {
  AppearanceController(this._prefs) : super(_read(_prefs));

  final SharedPreferences _prefs;
  static const _prefix = 'appearance.';

  static Appearance _read(SharedPreferences prefs) => Appearance(
    presetId: prefs.getString('${_prefix}preset') ?? 'sakto',
    backgroundHex: prefs.getString('${_prefix}background'),
    surfaceHex: prefs.getString('${_prefix}surface'),
    accentHex: prefs.getString('${_prefix}accent'),
    textHex: prefs.getString('${_prefix}text'),
    imagePath: prefs.getString('${_prefix}image'),
    imageDim: prefs.getDouble('${_prefix}dim') ?? 0.40,
  );

  Future<void> _save() async {
    await _prefs.setString('${_prefix}preset', state.presetId);
    await _setOrRemove('${_prefix}background', state.backgroundHex);
    await _setOrRemove('${_prefix}surface', state.surfaceHex);
    await _setOrRemove('${_prefix}accent', state.accentHex);
    await _setOrRemove('${_prefix}text', state.textHex);
    await _setOrRemove('${_prefix}image', state.imagePath);
    await _prefs.setDouble('${_prefix}dim', state.imageDim);
  }

  Future<void> _setOrRemove(String key, String? value) async {
    if (value == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, value);
    }
  }

  Future<void> setPreset(String id) async {
    state = Appearance(
      presetId: id,
      imagePath: state.imagePath,
      imageDim: state.imageDim,
    );
    await _save();
  }

  Future<void> setColor({
    String? backgroundHex,
    String? surfaceHex,
    String? accentHex,
    String? textHex,
  }) async {
    state = state.copyWith(
      backgroundHex: backgroundHex,
      surfaceHex: surfaceHex,
      accentHex: accentHex,
      textHex: textHex,
    );
    await _save();
  }

  Future<void> setImageDim(double value) async {
    state = state.copyWith(imageDim: value.clamp(0, 0.8));
    await _save();
  }

  Future<void> pickBackgroundImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (picked == null) return;
    final path = await copyPickedImageToDocuments(picked.path);
    state = state.copyWith(imagePath: path);
    await _save();
  }

  Future<void> clearBackgroundImage() async {
    await deleteLocalFile(state.imagePath);
    state = state.copyWith(clearImage: true);
    await _save();
  }
}
