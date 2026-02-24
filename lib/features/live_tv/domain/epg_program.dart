/// Model representing a single EPG program entry.
class EpgProgram {
  final String name;
  final DateTime startTime;
  final DateTime endTime;
  final String? subtitle;
  final String? description;
  final String? imageUrl;

  const EpgProgram({
    required this.name,
    required this.startTime,
    required this.endTime,
    this.subtitle,
    this.description,
    this.imageUrl,
  });

  /// Progress ratio (0.0 to 1.0) of the current program.
  double get progress {
    final now = DateTime.now();
    if (now.isBefore(startTime)) return 0.0;
    if (now.isAfter(endTime)) return 1.0;
    final total = endTime.difference(startTime).inSeconds;
    if (total <= 0) return 0.0;
    final elapsed = now.difference(startTime).inSeconds;
    return elapsed / total;
  }

  /// Whether this program is currently airing.
  bool get isLive {
    final now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  /// Formatted time range, e.g. "20:00 — 20:35".
  String get timeRange {
    final start = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    final end = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    return '$start — $end';
  }

  factory EpgProgram.fromJson(Map<String, dynamic> json) {
    final startTimeData = json['startTime'] as Map<String, dynamic>;
    final endTimeData = json['endTime'] as Map<String, dynamic>;

    return EpgProgram(
      name: json['name'] as String,
      startTime: DateTime.fromMillisecondsSinceEpoch(
        (startTimeData['unix'] as num).toInt(),
      ),
      endTime: DateTime.fromMillisecondsSinceEpoch(
        (endTimeData['unix'] as num).toInt(),
      ),
      subtitle: json['subtitle'] as String?,
      description: json['description'] as String?,
      imageUrl: json['image'] as String?,
    );
  }
}
