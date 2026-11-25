# KEIKAI 警戒 for Flutter

지휘소(HQ)·HUD 화면용 다크 디자인 언어 KEIKAI의 Flutter 구현입니다. 검은 바탕 위 신호 오렌지 프레임, 굵은 명조 漢字/한글 표제와 압축 영문 라벨, 고정폭 계측 숫자, 해저드 사선과 단계식 모션으로 "감시 중인 시스템"을 보여 줍니다. 평시에는 오렌지, 경보 시에는 화면 전체가 적색으로 바뀝니다.

모든 위젯은 Flutter의 `widgets`·`rendering` 레이어 위에 직접 만들었습니다. `material.dart`와 `cupertino.dart`는 어디에서도 import하지 않습니다.

> 개발 중입니다. 위젯 패밀리가 검증되는 대로 `main`에 올라옵니다.

## 시작

```yaml
dependencies:
  keikai:
    git: https://github.com/itsmekingtiger/keikai-flutter
```

```dart
import 'package:keikai/keikai.dart';

void main() => runApp(const HqApp());

class HqApp extends StatelessWidget {
  const HqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const KeikaiApp(
      title: 'HQ',
      home: KkBackdrop(
        alignment: Alignment.center,
        child: KkLabel(cjk: '警戒', en: 'keikai for flutter', cjkSize: 44, enSize: 13),
      ),
    );
  }
}
```

`package:keikai/keikai.dart` 하나만 import하면 됩니다. 프레임워크의 `widgets` 레이어(`State`, `BuildContext`, `Navigator` …)를 함께 내보냅니다.

## 원칙

- 밀도가 장식보다 우선이다. 면은 명도와 선으로 나누고 그라데이션·둥근 모서리·그림자를 쓰지 않는다. 모서리를 줄일 때는 45°로 깎는다.
- 상태는 색 + 단어 + 상태 아이콘 세 가지로 말한다(`KkLevel`: nominal · caution · critical · offline).
- `signal`(오렌지)은 구조와 조작의 색이다. 상태의 색으로 쓰지 않는다.
- 모션은 계단식(`steps()`)이고 이징이 없다. 움직임은 상태 전이를 알릴 때만 쓴다.
- 표제는 두 언어로 쓴다: CJK 표제 + 영문 대문자 부제(`cjk` / `en`).

## 구성

| 계층 | 경로 | 내용 |
| --- | --- | --- |
| 기반 | `lib/src/foundation` | 두 테마의 색 역할(`KkColors`), 타이포(`KkTypography`), 치수 토큰(`KkMetrics`), 모션 규칙(`KkMotion`, `KkSteps`), 수준(`KkLevel`), 아이콘 104종(`KkIcons`), 테마(`KeikaiTheme`) |
| 페인팅 | `lib/src/painting` | 45° 도형(`KkShape`), 테두리·브래킷·발광, 하드 스톱 패턴, SVG 경로 파서 |
| 모션 | `lib/src/motion` | 부트 와이프, 플리커, 스크램블, 스트로브·블링크, 해저드, 글리치 |
| 레이아웃 | `lib/src/layout` | 커스텀 RenderObject: `KkRow`/`KkColumn`(gap), `KkBox`, `KkSurface`, `KkLayers`, `KkWrap`, 4/8/12/16/24열 `KkGrid`, `KkScreen`, `KkSplit`, `KkBreakpoint` |
| 위젯 | `lib/src/widgets` | `KkText`, `KkLabel`, `KkIcon`, `KkGlyph`, `KkPressable`, `KkWidgetFrame`, `KkClock` |
| 앱 | `lib/src/app` | `KeikaiApp`, `KkPageRoute`, `KkPopupRoute` |

컨트롤, 입력, 셸/오버레이, HUD 계측, 차트, 데이터 테이블, 다이어그램 렌더러는 검증 후 추가됩니다.

## 테마와 조건

```dart
KeikaiApp(
  theme: const KeikaiThemeData(
    motion: KkMotion(timeScale: 1.0),       // KkMotion.off 로 모션 전체 끄기
    metrics: KkMetrics(gridGutter: 8),      // 치수 토큰 재정의
  ),
  condition: KkCondition.standby,            // alert 로 바꾸면 화면이 글리치 후 적색으로 전환
  home: const SituationBoard(),
);
```

영역 하나만 경보색으로 바꾸려면 `KkConditionScope(condition: KkCondition.alert, child: …)`를 씁니다.

## 개발

```bash
flutter analyze
flutter test
flutter test --update-goldens   # 골든 이미지 다시 쓰기 (Linux에서 렌더)
```

위젯 테스트에서는 `KkMotion.off`를 주면 반복 모션이 멈춰 `pumpAndSettle`을 쓸 수 있습니다. `test/support/harness.dart`의 `pumpKk`가 그렇게 합니다.

## 폰트와 라이선스

패키지에 다음 폰트가 들어 있으며 각각 SIL Open Font License 1.1을 따릅니다(`fonts/OFL-*.txt`): Zen Old Mincho, Noto Serif KR, Sofia Sans Extra Condensed, IBM Plex Mono, IBM Plex Sans KR. 다른 폰트를 쓰려면 `KkTypography`에 패밀리 이름을 주고 `package`를 비우면 됩니다.

코드 라이선스는 아직 정해지지 않았습니다.
