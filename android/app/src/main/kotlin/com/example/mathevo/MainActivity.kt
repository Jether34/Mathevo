package com.example.mathevo

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

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
