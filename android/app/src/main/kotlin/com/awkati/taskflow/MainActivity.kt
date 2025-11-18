package com.awkati.taskflow

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.media.MediaRecorder
import android.os.Build
import java.io.File
import java.io.IOException
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.content.Intent
import android.app.Activity
import android.net.Uri
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.awkati.taskflow/audio_recorder"
    private val FILE_PICKER_CHANNEL = "com.awkati.taskflow/file_picker"
    private var mediaRecorder: MediaRecorder? = null
    private var audioFilePath: String? = null
    private var isRecording = false
    private var pendingResult: MethodChannel.Result? = null
    private val PICK_AUDIO_FILE = 12345

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startRecording" -> {
                    startRecording(result)
                }
                "stopRecording" -> {
                    stopRecording(result)
                }
                "isRecording" -> {
                    result.success(isRecording)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // File picker channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILE_PICKER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickAudioFile" -> {
                    pendingResult = result
                    openSystemFilePicker()
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun startRecording(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            result.error("PERMISSION_DENIED", "Microphone permission not granted", null)
            return
        }

        try {
            // Create file path
            val fileName = "recording_${System.currentTimeMillis()}.m4a"
            val storageDir = File(cacheDir, "recordings")
            if (!storageDir.exists()) {
                storageDir.mkdirs()
            }
            audioFilePath = File(storageDir, fileName).absolutePath

            // Initialize MediaRecorder
            mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }

            mediaRecorder?.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioEncodingBitRate(128000)
                setAudioSamplingRate(44100)
                setOutputFile(audioFilePath)
                
                prepare()
                start()
            }

            isRecording = true
            result.success(audioFilePath)
        } catch (e: IOException) {
            result.error("RECORDING_ERROR", "Failed to start recording: ${e.message}", null)
        }
    }

    private fun stopRecording(result: MethodChannel.Result) {
        if (!isRecording) {
            result.error("NOT_RECORDING", "No recording in progress", null)
            return
        }

        try {
            mediaRecorder?.apply {
                stop()
                release()
            }
            mediaRecorder = null
            isRecording = false

            // Check if file exists and return its path
            val file = File(audioFilePath ?: "")
            if (file.exists()) {
                result.success(mapOf(
                    "path" to audioFilePath,
                    "size" to file.length()
                ))
            } else {
                result.error("FILE_NOT_FOUND", "Recording file not found", null)
            }
        } catch (e: Exception) {
            result.error("STOP_ERROR", "Failed to stop recording: ${e.message}", null)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (isRecording) {
            mediaRecorder?.release()
            mediaRecorder = null
        }
    }
    
    // File picker methods
    private fun openSystemFilePicker() {
        val intent = Intent(Intent.ACTION_GET_CONTENT)
        intent.type = "audio/*"
        intent.addCategory(Intent.CATEGORY_OPENABLE)
        // This is important - it tells Android to show all sources
        intent.putExtra(Intent.EXTRA_LOCAL_ONLY, false)
        
        // Create chooser to ensure all apps are shown
        val chooserIntent = Intent.createChooser(intent, "Select Audio File")
        
        try {
            startActivityForResult(chooserIntent, PICK_AUDIO_FILE)
        } catch (e: Exception) {
            pendingResult?.error("ERROR", "Failed to open file picker: ${e.message}", null)
            pendingResult = null
        }
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == PICK_AUDIO_FILE && resultCode == Activity.RESULT_OK) {
            data?.data?.let { uri ->
                try {
                    val filePath = copyUriToFile(uri)
                    pendingResult?.success(mapOf(
                        "path" to filePath,
                        "name" to getFileName(uri)
                    ))
                } catch (e: Exception) {
                    pendingResult?.error("ERROR", "Failed to process file: ${e.message}", null)
                }
            } ?: run {
                pendingResult?.error("ERROR", "No file selected", null)
            }
        } else {
            pendingResult?.error("CANCELLED", "File selection cancelled", null)
        }
        pendingResult = null
    }
    
    private fun copyUriToFile(uri: Uri): String {
        val inputStream = contentResolver.openInputStream(uri)
        val fileName = "audio_${System.currentTimeMillis()}.tmp"
        val file = File(cacheDir, fileName)
        
        inputStream?.use { input ->
            FileOutputStream(file).use { output ->
                input.copyTo(output)
            }
        }
        
        return file.absolutePath
    }
    
    private fun getFileName(uri: Uri): String {
        var name = "audio_file"
        val cursor = contentResolver.query(uri, null, null, null, null)
        cursor?.use {
            if (it.moveToFirst()) {
                val nameIndex = it.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                if (nameIndex != -1) {
                    name = it.getString(nameIndex)
                }
            }
        }
        return name
    }
}