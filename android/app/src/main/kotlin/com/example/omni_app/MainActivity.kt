package com.example.omni_app

import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity: FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Disables the window inset barrier so Flutter renders behind the camera notch and navigation bar
        WindowCompat.setDecorFitsSystemWindows(window, false)

        // Crucial: Disables Android's automatic system bar dark scrims/letterboxes
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isStatusBarContrastEnforced = false
            window.isNavigationBarContrastEnforced = false
        }
    }
}