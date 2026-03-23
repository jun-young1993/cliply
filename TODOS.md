# TODOS

## P2 — VideoExportService 유닛 테스트

**What:** `VideoExportService._exportSplit` / `_exportMerge`의 filter_complex 문자열 생성 로직 유닛 테스트

**Why:** FFmpeg 커맨드가 틀려도 런타임에 조용히 실패한다. filter_complex 문자열 버그는 수동 테스트로 재현하기 어렵다.

**Pros:** anullsrc 분기, vstack/hstack 선택, args 리스트 순서 등 핵심 로직을 빠르게 검증 가능

**Cons:** Mock FfmpegService 설정 필요, 실제 FFmpeg 실행은 검증 안 됨

**Context:** `lib/services/video_export_service.dart` — `_exportSplit`, `_exportMerge` 메서드가 `FfmpegService.executeWithArgs(args, ...)` 를 호출한다. `FfmpegService`를 mock으로 교체하고 `args` 리스트를 검사하면 된다. `test/services/video_export_service_test.dart` 신규 생성.

**Depends on:** Phase 4/5 구현 완료 후 (filter 로직이 확정되면)

**Effort:** S

---

## P3 — ThumbnailService 경로 캐시

**What:** `ThumbnailService`에 `filePath → thumbnailPath` 메모리 캐시 추가

**Why:** 같은 클립이 선택된 채로 화면을 rebuild하면 동일 파일에 대한 FFmpeg 1프레임 추출이 중복 발생한다.

**Pros:** scroll/rebuild 시 불필요한 FFmpeg 호출 제거, UI 응답성 개선

**Cons:** 앱 생명주기 동안 캐시 메모리 누적 (소량)

**Context:** `lib/services/thumbnail_service.dart`. 이미 `VideoClip.thumbnailPath`에 경로를 저장하므로, 클립에 썸네일이 이미 있으면 `ThumbnailService`를 호출하지 않는 로직이 UI 레이어에 있으면 충분할 수도 있다. `if (clip.thumbnailPath != null) return;` 체크를 영상 선택 흐름에 추가하는 것으로 대체 가능.

**Depends on:** Phase 4/5 화면 구현 완료 후

**Effort:** XS

---

## P3 — 최근 작업 저장

**What:** 편집 완료된 프로젝트의 출력 경로 + 모드 + 날짜를 SharedPreferences에 저장하고 홈 화면에 "최근 작업" 섹션으로 표시

**Why:** 앱 재시작 후 이전에 만든 영상을 다시 찾기 어렵다. 결과 화면에서 저장 시점에 기록하면 충분하다.

**Pros:** 사용성 개선, SharedPreferences로 구현 단순

**Cons:** 출력 파일이 임시 디렉터리(getTemporaryDirectory)에 있어 OS가 삭제할 수 있음 — 갤러리 저장 여부도 함께 기록 필요

**Context:** `lib/services/video_export_service.dart`의 `_generateOutputPath()`는 임시 경로를 반환한다. 갤러리 저장 완료 후 `GalleryService.saveToGallery()` 성공 시점에 SharedPreferences에 기록하는 것이 안전하다. `lib/services/recent_projects_service.dart` 신규 생성, `HomeScreen`에 `ListView` 섹션 추가.

**Depends on:** Phase 6 완료 후

**Effort:** S

---

## P3 — 공통 에러 다이얼로그 위젯

**What:** `showErrorDialog(context, message)` 유틸 함수 또는 `ErrorDialog` 위젯 — SnackBar 대신 중요 오류에 다이얼로그 표시

**Why:** 현재 모든 오류가 SnackBar로 표시되는데, 내보내기 실패처럼 사용자 액션이 필요한 오류는 다이얼로그가 적합하다.

**Pros:** 사용자가 오류를 놓치지 않음, 재시도 버튼 추가 가능

**Cons:** SnackBar보다 흐름을 방해함 — 모든 오류에 적용하면 UX 저하

**Context:** `lib/screens/shared/` 에 `error_dialog.dart` 신규 생성. 편집 화면의 `ref.listen` 블록에서 `ExportError` 처리 시 사용. SnackBar는 권한 거부 같은 경미한 오류에 유지.

**Depends on:** 없음

**Effort:** XS

---

## P4 — 앱 아이콘

**What:** `flutter_launcher_icons` 패키지로 Android/iOS 앱 아이콘 설정

**Why:** 기본 Flutter 아이콘이 표시됨

**Pros:** 앱 완성도

**Cons:** 디자인 에셋(1024×1024 PNG) 필요

**Context:** `pubspec.yaml`에 `flutter_launcher_icons` 추가 후 `flutter pub run flutter_launcher_icons` 실행. Android는 `android/app/src/main/res/`, iOS는 `ios/Runner/Assets.xcassets/AppIcon.appiconset/` 에 자동 생성.

**Depends on:** 아이콘 디자인 에셋 준비 후

**Effort:** XS (에셋 준비 제외)

---

## P2 — ThumbnailService 셸 인젝션 수정

**What:** `ThumbnailService.extractThumbnail()`을 `FFmpegKit.execute(String)` → `FFmpegKit.executeWithArgumentsAsync(List<String>)` 방식으로 교체

**Why:** 현재 경로를 문자열에 직접 삽입(`-i "$videoPath"`)하므로 공백·따옴표 포함 경로에서 FFmpeg 실행이 조용히 실패한다. `video_export_service.dart`에서 동일 이유로 이미 `executeWithArgs(List)`로 전환한 선례가 있다.

**Pros:** 경로 안전성 확보, 갤러리 경로(`/storage/emulated/0/DCIM/Camera/my video.mp4`) 등 실제 기기에서 발생하는 실패 방지

**Cons:** 없음 — 단순 교체

**Context:** `lib/services/thumbnail_service.dart` line 20. `-ss {sec} -i "{path}" -vframes 1 -q:v 2 "{out}"` 형태를 `['-ss', sec, '-i', path, '-vframes', '1', '-q:v', '2', out]` 리스트로 교체하고 `executeWithArgumentsAsync` + Completer 패턴 사용.

**Depends on:** 없음

**Effort:** XS

---

## P3 — 3분할 UI 지원

**What:** `SplitEditScreen`에 슬롯 수 선택 UI 추가 (2분할 ↔ 3분할 토글), `VideoProject.splitLayout`을 `SplitLayout.three`로 설정하는 흐름 연결

**Why:** 모델(`SplitLayout.two / .three`)과 `VideoProject.maxSlots` 로직은 이미 구현되어 있으나 UI에서 선택이 불가능하다.

**Pros:** 기능 완성, 모델 활용

**Cons:** 3분할 시 각 슬롯 너비가 좁아 `_SlotGrid` 카드 레이아웃 조정 필요

**Context:** `lib/screens/edit/split_edit_screen.dart`의 `AspectRatioSelector` 아래에 `SegmentedButton<SplitLayout>` 추가 → `projectProvider.notifier.setSplitLayout(layout)` 호출 (현재 `ProjectNotifier`에 `setSplitLayout` 없으므로 추가 필요). `_SplitPreview`와 `_SlotGrid`는 이미 `maxSlots`를 파라미터로 받으므로 자동 반영.

**Depends on:** 없음

**Effort:** S

---

## P3 — 임시 파일 정리

**What:** 앱 시작 시 또는 내보내기 완료 후 `getTemporaryDirectory()`의 `cliply_*.mp4` / `thumb_*.jpg` 파일 중 오래된 것을 삭제

**Why:** 내보내기 실패 시 `_tryDeleteFile()`로 정리되지만, 앱 강제종료·크래시 시 임시 파일이 누적된다. 썸네일도 영상 선택마다 새 파일이 생성된다.

**Pros:** 기기 저장 공간 절약

**Cons:** 삭제 타이밍을 잘못 잡으면 재생 중인 파일 삭제 위험 — 앱 시작 시(이전 세션 잔여물만) 정리하는 것이 안전

**Context:** `lib/services/video_export_service.dart`의 `_generateOutputPath()`와 `lib/services/thumbnail_service.dart`의 `extractThumbnail()`이 각각 임시 경로를 생성한다. `main.dart`의 `main()` 또는 별도 `CleanupService`에서 24시간 이상 된 `cliply_*` / `thumb_*` 파일을 삭제.

**Depends on:** 없음

**Effort:** XS
