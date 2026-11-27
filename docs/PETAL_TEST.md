# Petal Ads commissioning build

The standard Android preset does not package the Huawei SDK. The commissioning build uses the separate package `com.mhmmad.hexivra.petaltest` so that it can be installed alongside the existing app. Its native bridge is activated only in debuggable builds.

Use the Android source template matching Godot 4.7.2, JDK 17, Android SDK Platform 36 and Build Tools 36.1.0. Configure their paths in Godot's Android editor settings and provide debug signing credentials.

```sh
android-petal/build-test.sh /path/to/android_source.zip build/Hexivra-petal-test.apk
```

Settings includes a commissioning consent page in all three languages. Petal requests begin only after the tester consents through that page. Testers can withdraw consent in the same place. Huawei may process device and network information and ad interactions as described in its [Ads SDK Privacy Statement](https://developer.huawei.com/consumer/en/doc/hmscore-guides/whale-hong-kinetic-energy-sdk-privacy-statement-0000001658283582/). The bridge requests non-personalised delivery with location-based requests disabled. The standard build's privacy notice covers the offline build.

The GitHub Actions workflow also accepts the optional `petal_test` input to build and verify this APK independently of the standard debug artefact.

The SDK uses Huawei Maven's banner and interstitial modules at 13.4.91.300 and its consent module at 3.4.91.300. The two IDs are the official [banner test placement](https://developer.huawei.com/consumer/en/doc/hmscore-guides/publisher-service-banner-0000001057202899/) and [interstitial test placement](https://developer.huawei.com/consumer/en/doc/HMSCore-Guides/publisher-service-interstitial-0000001050064970/). The banner is restricted to Home and Gameplay. The interstitial runs only on a requested next-level transition after a win, with a minimum 90-second interval. If no ad is loaded, the next level starts immediately.

This mode is for Huawei testing. Before including ads in the production APK, obtain the production placements through the publisher account, determine supported devices and regions, configure category restrictions, update the app's production privacy policy, and verify consent, banner placement and ad readiness on device.
