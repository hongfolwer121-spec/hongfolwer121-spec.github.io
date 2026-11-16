# My Little Cat — 스토어 출시 준비 체크리스트

Google Play와 App Store 동시 출시 기준. `[x]` 완료, `[ ]` 미완료.

## 0. 먼저 확정해야 하는 것 (나중에 바꿀 수 없음)

- [ ] **패키지 이름 / 번들 ID** — 현재 임시값 `com.mylittlecat.game`.
      Play와 App Store 모두 첫 업로드 후 변경 불가. 본인 소유 도메인이나 고유한 이름으로 확정할 것.
- [ ] **앱 이름** — Play와 App Store에서 같은 이름의 앱이 있는지 검색, 상표 확인.

## 1. 개발 구조 (양쪽 공통)

- [x] Godot 4.7 사용 — Android와 iOS를 같은 코드로 출시 가능
- [x] Android 내보내기 설정 (`export_presets.cfg` preset.0)
- [x] iOS 내보내기 설정 (`export_presets.cfg` preset.1, Team ID 비어 있음)
- [ ] 알림 플러그인 (Android + iOS) — 밥/놀이 알림
- [ ] 광고 플러그인 AdMob (Android + iOS) — 보상형 광고
- [ ] 로그인 + 클라우드 저장 (Firebase)
- [ ] 서버 측 광고 시청 확인(SSV) + 서버 뽑기 (Cloud Functions)

## 2. Google Play

- [ ] Google Play 개발자 계정 (1회 등록비)
- [ ] 신규 개인 계정: 프로덕션 출시 전 **테스터 12명 이상, 14일 비공개 테스트**
- [ ] 최신 targetSdk 충족 (현재 템플릿 targetSdk 36)
- [ ] 업로드 키 / 앱 서명 키 생성 및 안전 보관 (분실 시 업데이트 불가)
- [ ] 출시용 AAB 형식 빌드 (`gradle_build/export_format=1`)
- [ ] 데이터 보안(Data safety) 양식
- [ ] 콘텐츠 등급(IARC) 설문
- [ ] 대상 연령 설정 — 13세 이상 권장 (아동 대상이면 Families 정책 + 광고 제한)
- [ ] 개인정보처리방침 URL
- [ ] 계정 삭제 안내 URL (계정 기능이 있으면 필수)
- [ ] 뽑기 확률 공개 (Play 정책 + 한국 게임산업법)

## 3. App Store

- [ ] **Apple Developer Program 가입** (연간 회비) → Team ID를 iOS 내보내기 설정에 입력
- [ ] **Mac에서 빌드** — iOS 앱은 Xcode로만 빌드·서명 가능.
      방법: (a) 본인 Mac, (b) GitHub Actions의 macOS 빌드 머신 (클라우드, 저장소에 서명 인증서를 비밀값으로 등록)
- [ ] 실제 iPhone 테스트 — TestFlight
- [ ] **Sign in with Apple** — Google 로그인을 제공하면 Apple 로그인도 함께 제공해야 함 (App Store 가이드라인 4.8)
- [ ] **ATT(앱 추적 투명성) 권한 요청** — 맞춤형 광고를 쓰면 필수
- [ ] **앱 내 계정 삭제 기능** — 계정을 만들 수 있으면 앱 안에서 삭제도 가능해야 함 (가이드라인 5.1.1(v))
- [ ] 개인정보 라벨(App Privacy) 작성
- [ ] 뽑기 확률을 구매/사용 전에 공개 (가이드라인 3.1.1)
- [ ] 연령 등급 설문
- [ ] 스크린샷 (6.9인치/6.5인치 iPhone 등 요구 크기), 앱 아이콘 1024×1024

## 4. 양쪽 공통 출시 자료

- [ ] 앱 아이콘, 스크린샷, 소개 문구 (한국어/영어)
- [ ] 개인정보처리방침 페이지 (이 GitHub Pages 저장소에 호스팅 가능)
- [ ] 이용약관 페이지
- [ ] 고객 문의 이메일
- [ ] 고양이 에셋 라이선스 확인 문서 보관 (상업 이용, 모바일 앱 배포 가능 여부)
- [ ] 폰트 라이선스 (나눔고딕: SIL OFL — 앱 포함 가능)
