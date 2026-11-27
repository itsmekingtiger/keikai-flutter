# Keikai runbook

State on 2026-11-27 09:10 UTC. Work is paused at the user's request ("finish the widget in hand, the remaining
families continue next Monday"). A scheduled task wakes this session on Monday 2026-11-30 12:05 UTC (21:05 KST).

## 1. Where things are

The generated workflow scripts and the tools have these absolute paths baked in. Recreate them exactly.

- REPO `/home/user/keikai-flutter`: git checkout of main. Only verified work goes here.
- WORK `/home/user/keikai`: plain directory, the tree the review agents edit. It is main plus the fixes of the
  groups that are not landed yet (section 4).
- BEFORE `/home/user/keikai-before`: plain copy of commit b5e6461, the state before the fix rounds. Attack agents
  diff WORK against it.
- O `/tmp/claude-0/-home-user/f20da2ea-0faa-5ffb-843b-e952279df433/scratchpad`: tools and data
  (`promote.py`, `wf/`, `fixes/`, `partial/`, `artifact-files/` with the design system files).
- N `/tmp/claude-0/-home-user-keikai-flutter/f20da2ea-0faa-5ffb-843b-e952279df433/scratchpad`: the session
  scratchpad. A Workflow `scriptPath` and the canvas `root` must be here (`N/wf`, `N/canvas`).
- Flutter 3.50.1 at `/opt/sdk/flutter` (`export PATH=/opt/sdk/flutter/bin:$PATH`). `bin/flutter` is a wrapper that
  gives every `flutter test` one of three slots with its own build directory; the real launcher is `flutter.real`.

## 2. Restore after a container loss

Everything that is not on main is on the branch `wip/review-state`: its tree is WORK, and `.wip/` holds the rest.

```bash
cd /home/user/keikai-flutter && git fetch origin wip/review-state && git fetch --unshallow origin main || true
mkdir -p /home/user/keikai && git archive origin/wip/review-state | tar -x -C /home/user/keikai
O=/tmp/claude-0/-home-user/f20da2ea-0faa-5ffb-843b-e952279df433/scratchpad
N=/tmp/claude-0/-home-user-keikai-flutter/f20da2ea-0faa-5ffb-843b-e952279df433/scratchpad
mkdir -p $O $N/wf && mv /home/user/keikai/.wip $O/wip-copy
cp -r $O/wip-copy/promote.py $O/wip-copy/wf $O/wip-copy/fixes $O/wip-copy/partial $O/
cp $O/wip-copy/RUNBOOK.md $O/wip-copy/tools/*.py $N/ && cp $O/wip-copy/wf/keikai-f*.js $N/wf/
mkdir -p /home/user/keikai-before && git archive b5e6461 | tar -x -C /home/user/keikai-before
```

- Flutter, if `/opt/sdk/flutter` is missing (this is the command that installed it in this session):
  `mkdir -p /opt/sdk && cd /opt/sdk && curl -fsSL --retry 4 --retry-delay 3 -o flutter.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.50.1-stable.tar.xz && echo "4ad17fc8462fbcef2ba19ff4a78c0a16b7147fde1add8578e267ea62cdb92678  flutter.tar.xz" | sha256sum -c - && tar -xf flutter.tar.xz && rm flutter.tar.xz && git config --global --add safe.directory /opt/sdk/flutter && /opt/sdk/flutter/bin/flutter --disable-analytics`
- Test wrapper: `mv /opt/sdk/flutter/bin/flutter /opt/sdk/flutter/bin/flutter.real`, copy
  `wip-copy/tools/flutter-wrapper.sh` to `/opt/sdk/flutter/bin/flutter` (chmod +x), then for n in 1 2 3:
  `mkdir -p /tmp/kk-flutter-slots/slot$n && echo '{"build-dir": "build/slot'$n'"}' > /tmp/kk-flutter-slots/slot$n/settings`.
- `flutter pub get` in WORK and in REPO.
- Design system files (not on the branch; the agents' prompts point at them): read them with the Artifact tool,
  `action: read`, the design system link from the session's system prompt (id bbbfd26b-8116-409a-b21c-e4cda4178056),
  `paths: ["project/README.md", "project/tokens.json", "project/components/bundle.css"]`, and copy them to
  `$O/artifact-files/bbbfd26b-8116-409a-b21c-e4cda4178056/project/` at the same relative paths.
- Check: `flutter analyze` in WORK is clean and `flutter test` there fails only on golden images (21 on 11-27: the
  controls, hud, inputs, layout, shell and table sheets in both conditions and the 9 app goldens), because WORK
  holds visual fixes that main does not have yet.

## 3. Tools

- `python3 $O/promote.py commit "<subject>" [--body "<body>"] <paths...>`: copy WORK paths to REPO and commit.
- `promote.py show <fixes/group>`, `replay <fixes/group> <first NN not yet in REPO>` (always give NN; read the
  whole output), `drift <paths...>`, `verify` (analyze + all tests in REPO), `push` (verify, then push main).
- The tool adds the commit trailer. No model name in commit messages.
- `python3 $N/jsum.py <wf ids>`: which stages of a workflow are done. `dump_stage_results.py`: copy the results of
  the journals into `wf/stage_results.json` (edit the workflow ids in it). `waitstage.py`: wait for a stage.
  `gbands.py <dir with the old goldens>`: where regenerated goldens differ.
- Workflows are capped at 2 agents each on this machine (4 CPUs); two workflows side by side is the practical limit.

## 4. Fix pipeline: where every group stands

Each group goes fix, attack (a second agent tries to break the fixes), repair. Snapshots are in
`$O/fixes/<group>/<NN>/` (files plus message.txt), one commit each when replayed. Findings: `wf/found.json`
(ids 0-42), `found2.json` (100-137), `found3.json` (200-262). Stage results: `wf/stage_results.json`
(key `<workflow id>|<label>`), state of the stopped runs in `wf/stage_state_1127.json`.

Landed on main (all three stages done): motion-core (14), scroll (6), flex (5 fixes, attack still owed),
pressable (8), hud-readouts (10), theme-app (4), painting (15, goldens regenerated).

Not landed, in WORK and in `$O/fixes`:

| group | files | snapshots | done | next |
| --- | --- | --- | --- | --- |
| effects | lib/src/motion/effects.dart | 01-06 | fix | attack, repair |
| grid | lib/src/layout/grid.dart, layout sheet ruler | 01-02 | fix, attack (4 low problems) | repair; the stopped repair's unfinished work is in `$O/partial/grid-repair/` |
| screen-split | lib/src/layout/screen.dart, split.dart | 01-10 | fix | attack, repair |
| hud-panel | lib/src/hud/panel.dart, fill_column, hug, state_word, heading | 01-10 | fix, attack (1 medium, 3 low) | repair |
| ctl-plates | lib/src/controls/badge, button, control_style, fab, icon_button, kbd, status_tag | 01-08 | fix | attack (a stopped attack's scratch test is in `$O/partial/attack-ctl-plates/`), repair |

Not started: tokens-colors, text-frame, box-layers (foundation and layout), hud-matrix-log, hud-alarms,
ctl-choice, ctl-slider, ctl-feedback. Owed: the attack of the five flex fixes that are on main.

Not reviewed at all: inputs, shell, charts, diagram, table. The find scripts are ready: `N/wf/keikai-find-3.js`
(inputs x4, shell x4), `keikai-find-4.js` (charts x4, diagram x4), `keikai-find-5.js` (table x3).

## 5. Monday plan

1. Restore if needed (section 2). Read `git log --oneline -30` in REPO.
2. Launch `N/wf/keikai-fix-7a.js` (effects, tokens-colors, text-frame, box-layers | grid, screen-split, flex) and
   `N/wf/keikai-fix-7b.js` (hud-panel, hud-matrix-log, hud-alarms | ctl-plates, ctl-choice, ctl-slider, ctl-feedback).
   Every group starts at its stage. They were generated by `python3 $O/wf/make_fix7.py $N/wf`; run it again if
   snapshots or stage results changed.
3. Land every group whose three stages are done (section 6). One verified push per group or batch.
4. Then the reviews of the remaining families: find-3, find-4, find-5. Save their findings with `_id` and
   `_target` (as `found3.json`), write a spec like `wf/spec6.json`, generate the fix workflow with
   `python3 $O/wf/make_fix6.py <out.js> <found.json> <spec.json>`.
5. After goldens change, refresh the canvas (section 7).
6. When everything is landed, tell the user that `wip/review-state` can be deleted. Do not delete it unasked.

## 6. Landing a group

1. `promote.py show $O/fixes/<group>`; read the repair agent's notes in the journal for decisions left to me.
2. `promote.py replay $O/fixes/<group> <first new NN>`, then `promote.py drift <the group's files>`.
3. If pixels change: copy the tracked PNGs under test/ to a scratch directory, run
   `flutter test --no-pub --update-goldens` in REPO, look at the differences (`gbands.py`, crops), commit the
   goldens as one commit that says which fixes changed what.
4. `promote.py verify`, then push main. Copy the REPO goldens into WORK afterwards.
5. `dart fix --apply --code=unnecessary_import` in REPO if analyze complains about imports after a replay.

## 7. Canvas

The Design canvas "Keikai Design Language" (link in the scheduled task's prompt and in the session summary) is at
version 12. Its sources are in `N/canvas/project` (`canvas.json` plus one `*.dc.html` per artboard, each a single
`<img src="/_blob/<id>">`). They are not on the wip branch: after a container loss read them back from the
artifact (`action: list`, `scope: files`, then `action: read` with `paths`) and copy them to `N/canvas/project`. To refresh: upload the changed goldens as assets (`asset: true`, `file_paths`),
put the new ids into the artboards, publish with `url`, `root: N/canvas`, `file_path: N/canvas/project/canvas.json`
and a `files` map of the changed artboards. Read an artboard with `action: read` first if the publish is refused.
Sheets are 2880 px wide at pixel ratio 2; the artboards are half of that. The motion artboard is an animated WebP
made by `test/example/capture_test.dart` with `--update-goldens` and `tool/assemble_frames.sh`.

## 8. Open follow-ups

- Pixel snapping (finding 24) is only done for painters and patterns. Left: KkBox hug sizes (now in the note of
  box-layers), KkChip width (65.2), flex shares of a width that does not divide, boxes under a line of text.
- KkDialog is centred on half pixels on odd window sizes (801 x 601 puts it at 140.5, 252.5): round the offset.
- From the example app: KkSlider takes no focus on press (in ctl-slider), KkPopup stays when its anchor scrolls
  away, `KkMenuAnchor(initiallyOpen: true)` grabs the focus, KkMessenger position and width, KkProgress chase,
  no banner slot in KkScreen.
- The repository has no LICENSE file; the user has to choose one.
- Old canvas assets that no artboard uses any more can be deleted if the user asks.

## 9. Rules from the user

- Commit per feature or fix, one verified push per task, to main. Never force-push, never delete, no pull requests.
- Explanations short and clear, in Korean. The user's e-mail address is private.
- Workflows were approved for this session (ultracode was on on 11-27). If it is off on Monday, ask before
  launching one.
