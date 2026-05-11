package com.example.pipze

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.webkit.WebView

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Disable WebView logging and frame rate logs
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.KITKAT) {
            WebView.setWebContentsDebuggingEnabled(false)
        }
        
        // Disable verbose logging for WebView components
        try {
            // Set log level to reduce noise
            System.setProperty("android.webkit.WebView.EnableSafeBrowsing", "false")
            System.setProperty("android.webkit.WebView.MetricsOptOut", "true")
            
            // Disable GPU logging
            System.setProperty("debug.egl.debug_messages", "0")
            System.setProperty("debug.gpu.debug_messages", "0")
            System.setProperty("debug.gpu.profiler", "0")
            System.setProperty("debug.gpu.use_profiler", "0")
            
            // Suppress specific log tags at system level
            // ASSERT level suppresses all logs for these tags
            System.setProperty("log.tag.View", "ASSERT")
            System.setProperty("log.tag.ImageReader_JNI", "ASSERT")
            System.setProperty("log.tag.GPUAUX", "ASSERT")
            
            // Disable View frame rate logging
            System.setProperty("debug.view.frame_rate", "0")
            System.setProperty("debug.view.requested_frame_rate", "0")
            
            // Disable ImageReader verbose logging
            System.setProperty("debug.imagereader", "0")
            
            // Additional ImageReader buffer suppression
            System.setProperty("log.tag.ImageReader", "ASSERT")
            System.setProperty("log.tag.BufferQueue", "ASSERT")
            
            // Suppress buffer-related warnings
            System.setProperty("debug.buffer.verbose", "0")
            System.setProperty("debug.buffer.warning", "0")
            
        } catch (e: Exception) {
            // Silently fail - don't log errors about logging suppression
        }
    }
}
