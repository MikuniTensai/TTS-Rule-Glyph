import { CHAR_TO_COLOR, GLYPH_TYPES } from './rules.js';
import { AudioEngine } from './audio.js';

export class GridEngine {
  constructor(boardDom, gridBgDom) {
    this.boardDom = boardDom;
    this.gridBgDom = gridBgDom;
    
    // Level dimensions
    this.width = 0;
    this.height = 0;
    
    // Static cell elements: 2D array [x][y]
    this.cells = [];
    
    // Dynamic entities (up to 4 players)
    this.players = [
      { id: 'p1', label: 'P1', x: 0, y: 0, dead: false, finished: false },
      { id: 'p2', label: 'P2', x: 0, y: 0, dead: false, finished: false },
      { id: 'p3', label: 'P3', x: 0, y: 0, dead: false, finished: false },
      { id: 'p4', label: 'P4', x: 0, y: 0, dead: false, finished: false }
    ];
    this.player = this.players[0];
    this.glyphs = []; // Array of { id, type, x, y }
    
    // DOM Cache maps
    this.glyphDoms = new Map(); // id -> HTMLElement
    this.playerDoms = new Map(); // id -> HTMLElement
    this.playerDom = null;
    this.gateDoms = new Map(); // 'x,y' -> HTMLElement
    this.plateDoms = new Map(); // 'x,y' -> HTMLElement
    this.spikeDoms = new Map(); // 'x,y' -> HTMLElement
    this.wallDoms = new Map(); // 'x,y' -> HTMLElement
    this.floorDoms = new Map(); // 'x,y' -> HTMLElement
    this.portalDoms = new Map(); // 'x,y' -> HTMLElement
    this.teleportDoms = new Map(); // 'x,y' -> HTMLElement
    this.chasmDoms = new Map(); // 'x,y' -> HTMLElement
    this.emitterDoms = new Map(); // 'x,y' -> HTMLElement
    this.conveyorDoms = new Map(); // 'x,y' -> HTMLElement
    this.identityPortalDoms = new Map(); // 'x,y' -> HTMLElement
    this.jammerDoms = new Map(); // 'x,y' -> HTMLElement
    this.sensorDoms = new Map(); // 'x,y' -> HTMLElement
    this.wallChallengeDoms = new Map(); // 'x,y' -> HTMLElement
    
    this.glyphIdCounter = 0;
    this.stepCount = 0;
  }

  /**
   * Parse a raw level map and initialize the grids
   */
  loadLevel(levelData) {
    this.levelData = levelData;
    this.width = levelData.width;
    this.height = levelData.height;
    
    // Clear DOM and caches
    this.boardDom.querySelectorAll('.grid-element').forEach(el => el.remove());
    this.gridBgDom.innerHTML = '';
    this.glyphDoms.clear();
    this.gateDoms.clear();
    this.plateDoms.clear();
    this.spikeDoms.clear();
    this.wallDoms.clear();
    this.floorDoms.clear();
    this.portalDoms.clear();
    this.teleportDoms.clear();
    this.chasmDoms.clear();
    this.emitterDoms.clear();
    this.conveyorDoms.clear();
    this.identityPortalDoms.clear();
    this.jammerDoms.clear();
    this.sensorDoms.clear();
    this.wallChallengeDoms.clear();
    this.playerDoms.clear();
    this.playerDom = null;
    
    this.glyphIdCounter = 0;
    this.stepCount = 0;
    this.players = [
      { id: 'p1', label: 'P1', x: -1, y: -1, dead: false, finished: false },
      { id: 'p2', label: 'P2', x: -1, y: -1, dead: false, finished: false },
      { id: 'p3', label: 'P3', x: -1, y: -1, dead: false, finished: false },
      { id: 'p4', label: 'P4', x: -1, y: -1, dead: false, finished: false }
    ];
    this.player = this.players[0];
    this.glyphs = [];
    
    // Set CSS grid size variables
    const boardSize = `min(${this.width * 48}px, calc(100vw - 48px))`;
    this.boardDom.style.setProperty('--grid-cols', this.width);
    this.boardDom.style.setProperty('--grid-rows', this.height);
    this.boardDom.style.setProperty('--board-size', boardSize);
    this.boardDom.parentElement?.style.setProperty('--grid-cols', this.width);
    this.boardDom.parentElement?.style.setProperty('--grid-rows', this.height);
    this.boardDom.parentElement?.style.setProperty('--board-size', boardSize);
    this.boardDom.closest('.play-area')?.style.setProperty('--grid-cols', this.width);
    this.boardDom.closest('.play-area')?.style.setProperty('--grid-rows', this.height);
    this.boardDom.closest('.play-area')?.style.setProperty('--board-size', boardSize);
    
    if (levelData && levelData.custom_floor) {
      this.boardDom.style.backgroundImage = `url(${levelData.custom_floor})`;
      this.boardDom.style.backgroundSize = 'cover';
      this.boardDom.style.backgroundPosition = 'center';
      this.boardDom.classList.add('has-custom-floor');
    } else {
      this.boardDom.style.removeProperty('background-image');
      this.boardDom.style.removeProperty('background-size');
      this.boardDom.style.removeProperty('background-position');
      this.boardDom.classList.remove('has-custom-floor');
    }
    
    const defaultFloorImage = levelData && levelData.custom_floor_0;
    // Build background grid lines
    this.gridBgDom.style.gridTemplateColumns = `repeat(${this.width}, 1fr)`;
    this.gridBgDom.style.gridTemplateRows = `repeat(${this.height}, 1fr)`;
    for (let i = 0; i < this.width * this.height; i++) {
      const bgCell = document.createElement('div');
      bgCell.className = 'grid-cell-bg';
      if (defaultFloorImage) {
        bgCell.style.backgroundImage = `url(${defaultFloorImage})`;
        bgCell.style.backgroundSize = 'cover';
        bgCell.style.backgroundPosition = 'center';
      }
      this.gridBgDom.appendChild(bgCell);
    }
    
    // Initialize 2D cells array
    this.cells = Array.from({ length: this.width }, () => 
      Array.from({ length: this.height }, () => ({
        isWall: false,
        customWallIndex: 0,
        customFloorIndex: 0,
        isCrackedWall: false,
        oneWayDir: null, // 'L', 'R', 'U', 'D'
        isTimedWall: false,
        colorWallColor: null, // 'red', 'blue', 'green'
        isMirrorWall: false,
        isSoftWall: false,
        linkedWallGroup: null, // 'a', 'b'
        rotatingWallAxis: null, // 'horizontal', 'vertical'
        playerWallAllowedId: null, // 'p1', 'p2', 'p3', 'p4'
        isGlyphOnlyWall: false,
        hasPortal: false,
        hasSpikes: false,
        plateColor: null, // 'red', 'blue', 'green' or null
        gateColor: null,  // 'red', 'blue', 'green' or null
        teleportType: null, // 'in' or 'out'
        isChasm: false,
        laserType: null, // 'L', 'l', 'P', 'p'
        conveyorDir: null, // 'L', 'R', 'U', 'D'
        identityPortalPlayer: null, // 'p1', 'p2', 'p3', 'p4'
        isJammer: false,
        isSensor: false
      }))
    );
    
    // Parse the map character rows
    for (let y = 0; y < this.height; y++) {
      const rowStr = levelData.map[y];
      if (!rowStr) continue;
      for (let x = 0; x < this.width; x++) {
        const char = rowStr[x];
        const cell = this.cells[x][y];
        
        switch (char) {
          case '#':
            cell.isWall = true;
            cell.customWallIndex = 0;
            this.wallDoms.set(`${x},${y}`, this.createStaticDom('wall wall-0', x, y));
            break;
          case '0':
            cell.isWall = true;
            cell.customWallIndex = 1;
            this.wallDoms.set(`${x},${y}`, this.createStaticDom('wall wall-1', x, y));
            break;
          case '7':
            cell.isWall = true;
            cell.customWallIndex = 2;
            this.wallDoms.set(`${x},${y}`, this.createStaticDom('wall wall-2', x, y));
            break;
          case '8':
            cell.isWall = true;
            cell.customWallIndex = 3;
            this.wallDoms.set(`${x},${y}`, this.createStaticDom('wall wall-3', x, y));
            break;
          case '9':
            cell.isWall = true;
            cell.customWallIndex = 4;
            this.wallDoms.set(`${x},${y}`, this.createStaticDom('wall wall-4', x, y));
            break;
          case '?':
            cell.isWall = true;
            cell.customWallIndex = 5;
            this.wallDoms.set(`${x},${y}`, this.createStaticDom('wall wall-5', x, y));
            break;
          case '!':
            cell.isWall = true;
            cell.customWallIndex = 6;
            this.wallDoms.set(`${x},${y}`, this.createStaticDom('wall wall-6', x, y));
            break;
          case 'R':
            cell.isCrackedWall = true;
            this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge cracked-wall', x, y));
            break;
          case '>':
            cell.oneWayDir = 'R';
            this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge one-way one-way-r', x, y));
            break;
          case '<':
            cell.oneWayDir = 'L';
            this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge one-way one-way-l', x, y));
            break;
          case 'N':
            cell.oneWayDir = 'U';
            this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge one-way one-way-u', x, y));
            break;
          case 'v':
            cell.oneWayDir = 'D';
            this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge one-way one-way-d', x, y));
            break;
          case 'T':
            cell.isTimedWall = true;
            this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge timed-wall', x, y));
            break;
          case '4':
            cell.colorWallColor = GLYPH_TYPES.RED;
            this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge color-wall color-wall-red', x, y));
            break;
          case '5':
            cell.colorWallColor = GLYPH_TYPES.BLUE;
            this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge color-wall color-wall-blue', x, y));
            break;
          case '6':
            cell.colorWallColor = GLYPH_TYPES.GREEN;
            this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge color-wall color-wall-green', x, y));
            break;
          case 'M':
            cell.isMirrorWall = true;
            this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge mirror-wall', x, y));
            break;
          case 'W':
            cell.isSoftWall = true;
            this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge soft-wall', x, y));
            break;
          case 'Y':
            cell.linkedWallGroup = 'a';
            this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge linked-wall linked-wall-a', x, y));
            break;
          case 'Z':
            cell.linkedWallGroup = 'b';
            this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge linked-wall linked-wall-b', x, y));
            break;
          case '-':
            cell.rotatingWallAxis = 'horizontal';
            this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge rotating-wall rotating-wall-h', x, y));
            break;
          case '|':
            cell.rotatingWallAxis = 'vertical';
            this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge rotating-wall rotating-wall-v', x, y));
            break;
          case 'Q':
            cell.playerWallAllowedId = 'p1';
            this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge player-wall player-wall-p1', x, y));
            break;
          case 'E':
            cell.playerWallAllowedId = 'p2';
            this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge player-wall player-wall-p2', x, y));
            break;
          case 'F':
            cell.playerWallAllowedId = 'p3';
            this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge player-wall player-wall-p3', x, y));
            break;
          case 'G':
            cell.playerWallAllowedId = 'p4';
            this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge player-wall player-wall-p4', x, y));
            break;
          case 'D':
            cell.isGlyphOnlyWall = true;
            this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge glyph-only-wall', x, y));
            break;
          case 'X':
            cell.hasPortal = true;
            this.portalDoms.set(`${x},${y}`, this.createStaticDom('portal', x, y));
            break;
          case '^':
            cell.hasSpikes = true;
            this.spikeDoms.set(`${x},${y}`, this.createStaticDom('spikes', x, y));
            break;
            
          // Plates
          case 'a':
            cell.plateColor = GLYPH_TYPES.RED;
            this.plateDoms.set(`${x},${y}`, this.createStaticDom('plate plate-red', x, y));
            break;
          case 'b':
            cell.plateColor = GLYPH_TYPES.BLUE;
            this.plateDoms.set(`${x},${y}`, this.createStaticDom('plate plate-blue', x, y));
            break;
          case 'c':
            cell.plateColor = GLYPH_TYPES.GREEN;
            this.plateDoms.set(`${x},${y}`, this.createStaticDom('plate plate-green', x, y));
            break;
            
          // Gates
          case '1':
            cell.gateColor = GLYPH_TYPES.RED;
            this.gateDoms.set(`${x},${y}`, this.createStaticDom('gate gate-red', x, y));
            break;
          case '2':
            cell.gateColor = GLYPH_TYPES.BLUE;
            this.gateDoms.set(`${x},${y}`, this.createStaticDom('gate gate-blue', x, y));
            break;
          case '3':
            cell.gateColor = GLYPH_TYPES.GREEN;
            this.gateDoms.set(`${x},${y}`, this.createStaticDom('gate gate-green', x, y));
            break;
            
          // Player
          case '@':
            this.placePlayer('p1', x, y);
            break;
          case '&':
          case '%':
            this.placePlayer('p2', x, y);
            break;
          case '*':
            this.placePlayer('p3', x, y);
            break;
          case '$':
            this.placePlayer('p4', x, y);
            break;
            
          // Glyphs
          case 'A':
          case 'B':
          case 'C': {
            const color = CHAR_TO_COLOR[char];
            this.spawnGlyph(color, x, y);
            break;
          }
          case 'H':
            this.spawnGlyph('heavy-2', x, y);
            break;
          case 'K':
            this.spawnGlyph('heavy-3', x, y);
            break;
          case '[':
            cell.teleportType = 'in';
            this.teleportDoms.set(`${x},${y}`, this.createStaticDom('teleport-in', x, y));
            break;
          case ']':
            cell.teleportType = 'out';
            this.teleportDoms.set(`${x},${y}`, this.createStaticDom('teleport-out', x, y));
            break;
          case '_':
            cell.isChasm = true;
            this.chasmDoms.set(`${x},${y}`, this.createStaticDom('chasm', x, y));
            break;
          case 'L':
            cell.laserType = 'L';
            this.emitterDoms.set(`${x},${y}`, this.createStaticDom('emitter emitter-h', x, y));
            break;
          case 'l':
            cell.laserType = 'l';
            this.emitterDoms.set(`${x},${y}`, this.createStaticDom('emitter emitter-v', x, y));
            break;
          case 'P':
            cell.laserType = 'P';
            this.emitterDoms.set(`${x},${y}`, this.createStaticDom('emitter emitter-pulsing-h', x, y));
            break;
          case 'p':
            cell.laserType = 'p';
            this.emitterDoms.set(`${x},${y}`, this.createStaticDom('emitter emitter-pulsing-v', x, y));
            break;
          case '(':
            cell.conveyorDir = 'L';
            this.conveyorDoms.set(`${x},${y}`, this.createStaticDom('conveyor conveyor-left', x, y));
            break;
          case ')':
            cell.conveyorDir = 'R';
            this.conveyorDoms.set(`${x},${y}`, this.createStaticDom('conveyor conveyor-right', x, y));
            break;
          case '{':
            cell.conveyorDir = 'U';
            this.conveyorDoms.set(`${x},${y}`, this.createStaticDom('conveyor conveyor-up', x, y));
            break;
          case '}':
            cell.conveyorDir = 'D';
            this.conveyorDoms.set(`${x},${y}`, this.createStaticDom('conveyor conveyor-down', x, y));
            break;
          case 'I':
            cell.identityPortalPlayer = 'p1';
            this.identityPortalDoms.set(`${x},${y}`, this.createStaticDom('identity-portal portal-p1', x, y));
            break;
          case 'O':
            cell.identityPortalPlayer = 'p2';
            this.identityPortalDoms.set(`${x},${y}`, this.createStaticDom('identity-portal portal-p2', x, y));
            break;
          case 'U':
            cell.identityPortalPlayer = 'p3';
            this.identityPortalDoms.set(`${x},${y}`, this.createStaticDom('identity-portal portal-p3', x, y));
            break;
          case 'V':
            cell.identityPortalPlayer = 'p4';
            this.identityPortalDoms.set(`${x},${y}`, this.createStaticDom('identity-portal portal-p4', x, y));
            break;
          case 'J':
            cell.isJammer = true;
            this.jammerDoms.set(`${x},${y}`, this.createStaticDom('jammer-zone', x, y));
            break;
          case 'S':
            cell.isSensor = true;
            this.sensorDoms.set(`${x},${y}`, this.createStaticDom('sensor-floor', x, y));
            break;
          case 'd':
            cell.customFloorIndex = 1;
            this.floorDoms.set(`${x},${y}`, this.createStaticDom('floor floor-1', x, y));
            break;
          case 'e':
            cell.customFloorIndex = 2;
            this.floorDoms.set(`${x},${y}`, this.createStaticDom('floor floor-2', x, y));
            break;
          case 'f':
            cell.customFloorIndex = 3;
            this.floorDoms.set(`${x},${y}`, this.createStaticDom('floor floor-3', x, y));
            break;
          case 'g':
            cell.customFloorIndex = 4;
            this.floorDoms.set(`${x},${y}`, this.createStaticDom('floor floor-4', x, y));
            break;
          case 'h':
            cell.customFloorIndex = 5;
            this.floorDoms.set(`${x},${y}`, this.createStaticDom('floor floor-5', x, y));
            break;
          case 'i':
            cell.customFloorIndex = 6;
            this.floorDoms.set(`${x},${y}`, this.createStaticDom('floor floor-6', x, y));
            break;
        }
      }
    }

    // Auto-placement is disabled to support single-player mode when P2 is absent.
    
    // Spawn player DOMs
    for (const player of this.players) {
      if (player.x !== -1) {
        this.spawnPlayerDom(player);
      }
    }

    // Parse custom floor map layer if present (for cells with both floor and overlays/players)
    if (levelData && levelData.custom_floor_map) {
      for (let y = 0; y < this.height; y++) {
        const rowStr = levelData.custom_floor_map[y];
        if (!rowStr) continue;
        for (let x = 0; x < this.width; x++) {
          const char = rowStr[x];
          if (char >= '1' && char <= '6') {
            const idx = parseInt(char, 10);
            const cell = this.cells[x][y];
            cell.customFloorIndex = idx;
            const key = `${x},${y}`;
            if (this.floorDoms.has(key)) {
              this.floorDoms.get(key).remove();
            }
            this.floorDoms.set(key, this.createStaticDom(`floor floor-${idx}`, x, y));
          }
        }
      }
    }
    
    // Compute initial doors/plates states
    this.updateTriggers(false);
    this.render();
  }

  /**
   * Save a snapshot of the grid state for Undo operations
   */
  getStateSnapshot() {
    return {
      player: { ...this.player },
      players: this.players.map(p => ({ ...p })),
      glyphs: this.glyphs.map(g => ({ ...g })),
      stepCount: this.stepCount,
      cellsIsChasm: this.cells.map(row => row.map(cell => cell.isChasm)),
      cellsIsCrackedWall: this.cells.map(row => row.map(cell => cell.isCrackedWall))
    };
  }

  /**
   * Restore a snapshot of the grid state
   */
  restoreStateSnapshot(snapshot) {
    this.stepCount = snapshot.stepCount || 0;
    
    // Restore chasm states
    if (snapshot.cellsIsChasm) {
      for (let x = 0; x < this.width; x++) {
        for (let y = 0; y < this.height; y++) {
          const wasChasm = snapshot.cellsIsChasm[x][y];
          const cell = this.cells[x][y];
          if (cell.isChasm !== wasChasm) {
            cell.isChasm = wasChasm;
            if (wasChasm) {
              if (!this.chasmDoms.has(`${x},${y}`)) {
                this.chasmDoms.set(`${x},${y}`, this.createStaticDom('chasm', x, y));
              }
            } else {
              if (this.chasmDoms.has(`${x},${y}`)) {
                this.chasmDoms.get(`${x},${y}`).remove();
                this.chasmDoms.delete(`${x},${y}`);
              }
            }
          }
        }
      }
    }

    if (snapshot.cellsIsCrackedWall) {
      for (let x = 0; x < this.width; x++) {
        for (let y = 0; y < this.height; y++) {
          const wasCracked = snapshot.cellsIsCrackedWall[x][y];
          const cell = this.cells[x][y];
          if (cell.isCrackedWall !== wasCracked) {
            cell.isCrackedWall = wasCracked;
            const key = `${x},${y}`;
            if (wasCracked) {
              if (!this.wallChallengeDoms.has(key)) {
                this.wallChallengeDoms.set(key, this.createStaticDom('wall-challenge cracked-wall', x, y));
              }
            } else if (this.wallChallengeDoms.has(key)) {
              this.wallChallengeDoms.get(key).remove();
              this.wallChallengeDoms.delete(key);
            }
          }
        }
      }
    }

    this.players = (snapshot.players || [snapshot.player]).map((player, index) => ({
      id: player.id || `p${index + 1}`,
      label: player.label || `P${index + 1}`,
      x: player.x,
      y: player.y,
      dead: !!player.dead,
      finished: !!player.finished
    }));

    while (this.players.length < 4) {
      const idx = this.players.length;
      this.players.push({ id: `p${idx + 1}`, label: `P${idx + 1}`, x: -1, y: -1, dead: false, finished: false });
    }

    this.player = this.players[0];

    for (const player of this.players) {
      if (player.x !== -1 && !this.playerDoms.has(player.id)) {
        this.spawnPlayerDom(player);
      }
    }
    
    // Sync current glyphs with snapshot ones (preserving IDs for transition animation)
    const syncedGlyphs = [];
    const usedSnapIds = new Set();
    
    // 1. Update existing glyphs that match by ID
    for (const snapG of snapshot.glyphs) {
      const existing = this.glyphs.find(g => g.id === snapG.id);
      if (existing) {
        existing.x = snapG.x;
        existing.y = snapG.y;
        syncedGlyphs.push(existing);
        usedSnapIds.add(snapG.id);
      } else {
        // This glyph was merged/removed, so we recreate it with its original ID
        const newG = { ...snapG };
        this.createGlyphDom(newG);
        syncedGlyphs.push(newG);
      }
    }
    
    // 2. Remove DOM elements of glyphs that are no longer in the snapshot
    for (const g of this.glyphs) {
      if (!snapshot.glyphs.some(snapG => snapG.id === g.id)) {
        const dom = this.glyphDoms.get(g.id);
        if (dom) {
          dom.style.transform += ' scale(0)';
          dom.style.opacity = '0';
          setTimeout(() => dom.remove(), 150);
          this.glyphDoms.delete(g.id);
        }
      }
    }
    
    this.glyphs = syncedGlyphs;
    this.updateTriggers(false);
    this.render();
  }

  /**
   * Create static grid item DOM element
   */
  createStaticDom(className, x, y) {
    const el = document.createElement('div');
    const classes = className.split(' ').map(c => `elem-${c}`).join(' ');
    el.className = `grid-element ${classes}`;
    
    const content = document.createElement('div');
    content.className = 'element-content';
    el.appendChild(content);
    
    if (className.includes('wall') && !className.includes('wall-challenge')) {
      const match = className.match(/wall-(\d)/);
      if (match) {
        const wallIdx = parseInt(match[1], 10);
        let customWallData = this.levelData ? this.levelData[`custom_wall_${wallIdx}`] : null;
        if (!customWallData && wallIdx === 0) {
          try {
            customWallData = window.localStorage.getItem('rule_glyph_custom_wall_image');
          } catch (e) {}
        }
        if (customWallData) {
          content.style.backgroundImage = `url(${customWallData})`;
          content.style.backgroundSize = 'cover';
          content.style.backgroundPosition = 'center';
          el.classList.add('has-custom-texture');
        }
      }
    }
    
    if (className.includes('floor')) {
      const match = className.match(/floor-(\d)/);
      if (match) {
        const floorIdx = parseInt(match[1], 10);
        let customFloorData = this.levelData ? this.levelData[`custom_floor_${floorIdx}`] : null;
        if (customFloorData) {
          content.style.backgroundImage = `url(${customFloorData})`;
          content.style.backgroundSize = 'cover';
          content.style.backgroundPosition = 'center';
          el.classList.add('has-custom-texture');
        }
      }
    }
    
    this.positionElement(el, x, y);
    this.boardDom.appendChild(el);
    return el;
  }

  placePlayer(playerId, x, y) {
    const player = this.players.find(p => p.id === playerId);
    if (!player) return;

    player.x = x;
    player.y = y;
    player.dead = false;
    player.finished = false;

    if (playerId === 'p1') {
      this.player = player;
    }
  }

  getPlayer(playerId = 'p1') {
    return this.players.find(p => p.id === playerId) || this.player;
  }

  isPlayerActive(player) {
    return player && player.x !== -1 && !player.dead && !player.finished;
  }

  getPlayerAt(x, y, ignorePlayerId = null) {
    return this.players.find(player => {
      return player.id !== ignorePlayerId &&
        this.isPlayerActive(player) &&
        player.x === x &&
        player.y === y;
    }) || null;
  }

  hasAnyPlayerDead() {
    return this.players.some(player => player.dead);
  }

  areAllPlayersFinished() {
    return this.players.every(player => player.finished || player.x === -1);
  }

  isCellOpenForAutoPlayer(x, y) {
    if (x < 0 || x >= this.width || y < 0 || y >= this.height) return false;

    const cell = this.cells[x][y];
    if (cell.isWall || cell.hasSpikes || cell.hasPortal || cell.gateColor || cell.plateColor) return false;
    if (this.glyphs.some(g => g.x === x && g.y === y)) return false;
    if (this.getPlayerAt(x, y)) return false;

    return true;
  }

  placeAutoSecondPlayer() {
    const startX = this.player.x;
    const startY = this.player.y;
    const offsets = [
      [0, 1], [1, 0], [-1, 0], [0, -1],
      [1, 1], [-1, 1], [2, 0], [0, 2],
      [2, 1], [1, 2], [3, 0], [0, 3],
      [4, 0], [0, 4], [5, 0], [0, 5]
    ];

    for (const [dx, dy] of offsets) {
      const x = startX + dx;
      const y = startY + dy;
      if (this.isCellOpenForAutoPlayer(x, y)) {
        this.placePlayer('p2', x, y);
        return;
      }
    }

    for (let y = 0; y < this.height; y++) {
      for (let x = 0; x < this.width; x++) {
        if (this.isCellOpenForAutoPlayer(x, y)) {
          this.placePlayer('p2', x, y);
          return;
        }
      }
    }
  }

  /**
   * Spawn a new Glyph object
   */
  spawnGlyph(type, x, y) {
    const id = this.glyphIdCounter++;
    const glyph = { id, type, x, y };
    this.glyphs.push(glyph);
    this.createGlyphDom(glyph);
  }

  /**
   * Create visual representation of Glyph
   */
  createGlyphDom(glyph) {
    const el = document.createElement('div');
    el.className = `grid-element elem-glyph elem-glyph-${glyph.type}`;
    el.dataset.id = glyph.id;
    
    const content = document.createElement('div');
    content.className = 'element-content';
    el.appendChild(content);
    
    this.positionElement(el, glyph.x, glyph.y);
    this.boardDom.appendChild(el);
    this.glyphDoms.set(glyph.id, el);
  }

  /**
   * Spawn player DOM
   */
  spawnPlayerDom(player = this.player) {
    const existing = this.playerDoms.get(player.id);
    if (existing) {
      existing.remove();
    }
    const playerDom = document.createElement('div');
    playerDom.className = `grid-element elem-player elem-player-${player.id}`;
    playerDom.dataset.player = player.id;
    
    const content = document.createElement('div');
    content.className = 'element-content';
    playerDom.appendChild(content);
    
    this.positionElement(playerDom, player.x, player.y);
    this.boardDom.appendChild(playerDom);
    this.playerDoms.set(player.id, playerDom);

    if (player.id === 'p1') {
      this.playerDom = playerDom;
    }
  }

  /**
   * Set hardware accelerated translate on grid element
   */
  positionElement(el, x, y) {
    el.style.transform = `translate(${x * 100}%, ${y * 100}%)`;
  }

  /**
   * Clear all entities and static items in a single cell
   */
  clearCell(x, y) {
    // 1. Clear static logic states
    const cell = this.cells[x][y];
    cell.isWall = false;
    cell.customWallIndex = 0;
    cell.customFloorIndex = 0;
    cell.isCrackedWall = false;
    cell.oneWayDir = null;
    cell.isTimedWall = false;
    cell.colorWallColor = null;
    cell.isMirrorWall = false;
    cell.isSoftWall = false;
    cell.linkedWallGroup = null;
    cell.rotatingWallAxis = null;
    cell.playerWallAllowedId = null;
    cell.isGlyphOnlyWall = false;
    cell.hasPortal = false;
    cell.hasSpikes = false;
    cell.plateColor = null;
    cell.gateColor = null;
    cell.teleportType = null;
    cell.isChasm = false;
    cell.laserType = null;
    cell.conveyorDir = null;
    cell.identityPortalPlayer = null;
    cell.isJammer = false;
    cell.isSensor = false;

    // 2. Clear static DOM caches
    const coordKey = `${x},${y}`;
    const doms = [
      this.wallDoms,
      this.floorDoms,
      this.portalDoms,
      this.spikeDoms,
      this.plateDoms,
      this.gateDoms,
      this.teleportDoms,
      this.chasmDoms,
      this.emitterDoms,
      this.conveyorDoms,
      this.identityPortalDoms,
      this.jammerDoms,
      this.sensorDoms,
      this.wallChallengeDoms
    ];
    for (const domMap of doms) {
      if (domMap && domMap.has(coordKey)) {
        domMap.get(coordKey).remove();
        domMap.delete(coordKey);
      }
    }

    // 3. Clear dynamic glyphs
    const glyphIdx = this.glyphs.findIndex(g => g.x === x && g.y === y);
    if (glyphIdx !== -1) {
      const g = this.glyphs[glyphIdx];
      if (this.glyphDoms.has(g.id)) {
        this.glyphDoms.get(g.id).remove();
        this.glyphDoms.delete(g.id);
      }
      this.glyphs.splice(glyphIdx, 1);
    }

    // 4. Clear players if matches
    for (const player of this.players) {
      if (player.x === x && player.y === y) {
        player.x = -1;
        player.y = -1;
        player.dead = false;
        player.finished = false;
        const dom = this.playerDoms.get(player.id);
        if (dom) {
          dom.remove();
          this.playerDoms.delete(player.id);
        }
        if (player.id === 'p1') {
          this.playerDom = null;
        }
      }
    }
  }

  /**
   * Paint cell in Editor Mode
   */
  paintCell(x, y, brushType) {
    if (x < 0 || x >= this.width || y < 0 || y >= this.height) return;

    // Smart selective clearing to allow custom floor and overlays in the same cell
    const isWallBrush = brushType === 'wall' || 
                        brushType.startsWith('wall-') || 
                        brushType === 'cracked-wall' || 
                        brushType === 'timed-wall' || 
                        brushType.startsWith('color-wall-') || 
                        brushType === 'mirror-wall' || 
                        brushType === 'soft-wall' || 
                        brushType.startsWith('linked-wall-') || 
                        brushType.startsWith('rotating-wall-') || 
                        brushType.startsWith('player-wall-') || 
                        brushType === 'glyph-only-wall';

    const isFloorBrush = brushType.startsWith('floor-');

    if (brushType === 'clear' || isWallBrush) {
      this.clearCell(x, y);
    } else {
      // Clear walls and conflicting categories, but preserve custom floor for overlays
      const cell = this.cells[x][y];
      const coordKey = `${x},${y}`;

      // 1. Clear wall and special walls
      cell.isWall = false;
      cell.customWallIndex = 0;
      if (this.wallDoms.has(coordKey)) {
        this.wallDoms.get(coordKey).remove();
        this.wallDoms.delete(coordKey);
      }
      cell.isCrackedWall = false;
      cell.oneWayDir = null;
      cell.isTimedWall = false;
      cell.colorWallColor = null;
      cell.isMirrorWall = false;
      cell.isSoftWall = false;
      cell.linkedWallGroup = null;
      cell.rotatingWallAxis = null;
      cell.playerWallAllowedId = null;
      cell.isGlyphOnlyWall = false;
      if (this.wallChallengeDoms.has(coordKey)) {
        this.wallChallengeDoms.get(coordKey).remove();
        this.wallChallengeDoms.delete(coordKey);
      }

      // 2. Clear conflicting category based on the brushType
      if (isFloorBrush) {
        // If painting a floor, we replace the existing floor
        cell.customFloorIndex = 0;
        if (this.floorDoms.has(coordKey)) {
          this.floorDoms.get(coordKey).remove();
          this.floorDoms.delete(coordKey);
        }
      } else {
        // If painting an overlay, clear only its specific category (allow overlays to stack with floors and other non-conflicting overlays)
        if (brushType === 'player' || brushType === 'player2' || brushType === 'player3' || brushType === 'player4') {
          for (const player of this.players) {
            if (player.x === x && player.y === y) {
              player.x = -1;
              player.y = -1;
              player.dead = false;
              player.finished = false;
              const dom = this.playerDoms.get(player.id);
              if (dom) {
                dom.remove();
                this.playerDoms.delete(player.id);
              }
              if (player.id === 'p1') {
                this.playerDom = null;
              }
            }
          }
        } else if (brushType.startsWith('glyph-') || brushType.startsWith('heavy-')) {
          const glyphIdx = this.glyphs.findIndex(g => g.x === x && g.y === y);
          if (glyphIdx !== -1) {
            const g = this.glyphs[glyphIdx];
            if (this.glyphDoms.has(g.id)) {
              this.glyphDoms.get(g.id).remove();
              this.glyphDoms.delete(g.id);
            }
            this.glyphs.splice(glyphIdx, 1);
          }
        } else if (brushType === 'spikes') {
          cell.hasSpikes = false;
          if (this.spikeDoms.has(coordKey)) {
            this.spikeDoms.get(coordKey).remove();
            this.spikeDoms.delete(coordKey);
          }
        } else if (brushType === 'portal') {
          cell.hasPortal = false;
          if (this.portalDoms.has(coordKey)) {
            this.portalDoms.get(coordKey).remove();
            this.portalDoms.delete(coordKey);
          }
        } else if (brushType.startsWith('plate-')) {
          cell.plateColor = null;
          if (this.plateDoms.has(coordKey)) {
            this.plateDoms.get(coordKey).remove();
            this.plateDoms.delete(coordKey);
          }
        } else if (brushType.startsWith('gate-')) {
          cell.gateColor = null;
          if (this.gateDoms.has(coordKey)) {
            this.gateDoms.get(coordKey).remove();
            this.gateDoms.delete(coordKey);
          }
        } else if (brushType.startsWith('tele-')) {
          cell.teleportType = null;
          if (this.teleportDoms.has(coordKey)) {
            this.teleportDoms.get(coordKey).remove();
            this.teleportDoms.delete(coordKey);
          }
        } else if (brushType === 'chasm') {
          cell.isChasm = false;
          if (this.chasmDoms.has(coordKey)) {
            this.chasmDoms.get(coordKey).remove();
            this.chasmDoms.delete(coordKey);
          }
        } else if (brushType.startsWith('laser-')) {
          cell.laserType = null;
          if (this.emitterDoms.has(coordKey)) {
            this.emitterDoms.get(coordKey).remove();
            this.emitterDoms.delete(coordKey);
          }
        } else if (brushType.startsWith('conveyor-')) {
          cell.conveyorDir = null;
          if (this.conveyorDoms.has(coordKey)) {
            this.conveyorDoms.get(coordKey).remove();
            this.conveyorDoms.delete(coordKey);
          }
        } else if (brushType.startsWith('identity-')) {
          cell.identityPortalPlayer = null;
          if (this.identityPortalDoms.has(coordKey)) {
            this.identityPortalDoms.get(coordKey).remove();
            this.identityPortalDoms.delete(coordKey);
          }
        } else if (brushType === 'jammer') {
          cell.isJammer = false;
          if (this.jammerDoms.has(coordKey)) {
            this.jammerDoms.get(coordKey).remove();
            this.jammerDoms.delete(coordKey);
          }
        } else if (brushType === 'sensor') {
          cell.isSensor = false;
          if (this.sensorDoms.has(coordKey)) {
            this.sensorDoms.get(coordKey).remove();
            this.sensorDoms.delete(coordKey);
          }
        }
      }
    }

    const cell = this.cells[x][y];

    switch (brushType) {
      case 'wall':
        cell.isWall = true;
        cell.customWallIndex = 0;
        this.wallDoms.set(`${x},${y}`, this.createStaticDom('wall wall-0', x, y));
        break;
      case 'wall-1':
        cell.isWall = true;
        cell.customWallIndex = 1;
        this.wallDoms.set(`${x},${y}`, this.createStaticDom('wall wall-1', x, y));
        break;
      case 'wall-2':
        cell.isWall = true;
        cell.customWallIndex = 2;
        this.wallDoms.set(`${x},${y}`, this.createStaticDom('wall wall-2', x, y));
        break;
      case 'wall-3':
        cell.isWall = true;
        cell.customWallIndex = 3;
        this.wallDoms.set(`${x},${y}`, this.createStaticDom('wall wall-3', x, y));
        break;
      case 'wall-4':
        cell.isWall = true;
        cell.customWallIndex = 4;
        this.wallDoms.set(`${x},${y}`, this.createStaticDom('wall wall-4', x, y));
        break;
      case 'wall-5':
        cell.isWall = true;
        cell.customWallIndex = 5;
        this.wallDoms.set(`${x},${y}`, this.createStaticDom('wall wall-5', x, y));
        break;
      case 'wall-6':
        cell.isWall = true;
        cell.customWallIndex = 6;
        this.wallDoms.set(`${x},${y}`, this.createStaticDom('wall wall-6', x, y));
        break;
      case 'floor-1':
        cell.customFloorIndex = 1;
        this.floorDoms.set(`${x},${y}`, this.createStaticDom('floor floor-1', x, y));
        break;
      case 'floor-2':
        cell.customFloorIndex = 2;
        this.floorDoms.set(`${x},${y}`, this.createStaticDom('floor floor-2', x, y));
        break;
      case 'floor-3':
        cell.customFloorIndex = 3;
        this.floorDoms.set(`${x},${y}`, this.createStaticDom('floor floor-3', x, y));
        break;
      case 'floor-4':
        cell.customFloorIndex = 4;
        this.floorDoms.set(`${x},${y}`, this.createStaticDom('floor floor-4', x, y));
        break;
      case 'floor-5':
        cell.customFloorIndex = 5;
        this.floorDoms.set(`${x},${y}`, this.createStaticDom('floor floor-5', x, y));
        break;
      case 'floor-6':
        cell.customFloorIndex = 6;
        this.floorDoms.set(`${x},${y}`, this.createStaticDom('floor floor-6', x, y));
        break;
      case 'cracked-wall':
        cell.isCrackedWall = true;
        this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge cracked-wall', x, y));
        break;
      case 'one-way-r':
        cell.oneWayDir = 'R';
        this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge one-way one-way-r', x, y));
        break;
      case 'one-way-l':
        cell.oneWayDir = 'L';
        this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge one-way one-way-l', x, y));
        break;
      case 'one-way-u':
        cell.oneWayDir = 'U';
        this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge one-way one-way-u', x, y));
        break;
      case 'one-way-d':
        cell.oneWayDir = 'D';
        this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge one-way one-way-d', x, y));
        break;
      case 'timed-wall':
        cell.isTimedWall = true;
        this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge timed-wall', x, y));
        break;
      case 'color-wall-red':
        cell.colorWallColor = GLYPH_TYPES.RED;
        this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge color-wall color-wall-red', x, y));
        break;
      case 'color-wall-blue':
        cell.colorWallColor = GLYPH_TYPES.BLUE;
        this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge color-wall color-wall-blue', x, y));
        break;
      case 'color-wall-green':
        cell.colorWallColor = GLYPH_TYPES.GREEN;
        this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge color-wall color-wall-green', x, y));
        break;
      case 'mirror-wall':
        cell.isMirrorWall = true;
        this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge mirror-wall', x, y));
        break;
      case 'soft-wall':
        cell.isSoftWall = true;
        this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge soft-wall', x, y));
        break;
      case 'linked-wall-a':
        cell.linkedWallGroup = 'a';
        this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge linked-wall linked-wall-a', x, y));
        break;
      case 'linked-wall-b':
        cell.linkedWallGroup = 'b';
        this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge linked-wall linked-wall-b', x, y));
        break;
      case 'rotating-wall-h':
        cell.rotatingWallAxis = 'horizontal';
        this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge rotating-wall rotating-wall-h', x, y));
        break;
      case 'rotating-wall-v':
        cell.rotatingWallAxis = 'vertical';
        this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge rotating-wall rotating-wall-v', x, y));
        break;
      case 'player-wall-p1':
        cell.playerWallAllowedId = 'p1';
        this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge player-wall player-wall-p1', x, y));
        break;
      case 'player-wall-p2':
        cell.playerWallAllowedId = 'p2';
        this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge player-wall player-wall-p2', x, y));
        break;
      case 'player-wall-p3':
        cell.playerWallAllowedId = 'p3';
        this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge player-wall player-wall-p3', x, y));
        break;
      case 'player-wall-p4':
        cell.playerWallAllowedId = 'p4';
        this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge player-wall player-wall-p4', x, y));
        break;
      case 'glyph-only-wall':
        cell.isGlyphOnlyWall = true;
        this.wallChallengeDoms.set(`${x},${y}`, this.createStaticDom('wall-challenge glyph-only-wall', x, y));
        break;
      case 'portal':
        cell.hasPortal = true;
        this.portalDoms.set(`${x},${y}`, this.createStaticDom('portal', x, y));
        break;
      case 'spikes':
        cell.hasSpikes = true;
        this.spikeDoms.set(`${x},${y}`, this.createStaticDom('spikes', x, y));
        break;
      case 'player':
        // Find if P1 exists elsewhere, and delete them
        for (let py = 0; py < this.height; py++) {
          for (let px = 0; px < this.width; px++) {
            if (this.player.x === px && this.player.y === py) {
              this.clearCell(px, py);
            }
          }
        }
        this.player.x = x;
        this.player.y = y;
        this.player.dead = false;
        this.player.finished = false;
        this.spawnPlayerDom(this.player);
        break;
      case 'player2':
        // Find if P2 exists elsewhere, and delete them
        const p2 = this.players[1];
        for (let py = 0; py < this.height; py++) {
          for (let px = 0; px < this.width; px++) {
            if (p2.x === px && p2.y === py) {
              this.clearCell(px, py);
            }
          }
        }
        p2.x = x;
        p2.y = y;
        p2.dead = false;
        p2.finished = false;
        this.spawnPlayerDom(p2);
        break;
      case 'player3': {
        const p3 = this.players[2];
        for (let py = 0; py < this.height; py++) {
          for (let px = 0; px < this.width; px++) {
            if (p3.x === px && p3.y === py) {
              this.clearCell(px, py);
            }
          }
        }
        p3.x = x;
        p3.y = y;
        p3.dead = false;
        p3.finished = false;
        this.spawnPlayerDom(p3);
        break;
      }
      case 'player4': {
        const p4 = this.players[3];
        for (let py = 0; py < this.height; py++) {
          for (let px = 0; px < this.width; px++) {
            if (p4.x === px && p4.y === py) {
              this.clearCell(px, py);
            }
          }
        }
        p4.x = x;
        p4.y = y;
        p4.dead = false;
        p4.finished = false;
        this.spawnPlayerDom(p4);
        break;
      }
      case 'glyph-red':
        this.spawnGlyph(GLYPH_TYPES.RED, x, y);
        break;
      case 'glyph-blue':
        this.spawnGlyph(GLYPH_TYPES.BLUE, x, y);
        break;
      case 'glyph-green':
        this.spawnGlyph(GLYPH_TYPES.GREEN, x, y);
        break;
      case 'plate-red':
        cell.plateColor = GLYPH_TYPES.RED;
        this.plateDoms.set(`${x},${y}`, this.createStaticDom('plate plate-red', x, y));
        break;
      case 'plate-blue':
        cell.plateColor = GLYPH_TYPES.BLUE;
        this.plateDoms.set(`${x},${y}`, this.createStaticDom('plate plate-blue', x, y));
        break;
      case 'plate-green':
        cell.plateColor = GLYPH_TYPES.GREEN;
        this.plateDoms.set(`${x},${y}`, this.createStaticDom('plate plate-green', x, y));
        break;
      case 'gate-red':
        cell.gateColor = GLYPH_TYPES.RED;
        this.gateDoms.set(`${x},${y}`, this.createStaticDom('gate gate-red', x, y));
        break;
      case 'gate-blue':
        cell.gateColor = GLYPH_TYPES.BLUE;
        this.gateDoms.set(`${x},${y}`, this.createStaticDom('gate gate-blue', x, y));
        break;
      case 'gate-green':
        cell.gateColor = GLYPH_TYPES.GREEN;
        this.gateDoms.set(`${x},${y}`, this.createStaticDom('gate gate-green', x, y));
        break;
      case 'heavy-2':
        this.spawnGlyph('heavy-2', x, y);
        break;
      case 'heavy-3':
        this.spawnGlyph('heavy-3', x, y);
        break;
      case 'tele-in':
        cell.teleportType = 'in';
        this.teleportDoms.set(`${x},${y}`, this.createStaticDom('teleport-in', x, y));
        break;
      case 'tele-out':
        cell.teleportType = 'out';
        this.teleportDoms.set(`${x},${y}`, this.createStaticDom('teleport-out', x, y));
        break;
      case 'chasm':
        cell.isChasm = true;
        this.chasmDoms.set(`${x},${y}`, this.createStaticDom('chasm', x, y));
        break;
      case 'laser-h':
        cell.laserType = 'L';
        this.emitterDoms.set(`${x},${y}`, this.createStaticDom('emitter emitter-h', x, y));
        break;
      case 'laser-v':
        cell.laserType = 'l';
        this.emitterDoms.set(`${x},${y}`, this.createStaticDom('emitter emitter-v', x, y));
        break;
      case 'laser-p-h':
        cell.laserType = 'P';
        this.emitterDoms.set(`${x},${y}`, this.createStaticDom('emitter emitter-pulsing-h', x, y));
        break;
      case 'laser-p-v':
        cell.laserType = 'p';
        this.emitterDoms.set(`${x},${y}`, this.createStaticDom('emitter emitter-pulsing-v', x, y));
        break;
      case 'conveyor-l':
        cell.conveyorDir = 'L';
        this.conveyorDoms.set(`${x},${y}`, this.createStaticDom('conveyor conveyor-left', x, y));
        break;
      case 'conveyor-r':
        cell.conveyorDir = 'R';
        this.conveyorDoms.set(`${x},${y}`, this.createStaticDom('conveyor conveyor-right', x, y));
        break;
      case 'conveyor-u':
        cell.conveyorDir = 'U';
        this.conveyorDoms.set(`${x},${y}`, this.createStaticDom('conveyor conveyor-up', x, y));
        break;
      case 'conveyor-d':
        cell.conveyorDir = 'D';
        this.conveyorDoms.set(`${x},${y}`, this.createStaticDom('conveyor conveyor-down', x, y));
        break;
      case 'identity-p1':
        cell.identityPortalPlayer = 'p1';
        this.identityPortalDoms.set(`${x},${y}`, this.createStaticDom('identity-portal portal-p1', x, y));
        break;
      case 'identity-p2':
        cell.identityPortalPlayer = 'p2';
        this.identityPortalDoms.set(`${x},${y}`, this.createStaticDom('identity-portal portal-p2', x, y));
        break;
      case 'identity-p3':
        cell.identityPortalPlayer = 'p3';
        this.identityPortalDoms.set(`${x},${y}`, this.createStaticDom('identity-portal portal-p3', x, y));
        break;
      case 'identity-p4':
        cell.identityPortalPlayer = 'p4';
        this.identityPortalDoms.set(`${x},${y}`, this.createStaticDom('identity-portal portal-p4', x, y));
        break;
      case 'jammer':
        cell.isJammer = true;
        this.jammerDoms.set(`${x},${y}`, this.createStaticDom('jammer-zone', x, y));
        break;
      case 'sensor':
        cell.isSensor = true;
        this.sensorDoms.set(`${x},${y}`, this.createStaticDom('sensor-floor', x, y));
        break;
      case 'clear':
      default:
        // Already cleared, do nothing
        break;
    }

    this.updateTriggers(false);
    this.render();
  }

  /**
   * Serialize grid to array of map strings for Level sharing/export
   */
  serializeLevelData(movesLimit) {
    const mapRows = [];
    const customFloorRows = [];
    let hasCustomFloors = false;
    
    for (let y = 0; y < this.height; y++) {
      let row = '';
      let floorRow = '';
      for (let x = 0; x < this.width; x++) {
        const cell = this.cells[x][y];
        
        // Build custom floor map row (1-6 for custom floor indexes, . for default)
        if (cell.customFloorIndex > 0) {
          floorRow += cell.customFloorIndex.toString();
          hasCustomFloors = true;
        } else {
          floorRow += '.';
        }
        
        // 1. Check dynamic entities
        const playerHere = this.players.find(player => player.x === x && player.y === y && !player.finished);
        if (playerHere?.id === 'p1') {
          row += '@';
        } else if (playerHere?.id === 'p2') {
          row += '%';
        } else if (playerHere?.id === 'p3') {
          row += '*';
        } else if (playerHere?.id === 'p4') {
          row += '$';
        } else {
          const glyph = this.glyphs.find(g => g.x === x && g.y === y);
          if (glyph) {
            if (glyph.type === GLYPH_TYPES.RED) row += 'A';
            else if (glyph.type === GLYPH_TYPES.BLUE) row += 'B';
            else if (glyph.type === GLYPH_TYPES.GREEN) row += 'C';
            else if (glyph.type === 'heavy-2') row += 'H';
            else if (glyph.type === 'heavy-3') row += 'K';
          } else {
            // 2. Check static cells
            if (cell.isWall) {
              if (cell.customWallIndex === 1) row += '0';
              else if (cell.customWallIndex === 2) row += '7';
              else if (cell.customWallIndex === 3) row += '8';
              else if (cell.customWallIndex === 4) row += '9';
              else if (cell.customWallIndex === 5) row += '?';
              else if (cell.customWallIndex === 6) row += '!';
              else row += '#';
            }
            else if (cell.isCrackedWall) row += 'R';
            else if (cell.oneWayDir === 'R') row += '>';
            else if (cell.oneWayDir === 'L') row += '<';
            else if (cell.oneWayDir === 'U') row += 'N';
            else if (cell.oneWayDir === 'D') row += 'v';
            else if (cell.isTimedWall) row += 'T';
            else if (cell.colorWallColor === GLYPH_TYPES.RED) row += '4';
            else if (cell.colorWallColor === GLYPH_TYPES.BLUE) row += '5';
            else if (cell.colorWallColor === GLYPH_TYPES.GREEN) row += '6';
            else if (cell.isMirrorWall) row += 'M';
            else if (cell.isSoftWall) row += 'W';
            else if (cell.linkedWallGroup === 'a') row += 'Y';
            else if (cell.linkedWallGroup === 'b') row += 'Z';
            else if (cell.rotatingWallAxis === 'horizontal') row += '-';
            else if (cell.rotatingWallAxis === 'vertical') row += '|';
            else if (cell.playerWallAllowedId === 'p1') row += 'Q';
            else if (cell.playerWallAllowedId === 'p2') row += 'E';
            else if (cell.playerWallAllowedId === 'p3') row += 'F';
            else if (cell.playerWallAllowedId === 'p4') row += 'G';
            else if (cell.isGlyphOnlyWall) row += 'D';
            else if (cell.hasPortal) row += 'X';
            else if (cell.hasSpikes) row += '^';
            else if (cell.plateColor === GLYPH_TYPES.RED) row += 'a';
            else if (cell.plateColor === GLYPH_TYPES.BLUE) row += 'b';
            else if (cell.plateColor === GLYPH_TYPES.GREEN) row += 'c';
            else if (cell.gateColor === GLYPH_TYPES.RED) row += '1';
            else if (cell.gateColor === GLYPH_TYPES.BLUE) row += '2';
            else if (cell.gateColor === GLYPH_TYPES.GREEN) row += '3';
            else if (cell.teleportType === 'in') row += '[';
            else if (cell.teleportType === 'out') row += ']';
            else if (cell.isChasm) row += '_';
            else if (cell.laserType === 'L') row += 'L';
            else if (cell.laserType === 'l') row += 'l';
            else if (cell.laserType === 'P') row += 'P';
            else if (cell.laserType === 'p') row += 'p';
            else if (cell.conveyorDir === 'L') row += '(';
            else if (cell.conveyorDir === 'R') row += ')';
            else if (cell.conveyorDir === 'U') row += '{';
            else if (cell.conveyorDir === 'D') row += '}';
            else if (cell.identityPortalPlayer === 'p1') row += 'I';
            else if (cell.identityPortalPlayer === 'p2') row += 'O';
            else if (cell.identityPortalPlayer === 'p3') row += 'U';
            else if (cell.identityPortalPlayer === 'p4') row += 'V';
            else if (cell.isJammer) row += 'J';
            else if (cell.isSensor) row += 'S';
            else if (cell.customFloorIndex === 1) row += 'd';
            else if (cell.customFloorIndex === 2) row += 'e';
            else if (cell.customFloorIndex === 3) row += 'f';
            else if (cell.customFloorIndex === 4) row += 'g';
            else if (cell.customFloorIndex === 5) row += 'h';
            else if (cell.customFloorIndex === 6) row += 'i';
            else row += '.';
          }
        }
      }
      mapRows.push(row);
      customFloorRows.push(floorRow);
    }
    
    const result = {
      width: this.width,
      height: this.height,
      movesLimit: movesLimit,
      initialRules: { red: 'STOP', blue: 'STOP', green: 'STOP' },
      map: mapRows
    };
    
    if (hasCustomFloors) {
      result.custom_floor_map = customFloorRows;
    }
    
    return result;
  }

  /**
   * Try moving the player in the direction (dx, dy)
   * Returns: { moved: boolean, won: boolean, merged: boolean }
   */
  tryMove(dx, dy, activeRules, playerId = 'p1') {
    const player = this.getPlayer(playerId);
    if (!this.isPlayerActive(player)) return { moved: false, won: false, merged: false };
    
    const nextX = player.x + dx;
    const nextY = player.y + dy;
    
    // 1. Boundary check
    if (nextX < 0 || nextX >= this.width || nextY < 0 || nextY >= this.height) {
      return { moved: false, won: false, merged: false };
    }
    
    const targetCell = this.cells[nextX][nextY];
    const moveCost = targetCell.isSoftWall ? 2 : 1;

    if (targetCell.isMirrorWall) {
      const bounceX = player.x - dx;
      const bounceY = player.y - dy;
      if (bounceX >= 0 &&
          bounceX < this.width &&
          bounceY >= 0 &&
          bounceY < this.height &&
          !this.blocksPlayer(this.cells[bounceX][bounceY], player, -dx, -dy, activeRules) &&
          !this.getPlayerAt(bounceX, bounceY, player.id) &&
          !this.glyphs.some(g => g.x === bounceX && g.y === bounceY)) {
        player.x = bounceX;
        player.y = bounceY;
      }

      this.stepCount++;
      this.processConveyors();
      this.updateTriggers(true);
      this.render();
      return { moved: true, won: this.areAllPlayersFinished(), merged: false, dead: player.dead, moveCost };
    }
    
    // 2. Wall check
    if (this.blocksPlayer(targetCell, player, dx, dy, activeRules)) {
      return { moved: false, won: false, merged: false };
    }
    
    // 3. Gate (door) check
    if (targetCell.gateColor) {
      const isGateOpen = this.isGateColorOpen(targetCell.gateColor);
      if (!isGateOpen) {
        return { moved: false, won: false, merged: false };
      }
    }

    // 3b. Identity Portal check (blocked for other players)
    if (targetCell.identityPortalPlayer && targetCell.identityPortalPlayer !== player.id) {
      return { moved: false, won: false, merged: false };
    }

    if (this.getPlayerAt(nextX, nextY, player.id)) {
      return { moved: false, won: false, merged: false };
    }
    
    // 4. Glyph interaction check
    const glyphIndex = this.glyphs.findIndex(g => g.x === nextX && g.y === nextY);
    const targetSpikeWasCovered = targetCell.hasSpikes && glyphIndex !== -1;
    let didMerge = false;
    
    if (glyphIndex !== -1) {
      const glyph = this.glyphs[glyphIndex];
      
      // Compute effective rules
      const effectiveRules = this.getEffectiveRules(activeRules);
      let rule = effectiveRules[glyph.type]; // 'STOP', 'PUSH', 'SWAP', 'MERGE'
      
      // Jammer check override
      if (this.cells[glyph.x][glyph.y].isJammer) {
        rule = 'STOP';
      }
      
      // Heavy blocks check override (weight 2 and weight 3)
      if (glyph.type === 'heavy-2' || glyph.type === 'heavy-3') {
        const reqPlayers = glyph.type === 'heavy-2' ? 2 : 3;
        let lineOk = true;
        for (let i = 1; i < reqPlayers; i++) {
          const checkX = player.x - i * dx;
          const checkY = player.y - i * dy;
          if (!this.getPlayerAt(checkX, checkY)) {
            lineOk = false;
            break;
          }
        }
        if (!lineOk) {
          return { moved: false, won: false, merged: false };
        }
        rule = 'PUSH'; // behaves as push
      }
      
      if (rule === 'STOP') {
        return { moved: false, won: false, merged: false };
      }
      
      if (rule === 'PUSH' || rule === 'MERGE') {
        const behindX = nextX + dx;
        const behindY = nextY + dy;
        
        if (behindX < 0 || behindX >= this.width || behindY < 0 || behindY >= this.height) {
          return { moved: false, won: false, merged: false };
        }
        
        const behindCell = this.cells[behindX][behindY];
        
        if (behindCell.isCrackedWall) {
          this.destroyCrackedWallAt(behindX, behindY);
        } else if (this.blocksGlyph(behindCell, dx, dy, activeRules)) {
          return { moved: false, won: false, merged: false };
        }
        if (behindCell.gateColor && !this.isGateColorOpen(behindCell.gateColor)) {
          return { moved: false, won: false, merged: false };
        }
        // Identity Portal check for glyphs
        if (behindCell.identityPortalPlayer) {
          return { moved: false, won: false, merged: false };
        }
        if (this.getPlayerAt(behindX, behindY, player.id)) {
          return { moved: false, won: false, merged: false };
        }
        
        const secondGlyphIndex = this.glyphs.findIndex(g => g.x === behindX && g.y === behindY);
        
        if (secondGlyphIndex !== -1) {
          const secondGlyph = this.glyphs[secondGlyphIndex];
          if (rule === 'MERGE' && glyph.type === secondGlyph.type && glyph.type !== 'heavy-2' && glyph.type !== 'heavy-3') {
            // Merge
            glyph.x = behindX;
            glyph.y = behindY;
            
            const firstGlyphDom = this.glyphDoms.get(glyph.id);
            if (firstGlyphDom) {
              this.positionElement(firstGlyphDom, behindX, behindY);
              firstGlyphDom.style.transform += ' scale(0)';
              firstGlyphDom.style.opacity = '0';
              setTimeout(() => firstGlyphDom.remove(), 150);
              this.glyphDoms.delete(glyph.id);
            }
            
            this.glyphs.splice(glyphIndex, 1);
            didMerge = true;
            
            let playerDestX = nextX;
            let playerDestY = nextY;
            const pTele = this.getTeleportDestination(playerDestX, playerDestY);
            if (pTele) {
              playerDestX = pTele.x;
              playerDestY = pTele.y;
            }
            player.x = playerDestX;
            player.y = playerDestY;
          } else {
            return { moved: false, won: false, merged: false };
          }
        } else {
          // Push normally
          let glyphDestX = behindX;
          let glyphDestY = behindY;
          
          const gTele = this.getTeleportDestination(glyphDestX, glyphDestY);
          if (gTele) {
            glyphDestX = gTele.x;
            glyphDestY = gTele.y;
          }
          
          const destCell = this.cells[glyphDestX][glyphDestY];
          if (destCell.isChasm) {
            // Swallow glyph!
            destCell.isChasm = false;
            if (this.chasmDoms.has(`${glyphDestX},${glyphDestY}`)) {
              this.chasmDoms.get(`${glyphDestX},${glyphDestY}`).remove();
              this.chasmDoms.delete(`${glyphDestX},${glyphDestY}`);
            }
            const glyphDom = this.glyphDoms.get(glyph.id);
            if (glyphDom) {
              glyphDom.style.transform += ' scale(0)';
              glyphDom.style.opacity = '0';
              setTimeout(() => glyphDom.remove(), 150);
              this.glyphDoms.delete(glyph.id);
            }
            this.glyphs.splice(glyphIndex, 1);
            didMerge = true; // behaves as merge visually
          } else {
            glyph.x = glyphDestX;
            glyph.y = glyphDestY;
          }
          
          let playerDestX = nextX;
          let playerDestY = nextY;
          const pTele = this.getTeleportDestination(playerDestX, playerDestY);
          if (pTele) {
            playerDestX = pTele.x;
            playerDestY = pTele.y;
          }
          player.x = playerDestX;
          player.y = playerDestY;
        }
      }
      else if (rule === 'SWAP') {
        const originalPlayerX = player.x;
        const originalPlayerY = player.y;
        
        let playerDestX = nextX;
        let playerDestY = nextY;
        let glyphDestX = originalPlayerX;
        let glyphDestY = originalPlayerY;
        
        const pTele = this.getTeleportDestination(playerDestX, playerDestY);
        if (pTele) {
          playerDestX = pTele.x;
          playerDestY = pTele.y;
        }
        
        const gTele = this.getTeleportDestination(glyphDestX, glyphDestY);
        if (gTele) {
          glyphDestX = gTele.x;
          glyphDestY = gTele.y;
        }
        
        const gCell = this.cells[glyphDestX][glyphDestY];
        if (gCell.isChasm) {
          gCell.isChasm = false;
          if (this.chasmDoms.has(`${glyphDestX},${glyphDestY}`)) {
            this.chasmDoms.get(`${glyphDestX},${glyphDestY}`).remove();
            this.chasmDoms.delete(`${glyphDestX},${glyphDestY}`);
          }
          const glyphDom = this.glyphDoms.get(glyph.id);
          if (glyphDom) {
            glyphDom.style.transform += ' scale(0)';
            glyphDom.style.opacity = '0';
            setTimeout(() => glyphDom.remove(), 150);
            this.glyphDoms.delete(glyph.id);
          }
          this.glyphs.splice(glyphIndex, 1);
          didMerge = true;
        } else {
          glyph.x = glyphDestX;
          glyph.y = glyphDestY;
        }
        
        player.x = playerDestX;
        player.y = playerDestY;
      }
    } else {
      let playerDestX = nextX;
      let playerDestY = nextY;
      const pTele = this.getTeleportDestination(playerDestX, playerDestY);
      if (pTele) {
        playerDestX = pTele.x;
        playerDestY = pTele.y;
      }
      player.x = playerDestX;
      player.y = playerDestY;
    }
    
    this.stepCount++;
    
    // Process Conveyors
    this.processConveyors();
    
    // 5. Post-move triggers: Plates, Spikes, and Lasers
    this.updateTriggers(true);
    
    // Check if player landed on active spikes (deadly!)
    const currentCell = this.cells[player.x][player.y];
    if (currentCell.hasSpikes) {
      const isCovered = this.glyphs.some(g => g.x === player.x && g.y === player.y);
      if (!isCovered && !targetSpikeWasCovered) {
        player.dead = true;
        AudioEngine.playFail();
        this.render();
        return { moved: true, won: false, merged: didMerge, dead: true, moveCost };
      }
    }
    
    // Check if player landed in a chasm
    if (currentCell.isChasm) {
      player.dead = true;
      AudioEngine.playFail();
      this.render();
      return { moved: true, won: false, merged: didMerge, dead: true, moveCost };
    }
    
    // Check win condition (Exit Portal or Personal Identity Portal)
    const reachedPortal = currentCell.hasPortal || (currentCell.identityPortalPlayer === player.id);
    if (reachedPortal) {
      player.finished = true;
      this.updateTriggers(true);
    }
    
    // Check if any player died from laser in updateTriggers
    if (player.dead) {
      AudioEngine.playFail();
      this.render();
      return { moved: true, won: false, merged: didMerge, dead: true, moveCost };
    }

    const allPlayersFinished = this.areAllPlayersFinished();
    if (allPlayersFinished) {
      AudioEngine.playWin();
    } else if (reachedPortal) {
      AudioEngine.playUnlock();
    } else if (didMerge) {
      AudioEngine.playMerge();
    } else {
      AudioEngine.playMove();
    }
    
    this.render();
    return {
      moved: true,
      won: allPlayersFinished,
      merged: didMerge,
      dead: false,
      moveCost,
      playerFinished: reachedPortal,
      playerId: player.id
    };
  }

  /**
   * Helper: Check if a colored plate is active (has player or glyph on it)
   */
  isPlateActive(color) {
    const playerOnPlate = this.players.some(player => {
      return this.isPlayerActive(player) &&
        this.cells[player.x][player.y].plateColor === color;
    });
    if (playerOnPlate) return true;
    
    // Check glyphs
    return this.glyphs.some(g => {
      return this.cells[g.x][g.y].plateColor === color;
    });
  }

  /**
   * Helper: Check if a colored gate is open
   */
  isGateColorOpen(color) {
    return this.isPlateActive(color);
  }

  /**
   * Scan active plates and gates, updates their states, and triggers SFX if state changes
   */
  updateTriggers(playSound = true) {
    let stateChanged = false;
    
    for (const [coordStr, plateDom] of this.plateDoms.entries()) {
      const [x, y] = coordStr.split(',').map(Number);
      const cell = this.cells[x][y];
      const color = cell.plateColor;
      
      const isActiveNow = this.isPlateActive(color);
      const wasActive = plateDom.classList.contains('active');
      
      if (isActiveNow !== wasActive) {
        plateDom.classList.toggle('active', isActiveNow);
        stateChanged = true;
      }
    }
    
    // Update gate visual states
    for (const [coordStr, gateDom] of this.gateDoms.entries()) {
      const [x, y] = coordStr.split(',').map(Number);
      const cell = this.cells[x][y];
      
      const isOpenNow = this.isGateColorOpen(cell.gateColor);
      const wasOpen = gateDom.classList.contains('open');
      
      if (isOpenNow !== wasOpen) {
        gateDom.classList.toggle('open', isOpenNow);
      }
    }
    
    // Update spike covered state visual feedback
    for (const [coordStr, spikeDom] of this.spikeDoms.entries()) {
      const [x, y] = coordStr.split(',').map(Number);
      const isCovered = this.glyphs.some(g => g.x === x && g.y === y);
      spikeDom.classList.toggle('covered', isCovered);
    }
    
    // Update active lasers and raycasting checks
    this.updateLasers(this.stepCount);
    
    if (stateChanged && playSound) {
      AudioEngine.playUnlock();
    }
  }

  /**
   * Render the layout of player and glyphs by syncing coordinates to DOM transforms
   */
  render() {
    // Sync player positions
    for (const player of this.players) {
      const dom = this.playerDoms.get(player.id);
      if (!dom) continue;

      if (player.x === -1) {
        dom.style.display = 'none';
        continue;
      }

      dom.style.display = 'flex';
      this.positionElement(dom, player.x, player.y);
      dom.classList.toggle('finished', player.finished);

      if (player.dead) {
        dom.style.transform += ' scale(0.6) rotate(45deg)';
        dom.style.filter = 'hue-rotate(90deg) brightness(0.5)';
      } else if (player.finished) {
        dom.style.transform += ' scale(0.72)';
        dom.style.filter = 'saturate(0.6) brightness(1.25)';
      } else {
        dom.style.filter = 'none';
      }
    }
    
    // Sync glyph positions
    for (const glyph of this.glyphs) {
      const dom = this.glyphDoms.get(glyph.id);
      if (dom) {
        this.positionElement(dom, glyph.x, glyph.y);
      }
    }
  }

  // ==========================================
  // ADVANCED MECHANICS HELPER METHODS
  // ==========================================

  directionFromDelta(dx, dy) {
    if (dx > 0) return 'R';
    if (dx < 0) return 'L';
    if (dy > 0) return 'D';
    if (dy < 0) return 'U';
    return '';
  }

  isTimedWallSolid() {
    return Math.floor(this.stepCount / 2) % 2 === 0;
  }

  isLinkedWallSolid(group) {
    const even = this.stepCount % 2 === 0;
    return group === 'a' ? even : !even;
  }

  activeRotatingWallAxis(cell) {
    const axis = cell.rotatingWallAxis || 'horizontal';
    if (this.stepCount % 2 === 0) return axis;
    return axis === 'horizontal' ? 'vertical' : 'horizontal';
  }

  blocksByRotatingWall(cell, dx, dy) {
    if (!cell.rotatingWallAxis) return false;
    const axis = this.activeRotatingWallAxis(cell);
    return (axis === 'vertical' && dx !== 0) || (axis === 'horizontal' && dy !== 0);
  }

  isColorWallSolid(cell, activeRules) {
    if (!cell.colorWallColor) return false;
    return (activeRules[cell.colorWallColor] || 'STOP') === 'STOP';
  }

  blocksPlayer(cell, player, dx, dy, activeRules) {
    if (cell.isWall || cell.isCrackedWall || cell.isMirrorWall || cell.isGlyphOnlyWall) return true;
    if (cell.oneWayDir && cell.oneWayDir !== this.directionFromDelta(dx, dy)) return true;
    if (cell.isTimedWall && this.isTimedWallSolid()) return true;
    if (this.isColorWallSolid(cell, activeRules)) return true;
    if (cell.linkedWallGroup && this.isLinkedWallSolid(cell.linkedWallGroup)) return true;
    if (this.blocksByRotatingWall(cell, dx, dy)) return true;
    if (cell.playerWallAllowedId && cell.playerWallAllowedId !== player.id) return true;
    return false;
  }

  blocksGlyph(cell, dx, dy, activeRules) {
    if (cell.isWall || cell.isMirrorWall) return true;
    if (cell.oneWayDir && cell.oneWayDir !== this.directionFromDelta(dx, dy)) return true;
    if (cell.isTimedWall && this.isTimedWallSolid()) return true;
    if (this.isColorWallSolid(cell, activeRules)) return true;
    if (cell.linkedWallGroup && this.isLinkedWallSolid(cell.linkedWallGroup)) return true;
    if (this.blocksByRotatingWall(cell, dx, dy)) return true;
    if (cell.playerWallAllowedId) return true;
    return false;
  }

  blocksLaser(cell) {
    if (cell.isWall || cell.isCrackedWall || cell.isMirrorWall || cell.isGlyphOnlyWall) return true;
    if (cell.oneWayDir) return true;
    if (cell.isTimedWall && this.isTimedWallSolid()) return true;
    if (cell.colorWallColor) return true;
    if (cell.linkedWallGroup && this.isLinkedWallSolid(cell.linkedWallGroup)) return true;
    if (cell.rotatingWallAxis) return true;
    if (cell.playerWallAllowedId) return true;
    return false;
  }

  destroyCrackedWallAt(x, y) {
    const cell = this.cells[x][y];
    cell.isCrackedWall = false;
    const dom = this.wallChallengeDoms.get(`${x},${y}`);
    if (dom) {
      dom.remove();
      this.wallChallengeDoms.delete(`${x},${y}`);
    }
  }

  getEffectiveRules(baseRules) {
    const rules = { ...baseRules };
    for (const g of this.glyphs) {
      if (g.x >= 0 && g.x < this.width && g.y >= 0 && g.y < this.height) {
        if (this.cells[g.x][g.y].isSensor) {
          const overrideRule = baseRules[g.type];
          for (const color of ['red', 'blue', 'green']) {
            rules[color] = overrideRule;
          }
          break;
        }
      }
    }
    return rules;
  }

  getTeleportDestination(x, y) {
    const cell = this.cells[x][y];
    if (cell.teleportType !== 'in') return null;
    
    let bestOut = null;
    let minDist = Infinity;
    
    for (let tx = 0; tx < this.width; tx++) {
      for (let ty = 0; ty < this.height; ty++) {
        if (this.cells[tx][ty].teleportType === 'out') {
          const hasPlayer = this.players.some(p => this.isPlayerActive(p) && p.x === tx && p.y === ty);
          const hasGlyph = this.glyphs.some(g => g.x === tx && g.y === ty);
          if (!hasPlayer && !hasGlyph) {
            const dist = Math.abs(tx - x) + Math.abs(ty - y);
            if (dist < minDist) {
              minDist = dist;
              bestOut = { x: tx, y: ty };
            }
          }
        }
      }
    }
    return bestOut;
  }

  updateLasers(stepCount) {
    this.boardDom.querySelectorAll('.elem-laser-beam').forEach(el => el.remove());
    
    const laserBeamsH = new Set();
    const laserBeamsV = new Set();
    const pulsingActive = Math.floor(stepCount / 2) % 2 === 0;
    
    for (let x = 0; x < this.width; x++) {
      for (let y = 0; y < this.height; y++) {
        const cell = this.cells[x][y];
        if (!cell.laserType) continue;
        
        let active = false;
        let isHorizontal = false;
        
        if (cell.laserType === 'L') {
          active = true;
          isHorizontal = true;
        } else if (cell.laserType === 'l') {
          active = true;
          isHorizontal = false;
        } else if (cell.laserType === 'P') {
          active = pulsingActive;
          isHorizontal = true;
        } else if (cell.laserType === 'p') {
          active = pulsingActive;
          isHorizontal = false;
        }
        
        if (!active) continue;
        
        if (isHorizontal) {
          for (let tx = x - 1; tx >= 0; tx--) {
            if (this.blocksLaser(this.cells[tx][y])) break;
            if (this.isLaserBlocked(tx, y)) {
              laserBeamsH.add(`${tx},${y}`);
              break;
            }
            laserBeamsH.add(`${tx},${y}`);
          }
          for (let tx = x + 1; tx < this.width; tx++) {
            if (this.blocksLaser(this.cells[tx][y])) break;
            if (this.isLaserBlocked(tx, y)) {
              laserBeamsH.add(`${tx},${y}`);
              break;
            }
            laserBeamsH.add(`${tx},${y}`);
          }
        } else {
          for (let ty = y - 1; ty >= 0; ty--) {
            if (this.blocksLaser(this.cells[x][ty])) break;
            if (this.isLaserBlocked(x, ty)) {
              laserBeamsV.add(`${x},${ty}`);
              break;
            }
            laserBeamsV.add(`${x},${ty}`);
          }
          for (let ty = y + 1; ty < this.height; ty++) {
            if (this.blocksLaser(this.cells[x][ty])) break;
            if (this.isLaserBlocked(x, ty)) {
              laserBeamsV.add(`${x},${ty}`);
              break;
            }
            laserBeamsV.add(`${x},${ty}`);
          }
        }
      }
    }
    
    const allBeams = new Set([...laserBeamsH, ...laserBeamsV]);
    for (const coord of allBeams) {
      const [bx, by] = coord.split(',').map(Number);
      const isH = laserBeamsH.has(coord);
      const isV = laserBeamsV.has(coord);
      
      const beamEl = document.createElement('div');
      beamEl.className = `grid-element elem-laser-beam ${isH ? 'laser-h' : ''} ${isV ? 'laser-v' : ''}`;
      
      const content = document.createElement('div');
      content.className = 'element-content';
      beamEl.appendChild(content);
      
      this.positionElement(beamEl, bx, by);
      this.boardDom.appendChild(beamEl);
    }
    
    for (const player of this.players) {
      if (this.isPlayerActive(player)) {
        if (allBeams.has(`${player.x},${player.y}`)) {
          player.dead = true;
        }
      }
    }
  }

  isLaserBlocked(x, y) {
    const cell = this.cells[x][y];
    if (this.blocksLaser(cell)) return true;
    if (cell.gateColor && !this.isGateColorOpen(cell.gateColor)) return true;
    if (this.glyphs.some(g => g.x === x && g.y === y)) return true;
    return false;
  }

  processConveyors() {
    let movedAny = false;
    const slidEntities = new Set();
    
    for (let pass = 0; pass < 3; pass++) {
      let passMoved = false;
      
      // Players Conveyor Slide
      for (const player of this.players) {
        if (!this.isPlayerActive(player) || slidEntities.has(player.id)) continue;
        const cell = this.cells[player.x][player.y];
        if (!cell.conveyorDir) continue;
        
        const [cdx, cdy] = this.getConveyorOffset(cell.conveyorDir);
        const targetX = player.x + cdx;
        const targetY = player.y + cdy;
        
        if (this.isValidSlideTarget(targetX, targetY, player.id)) {
          let finalX = targetX;
          let finalY = targetY;
          const tele = this.getTeleportDestination(finalX, finalY);
          if (tele) {
            finalX = tele.x;
            finalY = tele.y;
          }
          
          player.x = finalX;
          player.y = finalY;
          slidEntities.add(player.id);
          passMoved = true;
          movedAny = true;
          
          const destCell = this.cells[player.x][player.y];
          if (destCell.isChasm) {
            player.dead = true;
          }
        }
      }
      
      // Glyphs Conveyor Slide
      for (let i = 0; i < this.glyphs.length; i++) {
        const glyph = this.glyphs[i];
        const glyphKey = `g_${glyph.id}`;
        if (slidEntities.has(glyphKey)) continue;
        
        const cell = this.cells[glyph.x][glyph.y];
        if (!cell.conveyorDir) continue;
        
        const [cdx, cdy] = this.getConveyorOffset(cell.conveyorDir);
        const targetX = glyph.x + cdx;
        const targetY = glyph.y + cdy;
        
        if (this.isValidSlideTarget(targetX, targetY, glyphKey)) {
          let finalX = targetX;
          let finalY = targetY;
          const tele = this.getTeleportDestination(finalX, finalY);
          if (tele) {
            finalX = tele.x;
            finalY = tele.y;
          }
          
          const destCell = this.cells[finalX][finalY];
          if (destCell.isChasm) {
            destCell.isChasm = false;
            if (this.chasmDoms.has(`${finalX},${finalY}`)) {
              this.chasmDoms.get(`${finalX},${finalY}`).remove();
              this.chasmDoms.delete(`${finalX},${finalY}`);
            }
            const glyphDom = this.glyphDoms.get(glyph.id);
            if (glyphDom) {
              glyphDom.style.transform += ' scale(0)';
              glyphDom.style.opacity = '0';
              setTimeout(() => glyphDom.remove(), 150);
              this.glyphDoms.delete(glyph.id);
            }
            this.glyphs.splice(i, 1);
            i--;
          } else {
            glyph.x = finalX;
            glyph.y = finalY;
          }
          slidEntities.add(glyphKey);
          passMoved = true;
          movedAny = true;
        }
      }
      
      if (!passMoved) break;
    }
    
    if (movedAny) {
      // Check if players moved onto portal in slides
      for (const player of this.players) {
        if (this.isPlayerActive(player)) {
          const destCell = this.cells[player.x][player.y];
          if (destCell.hasPortal || (destCell.identityPortalPlayer === player.id)) {
            player.finished = true;
          }
        }
      }
    }
  }

  getConveyorOffset(dir) {
    if (dir === 'L') return [-1, 0];
    if (dir === 'R') return [1, 0];
    if (dir === 'U') return [0, -1];
    if (dir === 'D') return [0, 1];
    return [0, 0];
  }

  isValidSlideTarget(x, y, movingEntityKey) {
    if (x < 0 || x >= this.width || y < 0 || y >= this.height) return false;
    const cell = this.cells[x][y];
    if (cell.isWall || cell.isCrackedWall || cell.isMirrorWall) return false;
    if (cell.oneWayDir) return false;
    if (cell.isTimedWall && this.isTimedWallSolid()) return false;
    if (cell.colorWallColor) return false;
    if (cell.linkedWallGroup && this.isLinkedWallSolid(cell.linkedWallGroup)) return false;
    if (cell.rotatingWallAxis) return false;
    if (cell.playerWallAllowedId && cell.playerWallAllowedId !== movingEntityKey) return false;
    if (cell.isGlyphOnlyWall && !movingEntityKey.startsWith('g_')) return false;
    if (cell.gateColor && !this.isGateColorOpen(cell.gateColor)) return false;
    
    // Identity portal check
    if (cell.identityPortalPlayer) {
      if (movingEntityKey.startsWith('g_')) return false; // Glyphs blocked
      if (cell.identityPortalPlayer !== movingEntityKey) return false; // Other players blocked
    }
    
    const playerAt = this.players.find(p => this.isPlayerActive(p) && p.x === x && p.y === y);
    if (playerAt && playerAt.id !== movingEntityKey) {
      const pCell = this.cells[playerAt.x][playerAt.y];
      if (!pCell.conveyorDir) return false;
    }
    
    const glyphAt = this.glyphs.find(g => g.x === x && g.y === y);
    if (glyphAt && `g_${glyphAt.id}` !== movingEntityKey) {
      const gCell = this.cells[glyphAt.x][glyphAt.y];
      if (!gCell.conveyorDir) return false;
    }
    
    return true;
  }
}
