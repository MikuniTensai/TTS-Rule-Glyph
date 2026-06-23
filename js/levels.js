/**
 * Campaign Database for Rule Glyph Lab
 * Map Characters:
 *  # : Wall
 *  . : Floor
 *  @ : Player 1
 *  & : Player 2 (optional; generated near Player 1 when omitted)
 *  X : Exit Portal
 *  ^ : Hazard Spikes
 *  A : Red Glyph (Alpha)
 *  B : Blue Glyph (Beta)
 *  C : Green Glyph (Gamma)
 *  a : Red Plate (opens Red Gate 1)
 *  b : Blue Plate (opens Blue Gate 2)
 *  c : Green Plate (opens Green Gate 3)
 *  1 : Red Gate
 *  2 : Blue Gate
 *  3 : Green Gate
 */

const START_RULES = {
  red: "STOP",
  blue: "STOP",
  green: "STOP"
};

const STOP_ONLY = ["STOP"];
const ADVANCED_START_INDEX = 10;
const PAR_MOVES = [
  2, 6, 7, 7, 9, 11, 14, 3, 14, 15,
  16, 16, 16, 16, 16, 16, 16, 16, 16, 16,
  16, 16
];

let BASE_LEVELS = [
  {
    id: 1,
    name: "Langkah Pertama",
    description: "Capai portal tanpa glyph. Ini level pemanasan.",
    width: 5,
    height: 5,
    movesLimit: 3,
    initialRules: START_RULES,
    allowedRules: {
      red: STOP_ONLY,
      blue: STOP_ONLY,
      green: STOP_ONLY
    },
    map: [
      "#####",
      "#@.X#",
      "#...#",
      "#...#",
      "#####"
    ]
  },
  {
    id: 2,
    name: "Dorong Sakelar",
    description: "Gunakan PUSH untuk menahan plate merah dan membuka gate.",
    width: 7,
    height: 5,
    movesLimit: 7,
    initialRules: START_RULES,
    allowedRules: {
      red: ["STOP", "PUSH"],
      blue: STOP_ONLY,
      green: STOP_ONLY
    },
    map: [
      "#######",
      "#@..1X#",
      "#A###.#",
      "#a....#",
      "#######"
    ]
  },
  {
    id: 3,
    name: "Koridor Dorong",
    description: "Dorong glyph lebih jauh sebelum kembali ke jalur utama.",
    width: 8,
    height: 5,
    movesLimit: 10,
    initialRules: START_RULES,
    allowedRules: {
      red: ["STOP", "PUSH"],
      blue: STOP_ONLY,
      green: STOP_ONLY
    },
    map: [
      "########",
      "#@...1X#",
      "#A####.#",
      "#a.....#",
      "########"
    ]
  },
  {
    id: 4,
    name: "Ruang Tukar",
    description: "Gunakan SWAP untuk masuk lewat glyph biru.",
    width: 7,
    height: 5,
    movesLimit: 10,
    initialRules: START_RULES,
    allowedRules: {
      red: STOP_ONLY,
      blue: ["STOP", "SWAP"],
      green: STOP_ONLY
    },
    map: [
      "#######",
      "#@B#..#",
      "##..#X#",
      "#.....#",
      "#######"
    ]
  },
  {
    id: 5,
    name: "Tukar Zigzag",
    description: "SWAP membuka jalur pendek melewati ruang yang dipisah dinding.",
    width: 8,
    height: 5,
    movesLimit: 12,
    initialRules: START_RULES,
    allowedRules: {
      red: STOP_ONLY,
      blue: ["STOP", "SWAP"],
      green: STOP_ONLY
    },
    map: [
      "########",
      "#@B#..X#",
      "##.#.#.#",
      "#..B...#",
      "########"
    ]
  },
  {
    id: 6,
    name: "Kunci Merge",
    description: "Gabungkan dua glyph merah agar lorong bisa dibuka.",
    width: 8,
    height: 5,
    movesLimit: 12,
    initialRules: START_RULES,
    allowedRules: {
      red: ["STOP", "MERGE"],
      blue: STOP_ONLY,
      green: STOP_ONLY
    },
    map: [
      "########",
      "#@AAa..#",
      "#.####.#",
      "#....1X#",
      "########"
    ]
  },
  {
    id: 7,
    name: "Lorong Padat",
    description: "Tiga glyph harus diringkas dengan MERGE sebelum gate merah.",
    width: 9,
    height: 5,
    movesLimit: 14,
    initialRules: START_RULES,
    allowedRules: {
      red: ["STOP", "MERGE"],
      blue: STOP_ONLY,
      green: STOP_ONLY
    },
    map: [
      "#########",
      "#@AAAa..#",
      "#.#####.#",
      "#.....1X#",
      "#########"
    ]
  },
  {
    id: 8,
    name: "Jembatan Spike",
    description: "Dorong glyph ke spike untuk menyeberang dengan aman.",
    width: 7,
    height: 3,
    movesLimit: 4,
    initialRules: START_RULES,
    allowedRules: {
      red: ["STOP", "PUSH"],
      blue: STOP_ONLY,
      green: STOP_ONLY
    },
    map: [
      "#######",
      "#@A^X.#",
      "#######"
    ]
  },
  {
    id: 9,
    name: "Dua Warna",
    description: "Buka gate merah dengan PUSH, lalu lewati glyph biru dengan SWAP.",
    width: 9,
    height: 6,
    movesLimit: 16,
    initialRules: START_RULES,
    allowedRules: {
      red: ["STOP", "PUSH"],
      blue: ["STOP", "SWAP"],
      green: STOP_ONLY
    },
    map: [
      "#########",
      "#@A.a...#",
      "#.#####.#",
      "#...1B#X#",
      "#####...#",
      "#########"
    ]
  },
  {
    id: 10,
    name: "Hijau Pertama",
    description: "PUSH merah membuka jalur, MERGE hijau membuka portal.",
    width: 10,
    height: 6,
    movesLimit: 20,
    initialRules: START_RULES,
    allowedRules: {
      red: ["STOP", "PUSH"],
      blue: STOP_ONLY,
      green: ["STOP", "MERGE"]
    },
    map: [
      "##########",
      "#@A.a....#",
      "#.######.#",
      "#...1CCcX#",
      "#......3.#",
      "##########"
    ]
  },
  {
    id: 11,
    name: "Tiga Kunci",
    description: "Gabungkan tiga mekanik dasar dalam satu jalur.",
    width: 10,
    height: 8,
    movesLimit: 26,
    initialRules: START_RULES,
    allowedRules: {
      red: ["STOP", "PUSH"],
      blue: ["STOP", "SWAP"],
      green: ["STOP", "MERGE"]
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
    ]
  },
  {
    id: 12,
    name: "Ruang Sempit",
    description: "Jalur lebih rapat dengan gate yang tetap harus dibuka berurutan.",
    width: 10,
    height: 8,
    movesLimit: 26,
    initialRules: START_RULES,
    allowedRules: {
      red: ["STOP", "PUSH"],
      blue: ["STOP", "SWAP"],
      green: ["STOP", "MERGE"]
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
    ]
  },
  {
    id: 13,
    name: "Rintangan Tajam",
    description: "Spike mempersempit jalur setelah gate biru.",
    width: 10,
    height: 8,
    movesLimit: 28,
    initialRules: START_RULES,
    allowedRules: {
      red: ["STOP", "PUSH"],
      blue: ["STOP", "SWAP"],
      green: ["STOP", "MERGE"]
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
    ]
  },
  {
    id: 14,
    name: "Audit Ketat",
    description: "Batas langkah mulai lebih sempit.",
    width: 10,
    height: 8,
    movesLimit: 27,
    initialRules: START_RULES,
    allowedRules: {
      red: ["STOP", "PUSH"],
      blue: ["STOP", "SWAP"],
      green: ["STOP", "MERGE"]
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
    ]
  },
  {
    id: 15,
    name: "Batas Hampir Pas",
    description: "Solusi butuh urutan rule yang efisien.",
    width: 10,
    height: 8,
    movesLimit: 26,
    initialRules: START_RULES,
    allowedRules: {
      red: ["STOP", "PUSH"],
      blue: ["STOP", "SWAP"],
      green: ["STOP", "MERGE"]
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
    ]
  },
  {
    id: 16,
    name: "Plate Jauh",
    description: "Plate dan gate masih berurutan, tapi ruang baca lebih padat.",
    width: 10,
    height: 9,
    movesLimit: 30,
    initialRules: START_RULES,
    allowedRules: {
      red: ["STOP", "PUSH"],
      blue: ["STOP", "SWAP"],
      green: ["STOP", "MERGE"]
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
    ]
  },
  {
    id: 17,
    name: "Jalur Bercabang",
    description: "Cabang palsu membuat route yang benar lebih sulit dibaca.",
    width: 10,
    height: 9,
    movesLimit: 30,
    initialRules: START_RULES,
    allowedRules: {
      red: ["STOP", "PUSH"],
      blue: ["STOP", "SWAP"],
      green: ["STOP", "MERGE"]
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
    ]
  },
  {
    id: 18,
    name: "Sirkuit Padat",
    description: "Semua gate inti muncul lagi dengan ruang gerak lebih kecil.",
    width: 10,
    height: 8,
    movesLimit: 25,
    initialRules: START_RULES,
    allowedRules: {
      red: ["STOP", "PUSH"],
      blue: ["STOP", "SWAP"],
      green: ["STOP", "MERGE"]
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
    ]
  },
  {
    id: 19,
    name: "Pra-Finale",
    description: "Hanya beberapa langkah cadangan tersisa.",
    width: 10,
    height: 9,
    movesLimit: 24,
    initialRules: START_RULES,
    allowedRules: {
      red: ["STOP", "PUSH"],
      blue: ["STOP", "SWAP"],
      green: ["STOP", "MERGE"]
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
    ]
  },
  {
    id: 20,
    name: "Ujian Bab Satu",
    description: "Semua rule inti muncul sebelum campaign masuk ke ronde presisi.",
    width: 10,
    height: 8,
    movesLimit: 24,
    initialRules: START_RULES,
    allowedRules: {
      red: ["STOP", "PUSH"],
      blue: ["STOP", "SWAP"],
      green: ["STOP", "MERGE"]
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
    ]
  },
  {
    id: 21,
    name: "Laboratorium Laser",
    description: "Tembak laser, teleport, dan timbun jurang. Pahami cara glyph berinteraksi dengan elemen ini.",
    width: 8,
    height: 7,
    movesLimit: 22,
    initialRules: START_RULES,
    allowedRules: {
      red: ["STOP", "PUSH", "SWAP"],
      blue: ["STOP", "PUSH"],
      green: STOP_ONLY
    },
    map: [
      "########",
      "#@.L..X#",
      "#A.###.#",
      "#..#_..#",
      "#B.#...#",
      "#[.#.]##",
      "########"
    ]
  },
  {
    id: 22,
    name: "Transisi Berwaktu",
    description: "Injak lantai sensor untuk menyalin aturan, dan manfaatkan lantai berjalan sebelum aturan berwaktu habis.",
    width: 8,
    height: 7,
    movesLimit: 20,
    initialRules: { red: "PUSH", blue: "STOP", green: "STOP" },
    allowedRules: {
      red: ["STOP", "PUSH"],
      blue: ["STOP", "PUSH"],
      green: STOP_ONLY
    },
    map: [
      "########",
      "#@.S...#",
      "#A.#####",
      "#..)..)#",
      "#B.#####",
      "#J....X#",
      "########"
    ]
  }
];

export let CHAPTER_1_TITLE = "Bab 1: Dasar & Mekanik";

export let EXTRA_CHAPTERS = [
  { title: "Bab 2: Rute Lanjutan", margin: 7 },
  { title: "Bab 3: Rute Padat", margin: 6 },
  { title: "Bab 4: Jalur Tajam", margin: 5 },
  { title: "Bab 5: Audit Cepat", margin: 4 },
  { title: "Bab 6: Hampir Presisi", margin: 3 },
  { title: "Bab 7: Presisi", margin: 2 },
  { title: "Bab 8: Master", margin: 1 },
  { title: "Finale", margin: 0 }
];

function cloneAllowedRules(allowedRules) {
  if (!allowedRules) return { red: ["STOP"], blue: ["STOP"], green: ["STOP"] };
  return Object.fromEntries(
    Object.entries(allowedRules).map(([color, rules]) => [color, Array.isArray(rules) ? [...rules] : ["STOP"]])
  );
}

function cloneLevel(level) {
  if (!level) return null;
  return {
    ...level,
    initialRules: level.initialRules ? { ...level.initialRules } : { red: "STOP", blue: "STOP", green: "STOP" },
    allowedRules: cloneAllowedRules(level.allowedRules),
    map: Array.isArray(level.map) ? [...level.map] : []
  };
}

function makeAdvancedLevel(base, baseIndex, chapter, chapterIndex) {
  const id = BASE_LEVELS.length + (chapterIndex * ADVANCED_LEVELS.length) + baseIndex + 1;
  const parMoves = PAR_MOVES[ADVANCED_START_INDEX + baseIndex];
  const isFinalLevel = chapterIndex === EXTRA_CHAPTERS.length - 1 && baseIndex === ADVANCED_LEVELS.length - 1;
  const cloned = cloneLevel(base);

  return {
    ...cloned,
    id,
    name: isFinalLevel ? "Tamat: Audit Akhir" : `${chapter.title} ${baseIndex + 1}`,
    description: isFinalLevel
      ? "Final campaign: semua rule inti harus dibaca tanpa satu langkah cadangan."
      : `${base.name} dengan batas langkah lebih ketat.`,
    movesLimit: parMoves + chapter.margin
  };
}

let ADVANCED_LEVELS = BASE_LEVELS.slice(ADVANCED_START_INDEX);

export let LEVELS = [
  ...BASE_LEVELS.map(cloneLevel),
  ...EXTRA_CHAPTERS.flatMap((chapter, chapterIndex) =>
    ADVANCED_LEVELS.map((base, baseIndex) =>
      makeAdvancedLevel(base, baseIndex, chapter, chapterIndex)
    )
  )
];

export let LEVELS_BY_MODE = {
  '1': LEVELS,
  '2': [
    {
      id: 1,
      name: "Dualitas Sakelar",
      description: "P1 dan P2 harus saling menginjak plate untuk membuka gate masing-masing.",
      width: 8,
      height: 5,
      movesLimit: 10,
      initialRules: START_RULES,
      allowedRules: { red: STOP_ONLY, blue: STOP_ONLY, green: STOP_ONLY },
      map: [
        "########",
        "#@.b.1X#",
        "########",
        "#%.a.2X#",
        "########"
      ]
    },
    {
      id: 2,
      name: "Dorong Sinkron",
      description: "P1 mendorong glyph merah ke plate merah untuk membuka jalur P1, sementara P2 menekan plate biru.",
      width: 10,
      height: 5,
      movesLimit: 18,
      initialRules: { red: "PUSH", blue: "STOP", green: "STOP" },
      allowedRules: { red: ["STOP", "PUSH"], blue: STOP_ONLY, green: STOP_ONLY },
      map: [
        "##########",
        "#@..A.1.X#",
        "####.#####",
        "#%.b.a.2X#",
        "##########"
      ]
    },
    {
      id: 3,
      name: "Persilangan Spike",
      description: "Gunakan SWAP/PUSH pada glyph biru untuk menyeberang dengan selamat.",
      width: 9,
      height: 5,
      movesLimit: 12,
      initialRules: START_RULES,
      allowedRules: { red: STOP_ONLY, blue: ["STOP", "PUSH", "SWAP"], green: STOP_ONLY },
      map: [
        "#########",
        "#@.B.^.X#",
        "####.####",
        "#%.B.^.X#",
        "#########"
      ]
    }
  ],
  '3': [
    {
      id: 1,
      name: "Triad Sakelar",
      description: "Tiga pemain harus saling membantu membuka gate dalam urutan melingkar.",
      width: 9,
      height: 7,
      movesLimit: 12,
      initialRules: START_RULES,
      allowedRules: { red: STOP_ONLY, blue: STOP_ONLY, green: STOP_ONLY },
      map: [
        "#########",
        "#@.c.1.X#",
        "#########",
        "#%.a.2.X#",
        "#########",
        "#*.b.3.X#",
        "#########"
      ]
    },
    {
      id: 2,
      name: "Segitiga Spike",
      description: "Dorong glyph masing-masing ke atas spikes dan injak plate untuk membuka gate teman.",
      width: 11,
      height: 7,
      movesLimit: 20,
      initialRules: { red: "PUSH", blue: "PUSH", green: "PUSH" },
      allowedRules: { red: ["STOP", "PUSH"], blue: ["STOP", "PUSH"], green: ["STOP", "PUSH"] },
      map: [
        "###########",
        "#@.A.^.b1X#",
        "#####.#####",
        "#%.B.^.c2X#",
        "#####.#####",
        "#*.C.^.a3X#",
        "###########"
      ]
    },
    {
      id: 3,
      name: "Merge Bertiga",
      description: "Gabungkan glyph hijau di pilar bawah untuk menyelesaikan level.",
      width: 10,
      height: 7,
      movesLimit: 16,
      initialRules: { red: "STOP", blue: "STOP", green: "MERGE" },
      allowedRules: { red: STOP_ONLY, blue: STOP_ONLY, green: ["STOP", "MERGE"] },
      map: [
        "##########",
        "#@..C.3.X#",
        "#.########",
        "#%.C.3.X##",
        "#.########",
        "#*.c.C.3X#",
        "##########"
      ]
    }
  ],
  '4': [
    {
      id: 1,
      name: "Kuartet Sakelar",
      description: "Empat pemain bekerja sama menggunakan 3 warna gate dengan dependency melingkar.",
      width: 9,
      height: 9,
      movesLimit: 16,
      initialRules: START_RULES,
      allowedRules: { red: STOP_ONLY, blue: STOP_ONLY, green: STOP_ONLY },
      map: [
        "#########",
        "#@.b.1.X#",
        "#########",
        "#%.c.2.X#",
        "#########",
        "#*.a.3.X#",
        "#########",
        "#$.a.1.X#",
        "#########"
      ]
    },
    {
      id: 2,
      name: "Kerja Sama Kuartet",
      description: "P1, P2, P3 harus menyeberangi spike, sementara P4 berdiri di atas plate-plate pengontrol gate.",
      width: 10,
      height: 9,
      movesLimit: 16,
      initialRules: { red: "PUSH", blue: "PUSH", green: "PUSH" },
      allowedRules: { red: ["STOP", "PUSH"], blue: ["STOP", "PUSH"], green: ["STOP", "PUSH"] },
      map: [
        "##########",
        "#@.A.^.1X#",
        "##########",
        "#%.B.^.2X#",
        "##########",
        "#*.C.^.3X#",
        "##########",
        "#$.a.b.cX#",
        "##########"
      ]
    },
    {
      id: 3,
      name: "Persilangan Kuartet",
      description: "Gunakan dependency melingkar untuk membebaskan semua rekan tim.",
      width: 9,
      height: 9,
      movesLimit: 16,
      initialRules: START_RULES,
      allowedRules: { red: STOP_ONLY, blue: STOP_ONLY, green: STOP_ONLY },
      map: [
        "#########",
        "#@.a.1.X#",
        "#########",
        "#%.b.2.X#",
        "#########",
        "#*.c.3.X#",
        "#########",
        "#$.b.2.X#",
        "#########"
      ]
    }
  ]
};

const VALID_LEVEL_SYMBOLS = new Set(
  [...'.#R><NvT456MWYZ-|QEFGDX^abc123@&%*$ABCHK[]_LlPp(){}IOUVJS0789?!defghi']
);
const VALID_RULES = new Set(['STOP', 'PUSH', 'SWAP', 'MERGE']);
const PLAYER_SYMBOLS = [
  ['@'],
  ['%', '&'],
  ['*'],
  ['$']
];
const PLAYER_PORTALS = ['I', 'O', 'U', 'V'];

function validateLevel(level, mode, index) {
  const label = `mode ${mode}, level ${index + 1}`;
  if (!level || typeof level !== 'object') {
    throw new Error(`${label}: expected an object`);
  }

  for (const field of ['id', 'width', 'height', 'movesLimit']) {
    if (!Number.isInteger(level[field]) || level[field] <= 0) {
      throw new Error(`${label}: ${field} must be a positive integer`);
    }
  }
  if (level.width > 64 || level.height > 64) {
    throw new Error(`${label}: grid dimensions exceed 64 cells`);
  }
  if (typeof level.name !== 'string' || typeof level.description !== 'string') {
    throw new Error(`${label}: name and description are required`);
  }
  if (!Array.isArray(level.map) || level.map.length !== level.height) {
    throw new Error(`${label}: map height does not match height`);
  }

  const mapText = level.map.join('');
  level.map.forEach((row, rowIndex) => {
    if (typeof row !== 'string' || row.length !== level.width) {
      throw new Error(`${label}: row ${rowIndex + 1} width does not match width`);
    }
    for (const symbol of row) {
      if (!VALID_LEVEL_SYMBOLS.has(symbol)) {
        throw new Error(`${label}: unsupported map symbol ${JSON.stringify(symbol)}`);
      }
    }
  });

  if (level.custom_floor_map) {
    if (!Array.isArray(level.custom_floor_map) || level.custom_floor_map.length !== level.height) {
      throw new Error(`${label}: custom_floor_map height does not match height`);
    }
    level.custom_floor_map.forEach((row, rowIndex) => {
      if (typeof row !== 'string' || row.length !== level.width) {
        throw new Error(`${label}: custom_floor_map row ${rowIndex + 1} width does not match width`);
      }
      for (const symbol of row) {
        if (symbol !== '.' && (symbol < '1' || symbol > '6')) {
          throw new Error(`${label}: unsupported custom_floor_map symbol ${JSON.stringify(symbol)}`);
        }
      }
    });
  }

  const playerCount = Number(mode);
  PLAYER_SYMBOLS.forEach((symbols, playerIndex) => {
    const count = symbols.reduce(
      (total, symbol) => total + [...mapText].filter(char => char === symbol).length,
      0
    );
    const expected = playerIndex < playerCount ? 1 : 0;
    if (count !== expected) {
      console.warn(`${label}: P${playerIndex + 1} start count must be ${expected}, got ${count}`);
    }
    if (expected === 1 && !mapText.includes('X') && !mapText.includes(PLAYER_PORTALS[playerIndex])) {
      console.warn(`${label}: P${playerIndex + 1} has no reachable goal type`);
    }
  });

  if (!level.initialRules || !level.allowedRules) {
    throw new Error(`${label}: initialRules and allowedRules are required`);
  }
  for (const color of ['red', 'blue', 'green']) {
    const initial = level.initialRules[color];
    const allowed = level.allowedRules[color];
    if (!VALID_RULES.has(initial) || !Array.isArray(allowed) || allowed.length === 0 ||
        allowed.some(rule => !VALID_RULES.has(rule)) || !allowed.includes(initial)) {
      throw new Error(`${label}: invalid rule configuration for ${color}`);
    }
  }
}

export function validateLevelData(level, mode = '1') {
  validateLevel(level, String(mode), 0);
  return level;
}

function validateCampaignData(data) {
  const modes = data?.levels_by_mode;
  if (!modes || typeof modes !== 'object') {
    throw new Error('levels_by_mode is required');
  }

  for (const mode of ['1', '2', '3', '4']) {
    const levels = modes[mode];
    if (!Array.isArray(levels) || levels.length === 0) {
      throw new Error(`levels_by_mode.${mode} must contain levels`);
    }
    const ids = new Set();
    levels.forEach((level, index) => {
      validateLevel(level, mode, index);
      if (ids.has(level.id)) {
        throw new Error(`mode ${mode}: duplicate level id ${level.id}`);
      }
      ids.add(level.id);
    });
  }
}

export async function loadLevels() {
  const candidates = [
    './rule_glyph_app/assets/levels.json',
    './assets/levels.json'
  ];

  try {
    let data = null;
    let loadedFrom = '';

    for (const path of candidates) {
      try {
        const response = await fetch(path, { cache: 'no-store' });
        if (!response.ok) continue;
        data = await response.json();
        loadedFrom = path;
        break;
      } catch (e) {
        // Try the next path; static fallback below still keeps the game playable.
      }
    }

    if (!data) {
      throw new Error('No Android JSON file found');
    }

    validateCampaignData(data);

    if (data.chapters && Array.isArray(data.chapters)) {
      if (data.chapters[0]) {
        CHAPTER_1_TITLE = data.chapters[0].title || data.chapters[0];
      }
      EXTRA_CHAPTERS.length = 0;
      data.chapters.slice(1).forEach((ch, idx) => {
        EXTRA_CHAPTERS.push({
          title: ch.title || ch,
          margin: ch.margin !== undefined ? ch.margin : Math.max(0, 7 - idx)
        });
      });
    }

    const modes = data.levels_by_mode || {};
    const soloLevels = modes['1'] || data.base_levels || [];
    if (soloLevels.length === 0) {
      throw new Error('No solo levels found in JSON');
    }

    // Enforce sequential 1-based IDs on load to prevent drift or mismatch
    soloLevels.forEach((level, index) => {
      level.id = index + 1;
    });

    for (const mode of ['2', '3', '4']) {
      const source = modes[mode] || data[mode] || [];
      source.forEach((level, index) => {
        level.id = index + 1;
      });
    }

    // levels_by_mode is the canonical source. base_levels is derived data.
    BASE_LEVELS = soloLevels.slice(0, 22).map(cloneLevel);
    ADVANCED_LEVELS = BASE_LEVELS.slice(ADVANCED_START_INDEX);

    LEVELS.length = 0;
    soloLevels.forEach(level => LEVELS.push(cloneLevel(level)));
    LEVELS_BY_MODE['1'] = LEVELS;

    for (const mode of ['2', '3', '4']) {
      const source = modes[mode] || data[mode] || [];
      if (source.length > 0) {
        LEVELS_BY_MODE[mode] = source.map(cloneLevel);
      }
    }

    console.log(`Loaded Android levels JSON from ${loadedFrom}:`, LEVELS.length, '1P levels.');
  } catch (error) {
    console.error('Failed to load Android levels JSON, falling back to static database:', error);
  }
}

export function setChapter1Title(title) {
  CHAPTER_1_TITLE = title;
}
