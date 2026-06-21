import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

const _validMapSymbols =
    '.#R><NvT456MWYZ-|QEFGDX^abc123@&%*\$ABCHK[]_LlPp(){}IOUVJS';
const _validRuleNames = {'STOP', 'PUSH', 'SWAP', 'MERGE'};

class LevelData {
  final int id;
  final String name;
  final String description;
  final int width;
  final int height;
  final int movesLimit;
  final Map<String, String> initialRules;
  final Map<String, List<String>> allowedRules;
  final List<String> map;

  LevelData({
    required this.id,
    required this.name,
    required this.description,
    required this.width,
    required this.height,
    required this.movesLimit,
    required this.initialRules,
    required this.allowedRules,
    required this.map,
  });

  LevelData copyWith({
    int? id,
    String? name,
    String? description,
    int? width,
    int? height,
    int? movesLimit,
    Map<String, String>? initialRules,
    Map<String, List<String>>? allowedRules,
    List<String>? map,
  }) {
    return LevelData(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      width: width ?? this.width,
      height: height ?? this.height,
      movesLimit: movesLimit ?? this.movesLimit,
      initialRules: initialRules ?? Map.from(this.initialRules),
      allowedRules: allowedRules ?? Map.from(this.allowedRules),
      map: map ?? List.from(this.map),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'width': width,
      'height': height,
      'movesLimit': movesLimit,
      'initialRules': initialRules,
      'allowedRules': allowedRules,
      'map': map,
    };
  }

  factory LevelData.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final description = json['description'];
    final width = json['width'];
    final height = json['height'];
    final movesLimit = json['movesLimit'];
    final initialRulesRaw = json['initialRules'];
    final allowedRulesRaw = json['allowedRules'];
    final mapRaw = json['map'];

    if (id is! int ||
        id <= 0 ||
        name is! String ||
        description is! String ||
        width is! int ||
        width <= 0 ||
        width > 64 ||
        height is! int ||
        height <= 0 ||
        height > 64 ||
        movesLimit is! int ||
        movesLimit <= 0 ||
        initialRulesRaw is! Map ||
        allowedRulesRaw is! Map ||
        mapRaw is! List) {
      throw const FormatException('Invalid level JSON schema');
    }

    final initialRules = Map<String, String>.from(initialRulesRaw);
    final allowedRules = allowedRulesRaw.map<String, List<String>>(
      (key, value) =>
          MapEntry(key as String, List<String>.from(value as Iterable)),
    );
    final map = List<String>.from(mapRaw);

    if (map.length != height) {
      throw FormatException('Level $id map height does not match height');
    }
    for (var rowIndex = 0; rowIndex < map.length; rowIndex++) {
      final row = map[rowIndex];
      if (row.length != width) {
        throw FormatException(
            'Level $id row ${rowIndex + 1} width does not match width');
      }
      for (final rune in row.runes) {
        final symbol = String.fromCharCode(rune);
        if (!_validMapSymbols.contains(symbol)) {
          throw FormatException(
              'Level $id contains unsupported symbol "$symbol"');
        }
      }
    }

    for (final color in ['red', 'blue', 'green']) {
      final initial = initialRules[color];
      final allowed = allowedRules[color];
      if (initial == null ||
          !_validRuleNames.contains(initial) ||
          allowed == null ||
          allowed.isEmpty ||
          allowed.any((rule) => !_validRuleNames.contains(rule)) ||
          !allowed.contains(initial)) {
        throw FormatException(
            'Level $id has invalid $color rule configuration');
      }
    }

    return LevelData(
      id: id,
      name: name,
      description: description,
      width: width,
      height: height,
      movesLimit: movesLimit,
      initialRules: initialRules,
      allowedRules: allowedRules,
      map: map,
    );
  }
}

final Map<String, String> START_RULES = {
  'red': 'STOP',
  'blue': 'STOP',
  'green': 'STOP',
};

final List<String> STOP_ONLY = ['STOP'];

final List<int> PAR_MOVES = [
  2,
  6,
  7,
  7,
  9,
  11,
  14,
  3,
  14,
  15,
  16,
  16,
  16,
  16,
  16,
  16,
  16,
  16,
  16,
  16
];

const int ADVANCED_START_INDEX = 10;

final List<LevelData> BASE_LEVELS = [
  LevelData(
    id: 1,
    name: "Langkah Pertama",
    description: "Capai portal tanpa glyph. Ini level pemanasan.",
    width: 5,
    height: 5,
    movesLimit: 3,
    initialRules: START_RULES,
    allowedRules: {'red': STOP_ONLY, 'blue': STOP_ONLY, 'green': STOP_ONLY},
    map: ["#####", "#@.X#", "#...#", "#...#", "#####"],
  ),
  LevelData(
    id: 2,
    name: "Dorong Sakelar",
    description: "Gunakan PUSH untuk menahan plate merah dan membuka gate.",
    width: 7,
    height: 5,
    movesLimit: 7,
    initialRules: START_RULES,
    allowedRules: {
      'red': ["STOP", "PUSH"],
      'blue': STOP_ONLY,
      'green': STOP_ONLY
    },
    map: ["#######", "#@..1X#", "#A###.#", "#a....#", "#######"],
  ),
  LevelData(
    id: 3,
    name: "Koridor Dorong",
    description: "Dorong glyph lebih jauh sebelum kembali ke jalur utama.",
    width: 8,
    height: 5,
    movesLimit: 10,
    initialRules: START_RULES,
    allowedRules: {
      'red': ["STOP", "PUSH"],
      'blue': STOP_ONLY,
      'green': STOP_ONLY
    },
    map: ["########", "#@...1X#", "#A####.#", "#a.....#", "########"],
  ),
  LevelData(
    id: 4,
    name: "Ruang Tukar",
    description: "Gunakan SWAP untuk masuk lewat glyph biru.",
    width: 7,
    height: 5,
    movesLimit: 10,
    initialRules: START_RULES,
    allowedRules: {
      'red': STOP_ONLY,
      'blue': ["STOP", "SWAP"],
      'green': STOP_ONLY
    },
    map: ["#######", "#@B#..#", "##..#X#", "#.....#", "#######"],
  ),
  LevelData(
    id: 5,
    name: "Tukar Zigzag",
    description:
        "SWAP membuka jalur pendek melewati ruang yang dipisah dinding.",
    width: 8,
    height: 5,
    movesLimit: 12,
    initialRules: START_RULES,
    allowedRules: {
      'red': STOP_ONLY,
      'blue': ["STOP", "SWAP"],
      'green': STOP_ONLY
    },
    map: ["########", "#@B#..X#", "##.#.#.#", "#..B...#", "########"],
  ),
  LevelData(
    id: 6,
    name: "Kunci Merge",
    description: "Gabungkan dua glyph merah agar lorong bisa dibuka.",
    width: 8,
    height: 5,
    movesLimit: 12,
    initialRules: START_RULES,
    allowedRules: {
      'red': ["STOP", "MERGE"],
      'blue': STOP_ONLY,
      'green': STOP_ONLY
    },
    map: ["########", "#@AAa..#", "#.####.#", "#....1X#", "########"],
  ),
  LevelData(
    id: 7,
    name: "Lorong Padat",
    description: "Tiga glyph harus diringkas dengan MERGE sebelum gate merah.",
    width: 9,
    height: 5,
    movesLimit: 14,
    initialRules: START_RULES,
    allowedRules: {
      'red': ["STOP", "MERGE"],
      'blue': STOP_ONLY,
      'green': STOP_ONLY
    },
    map: ["#########", "#@AAAa..#", "#.#####.#", "#.....1X#", "#########"],
  ),
  LevelData(
    id: 8,
    name: "Jembatan Spike",
    description: "Dorong glyph ke spike untuk menyeberang dengan aman.",
    width: 7,
    height: 3,
    movesLimit: 4,
    initialRules: START_RULES,
    allowedRules: {
      'red': ["STOP", "PUSH"],
      'blue': STOP_ONLY,
      'green': STOP_ONLY
    },
    map: ["#######", "#@A^X.#", "#######"],
  ),
  LevelData(
    id: 9,
    name: "Dua Warna",
    description:
        "Buka gate merah dengan PUSH, lalu lewati glyph biru dengan SWAP.",
    width: 9,
    height: 6,
    movesLimit: 16,
    initialRules: START_RULES,
    allowedRules: {
      'red': ["STOP", "PUSH"],
      'blue': ["STOP", "SWAP"],
      'green': STOP_ONLY
    },
    map: [
      "#########",
      "#@A.a...#",
      "#.#####.#",
      "#...1B#X#",
      "#####...#",
      "#########"
    ],
  ),
  LevelData(
    id: 10,
    name: "Hijau Pertama",
    description: "PUSH merah membuka jalur, MERGE hijau membuka portal.",
    width: 10,
    height: 6,
    movesLimit: 20,
    initialRules: START_RULES,
    allowedRules: {
      'red': ["STOP", "PUSH"],
      'blue': STOP_ONLY,
      'green': ["STOP", "MERGE"]
    },
    map: [
      "##########",
      "#@A.a....#",
      "#.######.#",
      "#...1CCcX#",
      "#......3.#",
      "##########"
    ],
  ),
  LevelData(
    id: 11,
    name: "Tiga Kunci",
    description: "Gabungkan tiga mekanik dasar dalam satu jalur.",
    width: 10,
    height: 8,
    movesLimit: 26,
    initialRules: START_RULES,
    allowedRules: {
      'red': ["STOP", "PUSH"],
      'blue': ["STOP", "SWAP"],
      'green': ["STOP", "MERGE"]
    },
    map: [
      "##########",
      "#@A.a....#",
      "#.######.#",
      "#...1B#..#",
      "#####...##",
      "#.....CCc#",
      "#......3X#",
      "##########"
    ],
  ),
  LevelData(
    id: 12,
    name: "Ruang Sempit",
    description:
        "Jalur lebih rapat dengan gate yang tetap harus dibuka berurutan.",
    width: 10,
    height: 8,
    movesLimit: 26,
    initialRules: START_RULES,
    allowedRules: {
      'red': ["STOP", "PUSH"],
      'blue': ["STOP", "SWAP"],
      'green': ["STOP", "MERGE"]
    },
    map: [
      "##########",
      "#@A.a....#",
      "#.######.#",
      "#...1B#..#",
      "###.#...##",
      "#...#.CCc#",
      "#.####.3X#",
      "##########"
    ],
  ),
  LevelData(
    id: 13,
    name: "Rintangan Tajam",
    description: "Spike mempersempit jalur setelah gate biru.",
    width: 10,
    height: 8,
    movesLimit: 28,
    initialRules: START_RULES,
    allowedRules: {
      'red': ["STOP", "PUSH"],
      'blue': ["STOP", "SWAP"],
      'green': ["STOP", "MERGE"]
    },
    map: [
      "##########",
      "#@A.a.^..#",
      "#.######.#",
      "#...1B#..#",
      "#####...##",
      "#.....CCc#",
      "#......3X#",
      "##########"
    ],
  ),
  LevelData(
    id: 14,
    name: "Audit Ketat",
    description: "Batas langkah mulai lebih sempit.",
    width: 10,
    height: 8,
    movesLimit: 27,
    initialRules: START_RULES,
    allowedRules: {
      'red': ["STOP", "PUSH"],
      'blue': ["STOP", "SWAP"],
      'green': ["STOP", "MERGE"]
    },
    map: [
      "##########",
      "#@A.a....#",
      "#.######.#",
      "#...1B#..#",
      "#####...##",
      "#.....CCc#",
      "#......3X#",
      "##########"
    ],
  ),
  LevelData(
    id: 15,
    name: "Batas Hampir Pas",
    description: "Solusi butuh urutan rule yang efisien.",
    width: 10,
    height: 8,
    movesLimit: 26,
    initialRules: START_RULES,
    allowedRules: {
      'red': ["STOP", "PUSH"],
      'blue': ["STOP", "SWAP"],
      'green': ["STOP", "MERGE"]
    },
    map: [
      "##########",
      "#@A.a....#",
      "#.######.#",
      "#...1B#..#",
      "#####.^.##",
      "#.....CCc#",
      "#......3X#",
      "##########"
    ],
  ),
  LevelData(
    id: 16,
    name: "Plate Jauh",
    description: "Plate dan gate masih berurutan, tapi ruang baca lebih padat.",
    width: 10,
    height: 9,
    movesLimit: 30,
    initialRules: START_RULES,
    allowedRules: {
      'red': ["STOP", "PUSH"],
      'blue': ["STOP", "SWAP"],
      'green': ["STOP", "MERGE"]
    },
    map: [
      "##########",
      "#@A.a....#",
      "#.######.#",
      "#...1B#..#",
      "#####...##",
      "#.....CCc#",
      "#......3X#",
      "#........#",
      "##########"
    ],
  ),
  LevelData(
    id: 17,
    name: "Jalur Bercabang",
    description: "Cabang palsu membuat route yang benar lebih sulit dibaca.",
    width: 10,
    height: 9,
    movesLimit: 30,
    initialRules: START_RULES,
    allowedRules: {
      'red': ["STOP", "PUSH"],
      'blue': ["STOP", "SWAP"],
      'green': ["STOP", "MERGE"]
    },
    map: [
      "##########",
      "#@A.a....#",
      "#.######.#",
      "#...1B#..#",
      "#####...##",
      "#.....CCc#",
      "#..#...3X#",
      "#........#",
      "##########"
    ],
  ),
  LevelData(
    id: 18,
    name: "Sirkuit Padat",
    description: "Semua gate inti muncul lagi dengan ruang gerak lebih kecil.",
    width: 10,
    height: 8,
    movesLimit: 25,
    initialRules: START_RULES,
    allowedRules: {
      'red': ["STOP", "PUSH"],
      'blue': ["STOP", "SWAP"],
      'green': ["STOP", "MERGE"]
    },
    map: [
      "##########",
      "#@A.a.^..#",
      "#.######.#",
      "#...1B#..#",
      "#####.^.##",
      "#.....CCc#",
      "#......3X#",
      "##########"
    ],
  ),
  LevelData(
    id: 19,
    name: "Pra-Finale",
    description: "Hanya beberapa langkah cadangan tersisa.",
    width: 10,
    height: 9,
    movesLimit: 24,
    initialRules: START_RULES,
    allowedRules: {
      'red': ["STOP", "PUSH"],
      'blue': ["STOP", "SWAP"],
      'green': ["STOP", "MERGE"]
    },
    map: [
      "##########",
      "#@A.a....#",
      "#.######.#",
      "#...1B#..#",
      "#####...##",
      "#.....CCc#",
      "#..#...3X#",
      "#..^.....#",
      "##########"
    ],
  ),
  LevelData(
    id: 20,
    name: "Ujian Bab Satu",
    description:
        "Semua rule inti muncul sebelum campaign masuk ke ronde presisi.",
    width: 10,
    height: 8,
    movesLimit: 24,
    initialRules: START_RULES,
    allowedRules: {
      'red': ["STOP", "PUSH"],
      'blue': ["STOP", "SWAP"],
      'green': ["STOP", "MERGE"]
    },
    map: [
      "##########",
      "#@A.a.^..#",
      "#.######.#",
      "#...1B#..#",
      "#####.^.##",
      "#.....CCc#",
      "#......3X#",
      "##########"
    ],
  ),
  LevelData(
    id: 21,
    name: "Laboratorium Laser",
    description:
        "Tembak laser, teleport, dan timbun jurang. Pahami cara glyph berinteraksi dengan elemen ini.",
    width: 8,
    height: 7,
    movesLimit: 22,
    initialRules: START_RULES,
    allowedRules: {
      'red': ["STOP", "PUSH", "SWAP"],
      'blue': ["STOP", "PUSH"],
      'green': STOP_ONLY
    },
    map: [
      "########",
      "#@.L..X#",
      "#A.###.#",
      "#..#_..#",
      "#B.#...#",
      "#[.#.]##",
      "########"
    ],
  ),
  LevelData(
    id: 22,
    name: "Transisi Berwaktu",
    description:
        "Injak lantai sensor untuk menyalin aturan, dan manfaatkan lantai berjalan sebelum aturan berwaktu habis.",
    width: 8,
    height: 7,
    movesLimit: 20,
    initialRules: {'red': 'PUSH', 'blue': 'STOP', 'green': 'STOP'},
    allowedRules: {
      'red': ["STOP", "PUSH"],
      'blue': ["STOP", "PUSH"],
      'green': STOP_ONLY
    },
    map: [
      "########",
      "#@.S...#",
      "#A.#####",
      "#..)..)#",
      "#B.#####",
      "#J....X#",
      "########"
    ],
  ),
];

class Chapter {
  final String title;
  final int margin;
  Chapter(this.title, this.margin);
}

final List<Chapter> EXTRA_CHAPTERS = [
  Chapter("Bab 2: Rute Lanjutan", 7),
  Chapter("Bab 3: Rute Padat", 6),
  Chapter("Bab 4: Jalur Tajam", 5),
  Chapter("Bab 5: Audit Cepat", 4),
  Chapter("Bab 6: Hampir Presisi", 3),
  Chapter("Bab 7: Presisi", 2),
  Chapter("Bab 8: Master", 1),
  Chapter("Finale", 0),
];

final List<LevelData> ADVANCED_LEVELS =
    BASE_LEVELS.sublist(ADVANCED_START_INDEX);

List<LevelData> generateAllLevels() {
  final List<LevelData> list = [];

  // Base Levels
  for (var lvl in BASE_LEVELS) {
    list.add(lvl);
  }

  // Advanced levels for chapters
  for (int chapterIndex = 0;
      chapterIndex < EXTRA_CHAPTERS.length;
      chapterIndex++) {
    final chapter = EXTRA_CHAPTERS[chapterIndex];
    for (int baseIndex = 0; baseIndex < ADVANCED_LEVELS.length; baseIndex++) {
      final base = ADVANCED_LEVELS[baseIndex];
      final id = BASE_LEVELS.length +
          (chapterIndex * ADVANCED_LEVELS.length) +
          baseIndex +
          1;

      // Safe par moves resolution
      final parMovesIndex = ADVANCED_START_INDEX + baseIndex;
      final parMoves = (parMovesIndex >= 0 && parMovesIndex < PAR_MOVES.length)
          ? PAR_MOVES[parMovesIndex]
          : 16;

      final isFinalLevel = (chapterIndex == EXTRA_CHAPTERS.length - 1) &&
          (baseIndex == ADVANCED_LEVELS.length - 1);

      list.add(LevelData(
        id: id,
        name: isFinalLevel
            ? "Tamat: Audit Akhir"
            : "${chapter.title} ${baseIndex + 1}",
        description: isFinalLevel
            ? "Final campaign: semua rule inti harus dibaca tanpa satu langkah cadangan."
            : "${base.name} dengan batas langkah lebih ketat.",
        width: base.width,
        height: base.height,
        movesLimit: parMoves + chapter.margin,
        initialRules: Map.from(base.initialRules),
        allowedRules: Map.from(base.allowedRules),
        map: List.from(base.map),
      ));
    }
  }

  return list;
}

List<LevelData> LEVELS = generateAllLevels();

Map<String, List<LevelData>> LEVELS_BY_MODE = {
  '1': LEVELS,
  '2': [
    LevelData(
      id: 1,
      name: "Dualitas Sakelar",
      description:
          "P1 dan P2 harus saling menginjak plate untuk membuka gate masing-masing.",
      width: 8,
      height: 5,
      movesLimit: 10,
      initialRules: START_RULES,
      allowedRules: {'red': STOP_ONLY, 'blue': STOP_ONLY, 'green': STOP_ONLY},
      map: ["########", "#@.b.1X#", "########", "#%.a.2X#", "########"],
    ),
    LevelData(
      id: 2,
      name: "Dorong Sinkron",
      description:
          "P1 mendorong glyph merah ke plate merah untuk membuka jalur P1, sementara P2 menekan plate biru.",
      width: 10,
      height: 5,
      movesLimit: 18,
      initialRules: {'red': "PUSH", 'blue': "STOP", 'green': "STOP"},
      allowedRules: {
        'red': ["STOP", "PUSH"],
        'blue': STOP_ONLY,
        'green': STOP_ONLY
      },
      map: [
        "##########",
        "#@..A.1.X#",
        "####.#####",
        "#%.b.a.2X#",
        "##########"
      ],
    ),
    LevelData(
      id: 3,
      name: "Persilangan Spike",
      description:
          "Gunakan SWAP/PUSH pada glyph biru untuk menyeberang dengan selamat.",
      width: 9,
      height: 5,
      movesLimit: 12,
      initialRules: START_RULES,
      allowedRules: {
        'red': STOP_ONLY,
        'blue': ["STOP", "PUSH", "SWAP"],
        'green': STOP_ONLY
      },
      map: ["#########", "#@.B.^.X#", "####.####", "#%.B.^.X#", "#########"],
    ),
  ],
  '3': [
    LevelData(
      id: 1,
      name: "Triad Sakelar",
      description:
          "Tiga pemain harus saling membantu membuka gate dalam urutan melingkar.",
      width: 9,
      height: 7,
      movesLimit: 12,
      initialRules: START_RULES,
      allowedRules: {'red': STOP_ONLY, 'blue': STOP_ONLY, 'green': STOP_ONLY},
      map: [
        "#########",
        "#@.c.1.X#",
        "#########",
        "#%.a.2.X#",
        "#########",
        "#*.b.3.X#",
        "#########"
      ],
    ),
    LevelData(
      id: 2,
      name: "Segitiga Spike",
      description:
          "Dorong glyph masing-masing ke atas spikes dan injak plate untuk membuka gate teman.",
      width: 11,
      height: 7,
      movesLimit: 20,
      initialRules: {'red': "PUSH", 'blue': "PUSH", 'green': "PUSH"},
      allowedRules: {
        'red': ["STOP", "PUSH"],
        'blue': ["STOP", "PUSH"],
        'green': ["STOP", "PUSH"]
      },
      map: [
        "###########",
        "#@.A.^.b1X#",
        "#####.#####",
        "#%.B.^.c2X#",
        "#####.#####",
        "#*.C.^.a3X#",
        "###########"
      ],
    ),
    LevelData(
      id: 3,
      name: "Merge Bertiga",
      description:
          "Gabungkan glyph hijau di pilar bawah untuk menyelesaikan level.",
      width: 10,
      height: 7,
      movesLimit: 16,
      initialRules: {'red': "STOP", 'blue': "STOP", 'green': "MERGE"},
      allowedRules: {
        'red': STOP_ONLY,
        'blue': STOP_ONLY,
        'green': ["STOP", "MERGE"]
      },
      map: [
        "##########",
        "#@..C.3.X#",
        "#.########",
        "#%.C.3.X##",
        "#.########",
        "#*.c.C.3X#",
        "##########"
      ],
    ),
  ],
  '4': [
    LevelData(
      id: 1,
      name: "Kuartet Sakelar",
      description:
          "Empat pemain bekerja sama menggunakan 3 warna gate dengan dependency melingkar.",
      width: 9,
      height: 9,
      movesLimit: 16,
      initialRules: START_RULES,
      allowedRules: {'red': STOP_ONLY, 'blue': STOP_ONLY, 'green': STOP_ONLY},
      map: [
        "#########",
        "#@.b.1.X#",
        "#########",
        "#%.c.2.X#",
        "#########",
        "#*.a.3.X#",
        "#########",
        "#\$.a.1.X#",
        "#########"
      ],
    ),
    LevelData(
      id: 2,
      name: "Kerja Sama Kuartet",
      description:
          "P1, P2, P3 harus menyeberangi spike, sementara P4 berdiri di atas plate-plate pengontrol gate.",
      width: 10,
      height: 9,
      movesLimit: 16,
      initialRules: {'red': "PUSH", 'blue': "PUSH", 'green': "PUSH"},
      allowedRules: {
        'red': ["STOP", "PUSH"],
        'blue': ["STOP", "PUSH"],
        'green': ["STOP", "PUSH"]
      },
      map: [
        "##########",
        "#@.A.^.1X#",
        "##########",
        "#%.B.^.2X#",
        "##########",
        "#*.C.^.3X#",
        "##########",
        "#\$.a.b.cX#",
        "##########"
      ],
    ),
    LevelData(
      id: 3,
      name: "Persilangan Kuartet",
      description:
          "Gunakan dependency melingkar untuk membebaskan semua rekan tim.",
      width: 9,
      height: 9,
      movesLimit: 16,
      initialRules: START_RULES,
      allowedRules: {'red': STOP_ONLY, 'blue': STOP_ONLY, 'green': STOP_ONLY},
      map: [
        "#########",
        "#@.a.1.X#",
        "#########",
        "#%.b.2.X#",
        "#########",
        "#*.c.3.X#",
        "#########",
        "#\$.b.2.X#",
        "#########"
      ],
    ),
  ]
};

List<LevelData> _parseLevelList(dynamic raw) {
  if (raw is! Iterable) {
    return [];
  }

  return raw
      .whereType<Map>()
      .map((level) => LevelData.fromJson(Map<String, dynamic>.from(level)))
      .toList();
}

Future<bool> _initializeLevelsFromBundleJson() async {
  final jsonStr = await rootBundle.loadString('assets/levels.json');
  final Map<String, dynamic> data = json.decode(jsonStr);
  final Map<String, dynamic> modesData =
      Map<String, dynamic>.from(data['levels_by_mode'] as Map? ?? {});

  final singlePlayerLevels = _parseLevelList(modesData['1']);
  if (singlePlayerLevels.isEmpty) {
    return false;
  }

  LEVELS = singlePlayerLevels;
  LEVELS_BY_MODE['1'] = LEVELS;

  for (final mode in ['2', '3', '4']) {
    final modeLevels = _parseLevelList(modesData[mode]);
    if (modeLevels.isNotEmpty) {
      LEVELS_BY_MODE[mode] = modeLevels;
    }
  }

  return true;
}

Future<void> initializeLevels() async {
  try {
    final loaded = await _initializeLevelsFromBundleJson();
    if (loaded) {
      return;
    }
  } catch (e) {
    print("Single JSON level initialization failed, trying split assets: $e");
  }

  try {
    // 1. Load Single Player Chapters (solo/chap1 to solo/chap9)
    final List<LevelData> newSinglePlayerLevels = [];
    for (int chap = 1; chap <= 9; chap++) {
      int id = 1;
      while (true) {
        try {
          final String path = 'assets/levels/solo/chap$chap/$id.json';
          final jsonStr = await rootBundle.loadString(path);
          final Map<String, dynamic> data = json.decode(jsonStr);
          newSinglePlayerLevels.add(LevelData.fromJson(data));
          id++;
        } catch (e) {
          // No more levels in this chapter, break loop
          break;
        }
      }
    }

    if (newSinglePlayerLevels.isNotEmpty) {
      LEVELS = newSinglePlayerLevels;
      LEVELS_BY_MODE['1'] = LEVELS;
    }

    // 2. Load Coop modes ('2', '3', '4')
    for (final mode in ['2', '3', '4']) {
      final List<LevelData> modeLevels = [];
      int id = 1;
      while (true) {
        try {
          final String path = 'assets/levels/coop/${mode}p/$id.json';
          final jsonStr = await rootBundle.loadString(path);
          final Map<String, dynamic> data = json.decode(jsonStr);
          modeLevels.add(LevelData.fromJson(data));
          id++;
        } catch (e) {
          // No more levels in this coop mode, break loop
          break;
        }
      }

      if (modeLevels.isNotEmpty) {
        LEVELS_BY_MODE[mode] = modeLevels;
      }
    }
  } catch (e) {
    // Falls back silently to default compiled-in levels
    print(
        "Levels asset directory initialization failed, using default levels: $e");
  }
}
