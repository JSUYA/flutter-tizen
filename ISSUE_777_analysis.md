# Issue #777 — Release TPK contains dummy author certificate

> Certificate / author signature error when uploading TPK to Samsung Seller Portal on latest flutter-tizen
> Reporter: @alensh12 · Working: flutter-tizen 3.22.2 · Broken: 3.44.1-tizen.1.0.0

분석/패치 작업 정리. 코드·명령·기술용어는 원문 유지.

---

## 1. 증상

- `flutter-tizen build tpk --release --security-profile=<profile>` 로 빌드한 release TPK가
  지정한 프로파일이 아니라 **dummy 기본 인증서(`CN=author`, Tizen Developers CA)** 로 서명됨.
- **빌드는 성공**(에러 없음) → 사용자가 모르고 Samsung Seller Portal에 업로드 → 거부.
  TV 실기기 설치 시 certificate error.
- 3.22.2 정상 / 3.44.1 깨짐.

---

## 2. dummy 서명이 들어가는 메커니즘 (확정)

`.NET` 빌드(`Tizen.NET.Sdk` = build-task-tizen)는 **인증서 정보(`AuthorPath`)가 비어 있으면
자동으로 기본(dummy) 인증서로 서명하고 빌드를 성공시킨다.**

`~/.nuget/packages/tizen.net.sdk/1.1.7/build/Tizen.NET.Sdk.Packaging.targets`:
```xml
<PropertyGroup Condition="'$(AuthorPath)'==''">
  <AuthorPath>$(TizenDefaultAuthorPath)</AuthorPath>            <!-- = dummy cert -->
  <TizenUseDefaultCertificate>true</TizenUseDefaultCertificate>
</PropertyGroup>
<Message Condition="'$(TizenUseDefaultCertificate)'=='true'"
         Text="... is signed with Default Certificates!" />
```

`AuthorPath` 를 채우는 주체 = **tz**. tz 가 `signing_profile` 을 resolve 해서
`/p:AuthorPath=...` 로 dotnet 에 전달한다. tz 가 채우지 못하면 빈값 → dummy.

### dummy 신호 (빌드 로그 문자열)

| 경로 | 서명 주체 | 로그 |
|---|---|---|
| `tz build` (flutter-tizen 3.44.1 경로) | **tz** (Go x509 로 직접 서명) | `Using default certificates` |
| `dotnet build` 직접 (옛 경로) | **build-task-tizen** | `signed with Default Certificates` |

---

## 3. tz 의 signing_profile 처리 (실험으로 확정, tz v10.3.8)

`tizen_dotnet_project.yaml` 의 `signing_profile` 값에 따른 `tz build` 동작:

| `signing_profile` | tz 동작 |
|---|---|
| `"<profile>"` (정상) | 해당 프로파일로 서명 |
| `""` (빈값) | **active 프로파일로 폴백** (dummy 아님) |
| `"no_such_profile"` (없는 이름) | **active 프로파일로 폴백** (dummy 아님) |
| **`"."`** (default 지시자) | **DEFAULT dummy** → `Using default certificates` |

→ tz 가 dummy 로 가는 경우는 **`signing_profile` 이 정확히 `.` 일 때만**
  (또는 `tz build -D/--default`). 빈/오타/누락은 전부 active 폴백이라 dummy 아님.
  비번을 못 얻으면 → **빌드 에러** (default 폴백 아님).

---

## 4. 3.22 가 정상이고 3.44 가 깨진 구조적 이유

### 3.22.2
```
dotnet build              → dummy TPK (build-task default 서명)
tizen package -s <profile> → 명시적 재서명 (항상 덮어씀)
```
- **안전망 1: 무조건 재서명.** 중간이 dummy 여도 최종은 정상.
- **안전망 2: 프로파일명을 명령 인자로 직접 전달** (yaml 안 거침).

### 3.44.1 (PR #595, b1f3243 — 최초 3.27.1-tizen.1.0.0)
```
tz set -s <profile>  → yaml(signing_profile) 기록
tz build             → yaml 되읽어 서명
```
- 재서명 단계 **삭제** → tz 단일 서명에 의존. 안전망 없음.
- 프로파일이 **yaml(signing_profile) 경유** → 이 값이 어떤 이유로 `.`(default)이 되면
  tz 가 dummy 서명, 그대로 최종 출고.

| | 3.22 (tizen) | 3.44 (tz) |
|---|---|---|
| 프로파일 전달 | 명령 인자 직접 | yaml 경유 (취약) |
| 안전망 | 무조건 재서명 | 없음 |
| yaml 깨질 때 | 무관 (덮어씀) | dummy 그대로 출고 |

관련 PR/이슈: PR #595(b1f3243, 회귀 도입) · PR #612(aa38538, `tz set` await race 수정) ·
Issue #610(`tz set` first-build 미반영) · Issue #777.

---

## 5. tz 와 tizen package 의 폴백 차이 (실험)

같은 dummy TPK 에 재패키징 시:

| `-s` 프로파일 | `tizen package` | `tz build` |
|---|---|---|
| 정상 이름 | 정상 서명 | 정상 서명 |
| `.` | dummy | dummy |
| 없는 이름 | **dummy (조용히, exit 0)** | **active 폴백** |

- `tizen package` 는 **없는 프로파일이면 조용히 dummy 로 폴백 + exit 0 + "created successfully".**
  exit code 로 dummy 여부 판단 불가.
- tz 는 없는 이름이면 active 폴백 (더 안전).
- → `tizen package -s <정상이름>` 으로 재서명하면 해결되지만,
  이름이 틀리거나 비번 접근 실패 시 **조용히 dummy 유지.** 결과 cert 검증 필수.

---

## 6. 인증서 비번 / keyring·D-Bus 의존성 (실험)

- 인증서 비번이 `.pwd` 파일이 아니라 **keyring(secret service, D-Bus 기반)** 에 저장될 수 있음.
- D-Bus 세션 / keyring 접근 불가(headless·SSH·CI, keyring 잠김) 시:

| 단계 | keyring 접근 실패 시 |
|---|---|
| `tz build` | **빌드 에러** (`PKCS12 MAC invalid` / `fetching author password ... timeout`) |
| `tizen package` 재서명 | **조용히 dummy 유지, exit 0** |

- 단 reporter 는 "빌드 성공 + dummy" → keyring 에러(빌드 실패) 경로는 증상과 불일치.
  → reporter 증상에는 **`signing_profile` 미해석(default)** 이 더 부합.

---

## 7. 재현 결과 요약 (로컬, tz v10.3.8)

- 정상 빌드 / 빈·오타·누락 yaml / 구(tizen40) 프로젝트→신 빌드 / `.` yaml 심고 flutter-tizen 빌드
  → **전부 정상 프로파일로 서명** (flutter-tizen 이 `tz set -s <profile>` 로 덮음).
- **빌드성공+dummy 를 flutter-tizen 정상 흐름으로는 재현 불가.**
- dummy 강제는 `signing_profile: "."` 직접 주입 시에만 (`--security-profile=.` + profiles.xml 에 `name="."` 추가로 검증 우회).
- → reporter 의 dummy 는 **flutter-tizen 밖 요인** (외부 IDE/도구가 yaml 에 `.` 기록,
  또는 reporter 환경에서 tz/yaml 이 default 로 해석). 확정에는 reporter 데이터 필요.

---

## 8. 패치 (적용)

**방향:** 재서명 복원(dbus 의존·조용한 실패 가능)으로 우회하지 않고,
**release 빌드가 dummy 로 서명되면 보이는 경고를 출력**(빌드는 계속).

`lib/build_targets/package.dart` (`DotnetTpk.build()`):
```dart
} else if (buildMode.isRelease &&
    (result.stdout.contains('Using default certificates') ||
        result.stdout.contains('signed with Default Certificates'))) {
  environment.logger.printWarning(
    'Warning: The release TPK was signed with a dummy default certificate '
    'instead of the "$securityProfile" profile.\n'
    'A package signed with the default certificate can be rejected by the '
    'Samsung Seller Portal.\n'
    'This usually means the signing profile could not be applied — for '
    'example the profile is invalid, or the certificate password is not '
    'accessible (a locked keyring, or a headless session without an active '
    'D-Bus/keyring session).\n'
    'Verify the "$securityProfile" profile in Certificate Manager, make '
    'sure the certificate password is unlocked, and rebuild before '
    'uploading.',
  );
}
```

- `printWarning` → `-v` 없이 노란색으로 표시. 빌드 중단 안 함.
- 두 신호(`Using default certificates` / `signed with Default Certificates`) 모두 감지 →
  tz 경로 + build-task 경로 커버.
- 테스트: `test/general/build_targets/package_test.dart` — dummy 서명 시 경고 + 빌드 성공 + TPK 생성 확인.

**실제 빌드 재현 확인:** `--security-profile=.` 로 강제 시 경고 출력 + 빌드 계속(`✓ Built`),
최종 cert = `CN=author` 확정.

검증: `flutter-tizen analyze` 무이슈, `package_test.dart` 7/7 통과.

---

## 9. 미확정 + reporter 에게 요청할 데이터

내 환경(tz v10.3.8)에선 dummy 자연 재현 불가 → reporter 환경 고유 요인 확정 필요:

1. **빌드된 `tizen/tizen_dotnet_project.yaml` 의 `signing_profile:` 값**
   (`.` 인지 = default 가설 확정)
2. `tz --version`
3. 빌드 환경 (desktop GUI / SSH / CI)
4. 빌드 로그의 `Using default certificates` / `signed with Default Certificates` 유무

---

## 10. 결론

- **확정:** dummy 출처 = `.NET` 빌드의 `AuthorPath==''` default 폴백. 3.44 가 취약한 건
  "재서명 안전망 제거 + 프로파일 yaml 경유"(PR #595 회귀). 패치 = dummy 출고 전 경고.
- **미확정:** reporter 환경에서 **왜** `signing_profile`/tz 가 default 로 갔는지 — yaml 값 확인 시 못박힘.
- 패치는 트리거가 무엇이든 출고 전 사용자에게 알림.
