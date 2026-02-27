import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
        colorScheme: const ColorScheme.dark(primary: Colors.red),
        useMaterial3: true,
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
      _username = prefs.getString('username');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _isLoggedIn! ? HomeScreen(username: _username!) : LoginPage(onLogin: _checkLoginStatus);
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

  Future<void> _login() async {
    if (_usernameController.text.isNotEmpty && _passwordController.text.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('username', _usernameController.text);
      widget.onLogin();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter username and password')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.music_note, size: 100, color: Colors.red),
            const SizedBox(height: 24),
            const Text(
              'FeelIt',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _login,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final String username;
  const HomeScreen({super.key, required this.username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  List<Video> _playlist = [];
  final AudioPlayer _player = AudioPlayer();
  final YoutubeExplode _yt = YoutubeExplode();

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
  }

  Future<void> _loadPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    final playlistJson = prefs.getString('playlist_${widget.username}');
    if (playlistJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(playlistJson);
        List<Video> loadedPlaylist = [];
        for (var id in decoded) {
          try {
            final video = await _yt.videos.get(id);
            loadedPlaylist.add(video);
          } catch (_) {}
        }
        if (mounted) {
          setState(() => _playlist = loadedPlaylist);
        }
      } catch (e) {
        debugPrint('Error loading playlist: $e');
      }
    }
  }

  Future<void> _savePlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> ids = _playlist.map((v) => v.id.value).toList();
    await prefs.setString('playlist_${widget.username}', jsonEncode(ids));
  }

  void _addToPlaylist(Video video) {
    setState(() {
      if (!_playlist.any((v) => v.id == video.id)) {
        _playlist.add(video);
        _savePlaylist();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${video.title} to playlist')),
    );
  }

  void _removeFromPlaylist(Video video) {
    setState(() {
      _playlist.remove(video);
      _savePlaylist();
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
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
        playlist: _playlist,
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
                      Text(metadata.artist ?? '', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loading song...'), duration: Duration(seconds: 2)),
        );
      }
      
      await _player.stop();
      if (kIsWeb) return;

      // manifest - increased timeout to 30s
      final manifest = await _yt.videos.streamsClient.getManifest(video.id)
          .timeout(const Duration(seconds: 30));

      final streams = manifest.audioOnly;
      if (streams.isEmpty) {
        throw Exception('No audio-only streams found for this video.');
      }

      // Prioritize 'mp4' container for better compatibility.
      final mp4Streams = streams.where((s) => s.container.name == 'mp4');
      final streamInfo = mp4Streams.isNotEmpty 
          ? mp4Streams.withHighestBitrate() 
          : streams.withHighestBitrate();

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
      ).timeout(const Duration(seconds: 30)); // increased timeout to 30s
      
      _player.play();

    } catch (e) {
      debugPrint('Playback error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        String message;
        if (e is TimeoutException) {
          message = 'Could not load song: Connection timed out. Please check your internet.';
        } else {
          message = 'Could not play this song. Error: ${e.toString()}';
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
      final results = await widget.yt.search.search(_searchController.text);
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
          _errorMessage = kIsWeb 
            ? 'Chrome is blocking the search (CORS restriction).' 
            : 'Error: $e';
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
    _debounce = Timer(const Duration(milliseconds: 700), () {
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
                  ? Center(child: Text(_errorMessage!, textAlign: TextAlign.center))
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

class PlaylistPage extends StatelessWidget {
  final List<Video> playlist;
  final Function(Video) onPlay;
  final Function(Video) onRemove;

  const PlaylistPage({super.key, required this.playlist, required this.onPlay, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return playlist.isEmpty
        ? const Center(child: Text('Your playlist is currently empty.'))
        : ListView.builder(
            itemCount: playlist.length,
            itemBuilder: (context, index) {
              final video = playlist[index];
              return ListTile(
                leading: Image.network(video.thumbnails.lowResUrl, 
                  errorBuilder: (_, __, ___) => const Icon(Icons.music_video)),
                title: Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(video.author),
                onTap: () => onPlay(video),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => onRemove(video),
                ),
              );
            },
          );
  }
}
