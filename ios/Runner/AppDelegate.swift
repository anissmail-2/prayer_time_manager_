import UIKit
import Flutter
import AVFoundation
import Speech

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    // Audio recording
    private var audioRecorder: AVAudioRecorder?
    private var recordingSession: AVAudioSession?
    private var audioFileURL: URL?

    // Speech recognition
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Initialize Flutter
        let controller: FlutterViewController = window?.rootViewController as! FlutterViewController

        // Setup audio recorder channel
        let audioRecorderChannel = FlutterMethodChannel(
            name: "com.awkati.taskflow/audio_recorder",
            binaryMessenger: controller.binaryMessenger
        )

        audioRecorderChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            self?.handleMethodCall(call: call, result: result)
        }

        // Initialize audio session
        setupAudioSession()

        // Initialize speech recognizer
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - Audio Session Setup

    private func setupAudioSession() {
        recordingSession = AVAudioSession.sharedInstance()

        do {
            try recordingSession?.setCategory(.playAndRecord, mode: .default)
            try recordingSession?.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error.localizedDescription)")
        }
    }

    // MARK: - Method Channel Handler

    private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startRecording":
            startRecording(result: result)
        case "stopRecording":
            stopRecording(result: result)
        case "pickAudioFile":
            pickAudioFile(result: result)
        case "requestMicrophonePermission":
            requestMicrophonePermission(result: result)
        case "requestSpeechPermission":
            requestSpeechPermission(result: result)
        case "startSpeechRecognition":
            startSpeechRecognition(result: result)
        case "stopSpeechRecognition":
            stopSpeechRecognition(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Recording Methods

    private func startRecording(result: @escaping FlutterResult) {
        // Check microphone permission
        guard recordingSession?.recordPermission == .granted else {
            result(FlutterError(code: "PERMISSION_DENIED", message: "Microphone permission not granted", details: nil))
            return
        }

        // Create temporary file URL
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        audioFileURL = tempDirectory.appendingPathComponent(fileName)

        guard let audioFileURL = audioFileURL else {
            result(FlutterError(code: "FILE_ERROR", message: "Failed to create audio file URL", details: nil))
            return
        }

        // Configure audio settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            // Create and start recorder
            audioRecorder = try AVAudioRecorder(url: audioFileURL, settings: settings)
            audioRecorder?.record()

            result(audioFileURL.path)
        } catch {
            result(FlutterError(code: "RECORDING_ERROR", message: "Failed to start recording: \(error.localizedDescription)", details: nil))
        }
    }

    private func stopRecording(result: @escaping FlutterResult) {
        guard let recorder = audioRecorder, recorder.isRecording else {
            result(FlutterError(code: "NOT_RECORDING", message: "No active recording", details: nil))
            return
        }

        recorder.stop()

        if let audioFileURL = audioFileURL {
            result(audioFileURL.path)
        } else {
            result(FlutterError(code: "FILE_ERROR", message: "Audio file URL is nil", details: nil))
        }
    }

    private func pickAudioFile(result: @escaping FlutterResult) {
        // Use document picker for audio files
        let documentPicker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.audio],
            asCopy: true
        )

        // Note: This requires implementing UIDocumentPickerDelegate
        // For now, return not implemented
        result(FlutterMethodNotImplemented)
    }

    // MARK: - Permission Methods

    private func requestMicrophonePermission(result: @escaping FlutterResult) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                result(granted)
            }
        }
    }

    private func requestSpeechPermission(result: @escaping FlutterResult) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    result(true)
                case .denied, .restricted, .notDetermined:
                    result(false)
                @unknown default:
                    result(false)
                }
            }
        }
    }

    // MARK: - Speech Recognition Methods

    private func startSpeechRecognition(result: @escaping FlutterResult) {
        // Check permissions
        guard speechRecognizer?.isAvailable == true else {
            result(FlutterError(code: "NOT_AVAILABLE", message: "Speech recognition not available", details: nil))
            return
        }

        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            result(FlutterError(code: "PERMISSION_DENIED", message: "Speech recognition permission not granted", details: nil))
            return
        }

        // Cancel previous task if exists
        recognitionTask?.cancel()
        recognitionTask = nil

        // Initialize audio engine if needed
        if audioEngine == nil {
            audioEngine = AVAudioEngine()
        }

        guard let audioEngine = audioEngine else {
            result(FlutterError(code: "ENGINE_ERROR", message: "Failed to initialize audio engine", details: nil))
            return
        }

        do {
            // Configure audio session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            // Create recognition request
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

            guard let recognitionRequest = recognitionRequest else {
                result(FlutterError(code: "REQUEST_ERROR", message: "Failed to create recognition request", details: nil))
                return
            }

            recognitionRequest.shouldReportPartialResults = true

            // Get input node
            let inputNode = audioEngine.inputNode

            // Start recognition task
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] recognitionResult, error in
                if let error = error {
                    print("Speech recognition error: \(error.localizedDescription)")
                    self?.stopSpeechRecognition(result: { _ in })
                    return
                }

                if let recognitionResult = recognitionResult {
                    let transcription = recognitionResult.bestTranscription.formattedString
                    // Send transcription back to Flutter via event channel
                    // For now, print to console
                    print("Transcription: \(transcription)")
                }
            }

            // Configure recording format
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }

            // Start audio engine
            audioEngine.prepare()
            try audioEngine.start()

            result("Speech recognition started")

        } catch {
            result(FlutterError(code: "START_ERROR", message: "Failed to start speech recognition: \(error.localizedDescription)", details: nil))
        }
    }

    private func stopSpeechRecognition(result: @escaping FlutterResult) {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil

        result("Speech recognition stopped")
    }
}
