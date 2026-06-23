/// "Edit DNA" — the editing fingerprint of a video. In v1 it is filled by cheap
/// heuristics from scenes/silences/transcript and shown as insight. In v2 it is
/// extracted from a *reference* viral video and used to re-cut the user's own
/// footage (sequence of exportVideo() segments + concat). The `extra` map and
/// `version` field let v2 add data without breaking v1's serialization.
class PacingStat {
  const PacingStat({
    required this.avgClipLenSec,
    required this.medianClipLenSec,
    required this.cutsPerMinute,
    required this.stdClipLenSec,
  });
  final double avgClipLenSec;
  final double medianClipLenSec;
  final double cutsPerMinute;
  final double stdClipLenSec;

  Map<String, dynamic> toJson() => {
        'avgClipLenSec': avgClipLenSec,
        'medianClipLenSec': medianClipLenSec,
        'cutsPerMinute': cutsPerMinute,
        'stdClipLenSec': stdClipLenSec,
      };
  factory PacingStat.fromJson(Map<String, dynamic> j) => PacingStat(
        avgClipLenSec: (j['avgClipLenSec'] as num).toDouble(),
        medianClipLenSec: (j['medianClipLenSec'] as num).toDouble(),
        cutsPerMinute: (j['cutsPerMinute'] as num).toDouble(),
        stdClipLenSec: (j['stdClipLenSec'] as num).toDouble(),
      );
}

class CaptionStyleStat {
  const CaptionStyleStat({
    required this.avgDurationSec,
    required this.cps,
    required this.wordsPerCaptionMedian,
  });
  final double avgDurationSec;
  final double cps; // characters per second of speech
  final int wordsPerCaptionMedian;

  Map<String, dynamic> toJson() => {
        'avgDurationSec': avgDurationSec,
        'cps': cps,
        'wordsPerCaptionMedian': wordsPerCaptionMedian,
      };
  factory CaptionStyleStat.fromJson(Map<String, dynamic> j) => CaptionStyleStat(
        avgDurationSec: (j['avgDurationSec'] as num).toDouble(),
        cps: (j['cps'] as num).toDouble(),
        wordsPerCaptionMedian: j['wordsPerCaptionMedian'] as int,
      );
}

class EditRecipe {
  const EditRecipe({
    this.version = 1,
    required this.pacing,
    required this.captionStyle,
    this.hookWindowSec = 3.0,
    this.cutTimestamps = const [],
    this.extra = const {},
  });

  final int version;
  final PacingStat pacing;
  final CaptionStyleStat captionStyle;
  final double hookWindowSec;
  final List<double> cutTimestamps; // normalized 0..1 positions — rhythm fingerprint
  final Map<String, dynamic> extra; // forward slot for v2

  Map<String, dynamic> toJson() => {
        'version': version,
        'pacing': pacing.toJson(),
        'captionStyle': captionStyle.toJson(),
        'hookWindowSec': hookWindowSec,
        'cutTimestamps': cutTimestamps,
        'extra': extra,
      };

  factory EditRecipe.fromJson(Map<String, dynamic> j) => EditRecipe(
        version: (j['version'] ?? 1) as int,
        pacing: PacingStat.fromJson(j['pacing'] as Map<String, dynamic>),
        captionStyle: CaptionStyleStat.fromJson(j['captionStyle'] as Map<String, dynamic>),
        hookWindowSec: ((j['hookWindowSec'] ?? 3.0) as num).toDouble(),
        cutTimestamps:
            ((j['cutTimestamps'] as List?) ?? []).map((e) => (e as num).toDouble()).toList(),
        extra: (j['extra'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}
