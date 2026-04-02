class FocusPreset {
  final String id;
  final String title;
  final String description;
  final int suggestedMinutes;
  final String suggestedSoundLabel;
  final String tip;

  const FocusPreset({
    required this.id,
    required this.title,
    required this.description,
    required this.suggestedMinutes,
    required this.suggestedSoundLabel,
    required this.tip,
  });
}

class FocusSoundOption {
  final String label;
  final String assetPath;

  const FocusSoundOption({
    required this.label,
    required this.assetPath,
  });
}

class FocusLibrary {
  static const List<FocusPreset> presets = [
    FocusPreset(
      id: 'deep_learning',
      title: 'Deep Learning',
      description: 'Low-distraction mode for complex work and deep concentration.',
      suggestedMinutes: 50,
      suggestedSoundLabel: 'White Noise',
      tip: 'Stay on one task only. Keep tabs and notifications closed.',
    ),
    FocusPreset(
      id: 'light_focus',
      title: 'Light Focus',
      description: 'Short focused block for quick progress and momentum.',
      suggestedMinutes: 25,
      suggestedSoundLabel: 'Rain',
      tip: 'Pick one clear objective and finish that before switching.',
    ),
    FocusPreset(
      id: 'creative_work',
      title: 'Creative Work',
      description: 'Flow-oriented mode for writing, design, and ideation.',
      suggestedMinutes: 45,
      suggestedSoundLabel: 'Soft Instrumental Loop',
      tip: 'Allow imperfect first drafts. Refine after the timer ends.',
    ),
  ];

  static const List<FocusSoundOption> sounds = [
    FocusSoundOption(
      label: 'White Noise',
      assetPath: 'audio/white_noise.mp3',
    ),
    FocusSoundOption(
      label: 'Rain',
      assetPath: 'audio/rain.mp3',
    ),
    FocusSoundOption(
      label: 'Ambient Focus',
      assetPath: 'audio/ambient_focus.mp3',
    ),
    FocusSoundOption(
      label: 'Soft Instrumental Loop',
      assetPath: 'audio/soft_instrumental.mp3',
    ),
  ];

  static FocusSoundOption soundByLabel(String label) {
    return sounds.firstWhere(
      (sound) => sound.label == label,
      orElse: () => sounds.first,
    );
  }
}
