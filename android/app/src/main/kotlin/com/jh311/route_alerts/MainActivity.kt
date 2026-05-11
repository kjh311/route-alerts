package com.jh311.haul_alerts

import android.os.Bundle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Handle the splash screen transition before calling super.onCreate()
        installSplashScreen()

        super.onCreate(savedInstanceState)
    }
}
