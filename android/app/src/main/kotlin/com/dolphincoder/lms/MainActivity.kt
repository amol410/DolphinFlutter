package com.dolphincoder.lms

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
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
                    "isRecognitionAvailable" -> {
                        val available = SpeechRecognizer.isRecognitionAvailable(this@MainActivity)
                        Log.d(TAG, "MethodChannel: isRecognitionAvailable -> $available")
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
