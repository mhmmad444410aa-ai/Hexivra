# Verification and release status

## Verified in this rebuild

| Check | Result |
| --- | --- |
| Godot | Godot 4.7.2 Stable imported the geometry, textures, UI and audio and launched the main scene. |
| Campaign and procedural generation | 400 campaign levels plus 1,000 generated cases spanning all eight modes. The tests replayed each hint chain, checked the resulting connections and mode conditions, checked deterministic starting masks and rejected exact campaign duplicates. |
| Runtime and persistence | The scene test visited the six primary screens and the achievements, pause and timeout screens. It exercised all eight mode entry points, projected a synthetic touch onto the 3D board, and checked resume, all three settings translations, Arabic RTL, hints, duplicate reward prevention and simulated ad transition failures. |
| Rendered screens | Six portrait captures came from the running Godot project on a Linux virtual display with OpenGL Compatibility and Mesa software rendering. Arabic layout and energized tracks were visually reviewed. |
| Android package | The debug export was built with the official Godot templates and verified with Android build-tools 36. See the workflow artifact for the signed debug binary and its separate size, hash, certificate and manifest reports. |
| Public privacy notice | The [immutable HTTPS copy](https://raw.githubusercontent.com/mhmmad444410aa-ai/Hexivra/34974c64257a812bd4710bcbe6e2e29fe155025b/docs/PRIVACY.md) returned HTTP 200 without credentials. |

## Still open before store submission

- Physical touch, vibration, audio output, Android installation and launch, offline airplane mode, app updates over the original APK, memory, frame time, and Huawei compatibility require device or emulator verification. Desktop software rendering does not establish mobile performance.
- The standard APK has no advertising SDK. The separate [Petal test integration](PETAL_TEST.md) uses official test-only banner and interstitial placements. It is limited to debugging. Huawei-device delivery, production-region consent, category restrictions and production placements are open. Update the privacy notice, including the SDK's data processing and consent controls, before enabling production ads. The documentation currently identifies Ads SDK 13.4.91.300 and Consent SDK 3.4.91.300. See the [integration guide](https://developer.huawei.com/consumer/en/doc/HMSCore-Guides/publisher-service-integrating-sdk-0000001050066913/), [consent guide](https://developer.huawei.com/consumer/en/doc/hmscore-guides/publisher-service-consent-settings-0000001075342977/) and [publisher restrictions](https://developer.huawei.com/consumer/en/doc/monetize/restriction-0000001061730052/).
- Verify the prior version code and original certificate fingerprint in AppGallery Connect for app 118757677. The account's original keystore, private signing password/alias, and existing Huawei production placement IDs were unavailable to this run. The signing job reads `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD` and `KEY_ALIAS` from GitHub Secrets and checks `ORIGINAL_CERT_SHA256` and `PUBLISHED_VERSION_CODE` from repository variables. It accepts an explicit production invocation on `main` after `PRODUCTION_READY` is set. Set that variable only after closing the release items. The workflow does not generate a production key.
- The existing GitHub prototype's `progress.cfg` fields are carried forward. The historical AppGallery build's save format and data migration remain unverified.
- The asset gaps and substitutions are recorded in [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md). Additional polish remains in the level-map connections, transition effects, particle budgeting and asset batching. The store drafts include desktop captures, still images and a silent gameplay video. Android storefront captures are pending.
- AppGallery's [content guidelines](https://developer.huawei.com/consumer/en/doc/app/50104-04/) cover originality, content quality and similar submissions. Huawei's [policy centre](https://developer.huawei.com/consumer/en/doc/start/policycenter-0000001053129900/) and [release guidelines](https://developer.huawei.com/consumer/en/doc/app/agc-help-release-app-guide-0000002287176372/) cover distribution and the review process. [Chapter 7](https://developer.huawei.com/consumer/en/doc/app/50104-07/) calls for an easy-to-find in-game privacy link and a matching submission URL. This branch is a tested development build and has not gone through store review.

## Store materials

[Descriptions, search terms, icon, feature graphic and real in-engine captures](store/LISTING.md)
