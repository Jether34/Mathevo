package com.example.mathevo

import android.os.Build
import android.os.Bundle
import android.graphics.Color
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Keep the gesture navigation area visually continuous with the auth
        // sheet and suppress Android's default separator line.
        window.navigationBarColor = Color.rgb(249, 250, 255)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.navigationBarDividerColor = Color.TRANSPARENT
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val modes = windowManager.defaultDisplay.supportedModes
            val preferredRate = modes
                .map { it.refreshRate }
                .filter { it >= 143.5f && it <= 144.5f }
                .maxOrNull()

            if (preferredRate != null) {
                window.attributes = window.attributes.apply {
                    preferredRefreshRate = preferredRate
                }
            }
        }
    }
}
