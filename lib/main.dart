import 'dart:async';
import 'dart:io' show File;
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:microphone/microphone.dart'; // for web audio recording
import 'package:just_audio/just_audio.dart'; // for audio playback
import 'package:http/http.dart' as http;

// For web: import dart:html to fetch blob data and create download links
//import 'dart:html' as html;
import 'html_import.dart' as html;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deepspeak Demo',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: const HomeScreen(),
      routes: {
        '/recording': (context) => const RecordingScreen(),
        '/history': (context) => const RecordingsHistoryScreen(),
        '/upload': (context) => const UploadFileScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            // Center content (logo + text)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.graphic_eq,
                      size: 80,
                      color: Colors.deepPurple,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'DEEPSPEAK',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Communicate easier',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Arrow button to navigate
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/recording');
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 40),
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Colors.deepPurple,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  // Mobile/Desktop recorder:
  final Record _audioRecorder = Record();

  // Web recorder:
  MicrophoneRecorder? _webRecorder;
  bool _isInitializingWeb = false;

  bool isRecording = false;
  String? audioFilePath; // For mobile: file path; for web: blob URL.
  double pulseSize = 250;
  double opacity = 1.0;

  // For playback:
  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<String?> _getAppDirectoryPath() async {
    if (kIsWeb) {
      return null;
    } else {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    }
  }

  Future<void> _toggleRecording() async {
    if (kIsWeb) {
      if (_isInitializingWeb) return;

      if (isRecording) {
        await _webRecorder!.stop();
        final recordingUrl = _webRecorder!.value.recording?.url;
        print('Web recording URL: $recordingUrl');
        _webRecorder!.dispose();
        _webRecorder = null;
        setState(() {
          isRecording = false;
          audioFilePath = recordingUrl;
        });
      } else {
        _webRecorder = MicrophoneRecorder();
        _isInitializingWeb = true;
        await _webRecorder!.init();
        _isInitializingWeb = false;
        await _webRecorder!.start();
        setState(() {
          isRecording = true;
        });
        _startPulsatingEffect();
      }
    } else {
      if (isRecording) {
        final path = await _audioRecorder.stop();
        setState(() {
          isRecording = false;
          audioFilePath = path;
        });
        print('Recording saved at: $path');
      } else {
        if (await _audioRecorder.hasPermission()) {
          final directoryPath = await _getAppDirectoryPath();
          if (directoryPath == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Unable to get storage directory.')),
            );
            return;
          }
          final path =
              '$directoryPath/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
          await _audioRecorder.start(
            path: path,
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            samplingRate: 44100,
          );
          setState(() {
            isRecording = true;
            audioFilePath = path;
          });
          _startPulsatingEffect();
        } else {
          print("Microphone permission denied");
        }
      }
    }
  }

  void _startPulsatingEffect() {
    Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!isRecording) {
        timer.cancel();
        return;
      }
      setState(() {
        pulseSize = pulseSize == 250 ? 280 : 250;
        opacity = opacity == 1.0 ? 0.4 : 1.0;
      });
    });
  }

  /// Play the recorded audio.
  Future<void> _playRecording() async {
    if (audioFilePath == null) return;
    try {
      if (kIsWeb) {
        await _audioPlayer.setUrl(audioFilePath!);
      } else {
        await _audioPlayer.setFilePath(audioFilePath!);
      }
      _audioPlayer.play();
    } catch (e) {
      print("Error playing audio: $e");
    }
  }

  /// New method to summarize the recording.
  Future<void> _summarizeRecording() async {
    if (audioFilePath == null) return;

    // Example: Replace this with actual summarization logic.
    // Send the file to an API that returns a summary.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Summarizing the recording...")),
    );

    // For demonstration - printing the file path.
    print("Summarizing file: $audioFilePath");
    // Summarization process here.
  }

  /// Allow user to download the recording on web.
  void _downloadRecording() {
    if (!kIsWeb || audioFilePath == null) return;
    final anchor = html.AnchorElement(href: audioFilePath)
      ..download = 'recording_${DateTime.now().millisecondsSinceEpoch}.m4a'
      ..target = 'blank';
    html.document.body!.append(anchor);
    anchor.click();
    anchor.remove();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    _webRecorder?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'DEEPSPEAK',
          style: TextStyle(color: Colors.black87),
        ),
        iconTheme: const IconThemeData(color: Colors.deepPurple),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 800),
                  opacity: isRecording ? opacity : 0.0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 800),
                    width: isRecording ? pulseSize : 250,
                    height: isRecording ? pulseSize : 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.deepPurple.withOpacity(0.3),
                    ),
                  ),
                ),
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.deepPurple.shade100,
                  ),
                ),
                // Record/Stop button
                GestureDetector(
                  onTap: _toggleRecording,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isRecording
                          ? Colors.deepPurple
                          : Colors.deepPurple.shade200,
                    ),
                    child: Icon(
                      isRecording ? Icons.stop : Icons.mic,
                      size: 48,
                      color: isRecording ? Colors.white : Colors.deepPurple,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            // Playback, Summarize and Download buttons (Download button shown only on web)
            if (audioFilePath != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _playRecording,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text("Play"),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton.icon(
                    onPressed: _summarizeRecording,
                    icon: const Icon(Icons.summarize),
                    label: const Text("Summarize"),
                  ),
                  if (kIsWeb) ...[
                    const SizedBox(width: 20),
                    ElevatedButton.icon(
                      onPressed: _downloadRecording,
                      icon: const Icon(Icons.download),
                      label: const Text("Download"),
                    ),
                  ]
                ],
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.transparent,
        elevation: 0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.history),
              color: Colors.deepPurple,
              onPressed: () {
                Navigator.pushNamed(context, '/history');
              },
            ),
            IconButton(
              icon: const Icon(Icons.upload_file),
              color: Colors.deepPurple,
              onPressed: () {
                Navigator.pushNamed(context, '/upload');
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              color: Colors.deepPurple,
              onPressed: () {
                Navigator.pushNamed(context, '/settings');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class RecordingsHistoryScreen extends StatelessWidget {
  const RecordingsHistoryScreen({super.key});

  final List<Map<String, String>> dummyRecordings = const [
    {
      'title': 'Recording 1',
      'date': '2025-02-01',
      'summary': 'Discussing project requirements and timelines.'
    },
    {
      'title': 'Recording 2',
      'date': '2025-02-05',
      'summary': 'Brainstorm session on new marketing strategies.'
    },
    {
      'title': 'Recording 3',
      'date': '2025-02-10',
      'summary': 'Update on budget and financial forecasts.'
    },
    {
      'title': 'Recording 4',
      'date': '2025-02-14',
      'summary': 'Brief conversation about upcoming team events.'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          'Previous Recordings',
          style: TextStyle(color: Colors.black87),
        ),
        iconTheme: const IconThemeData(color: Colors.deepPurple),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView.builder(
        itemCount: dummyRecordings.length,
        itemBuilder: (context, index) {
          final recording = dummyRecordings[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.file_present, color: Colors.deepPurple),
              title: Text(recording['title'] ?? 'No Title'),
              subtitle: Text(
                'Date: ${recording['date']}\nSummary: ${recording['summary']}',
              ),
              isThreeLine: true,
              onTap: () {
                // TODO: Implement playback or detail view.
              },
            ),
          );
        },
      ),
    );
  }
}

class UploadFileScreen extends StatelessWidget {
  const UploadFileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // This is a placeholder UI for file upload.
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Upload a File',
            style: TextStyle(color: Colors.black87)),
        iconTheme: const IconThemeData(color: Colors.deepPurple),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(16),
          elevation: 2,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.upload_file,
                    color: Colors.deepPurple, size: 60),
                const SizedBox(height: 16),
                const Text(
                  'Upload a file to process',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Implement file picker.
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                  ),
                  child: const Text('Choose File'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Implement actual upload logic.
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                  ),
                  child: const Text('Upload'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.black87)),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: const Text('Theme Mode'),
            trailing: DropdownButton<String>(
              value: 'System',
              items: ['Light', 'Dark', 'System']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) {},
            ),
          ),
          ListTile(
            leading: const Icon(Icons.cloud),
            title: const Text('Upload recordings to cloud'),
            trailing: Switch(value: false, onChanged: (val) {}),
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Clear cache'),
            onTap: () {
              // TODO: Implement cache clearing.
            },
          ),
        ],
      ),
    );
  }
}
