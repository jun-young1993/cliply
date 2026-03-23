 Cliply Flutter 앱 구현 계획

 Context

 PLAN.md에 기획된 "cliply" 앱을 Flutter로 구현한다. 현재는 기본 카운터 앱 템플릿 상태이며, 
  영상 분할 편집 / 이어붙이기 / 구간 편집 등 핵심 기능을 처음부터 구축해야 한다.

 ---
 1. 패키지 추가 (pubspec.yaml)

 dependencies:
   flutter:
     sdk: flutter
   cupertino_icons: ^1.0.8
   # 영상 처리
   ffmpeg_kit_flutter_new: ^4.1.0   # 이미 추가됨
   video_player: ^2.9.2
   image_picker: ^1.1.2
   # 상태 관리
   flutter_riverpod: ^2.6.1
   # 파일 / 저장 / 공유
   path_provider: ^2.1.5
   path: ^1.9.1
   gal: ^2.3.0
   share_plus: ^10.1.4
   # 권한
   permission_handler: ^11.3.1
   device_info_plus: ^10.1.0        # Android 버전별 권한 분기

 ---
 2. Android 설정 변경

 android/app/build.gradle.kts

 minSdk = 24  // flutter.minSdkVersion → 24 (ffmpeg_kit 요구사항)

 android/app/src/main/AndroidManifest.xml

 <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
 <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
 android:maxSdkVersion="32" />
 <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
 android:maxSdkVersion="28" />

 ---
 3. 폴더 구조

 lib/
 ├── main.dart                          # ProviderScope + MaterialApp (전면 교체)
 ├── app.dart                           # 테마, 라우팅
 ├── core/
 │   ├── constants/app_colors.dart      # 다크 테마 컬러
 │   ├── constants/app_constants.dart   # 전역 상수
 │   └── theme/app_theme.dart
 ├── models/
 │   ├── video_clip.dart                # id, filePath, duration, startTime, endTime,      
 slotIndex
 │   ├── video_project.dart             # editMode, aspectRatio, clips[]
 │   ├── aspect_ratio_type.dart         # enum: ratio_9_16, ratio_1_1, ratio_16_9
 │   ├── edit_mode.dart                 # enum: horizontalSplit, verticalSplit, merge      
 │   └── split_layout.dart
 ├── services/
 │   ├── ffmpeg_service.dart            # FFmpegKit.executeAsync 래퍼 + 진행률
 │   ├── video_export_service.dart      # filter_complex 명령 조립 (분할/합치기)
 │   ├── permission_service.dart        # Android 버전별 권한 분기
 │   ├── thumbnail_service.dart         # ffmpeg로 썸네일 추출
 │   └── gallery_service.dart           # gal + share_plus
 ├── providers/
 │   ├── project_provider.dart          # 현재 프로젝트 상태 (Riverpod)
 │   └── export_provider.dart           # idle | processing(progress) | done | error       
 └── screens/
     ├── home/
     │   ├── home_screen.dart
     │   └── widgets/feature_card.dart
     ├── edit/
     │   ├── split_edit_screen.dart     # 분할 편집
     │   ├── merge_edit_screen.dart     # 이어붙이기
     │   └── widgets/
     │       ├── preview_area.dart
     │       ├── video_slot.dart
     │       ├── trim_slider.dart       # RangeSlider 기반
     │       └── aspect_ratio_selector.dart
     └── result/
         └── result_screen.dart

 ---
 4. 데이터 모델

 // VideoClip
 { id, filePath, duration, startTime, endTime, slotIndex, thumbnailPath? }

 // VideoProject
 { id, editMode, aspectRatio, splitLayout, clips[], createdAt, outputPath? }

 ---
 5. 핵심 서비스: video_export_service.dart

 가로 분할 FFmpeg filter_complex 예시:
 -filter_complex "[0:v]trim=start=SS:end=EE,setpts=PTS-STARTPTS,scale=W:H[v0];
                  [1:v]trim=start=SS:end=EE,setpts=PTS-STARTPTS,scale=W:H[v1];
                  [v0][v1]vstack=inputs=2[out]"
 세로 분할: hstack 사용
 이어붙이기: concat 필터 사용

 ---
 6. 구현 순서

 ┌───────┬──────────────────────────┬─────────────────────────────────────────────────┐    
 │ Phase │           내용           │                    주요 파일                    │    
 ├───────┼──────────────────────────┼─────────────────────────────────────────────────┤    
 │ 1     │ 패키지, Android 설정,    │ pubspec.yaml, build.gradle.kts,                 │    
 │       │ 다크 테마                │ AndroidManifest.xml, app_theme.dart             │    
 ├───────┼──────────────────────────┼─────────────────────────────────────────────────┤    
 │ 2     │ 데이터 모델 + 서비스     │ models/, services/, providers/                  │    
 │       │ 레이어                   │                                                 │    
 ├───────┼──────────────────────────┼─────────────────────────────────────────────────┤    
 │ 3     │ 홈 화면                  │ home_screen.dart, feature_card.dart             │    
 ├───────┼──────────────────────────┼─────────────────────────────────────────────────┤    
 │ 4     │ 이어붙이기 편집 (FFmpeg  │ merge_edit_screen.dart,                         │    
 │       │ concat)                  │ video_export_service.dart                       │    
 ├───────┼──────────────────────────┼─────────────────────────────────────────────────┤    
 │ 5     │ 분할 편집 (FFmpeg        │ split_edit_screen.dart, split_preview.dart      │    
 │       │ filter_complex)          │                                                 │    
 ├───────┼──────────────────────────┼─────────────────────────────────────────────────┤    
 │ 6     │ 결과 화면 + 저장/공유    │ result_screen.dart, gallery_service.dart        │    
 ├───────┼──────────────────────────┼─────────────────────────────────────────────────┤    
 │ 7     │ 최근 작업 저장, 에러     │ recent_projects_provider.dart                   │    
 │       │ 처리, 앱 아이콘          │                                                 │    
 └───────┴──────────────────────────┴─────────────────────────────────────────────────┘    

 ---
 7. 검증 방법

 1. Android 에뮬레이터(API 24 이상) 또는 실기기에서 flutter run 실행
 2. 홈 화면 → 기능 카드 탭 → 영상 선택(갤러리) → 구간 설정 → 저장 플로우 확인
 3. 출력 영상이 갤러리에 저장되는지 확인
 4. FFmpeg 진행률 오버레이 정상 동작 여부 확인

 ---
 주요 수정 파일 목록

 - pubspec.yaml — 패키지 추가
 - android/app/build.gradle.kts — minSdk 24로 변경
 - android/app/src/main/AndroidManifest.xml — 권한 추가
 - lib/main.dart — 전면 교체 (ProviderScope)
 - lib/services/video_export_service.dart — 신규 생성 (핵심)
 - lib/providers/project_provider.dart — 신규 생성
 - lib/screens/ — 전체 신규 생성

📄 앱 기획서
(가칭) cliply
1. 📌 서비스 개요

cliply는
여러 영상을 분할하고 배치하여 하나의 영상으로 만드는
모바일 영상 편집 앱이다.

사용자는 복잡한 편집 없이
간단한 조작만으로 SNS용 멀티 영상 콘텐츠를 빠르게 제작할 수 있다.

2. 🎯 서비스 목표
누구나 쉽게 멀티 영상 콘텐츠 제작
10초 이내 편집 완료 경험 제공
틱톡 / 릴스 / 쇼츠 최적화 영상 생성
3. 👤 타겟 사용자
SNS 콘텐츠 제작자 (틱톡, 릴스)
브이로그 유저
인터뷰 / 리액션 영상 제작자
간단 편집을 원하는 일반 사용자
4. ⭐ 핵심 가치
빠름 (Fast)
직관적 (Simple)
결과 중심 (Instant Result)
5. 🧩 주요 기능
5.1 영상 분할 편집
설명

여러 영상을 하나의 화면에 분할하여 동시에 재생

유형
가로 분할 (Top / Middle / Bottom)
세로 분할 (Left / Center / Right)
5.2 영상 이어붙이기
설명

여러 영상을 순차적으로 연결하여 하나의 영상으로 제작

5.3 영상 구간 편집
설명

각 영상의 시작과 끝 구간을 설정

5.4 레이아웃 편집
설명

영상 배치 방식 선택

5.5 비율 설정
지원 비율
9:16 (릴스/틱톡)
1:1
16:9
5.6 미리보기 및 저장
설명

편집 결과를 실시간으로 확인하고 저장

6. 🗂 정보 구조 (IA)
6.1 홈 화면
구성
기능 선택 메뉴
최근 작업
메뉴 목록
가로 분할 영상 만들기
세로 분할 영상 만들기
영상 이어붙이기
6.2 편집 화면
공통 구조
1. 상단
영상 미리보기 영역
2. 중간
영상 슬롯 (영상 추가 영역)
3. 하단
타임라인 / 구간 조절 바
4. 하단 액션
미리보기
저장
공유
7. 🔄 사용자 흐름 (User Flow)
7.1 분할 영상 제작 흐름
홈 진입
기능 선택 (가로/세로 분할)
영상 선택
영상 자동 배치
구간 조절
미리보기
저장 / 공유
7.2 영상 합치기 흐름
홈 진입
영상 이어붙이기 선택
영상 선택
순서 정렬
미리보기
저장
8. 🎛 UI/UX 설계
8.1 디자인 원칙
최소 클릭 (Minimal Interaction)
직관적 구조 (No Learning Curve)
즉각적 피드백
8.2 핵심 인터랙션
1. 드래그
영상 순서 변경
영역 크기 조절
2. 슬라이더
영상 구간 설정
3. 탭
기능 선택
9. 📱 주요 화면 정의
9.1 홈 화면
요소
상단: 앱 이름
중앙: 기능 카드
하단: 최근 작업
9.2 편집 화면
요소
미리보기
영상 리스트
타임라인
저장 버튼
9.3 결과 화면
요소
완성 영상
공유 버튼
재편집 버튼
10. 🎨 콘텐츠 스타일
세로 영상 중심
짧은 영상 (Short-form)
빠른 템포
11. 💰 수익 모델
광고 (무료 사용자)
워터마크 제거 (유료)
고화질 저장 (유료)
12. 🚀 확장 방향
템플릿 기능
자동 편집 기능
음악 추가 기능
효과 / 필터
13. 📊 성공 지표 (KPI)
영상 생성 완료율
평균 편집 시간
재방문율
공유율
14. 🧠 차별화 포인트
“분할 영상 제작”에 특화
빠른 결과 중심 UX
복잡한 편집 기능 제거
15. 🧾 한 줄 요약

👉
“누구나 10초 만에 멀티 영상 만드는 초간단 Video Editor”