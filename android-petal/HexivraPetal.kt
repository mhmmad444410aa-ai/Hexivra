package com.mhmmad.hexivra.ads

import android.app.Activity
import android.content.pm.ApplicationInfo
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import com.huawei.hms.ads.AdListener
import com.huawei.hms.ads.AdParam
import com.huawei.hms.ads.BannerAdSize
import com.huawei.hms.ads.HwAds
import com.huawei.hms.ads.InterstitialAd
import com.huawei.hms.ads.RequestOptions
import com.huawei.hms.ads.banner.BannerView
import com.huawei.hms.ads.consent.constant.ConsentStatus
import com.huawei.hms.ads.consent.inter.Consent
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import kotlin.math.roundToInt

/** Debug-only bridge for official test placements on Huawei devices. */
class HexivraPetal(godot: Godot) : GodotPlugin(godot) {
    private var banner: BannerView? = null
    private var interstitial: InterstitialAd? = null
    private var bannerWanted = false
    private var bannerLoaded = false
    private var initialized = false
    private var awaitingClose = false
    private var consented = false

    @Volatile private var canShowInterstitial = false
    @Volatile private var height = 0

    override fun getPluginName() = "HexivraPetal"

    override fun getPluginSignals() = setOf(SignalInfo("transition_finished"))

    private fun testHost(): Activity? = activity?.takeIf {
        it.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
    }

    @UsedByGodot
    fun commissioningConsent(allowed: Boolean) {
        val host = testHost() ?: return
        host.runOnUiThread {
            consented = allowed
            if (!allowed) {
                canShowInterstitial = false
                banner?.destroy()
                (banner?.parent as? FrameLayout)?.removeView(banner)
                banner = null
                interstitial = null
                awaitingClose = false
                bannerLoaded = false
                height = 0
                if (!initialized) return@runOnUiThread
            }
            runCatching {
                Consent.getInstance(host).setConsentStatus(
                    if (allowed) ConsentStatus.NON_PERSONALIZED else ConsentStatus.UNKNOWN
                )
                if (allowed) {
                    if (!initialized) {
                        HwAds.init(host)
                        HwAds.setRequestOptions(RequestOptions.Builder()
                            .setNonPersonalizedAd(1)
                            .setRequestLocation(false)
                            .build())
                        initialized = true
                    }
                    updateBanner(host)
                    preloadInterstitial(host)
                }
            }
        }
    }

    @UsedByGodot
    fun showBanner(show: Boolean) {
        val host = testHost() ?: return
        host.runOnUiThread {
            bannerWanted = show
            runCatching { updateBanner(host) }
        }
    }

    @UsedByGodot
    fun bannerHeightPx(): Int = height

    override fun onMainDestroy() {
        canShowInterstitial = false
        height = 0
        banner?.destroy()
        banner = null
        interstitial = null
    }

    private fun updateBanner(host: Activity) {
        if (!bannerWanted || !consented || !initialized) {
            banner?.visibility = View.GONE
            height = 0
            return
        }
        if (banner != null) {
            if (bannerLoaded) {
                height = (50 * host.resources.displayMetrics.density).roundToInt()
                banner?.visibility = View.VISIBLE
            }
            return
        }
        val content = host.findViewById<FrameLayout>(android.R.id.content) ?: return
        val ad = BannerView(host)
        ad.adId = "testw6vs28auh3"
        ad.bannerAdSize = BannerAdSize.BANNER_SIZE_320_50
        ad.visibility = View.GONE
        ad.adListener = object : AdListener() {
            override fun onAdLoaded() {
                if (banner === ad && consented) {
                    bannerLoaded = true
                    updateBanner(host)
                }
            }

            override fun onAdFailed(errorCode: Int) {
                if (banner === ad) {
                    height = 0
                    bannerLoaded = false
                    content.removeView(ad)
                    ad.destroy()
                    banner = null
                }
            }
        }
        banner = ad
        content.addView(ad, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL,
        ))
        ad.loadAd(AdParam.Builder().build())
    }

    private fun preloadInterstitial(host: Activity) {
        if (interstitial != null || !consented) return
        val ad = InterstitialAd(host)
        ad.adId = "testb4znbuh3n2"
        ad.adListener = object : AdListener() {
            override fun onAdLoaded() {
                if (interstitial === ad && consented) canShowInterstitial = true
            }

            override fun onAdClosed() {
                canShowInterstitial = false
                interstitial = null
                endTransition()
                runCatching { preloadInterstitial(host) }
            }

            override fun onAdFailed(errorCode: Int) {
                if (interstitial !== ad) return
                canShowInterstitial = false
                interstitial = null
                endTransition()
            }
        }
        interstitial = ad
        ad.loadAd(AdParam.Builder().build())
    }

    private fun endTransition() {
        if (!awaitingClose) return
        awaitingClose = false
        emitSignal("transition_finished")
    }

    @UsedByGodot
    fun betweenLevels(): Boolean {
        val host = testHost() ?: return false
        if (!canShowInterstitial) {
            host.runOnUiThread { runCatching { preloadInterstitial(host) } }
            return false
        }
        canShowInterstitial = false
        host.runOnUiThread {
            val ad = interstitial
            awaitingClose = true
            if (ad == null || !consented || !ad.isLoaded ||
                runCatching { ad.show(host) }.isFailure) {
                interstitial = null
                endTransition()
            }
        }
        return true
    }
}
