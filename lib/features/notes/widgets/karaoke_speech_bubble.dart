import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/models/karaoke_model.dart';

/// Comic-style speech bubble pointing left towards the speaking character.
/// Contains the audio speaker replay button and the word-by-word highlighted text.
class KaraokeSpeechBubble extends StatelessWidget {
  final KaraokeSentence sentence;
  final double currentSeconds;
  final bool isAudioPlaying;
  final VoidCallback onPlayAudio;

  const KaraokeSpeechBubble({
    super.key,
    required this.sentence,
    required this.currentSeconds,
    required this.isAudioPlaying,
    required this.onPlayAudio,
  });

  @override
  Widget build(BuildContext context) {
    final words = sentence.words.isNotEmpty
        ? sentence.words
        : sentence.text
            .split(' ')
            .map((w) => KaraokeWord(word: w, clean: w, start: sentence.start, end: sentence.end))
            .toList();

    return CustomPaint(
      painter: _SpeechBubbleTailPainter(),
      child: Container(
        margin: const EdgeInsets.only(left: 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Speaker icon button (tappable to replay sentence audio)
            GestureDetector(
              onTap: onPlayAudio,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF1CB0F6).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.volume_up_rounded,
                    color: Color(0xFF1CB0F6),
                    size: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Target German sentence with word-level highlight
            Flexible(
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: words.map((w) {
                  final isWordActive = isAudioPlaying &&
                      currentSeconds >= w.start &&
                      currentSeconds <= w.end;

                  return GestureDetector(
                    onTap: onPlayAudio,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: isWordActive
                          ? BoxDecoration(
                              color: const Color(0xFF1CB0F6).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(6),
                            )
                          : null,
                      child: Text(
                        w.word,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isWordActive
                              ? const Color(0xFF0284C7)
                              : const Color(0xFF1CB0F6),
                          decoration: isWordActive ? TextDecoration.underline : null,
                          decorationStyle: TextDecorationStyle.dotted,
                          decorationColor: const Color(0xFF1CB0F6),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeechBubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()..color = Colors.white;
    final strokePaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Small triangular speech tail pointing to character on the left
    final tailPath = Path()
      ..moveTo(14, size.height * 0.45)
      ..lineTo(0, size.height * 0.5)
      ..lineTo(14, size.height * 0.55);

    canvas.drawPath(tailPath, fillPaint);
    canvas.drawPath(tailPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
