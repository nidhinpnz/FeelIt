import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (!kIsWeb) {
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.example.feelit.audio',
        androidNotificationChannelName: 'Audio playback',
        androidNotificationOngoing: true,
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('JustAudioBackground init error: $e');
    }
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FeelIt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.red,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark,
          primary: Colors.red,
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[900],
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool? _isLoggedIn;
  String? _userId;
  String? _username;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      _userId = prefs.getString('userId');
      _username = prefs.getString('username');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    if (_isLoggedIn!) {
      if (_userId == null || _username == null) {
        return LoginPage(onLogin: _checkLoginStatus);
      }
      return HomeScreen(userId: _userId!, username: _username!);
    }
    
    return LoginPage(onLogin: _checkLoginStatus);
  }
}

class LoginPage extends StatefulWidget {
  final VoidCallback onLogin;
  const LoginPage({super.key, required this.onLogin});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showError('Please enter username and password');
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString('feelit_users') ?? '{}';
      final Map<String, dynamic> users = jsonDecode(usersJson);

      if (users.containsKey(username) && users[username] == password) {
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userId', 'feelit_$username');
        await prefs.setString('username', username);
        widget.onLogin();
      } else {
        _showError('Invalid username or password');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.red[900]!.withOpacity(0.5), Colors.black],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 60),
                  const Hero(
                    tag: 'logo',
                    child: Icon(Icons.music_note_rounded, size: 100, color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'FeelIt',
                    style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    textAlign: TextAlign.center,
                  ),
                  const Text(
                    'Your music, your feelings.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 60),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _login,
                        child: const Text('Sign In', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('New to FeelIt? '),
                      TextButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => RegisterPage(onLogin: widget.onLogin)));
                        },
                        child: const Text('Create Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  final VoidCallback onLogin;
  const RegisterPage({super.key, required this.onLogin});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _register() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showError('Please fill all fields');
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString('feelit_users') ?? '{}';
      final Map<String, dynamic> users = jsonDecode(usersJson);

      if (users.containsKey(username)) {
        _showError('Username already exists');
      } else {
        users[username] = password;
        await prefs.setString('feelit_users', jsonEncode(users));
        
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userId', 'feelit_$username');
        await prefs.setString('username', username);
        
        if (mounted) {
          Navigator.pop(context);
          widget.onLogin();
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account'), backgroundColor: Colors.transparent),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A1A), Colors.black],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                const Text(
                  'Join FeelIt',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('Start your musical journey today.', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 48),
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 32),
                _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _register,
                      child: const Text('Create Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final String userId;
  final String username;
  const HomeScreen({super.key, required this.userId, required this.username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  Map<String, List<Video>> _playlists = {'My Playlist': []};
  Video? _currentVideo; 
  final AudioPlayer _player = AudioPlayer();
  final YoutubeExplode _yt = YoutubeExplode();

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final namesJson = prefs.getString('user_playlists_${widget.userId}');
    List<String> names = namesJson != null ? List<String>.from(jsonDecode(namesJson)) : ['My Playlist'];
    
    Map<String, List<Video>> loadedPlaylists = {};
    for (var name in names) {
      final playlistJson = prefs.getString('playlist_${widget.userId}_$name');
      if (playlistJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(playlistJson);
          List<Video> videos = [];
          for (var id in decoded) {
            try {
              final video = await _yt.videos.get(id);
              videos.add(video);
            } catch (_) {}
          }
          loadedPlaylists[name] = videos;
        } catch (e) {
          debugPrint('Error loading playlist $name: $e');
          loadedPlaylists[name] = [];
        }
      } else {
        loadedPlaylists[name] = [];
      }
    }
    
    if (mounted) {
      setState(() => _playlists = loadedPlaylists);
    }
  }

  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_playlists_${widget.userId}', jsonEncode(_playlists.keys.toList()));
    for (var entry in _playlists.entries) {
      final List<String> ids = entry.value.map((v) => v.id.value).toList();
      await prefs.setString('playlist_${widget.userId}_${entry.key}', jsonEncode(ids));
    }
  }

  void _addToPlaylist(Video video) {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController _newPlaylistController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add to Playlist'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.3),
                    child: SingleChildScrollView(
                      child: Column(
                        children: _playlists.keys.map((name) => ListTile(
                          title: Text(name),
                          onTap: () {
                            setState(() {
                              if (!_playlists[name]!.any((v) => v.id == video.id)) {
                                _playlists[name]!.add(video);
                                _savePlaylists();
                              }
                            });
                            Navigator.pop(context);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text('Added ${video.title} to $name')),
                            );
                          },
                        )).toList(),
                      ),
                    ),
                  ),
                  const Divider(),
                  TextField(
                    controller: _newPlaylistController,
                    decoration: const InputDecoration(hintText: 'New Playlist Name'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final name = _newPlaylistController.text.trim();
                    if (name.isNotEmpty) {
                      setState(() {
                        if (!_playlists.containsKey(name)) {
                          _playlists[name] = [video];
                          _savePlaylists();
                        }
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(content: Text('Created $name and added ${video.title}')),
                      );
                    }
                  },
                  child: const Text('Create & Add'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _removeFromPlaylist(String playlistName, Video video) {
    setState(() {
      _playlists[playlistName]?.remove(video);
      _savePlaylists();
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('userId');
    await prefs.remove('username');
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _yt.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      SearchPage(yt: _yt, onPlay: _playVideo, onAddToPlaylist: _addToPlaylist),
      PlaylistPage(
        playlists: _playlists,
        onPlay: _playVideo,
        onRemove: _removeFromPlaylist,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('FeelIt - ${widget.username}'),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _logout)],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: StreamBuilder<SequenceState?>(
        stream: _player.sequenceStateStream,
        builder: (context, snapshot) {
          final state = snapshot.data;
          final showMiniPlayer = state != null && state.sequence.isNotEmpty;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showMiniPlayer) _buildMiniPlayer(),
              BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: (index) => setState(() => _selectedIndex = index),
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
                  BottomNavigationBarItem(icon: Icon(Icons.playlist_play), label: 'Playlist'),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMiniPlayer() {
    return StreamBuilder<SequenceState?>(
      stream: _player.sequenceStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (state?.sequence.isEmpty ?? true) return const SizedBox();
        final metadata = state!.currentSource!.tag as MediaItem;

        return InkWell(
          onTap: () => _showNowPlayingSheet(context, metadata),
          child: Container(
            color: Colors.grey[900],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Hero(
                  tag: 'album_art',
                  child: Image.network(metadata.artUri.toString(), width: 50, height: 50, fit: BoxFit.cover, 
                    errorBuilder: (_, __, ___) => const Icon(Icons.music_note)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(metadata.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      StreamBuilder<PlayerState>(
                        stream: _player.playerStateStream,
                        builder: (context, snapshot) {
                          final processingState = snapshot.data?.processingState;
                          if (processingState == ProcessingState.buffering || processingState == ProcessingState.loading) {
                            return const Text('Buffering...', style: TextStyle(fontSize: 12, color: Colors.red));
                          }
                          return Text(metadata.artist ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey));
                        },
                      ),
                    ],
                  ),
                ),
                _buildPlayPauseButton(32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayPauseButton(double size) {
    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final processingState = playerState?.processingState;
        final playing = playerState?.playing;

        if (processingState == ProcessingState.loading ||
            processingState == ProcessingState.buffering) {
          return Container(
            margin: const EdgeInsets.all(8.0),
            width: size,
            height: size,
            child: const CircularProgressIndicator(strokeWidth: 3, color: Colors.red),
          );
        } else if (playing != true) {
          return IconButton(
            icon: Icon(size > 40 ? Icons.play_circle_filled : Icons.play_arrow, size: size),
            onPressed: () => _player.play(),
          );
        } else if (processingState != ProcessingState.completed) {
          return IconButton(
            icon: Icon(size > 40 ? Icons.pause_circle_filled : Icons.pause, size: size),
            onPressed: () => _player.pause(),
          );
        } else {
          return IconButton(
            icon: Icon(size > 40 ? Icons.replay_circle_filled : Icons.replay, size: size),
            onPressed: () => _player.seek(Duration.zero),
          );
        }
      },
    );
  }

  void _showNowPlayingSheet(BuildContext context, MediaItem metadata) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.keyboard_arrow_down, size: 30),
              const SizedBox(height: 20),
              Hero(
                tag: 'album_art',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    metadata.artUri.toString(),
                    height: 300,
                    width: 300,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                metadata.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                metadata.artist ?? '',
                style: const TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const Spacer(),
              StreamBuilder<Duration>(
                stream: _player.positionStream,
                builder: (context, snapshot) {
                  final position = snapshot.data ?? Duration.zero;
                  final duration = _player.duration ?? Duration.zero;
                  return Column(
                    children: [
                      Slider(
                        activeColor: Colors.red,
                        inactiveColor: Colors.grey[800],
                        value: position.inSeconds.toDouble(),
                        max: duration.inSeconds.toDouble() > 0 ? duration.inSeconds.toDouble() : (position.inSeconds.toDouble() + 1),
                        onChanged: (value) => _player.seek(Duration(seconds: value.toInt())),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(position)),
                            Text(_formatDuration(duration)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous, size: 48),
                    onPressed: () => _player.seekToPrevious(),
                  ),
                  _buildPlayPauseButton(80),
                  IconButton(
                    icon: const Icon(Icons.skip_next, size: 48),
                    onPressed: () => _player.seekToNext(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_currentVideo != null) 
                ElevatedButton.icon(
                  onPressed: () => _addToPlaylist(_currentVideo!),
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('Add to Playlist'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    minimumSize: const Size(200, 50),
                  ),
                ),
              const Spacer(),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  Future<void> _playVideo(Video video) async {
    try {
      debugPrint('--- Attempting to play: ${video.title} ---');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connecting to stream...'), duration: Duration(seconds: 2)),
        );
      }
      
      setState(() {
        _currentVideo = video;
      });

      await _player.stop();
      if (kIsWeb) return;

      final manifest = await _yt.videos.streamsClient.getManifest(video.id)
          .timeout(const Duration(seconds: 30));

      final streams = manifest.audioOnly;
      if (streams.isEmpty) {
        throw Exception('No audio-only streams found for this video.');
      }

      // Optimization: Pick a standard bitrate stream (not necessarily highest) for faster loading
      final streamInfo = streams.where((s) => s.container.name == 'mp4').first;
      debugPrint('Stream URL: ${streamInfo.url}');

      await _player.setAudioSource(
        AudioSource.uri(
          streamInfo.url,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            'Referer': 'https://www.youtube.com/',
          },
          tag: MediaItem(
            id: video.id.value,
            album: video.author,
            title: video.title,
            artist: video.author,
            artUri: Uri.parse(video.thumbnails.highResUrl),
          ),
        ),
      );
      
      _player.play();
      debugPrint('Play command sent');

    } catch (e) {
      debugPrint('Playback error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        String message = 'Could not play this song. Error: ${e.toString()}';
        if (e is TimeoutException) {
          message = 'Network timeout. Check your connection.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message, maxLines: 2), duration: const Duration(seconds: 5)),
        );
      }
    }
  }
}

class SearchPage extends StatefulWidget {
  final Function(Video) onPlay;
  final Function(Video) onAddToPlaylist;
  final YoutubeExplode yt;

  const SearchPage({super.key, required this.onPlay, required this.onAddToPlaylist, required this.yt});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Video> _searchResults = [];
  bool _isSearching = false;
  String? _errorMessage;
  Timer? _debounce;

  Future<void> _search({bool shouldUnfocus = true}) async {
    if (_searchController.text.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _errorMessage = null;
      });
      return;
    }
    if (shouldUnfocus) FocusScope.of(context).unfocus();
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });
    try {
      final results = await widget.yt.search.search(_searchController.text)
          .timeout(const Duration(seconds: 15));
      if (mounted) {
        setState(() {
          _searchResults = results.toList();
          if (_searchResults.isEmpty) _errorMessage = 'No results found.';
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) {
        setState(() {
          if (e is TimeoutException) {
            _errorMessage = 'Search timed out. Please try again.';
          } else {
            _errorMessage = kIsWeb 
              ? 'Chrome is blocking the search (CORS restriction).' 
              : 'Error: $e';
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _search(shouldUnfocus: false);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search music...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty 
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    })
                  : null,
              border: const OutlineInputBorder(),
            ),
            onChanged: _onSearchChanged,
            onSubmitted: (_) => _search(shouldUnfocus: true),
          ),
        ),
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_errorMessage!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(onPressed: _search, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : _searchResults.isEmpty
                      ? const Center(child: Text('Type to find your favorite music!'))
                      : ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final video = _searchResults[index];
                            return ListTile(
                              leading: Image.network(video.thumbnails.lowResUrl, 
                                errorBuilder: (_, __, ___) => const Icon(Icons.music_video)),
                              title: Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                              subtitle: Text(video.author),
                              onTap: () => widget.onPlay(video),
                              trailing: IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () => widget.onAddToPlaylist(video),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

class PlaylistPage extends StatefulWidget {
  final Map<String, List<Video>> playlists;
  final Function(Video) onPlay;
  final Function(String, Video) onRemove;

  const PlaylistPage({super.key, required this.playlists, required this.onPlay, required this.onRemove});

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  String? _selectedPlaylist;

  @override
  Widget build(BuildContext context) {
    if (_selectedPlaylist == null) {
      return widget.playlists.isEmpty
          ? const Center(child: Text('No playlists found.'))
          : ListView.builder(
              itemCount: widget.playlists.length,
              itemBuilder: (context, index) {
                final name = widget.playlists.keys.elementAt(index);
                final count = widget.playlists[name]?.length ?? 0;
                return ListTile(
                  leading: const Icon(Icons.playlist_play, color: Colors.red),
                  title: Text(name),
                  subtitle: Text('$count songs'),
                  onTap: () => setState(() => _selectedPlaylist = name),
                );
              },
            );
    }

    final songs = widget.playlists[_selectedPlaylist] ?? [];
    return Column(
      children: [
        ListTile(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _selectedPlaylist = null),
          ),
          title: Text(_selectedPlaylist!, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: songs.isEmpty
              ? const Center(child: Text('This playlist is empty.'))
              : ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final video = songs[index];
                    return ListTile(
                      leading: Image.network(video.thumbnails.lowResUrl, 
                        errorBuilder: (_, __, ___) => const Icon(Icons.music_video)),
                      title: Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(video.author),
                      onTap: () => widget.onPlay(video),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => widget.onRemove(_selectedPlaylist!, video),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
