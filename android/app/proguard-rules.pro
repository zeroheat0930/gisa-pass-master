# R8 / ProGuard 규칙
#
# 코드·리소스 축소를 켜면서(build.gradle.kts 의 release 블록) 함께 들어왔다.
# Flutter 는 엔진과 플러그인 유지 규칙을 자동으로 넣어주므로 대부분은 비어 있어도
# 되지만, **리플렉션으로 접근하는 클래스는 R8 이 이름을 바꾸거나 지워버린다.**
# 그런 것들만 여기서 붙잡는다. 릴리즈 빌드에서만 터지므로 디버그로는 안 잡힌다.

# ── 결제 ──────────────────────────────────────────────────────────────────
# Play Billing 은 응답 객체를 리플렉션으로 다룬다. 지워지면 구매가 조용히
# 실패하는데, 이 앱은 실제 매출이 나는 앱이라 가장 위험한 자리다.
-keep class com.android.vending.billing.** { *; }
-keep class com.android.billingclient.api.** { *; }

# ── 광고 ──────────────────────────────────────────────────────────────────
# AdMob 은 광고 포맷 클래스를 이름으로 찾는다.
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }

# ── 알림 ──────────────────────────────────────────────────────────────────
# flutter_local_notifications 는 예약 알림을 GSON 으로 직렬화해 두었다가
# 부팅 후 되살린다. 필드 이름이 바뀌면 예약해둔 알림이 살아나지 못한다.
-keep class com.dexterous.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keepattributes Signature
-keepattributes *Annotation*

# ── 진단 ──────────────────────────────────────────────────────────────────
# 크래시 리포트에서 줄 번호를 읽을 수 있게 남긴다. 파일 이름은 감춘다.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
