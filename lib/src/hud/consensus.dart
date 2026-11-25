import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../motion/loops.dart';
import '../painting/decoration.dart';
import '../painting/patterns.dart';
import '../painting/shapes.dart';
import '../widgets/frame.dart';
import '../widgets/text.dart';

/// One channel's judgement in a [KkConsensus], and also the poll's result
/// (which is never [fault]).
enum KkVote {
  /// In favour. Nominal green.
  go,

  /// Against. Alert red.
  nogo,

  /// Still deciding. Caution yellow, blinking.
  wait,

  /// The channel is not answering. Offline grey, hatched.
  fault,
}

/// One voting channel of a [KkConsensus].
@immutable
class KkVoter {
  const KkVoter({required this.id, required this.name, this.vote = KkVote.wait, this.note});

  /// The channel identifier, such as `CH.01`.
  final String id;
  final String name;
  final KkVote vote;

  /// One line of reasoning in dim mono.
  final String? note;

  @override
  bool operator ==(Object other) =>
      other is KkVoter && other.id == id && other.name == name && other.vote == vote && other.note == note;

  @override
  int get hashCode => Object.hash(id, name, vote, note);
}

/// The words a [KkConsensus] uses for votes and results.
@immutable
class KkConsensusLabels {
  const KkConsensusLabels({
    this.goCjk = '承認',
    this.goEn = 'GO',
    this.nogoCjk = '否認',
    this.nogoEn = 'NO-GO',
    this.waitCjk = '審議',
    this.waitEn = 'WAIT',
    this.faultCjk = '断線',
    this.faultEn = 'FAULT',
    this.passedCjk = '可決',
    this.passedEn = 'GO',
    this.rejectedCjk = '否決',
    this.rejectedEn = 'NO-GO',
    this.pendingCjk = '審議中',
    this.pendingEn = 'WAIT',
  });

  final String goCjk;
  final String goEn;
  final String nogoCjk;
  final String nogoEn;
  final String waitCjk;
  final String waitEn;
  final String faultCjk;
  final String faultEn;

  /// Result words when the poll passes.
  final String passedCjk;
  final String passedEn;

  /// Result words when the poll can no longer pass.
  final String rejectedCjk;
  final String rejectedEn;

  /// Result words while the poll is open.
  final String pendingCjk;
  final String pendingEn;
}

/// A k-of-n poll: several channels judge the same question and all of their
/// verdicts are shown side by side, with the result underneath.
///
/// The result is worked out from the votes and the [quorum] (a simple
/// majority unless given): it is go as soon as enough channels say go, no-go
/// as soon as too few can still say go, and waiting in between. Faulted
/// channels never count as go.
class KkConsensus extends StatelessWidget {
  const KkConsensus({
    super.key,
    this.cjk,
    this.en,
    this.meta,
    required this.voters,
    this.quorum,
    this.result,
    this.rule,
    this.tally,
    this.labels = const KkConsensusLabels(),
    this.boot = true,
  });

  final String? cjk;
  final String? en;

  /// Short mono text at the right of the head.
  final String? meta;
  final List<KkVoter> voters;

  /// How many go votes pass the poll. Defaults to a simple majority.
  final int? quorum;

  /// Overrides the computed result.
  final KkVote? result;

  /// The rule text in the result band. Defaults to `2-OF-3`.
  final String? rule;

  /// The tally at the right of the result band. Defaults to `GO 02 / 03`.
  final String? tally;
  final KkConsensusLabels labels;

  /// Wipe in when first shown.
  final bool boot;

  /// The number of go votes needed for [count] voters: [quorum] when given
  /// (kept between 1 and [count]), else a simple majority.
  static int quorumFor(int count, {int? quorum}) {
    if (count <= 0) return 1;
    return (quorum ?? count ~/ 2 + 1).clamp(1, count);
  }

  /// The result of a poll: [KkVote.go] once [quorum] channels say go,
  /// [KkVote.nogo] once the go and waiting votes together cannot reach it,
  /// [KkVote.wait] otherwise.
  static KkVote resultOf(Iterable<KkVote> votes, {int? quorum}) {
    int count = 0;
    int go = 0;
    int open = 0;
    for (final KkVote v in votes) {
      count++;
      if (v == KkVote.go) go++;
      if (v == KkVote.wait) open++;
    }
    if (count == 0) return KkVote.wait;
    final int need = quorumFor(count, quorum: quorum);
    if (go >= need) return KkVote.go;
    if (go + open < need) return KkVote.nogo;
    return KkVote.wait;
  }

  static String _two(int v) => v < 10 ? '0$v' : '$v';

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final Iterable<KkVote> votes = voters.map((KkVoter v) => v.vote);
    final KkVote outcome = result ?? resultOf(votes, quorum: quorum);
    final int need = quorumFor(voters.length, quorum: quorum);
    final int go = votes.where((KkVote v) => v == KkVote.go).length;
    final String ruleText = rule ?? '$need-OF-${voters.length}';
    final String tallyText = tally ?? '${labels.goEn} ${_two(go)} / ${_two(voters.length)}';

    final (String, String) words = switch (outcome) {
      KkVote.go => (labels.passedCjk, labels.passedEn),
      KkVote.nogo || KkVote.fault => (labels.rejectedCjk, labels.rejectedEn),
      KkVote.wait => (labels.pendingCjk, labels.pendingEn),
    };
    final Color bandFill = switch (outcome) {
      KkVote.go => c.nominal,
      KkVote.nogo || KkVote.fault => c.alert,
      KkVote.wait => c.bg300,
    };
    final Color bandInk = outcome == KkVote.wait ? c.ink : c.onFill;

    return Semantics(
      container: true,
      label: <String>[?cjk, ?en].join(' '),
      value: '${words.$2}, $ruleText, $tallyText',
      child: KkWidgetFrame(
        cjk: cjk,
        en: en,
        meta: meta,
        boot: boot,
        child: KkColumn(
          shrinkWrap: true,
          children: <Widget>[
            if (voters.isNotEmpty)
              KkBox(
                padding: EdgeInsets.fromLTRB(m.space3, m.space3, m.space3, 0),
                child: KkRow(
                  gap: 3,
                  cross: KkCrossAlign.stretch,
                  children: <Widget>[
                    for (final KkVoter voter in voters) KkExpanded(child: _VoterColumn(voter: voter, labels: labels)),
                  ],
                ),
              ),
            KkBox(
              padding: EdgeInsets.all(m.space3),
              child: KkBlink(
                enabled: outcome == KkVote.wait,
                child: KkBox(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  fill: bandFill,
                  clip: true,
                  child: KkRow(
                    gap: m.space3,
                    children: <Widget>[
                      KkText.cjk(words.$1, size: 30, color: bandInk, squeeze: 0.8),
                      KkText.en(words.$2, size: 13, height: 1.55, color: bandInk),
                      KkText.num(ruleText, size: 11, weight: FontWeight.w600, color: kkFade(bandInk, 0.85)),
                      const KkSpacer(),
                      KkText.num(tallyText, size: 12, weight: FontWeight.w600, color: bandInk),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoterColumn extends StatelessWidget {
  const _VoterColumn({required this.voter, required this.labels});

  final KkVoter voter;
  final KkConsensusLabels labels;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final KkVote vote = voter.vote;
    final Color vc = switch (vote) {
      KkVote.go => c.nominal,
      KkVote.nogo => c.alert,
      KkVote.wait => c.caution,
      KkVote.fault => c.offline,
    };
    final (String, String) words = switch (vote) {
      KkVote.go => (labels.goCjk, labels.goEn),
      KkVote.nogo => (labels.nogoCjk, labels.nogoEn),
      KkVote.wait => (labels.waitCjk, labels.waitEn),
      KkVote.fault => (labels.faultCjk, labels.faultEn),
    };
    final String? note = voter.note;
    return Semantics(
      container: true,
      label: '${voter.id} ${voter.name}',
      value: <String>[words.$2, ?note].join(', '),
      child: ExcludeSemantics(
        child: KkBox(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          decoration: KkDecoration(
            fill: c.bg200,
            pattern: vote == KkVote.fault ? KkPattern.stripes(a: c.bg200, b: c.bg100, width: 4, period: 8) : null,
            edges: KkEdges(top: KkSide(vc, width: m.stroke4)),
          ),
          child: KkColumn(
            gap: 5,
            shrinkWrap: true,
            children: <Widget>[
              KkText.num(voter.id, size: 10, weight: FontWeight.w600, spacing: 0.06, color: c.inkDim),
              KkText.en(voter.name, size: 13, color: c.ink, overflow: TextOverflow.ellipsis),
              KkBox(
                padding: EdgeInsets.only(top: m.space1),
                clip: true,
                child: KkBlink(
                  enabled: vote == KkVote.wait,
                  child: KkRow(
                    gap: 6,
                    cross: KkCrossAlign.baseline,
                    clip: Clip.hardEdge,
                    children: <Widget>[
                      KkText.cjk(words.$1, size: 28, color: vc, squeeze: 0.8),
                      KkText.en(words.$2, size: 11, height: 1.55, color: vc),
                    ],
                  ),
                ),
              ),
              if (note != null)
                KkText.num(note, size: 10, height: 1.3, color: c.inkDim, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
