package com.dolphincoder.lms

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.SpeechRecognizer
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "DolphinSpeechLifecycle"
        private const val CHANNEL = "com.dolphincoder.lms/speech_lifecycle"
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var methodChannel: MethodChannel? = null
    private var audioManager: AudioManager? = null
    private var isBecomingNoisyRegistered = false
    private var isScoActive = false

    // Cached optimal speech recognition engine to prevent repeated IPC test queries and AIDL churn
    private var cachedOptimalComponent: ComponentName? = null
    private var cachedTier: String = "none"
    private var cachedPackage: String = ""
    private var cachedServiceName: String = ""
    private var hasResolvedOptimalEngine: Boolean = false

    // 1. BECOMING NOISY: Dispatched by Android when headphones/Bluetooth disconnect during playback
    private val becomingNoisyReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (AudioManager.ACTION_AUDIO_BECOMING_NOISY == intent?.action) {
                Log.d(TAG, "Audio becoming noisy: headphones disconnected, pausing audio in Flutter")
                mainHandler.post {
                    methodChannel?.invokeMethod("onAudioBecomingNoisy", null)
                }
            }
        }
    }

    // 2. AUDIO FOCUS: Dispatched when an external app (phone call, alarm) requests audio focus
    private val audioFocusChangeListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
        when (focusChange) {
            AudioManager.AUDIOFOCUS_LOSS,
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                Log.d(TAG, "AudioFocus lost transient/permanent: notifying Flutter to pause audio")
                mainHandler.post {
                    methodChannel?.invokeMethod("onAudioFocusLost", null)
                }
            }
            AudioManager.AUDIOFOCUS_GAIN -> {
                Log.d(TAG, "AudioFocus regained")
                mainHandler.post {
                    methodChannel?.invokeMethod("onAudioFocusGained", null)
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "destroyRecognizer" -> {
                        Log.d(TAG, "MethodChannel: destroyRecognizer requested from Flutter")
                        forceReleaseRecognizer()
                        result.success(true)
                    }
                    "ensureOptimalSpeechEngine" -> {
                        val res = resolveAndPrepareOptimalSpeechEngine()
                        Log.d(TAG, "MethodChannel: ensureOptimalSpeechEngine -> $res")
                        result.success(res)
                    }
                    "isRecognitionAvailable" -> {
                        val res = resolveAndPrepareOptimalSpeechEngine()
                        val available = res["isAvailable"] as? Boolean ?: false
                        Log.d(TAG, "MethodChannel: isRecognitionAvailable -> $available (${res["tier"]})")
                        result.success(available)
                    }
                    "isBluetoothHeadsetConnected" -> {
                        val connected = checkBluetoothHeadsetConnected()
                        Log.d(TAG, "MethodChannel: isBluetoothHeadsetConnected -> $connected")
                        result.success(connected)
                    }
                    "startBluetoothSco" -> {
                        val started = startBluetoothScoVoiceRouting()
                        Log.d(TAG, "MethodChannel: startBluetoothSco -> $started")
                        result.success(started)
                    }
                    "stopBluetoothSco" -> {
                        stopBluetoothScoVoiceRouting()
                        Log.d(TAG, "MethodChannel: stopBluetoothSco")
                        result.success(true)
                    }
                    "requestAudioFocus" -> {
                        val granted = requestAppAudioFocus()
                        result.success(granted)
                    }
                    "abandonAudioFocus" -> {
                        abandonAppAudioFocus()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        registerBecomingNoisyReceiver()
    }

    private fun registerBecomingNoisyReceiver() {
        if (!isBecomingNoisyRegistered) {
            try {
                val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
                registerReceiver(becomingNoisyReceiver, filter)
                isBecomingNoisyRegistered = true
                Log.d(TAG, "Registered ACTION_AUDIO_BECOMING_NOISY receiver successfully")
            } catch (e: Exception) {
                Log.w(TAG, "Failed to register becomingNoisyReceiver: ${e.message}")
            }
        }
    }

    private fun unregisterBecomingNoisyReceiver() {
        if (isBecomingNoisyRegistered) {
            try {
                unregisterReceiver(becomingNoisyReceiver)
                isBecomingNoisyRegistered = false
                Log.d(TAG, "Unregistered ACTION_AUDIO_BECOMING_NOISY receiver")
            } catch (e: Exception) {
                Log.w(TAG, "Error unregistering becomingNoisyReceiver: ${e.message}")
            }
        }
    }

    private fun checkBluetoothHeadsetConnected(): Boolean {
        val am = audioManager ?: return false
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val devices = am.getDevices(AudioManager.GET_DEVICES_INPUTS)
                devices.any { device ->
                    device.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                    device.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP
                }
            } else {
                @Suppress("DEPRECATION")
                am.isBluetoothScoAvailableOffCall
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error checking Bluetooth headset status: ${e.message}")
            false
        }
    }

    private fun startBluetoothScoVoiceRouting(): Boolean {
        val am = audioManager ?: return false
        return try {
            if (checkBluetoothHeadsetConnected()) {
                am.mode = AudioManager.MODE_IN_COMMUNICATION
                am.startBluetoothSco()
                am.isBluetoothScoOn = true
                isScoActive = true
                Log.d(TAG, "Bluetooth SCO voice routing activated (MODE_IN_COMMUNICATION)")
                true
            } else {
                Log.d(TAG, "No Bluetooth headset connected; using standard microphone")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error starting Bluetooth SCO: ${e.message}")
            false
        }
    }

    private fun stopBluetoothScoVoiceRouting() {
        val am = audioManager ?: return
        if (isScoActive) {
            try {
                am.isBluetoothScoOn = false
                am.stopBluetoothSco()
                am.mode = AudioManager.MODE_NORMAL
                isScoActive = false
                Log.d(TAG, "Bluetooth SCO voice routing stopped (restored MODE_NORMAL)")
            } catch (e: Exception) {
                Log.w(TAG, "Error stopping Bluetooth SCO: ${e.message}")
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun requestAppAudioFocus(): Boolean {
        val am = audioManager ?: return true
        return try {
            val result = am.requestAudioFocus(
                audioFocusChangeListener,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
            )
            result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        } catch (e: Exception) {
            Log.w(TAG, "Error requesting audio focus: ${e.message}")
            true
        }
    }

    @Suppress("DEPRECATION")
    private fun abandonAppAudioFocus() {
        val am = audioManager ?: return
        try {
            am.abandonAudioFocus(audioFocusChangeListener)
        } catch (e: Exception) {
            Log.w(TAG, "Error abandoning audio focus: ${e.message}")
        }
    }

    override fun onPause() {
        super.onPause()
        Log.d(TAG, "Activity onPause: releasing SpeechRecognizer & SCO")
        stopBluetoothScoVoiceRouting()
        forceReleaseRecognizer()
    }

    override fun onStop() {
        super.onStop()
        Log.d(TAG, "Activity onStop: releasing SpeechRecognizer & SCO")
        stopBluetoothScoVoiceRouting()
        forceReleaseRecognizer()
    }

    override fun onDestroy() {
        Log.d(TAG, "Activity onDestroy: releasing all audio resources")
        unregisterBecomingNoisyReceiver()
        stopBluetoothScoVoiceRouting()
        abandonAppAudioFocus()
        forceReleaseRecognizer()
        super.onDestroy()
    }

    // 3. TIERED SPEECH ENGINE RESOLUTION (Tier 1: Google -> Tier 2: OEM -> Tier 3: Safety Net)
    private fun resolveAndPrepareOptimalSpeechEngine(): Map<String, Any> {
        if (hasResolvedOptimalEngine) {
            val isAvailable = cachedTier != "none"
            var injected = false
            if (isAvailable) {
                injected = injectOptimalRecognizerIntoPlugin(cachedOptimalComponent)
            }
            return mapOf(
                "isAvailable" to isAvailable,
                "tier" to cachedTier,
                "packageName" to cachedPackage,
                "serviceName" to cachedServiceName,
                "injected" to injected
            )
        }

        val pm = packageManager
        val intent = Intent("android.speech.RecognitionService")
        val services = pm.queryIntentServices(intent, 0)

        Log.d(TAG, "Speech Recognition Services detected on device: ${services.size}")
        services.forEach {
            Log.d(TAG, "  -> Service: ${it.serviceInfo.packageName} / ${it.serviceInfo.name}")
        }

        var selectedComponent: ComponentName? = null
        var selectedTier = "none"
        var selectedPackage = ""
        var selectedServiceName = ""

        // Tier 1: Try Google's official Speech Recognition Service
        // Priority: Speech Services by Google (com.google.android.tts) — unified STT+TTS engine
        // with offline language pack support (German, English, etc.), then Google App as fallback.
        // Note: com.google.android.as (Android System Intelligence / Soda) is excluded because
        // its ambient recognizer lacks offline packs for non-English languages.
        val googlePackages = listOf(
            "com.google.android.tts",
            "com.google.android.googlequicksearchbox"
        )
        for (pkg in googlePackages) {
            val match = services.firstOrNull { it.serviceInfo.packageName == pkg }
            if (match != null) {
                try {
                    val comp = ComponentName(match.serviceInfo.packageName, match.serviceInfo.name)
                    // Zero-Cost try-catch preflight check
                    val testRecognizer = SpeechRecognizer.createSpeechRecognizer(this@MainActivity, comp)
                    testRecognizer.destroy()
                    selectedComponent = comp
                    selectedTier = "tier1_google"
                    selectedPackage = pkg
                    selectedServiceName = match.serviceInfo.name
                    Log.d(TAG, "Tier 1 SUCCESS: Verified Google Speech Recognition ($pkg)")
                    break
                } catch (e: Exception) {
                    Log.w(TAG, "Tier 1: Google package $pkg failed test initialization: ${e.message}")
                }
            }
        }

        // Tier 2: Catch & Fallback to Phone's Native OEM Engine (Samsung, Xiaomi, Huawei, etc.)
        if (selectedComponent == null) {
            Log.d(TAG, "Tier 1 not available. Executing Tier 2 (OEM engine fallback)...")
            for (service in services) {
                val pkg = service.serviceInfo.packageName
                val name = service.serviceInfo.name

                // SAFETY FILTER: Skip Android System Intelligence (com.google.android.as)
                // Its Soda ambient recognizer lacks offline language packs for non-English languages
                if (pkg == "com.google.android.as") {
                    Log.d(TAG, "Tier 2: Skipping Android System Intelligence ($pkg) — no multi-language support")
                    continue
                }

                try {
                    val comp = ComponentName(pkg, name)
                    val testRecognizer = SpeechRecognizer.createSpeechRecognizer(this@MainActivity, comp)
                    testRecognizer.destroy()
                    selectedComponent = comp
                    selectedTier = "tier2_oem"
                    selectedPackage = pkg
                    selectedServiceName = name
                    Log.d(TAG, "Tier 2 SUCCESS: Verified OEM Speech Recognition ($pkg)")
                    break
                } catch (e: Exception) {
                    Log.w(TAG, "Tier 2: OEM service $pkg failed test initialization: ${e.message}")
                }
            }

            // If no specific OEM component matched, attempt generic platform recognizer
            if (selectedComponent == null) {
                try {
                    val defaultRecognizer = SpeechRecognizer.createSpeechRecognizer(this@MainActivity)
                    defaultRecognizer.destroy()
                    selectedTier = "tier2_default"
                    selectedPackage = "android.platform.default"
                    Log.d(TAG, "Tier 2 SUCCESS: Verified generic default platform SpeechRecognizer")
                } catch (e: Exception) {
                    Log.w(TAG, "Tier 2: Generic default platform SpeechRecognizer failed: ${e.message}")
                }
            }
        }

        cachedOptimalComponent = selectedComponent
        cachedTier = selectedTier
        cachedPackage = selectedPackage
        cachedServiceName = selectedServiceName
        hasResolvedOptimalEngine = true

        val isAvailable = selectedTier != "none"
        var injected = false
        if (isAvailable) {
            injected = injectOptimalRecognizerIntoPlugin(selectedComponent)
        }

        return mapOf(
            "isAvailable" to isAvailable,
            "tier" to selectedTier,
            "packageName" to selectedPackage,
            "serviceName" to selectedServiceName,
            "injected" to injected
        )
    }

    private fun injectOptimalRecognizerIntoPlugin(component: ComponentName?): Boolean {
        return try {
            val engine = flutterEngine ?: return false
            val pluginClass = try {
                Class.forName("com.csdcorp.speech_to_text.SpeechToTextPlugin")
            } catch (e: ClassNotFoundException) {
                null
            } ?: return false

            @Suppress("UNCHECKED_CAST")
            val plugin = engine.plugins.get(pluginClass as Class<out io.flutter.embedding.engine.plugins.FlutterPlugin>)
                ?: return false

            val field = plugin.javaClass.getDeclaredField("speechRecognizer")
            field.isAccessible = true
            val existing = field.get(plugin) as? SpeechRecognizer
            if (existing != null) {
                // Already injected and active: reuse to prevent Google App IPC churn
                Log.d(TAG, "Reusing existing active SpeechRecognizer in SpeechToTextPlugin")
                return true
            }

            val newRecognizer = if (component != null) {
                SpeechRecognizer.createSpeechRecognizer(this@MainActivity, component)
            } else {
                SpeechRecognizer.createSpeechRecognizer(this@MainActivity)
            }
            newRecognizer.setRecognitionListener(plugin as RecognitionListener)
            field.set(plugin, newRecognizer)
            Log.d(TAG, "Injected optimal SpeechRecognizer (component=$component) into SpeechToTextPlugin")
            true
        } catch (e: Exception) {
            Log.w(TAG, "Notice on SpeechToTextPlugin recognizer injection: ${e.message}")
            false
        }
    }

    private fun forceReleaseRecognizer() {
        mainHandler.post {
            try {
                val engine = flutterEngine ?: return@post
                val pluginClass = try {
                    Class.forName("com.csdcorp.speech_to_text.SpeechToTextPlugin")
                } catch (e: ClassNotFoundException) {
                    null
                }

                if (pluginClass != null) {
                    @Suppress("UNCHECKED_CAST")
                    val plugin = engine.plugins.get(pluginClass as Class<out io.flutter.embedding.engine.plugins.FlutterPlugin>)
                    if (plugin != null) {
                        try {
                            val field = plugin.javaClass.getDeclaredField("speechRecognizer")
                            field.isAccessible = true
                            val recognizer = field.get(plugin) as? SpeechRecognizer
                            if (recognizer != null) {
                                Log.d(TAG, "Releasing native SpeechRecognizer instance: $recognizer")
                                recognizer.cancel()
                                recognizer.destroy()
                                field.set(plugin, null)
                                Log.d(TAG, "Native SpeechRecognizer destroyed and nullified successfully")
                            } else {
                                Log.d(TAG, "speechRecognizer field was already null or inactive")
                            }
                        } catch (e: Exception) {
                            Log.w(TAG, "Reflection cleanup on speech_to_text plugin failed: ${e.message}")
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in forceReleaseRecognizer: ${e.message}")
            }
        }
    }
}
