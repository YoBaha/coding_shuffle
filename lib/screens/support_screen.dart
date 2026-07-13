import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class SupportScreen extends StatefulWidget {
  final VoidCallback? onAdWatched;
  const SupportScreen({super.key, this.onAdWatched});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  // ── AdMob ──────────────────────────────────────────────────────────────────
  // Replace with your real unit ID (use test ID during development):
  static const _adUnitId = 'ca-app-pub-3395053381611102/6370647393'; // test
  RewardedAd? _rewardedAd;

  bool _adLoading = false;
  bool _adWatched = false;
  int _totalWatched = 0; // session count — persist with SharedPreferences if needed

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  // ── Load a rewarded ad ─────────────────────────────────────────────────────
Future<void> _loadAd() async {
  RewardedAd.load(
    adUnitId: _adUnitId,
    request: const AdRequest(),
    rewardedAdLoadCallback: RewardedAdLoadCallback(
      onAdLoaded: (ad) {
        _rewardedAd = ad;
        if (mounted) setState(() => _adLoading = false);
      },
      onAdFailedToLoad: (err) {
        debugPrint('RewardedAd failed: $err');
        if (mounted) setState(() => _adLoading = false);
      },
    ),
  );
}

  // ── Show the ad ────────────────────────────────────────────────────────────
Future<void> _showAd() async {
  if (_adLoading || _rewardedAd == null) return;

  _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
    onAdDismissedFullScreenContent: (ad) {
      ad.dispose();
      _rewardedAd = null;
      _loadAd();
    },
    onAdFailedToShowFullScreenContent: (ad, err) {
      ad.dispose();
      _rewardedAd = null;
      _loadAd();
    },
  );

  await _rewardedAd!.show(
    onUserEarnedReward: (ad, reward) {
      if (mounted) setState(() { _adWatched = true; _totalWatched++; });
      _showThankYouSnack();
      widget.onAdWatched?.call();
    },
  );
}

  void _showThankYouSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1A1530),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            ShaderMask(
              shaderCallback: (r) => kGoldGradient.createShader(r),
              child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'Thank you for your support! 💙',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
              const Text(
                'Support',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 24),

              // ── Hero card ───────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E1838), Color(0xFF2A1F4A)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kPurpleMid.withOpacity(.3)),
                ),
                child: Column(
                  children: [
                    // Crown icon with gold glow
                    SizedBox(
  width: 100,
  height: 100,
  child: Image.asset(
    'assets/images/support_icon.png',
    fit: BoxFit.contain,
  ),
),
                    const SizedBox(height: 16),
                    const Text(
                      'Support the project',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Coding Shuffle Duel is free and always will be. '
                      'If you enjoy the app, you can support its development '
                      'by watching a short ad — completely optional.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white60,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Support box ─────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: kBgDark.withOpacity(.6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kPurpleMid.withOpacity(.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShaderMask(
                            shaderCallback: (r) =>
                                const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)])
                                    .createShader(r),
                            child: const Icon(Icons.favorite_rounded,
                                color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'You can freely support the development by watching '
                              'an ad from time to time. The app stays fully usable '
                              'without it.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Watch ad button ─────────────────────────────────────────
              GestureDetector(
                onTap: _adLoading ? null : _showAd,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: _adLoading
                        ? const LinearGradient(
                            colors: [Color(0xFF2A2040), Color(0xFF2A2040)])
                        : kButtonGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _adLoading
                        ? []
                        : [
                            BoxShadow(
                              color: kPurpleMid.withOpacity(.45),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                  ),
                  alignment: Alignment.center,
                  child: _adLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white54),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.play_circle_fill_rounded,
                                color: Colors.white, size: 22),
                            SizedBox(width: 10),
                            Text(
                              'WATCH AN AD TO SUPPORT',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                letterSpacing: 1.2,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              // ── Session counter (shows after first watch) ───────────────
              if (_totalWatched > 0) ...[
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: kPurpleMid.withOpacity(.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kPurpleMid.withOpacity(.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShaderMask(
                          shaderCallback: (r) => kGoldGradient.createShader(r),
                          child: const Icon(Icons.favorite_rounded,
                              color: Colors.white, size: 14),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'You\'ve supported $_totalWatched time${_totalWatched > 1 ? 's' : ''} this session',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // ── "How it helps" section ──────────────────────────────────
              const Text(
                'HOW IT HELPS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white38,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              ..._benefits.map((b) => _BenefitRow(icon: b.$1, text: b.$2)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Static benefit rows ─────────────────────────────────────────────────────
const _benefits = [
  (Icons.cloud_sync_rounded, 'Keeps our servers running'),
  (Icons.add_chart_rounded, 'Funds new SQL puzzle packs'),
  (Icons.bug_report_rounded, 'Supports ongoing bug fixes & updates'),
  (Icons.devices_rounded, 'Helps keep the app free for everyone'),
];

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _BenefitRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kPurpleMid.withOpacity(.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: kPurpleLight, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}