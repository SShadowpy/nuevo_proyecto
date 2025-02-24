import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

/// Modelo para un Pokémon
class Pokemon {
  final int id;
  final String name;
  final String imageUrl;
  final int attack;
  final int defense;
  final int hp;
  final String type;

  Pokemon({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.attack,
    required this.defense,
    required this.hp,
    required this.type,
  });
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Poke-TikTok',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const PokeTikTokPage(),
    );
  }
}

class PokeTikTokPage extends StatefulWidget {
  const PokeTikTokPage({Key? key}) : super(key: key);

  @override
  State<PokeTikTokPage> createState() => _PokeTikTokPageState();
}

class _PokeTikTokPageState extends State<PokeTikTokPage> {
  final PageController _pageController = PageController();

  /// Lista local de Pokémons cargados
  final List<Pokemon> _pokemonList = [];

  /// IDs de favoritos guardados
  Set<int> _favoritePokemonIds = {};

  /// Último ID de Pokémon cargado
  int _lastPokemonId = 0;

  bool _isLoading = false;

  /// Mapa de colores base según tipo de Pokémon
  final Map<String, Color> _typeColorMap = {
    'Normal': Colors.brown,
    'Fire': Colors.red,
    'Water': Colors.blue,
    'Electric': Colors.yellow,
    'Grass': Colors.green,
    'Ice': Colors.cyan,
    'Fighting': Colors.brown,
    'Poison': Colors.purple,
    'Ground': Colors.brown,
    'Flying': Colors.indigo,
    'Psychic': Colors.pink,
    'Bug': Colors.lightGreen,
    'Rock': Colors.grey,
    'Ghost': Colors.deepPurple,
    'Dragon': Colors.indigo,
    'Dark': Colors.black54,
    'Steel': Colors.blueGrey,
    'Fairy': Colors.pinkAccent,
  };

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadMorePokemons(); // Cargamos los primeros
  }

  /// Carga la lista de favoritos desde SharedPreferences
  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList('favorite_ids') ?? [];
    // Convertir a int
    _favoritePokemonIds = favs.map(int.parse).toSet();
    setState(() {});
  }

  /// Guarda la lista de favoritos en SharedPreferences
  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favs = _favoritePokemonIds.map((id) => id.toString()).toList();
    await prefs.setStringList('favorite_ids', favs);
  }

  /// Llama a la API y crea un objeto Pokemon
  Future<Pokemon?> _fetchPokemon(int id) async {
    try {
      final url = Uri.parse('https://pokeapi.co/api/v2/pokemon/$id/');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final name = _capitalize(data['name']);
        final sprites = data['sprites'];
        // Se puede usar la imagen oficial, o la default
        final imageUrl = sprites['other']['official-artwork']['front_default'] ??
            sprites['front_default'] ??
            '';

        // stats: [ {stat: {name: hp}, base_stat: 45}, ... ]
        int attack = 0;
        int defense = 0;
        int hp = 0;

        for (var stat in data['stats']) {
          final statName = stat['stat']['name'];
          final baseStat = stat['base_stat'];
          if (statName == 'attack') {
            attack = baseStat;
          } else if (statName == 'defense') {
            defense = baseStat;
          } else if (statName == 'hp') {
            hp = baseStat;
          }
        }

        // Tomamos el primer tipo
        String type = '';
        if (data['types'] != null && data['types'].isNotEmpty) {
          type = data['types'][0]['type']['name'];
        }

        return Pokemon(
          id: id,
          name: name,
          imageUrl: imageUrl,
          attack: attack,
          defense: defense,
          hp: hp,
          type: _capitalize(type),
        );
      }
    } catch (e) {
      debugPrint('Error fetching Pokemon $id: $e');
    }
    return null;
  }

  /// Carga más Pokemons en la lista.  
  /// Usamos _lastPokemonId para continuar.
  Future<void> _loadMorePokemons() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    // Cargamos los siguientes 5 (por ejemplo)
    for (int i = 0; i < 5; i++) {
      _lastPokemonId++;
      final pokemon = await _fetchPokemon(_lastPokemonId);
      if (pokemon != null) {
        _pokemonList.add(pokemon);
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  /// Capitaliza la primera letra de un string
  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  /// Marca o desmarca un Pokémon como favorito
  void _toggleFavorite(int pokemonId) {
    setState(() {
      if (_favoritePokemonIds.contains(pokemonId)) {
        _favoritePokemonIds.remove(pokemonId);
      } else {
        _favoritePokemonIds.add(pokemonId);
      }
    });
    _saveFavorites();
  }

  /// Retorna el color base según el tipo de Pokémon
  Color _getTypeColor(String type) {
    final lowerType = type.toLowerCase();
    final entry = _typeColorMap.entries.firstWhere(
      (e) => e.key.toLowerCase() == lowerType,
      orElse: () => const MapEntry('default', Colors.grey),
    );
    return entry.value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _pokemonList.length,
        onPageChanged: (index) {
          // Cuando llegamos cerca del final, cargamos más
          if (index == _pokemonList.length - 1) {
            _loadMorePokemons();
          }
        },
        itemBuilder: (context, index) {
          final pokemon = _pokemonList[index];
          final isFavorite = _favoritePokemonIds.contains(pokemon.id);

          return _buildPokemonPage(pokemon, isFavorite);
        },
      ),
    );
  }

  Widget _buildPokemonPage(Pokemon pokemon, bool isFavorite) {
    return Container(
      // Fondo degradado (color del tipo → blanco)
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _getTypeColor(pokemon.type),
            Colors.white,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pokemon Number ${pokemon.id}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: _showFavoritesDialog,
                    child: Row(
                      children: const [
                        Text(
                          'My favorites',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.favorite, color: Colors.white),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Nombre grande al centro
              Text(
                pokemon.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 24),

              // Imagen del Pokémon
              if (pokemon.imageUrl.isNotEmpty)
                Image.network(
                  pokemon.imageUrl,
                  height: 200,
                ),

              const Spacer(),

              // Tarjeta blanca con stats y botón
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    // Fila de stats (Attack, Defense, HP, Type)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _statItem('Attack', pokemon.attack.toString()),
                        _statItem('Defense', pokemon.defense.toString()),
                        _statItem('HP', pokemon.hp.toString()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // El tipo (ej. "Type: Grass")
                    Text(
                      'Type: ${pokemon.type}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Botón "Yo te elijo!"
                    ElevatedButton(
                      onPressed: () => _toggleFavorite(pokemon.id),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        isFavorite ? 'Already favorite' : 'I choose you!!',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Widget individual para un stat (Attack, Defense, etc.)
  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  /// Muestra un diálogo con la lista de Pokémon favoritos
  void _showFavoritesDialog() {
    final favoritePokemons = _pokemonList
        .where((p) => _favoritePokemonIds.contains(p.id))
        .toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('My favorites'),
          content: favoritePokemons.isEmpty
              ? const Text('You don\'t have any favorites yet.')
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: favoritePokemons.length,
                    itemBuilder: (context, index) {
                      final p = favoritePokemons[index];
                      return ListTile(
                        leading: p.imageUrl.isNotEmpty
                            ? Image.network(p.imageUrl, width: 50, height: 50)
                            : null,
                        title: Text(p.name),
                        subtitle: Text('ID: ${p.id} | Type: ${p.type}'),
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            )
          ],
        );
      },
    );
  }
}
