package com.example.lifelink

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.view.WindowManager

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Clinical records must not appear in screenshots, screen recordings,
        // or Android's recent-apps preview.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
}
