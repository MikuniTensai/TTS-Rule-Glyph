/**
 * BFS Bot Solver for Rule Glyph Lab.
 * Supports local co-op states: all players must enter a portal.
 */

const COLORS = ['red', 'blue', 'green'];
const ALL_RULES = ['STOP', 'PUSH', 'SWAP', 'MERGE'];
const DIRECTIONS = [
  { name: 'U', dx: 0, dy: -1 },
  { name: 'D', dx: 0, dy: 1 },
  { name: 'L', dx: -1, dy: 0 },
  { name: 'R', dx: 1, dy: 0 }
];

function getStateKey(state) {
  const playersString = state.players
    .map(p => `${p.id}:${p.x},${p.y},${p.finished ? 1 : 0}`)
    .join(';');
  const glyphsString = state.glyphs
    .map(g => `${g.type}:${g.x},${g.y}`)
    .sort()
    .join(';');
  const rulesString = COLORS.map(color => state.rules[color]).join(',');
  const expiryString = COLORS.map(color => state.ruleExpiryCounters ? state.ruleExpiryCounters[color] : 'null').join(',');
  const chasmString = Array.from(state.filledChasms || []).sort().join(';');
  const crackedString = Array.from(state.brokenCrackedWalls || []).sort().join(';');
  const laserPhase = Math.floor(state.moves / 2) % 2;

  return [
    playersString,
    glyphsString,
    rulesString,
    expiryString,
    chasmString,
    crackedString,
    laserPhase
  ].join('|');
}

function isPlayerActive(player) {
  return player && player.x !== -1 && !player.dead && !player.finished;
}

function getPlayerAt(state, x, y, ignorePlayerId = null) {
  return state.players.find(player => {
    return player.id !== ignorePlayerId &&
      isPlayerActive(player) &&
      player.x === x &&
      player.y === y;
  }) || null;
}

function areAllPlayersFinished(state) {
  return state.players.every(player => player.finished || player.x === -1);
}

function isPlateActiveInState(state, color, cells) {
  const playerOnPlate = state.players.some(player => {
    return isPlayerActive(player) && cells[player.x][player.y].plateColor === color;
  });
  if (playerOnPlate) return true;

  return state.glyphs.some(g => cells[g.x][g.y].plateColor === color);
}

function isGateOpenInState(state, color, cells) {
  return isPlateActiveInState(state, color, cells);
}

function cloneState(state) {
  return {
    players: state.players.map(p => ({ ...p })),
    glyphs: state.glyphs.map(g => ({ ...g })),
    rules: { ...state.rules },
    ruleExpiryCounters: state.ruleExpiryCounters ? { ...state.ruleExpiryCounters } : { red: null, blue: null, green: null },
    filledChasms: new Set(state.filledChasms || []),
    brokenCrackedWalls: new Set(state.brokenCrackedWalls || []),
    moves: state.moves,
    path: [...state.path]
  };
}

function directionFromDelta(dx, dy) {
  if (dx > 0) return 'R';
  if (dx < 0) return 'L';
  if (dy > 0) return 'D';
  if (dy < 0) return 'U';
  return '';
}

function isCrackedWallActive(state, x, y, cell) {
  return !!cell.isCrackedWall && !state.brokenCrackedWalls.has(`${x},${y}`);
}

function isTimedWallSolid(state) {
  return Math.floor(state.moves / 2) % 2 === 0;
}

function isLinkedWallSolid(state, group) {
  const even = state.moves % 2 === 0;
  return group === 'a' ? even : !even;
}

function activeRotatingWallAxis(state, cell) {
  const axis = cell.rotatingWallAxis || 'horizontal';
  if (state.moves % 2 === 0) return axis;
  return axis === 'horizontal' ? 'vertical' : 'horizontal';
}

function blocksByRotatingWall(state, cell, dx, dy) {
  if (!cell.rotatingWallAxis) return false;
  const axis = activeRotatingWallAxis(state, cell);
  return (axis === 'vertical' && dx !== 0) || (axis === 'horizontal' && dy !== 0);
}

function isColorWallSolid(state, cell) {
  if (!cell.colorWallColor) return false;
  return (state.rules[cell.colorWallColor] || 'STOP') === 'STOP';
}

function blocksPlayerInState(state, cell, x, y, player, dx, dy) {
  if (cell.isWall || isCrackedWallActive(state, x, y, cell) || cell.isMirrorWall || cell.isGlyphOnlyWall) return true;
  if (cell.oneWayDir && cell.oneWayDir !== directionFromDelta(dx, dy)) return true;
  if (cell.isTimedWall && isTimedWallSolid(state)) return true;
  if (isColorWallSolid(state, cell)) return true;
  if (cell.linkedWallGroup && isLinkedWallSolid(state, cell.linkedWallGroup)) return true;
  if (blocksByRotatingWall(state, cell, dx, dy)) return true;
  if (cell.playerWallAllowedId && cell.playerWallAllowedId !== player.id) return true;
  return false;
}

function blocksGlyphInState(state, cell, x, y, dx, dy) {
  if (cell.isWall || cell.isMirrorWall) return true;
  if (cell.oneWayDir && cell.oneWayDir !== directionFromDelta(dx, dy)) return true;
  if (cell.isTimedWall && isTimedWallSolid(state)) return true;
  if (isColorWallSolid(state, cell)) return true;
  if (cell.linkedWallGroup && isLinkedWallSolid(state, cell.linkedWallGroup)) return true;
  if (blocksByRotatingWall(state, cell, dx, dy)) return true;
  if (cell.playerWallAllowedId) return true;
  return false;
}

function blocksLaserInState(state, cell, x, y) {
  if (cell.isWall || isCrackedWallActive(state, x, y, cell) || cell.isMirrorWall || cell.isGlyphOnlyWall) return true;
  if (cell.oneWayDir) return true;
  if (cell.isTimedWall && isTimedWallSolid(state)) return true;
  if (cell.colorWallColor) return true;
  if (cell.linkedWallGroup && isLinkedWallSolid(state, cell.linkedWallGroup)) return true;
  if (cell.rotatingWallAxis) return true;
  if (cell.playerWallAllowedId) return true;
  return false;
}

function getEffectiveRulesInState(rules, glyphs, cells) {
  const eff = { ...rules };
  for (const g of glyphs) {
    if (g.x >= 0 && g.x < cells.length && g.y >= 0 && g.y < cells[0].length) {
      if (cells[g.x][g.y].isSensor) {
        const overrideRule = rules[g.type];
        for (const color of COLORS) {
          eff[color] = overrideRule;
        }
        break;
      }
    }
  }
  return eff;
}

function getTeleportDestinationInState(state, x, y, cells, width, height) {
  const cell = cells[x][y];
  if (cell.teleportType !== 'in') return null;
  
  let bestOut = null;
  let minDist = Infinity;
  
  for (let tx = 0; tx < width; tx++) {
    for (let ty = 0; ty < height; ty++) {
      if (cells[tx][ty].teleportType === 'out') {
        const hasPlayer = state.players.some(p => isPlayerActive(p) && p.x === tx && p.y === ty);
        const hasGlyph = state.glyphs.some(g => g.x === tx && g.y === ty);
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

function processConveyorsInState(state, cells, width, height) {
  let movedAny = false;
  const slidEntities = new Set();
  
  for (let pass = 0; pass < 3; pass++) {
    let passMoved = false;
    
    // Players
    for (const player of state.players) {
      if (!isPlayerActive(player) || slidEntities.has(player.id)) continue;
      const cell = cells[player.x][player.y];
      if (!cell.conveyorDir) continue;
      
      const [cdx, cdy] = getConveyorOffset(cell.conveyorDir);
      const targetX = player.x + cdx;
      const targetY = player.y + cdy;
      
      if (isValidSlideTargetInState(state, targetX, targetY, player.id, cells, width, height)) {
        let finalX = targetX;
        let finalY = targetY;
        const tele = getTeleportDestinationInState(state, finalX, finalY, cells, width, height);
        if (tele) {
          finalX = tele.x;
          finalY = tele.y;
        }
        
        player.x = finalX;
        player.y = finalY;
        slidEntities.add(player.id);
        passMoved = true;
        movedAny = true;
        
        const destCell = cells[player.x][player.y];
        const destIsChasm = destCell.isChasm && !state.filledChasms.has(`${player.x},${player.y}`);
        if (destIsChasm) {
          player.dead = true;
        }
      }
    }
    
    // Glyphs
    for (let i = 0; i < state.glyphs.length; i++) {
      const glyph = state.glyphs[i];
      const glyphKey = `g_${i}`;
      if (slidEntities.has(glyphKey)) continue;
      
      const cell = cells[glyph.x][glyph.y];
      if (!cell.conveyorDir) continue;
      
      const [cdx, cdy] = getConveyorOffset(cell.conveyorDir);
      const targetX = glyph.x + cdx;
      const targetY = glyph.y + cdy;
      
      if (isValidSlideTargetInState(state, targetX, targetY, glyphKey, cells, width, height)) {
        let finalX = targetX;
        let finalY = targetY;
        const tele = getTeleportDestinationInState(state, finalX, finalY, cells, width, height);
        if (tele) {
          finalX = tele.x;
          finalY = tele.y;
        }
        
        const destCell = cells[finalX][finalY];
        const destIsChasm = destCell.isChasm && !state.filledChasms.has(`${finalX},${finalY}`);
        if (destIsChasm) {
          state.filledChasms.add(`${finalX},${finalY}`);
          state.glyphs.splice(i, 1);
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
}

function getConveyorOffset(dir) {
  if (dir === 'L') return [-1, 0];
  if (dir === 'R') return [1, 0];
  if (dir === 'U') return [0, -1];
  if (dir === 'D') return [0, 1];
  return [0, 0];
}

function isValidSlideTargetInState(state, x, y, movingEntityKey, cells, width, height) {
  if (x < 0 || x >= width || y < 0 || y >= height) return false;
  const cell = cells[x][y];
  if (cell.isWall || isCrackedWallActive(state, x, y, cell) || cell.isMirrorWall) return false;
  if (cell.oneWayDir) return false;
  if (cell.isTimedWall && isTimedWallSolid(state)) return false;
  if (cell.colorWallColor) return false;
  if (cell.linkedWallGroup && isLinkedWallSolid(state, cell.linkedWallGroup)) return false;
  if (cell.rotatingWallAxis) return false;
  if (cell.playerWallAllowedId && cell.playerWallAllowedId !== movingEntityKey) return false;
  if (cell.isGlyphOnlyWall && !movingEntityKey.startsWith('g_')) return false;
  if (cell.gateColor && !isGateOpenInState(state, cell.gateColor, cells)) return false;
  
  if (cell.identityPortalPlayer) {
    if (movingEntityKey.startsWith('g_')) return false;
    if (cell.identityPortalPlayer !== movingEntityKey) return false;
  }
  
  const playerAt = state.players.find(p => isPlayerActive(p) && p.x === x && p.y === y);
  if (playerAt && playerAt.id !== movingEntityKey) {
    const pCell = cells[playerAt.x][playerAt.y];
    if (!pCell.conveyorDir) return false;
  }
  
  const glyphAt = state.glyphs.find(g => g.x === x && g.y === y);
  if (glyphAt && `g_${state.glyphs.indexOf(glyphAt)}` !== movingEntityKey) {
    const gCell = cells[glyphAt.x][glyphAt.y];
    if (!gCell.conveyorDir) return false;
  }
  
  return true;
}

function checkLasersInState(state, cells, width, height) {
  const laserBeams = new Set();
  const pulsingActive = Math.floor(state.moves / 2) % 2 === 0;
  
  for (let x = 0; x < width; x++) {
    for (let y = 0; y < height; y++) {
      const cell = cells[x][y];
      if (!cell.laserType) continue;
      
      let active = false;
      let isHorizontal = false;
      
      if (cell.laserType === 'L') { active = true; isHorizontal = true; }
      else if (cell.laserType === 'l') { active = true; isHorizontal = false; }
      else if (cell.laserType === 'P') { active = pulsingActive; isHorizontal = true; }
      else if (cell.laserType === 'p') { active = pulsingActive; isHorizontal = false; }
      
      if (!active) continue;
      
      if (isHorizontal) {
        for (let tx = x - 1; tx >= 0; tx--) {
          if (isLaserBlockedInState(state, tx, y, cells)) { laserBeams.add(`${tx},${y}`); break; }
          laserBeams.add(`${tx},${y}`);
        }
        for (let tx = x + 1; tx < width; tx++) {
          if (isLaserBlockedInState(state, tx, y, cells)) { laserBeams.add(`${tx},${y}`); break; }
          laserBeams.add(`${tx},${y}`);
        }
      } else {
        for (let ty = y - 1; ty >= 0; ty--) {
          if (isLaserBlockedInState(state, x, ty, cells)) { laserBeams.add(`${x},${ty}`); break; }
          laserBeams.add(`${x},${ty}`);
        }
        for (let ty = y + 1; ty < height; ty++) {
          if (isLaserBlockedInState(state, x, ty, cells)) { laserBeams.add(`${x},${ty}`); break; }
          laserBeams.add(`${x},${ty}`);
        }
      }
    }
  }
  
  for (const player of state.players) {
    if (isPlayerActive(player)) {
      if (laserBeams.has(`${player.x},${player.y}`)) {
        player.dead = true;
      }
    }
  }
}

function isLaserBlockedInState(state, x, y, cells) {
  const cell = cells[x][y];
  if (blocksLaserInState(state, cell, x, y)) return true;
  if (cell.gateColor && !isGateOpenInState(state, cell.gateColor, cells)) return true;
  if (state.glyphs.some(g => g.x === x && g.y === y)) return true;
  return false;
}

function getNextMoveState(state, playerIndex, direction, cells, width, height) {
  const player = state.players[playerIndex];
  if (!isPlayerActive(player)) {
    return null;
  }

  const nextX = player.x + direction.dx;
  const nextY = player.y + direction.dy;

  if (nextX < 0 || nextX >= width || nextY < 0 || nextY >= height) {
    return null;
  }

  const targetCell = cells[nextX][nextY];
  if (targetCell.isMirrorWall) {
    const nextState = cloneState(state);
    const nextPlayer = nextState.players[playerIndex];
    nextState.moves += 1;
    nextState.path.push(`${nextPlayer.label || nextPlayer.id.toUpperCase()}:${direction.name}`);

    const bounceX = player.x - direction.dx;
    const bounceY = player.y - direction.dy;
    if (bounceX >= 0 &&
        bounceX < width &&
        bounceY >= 0 &&
        bounceY < height &&
        !blocksPlayerInState(state, cells[bounceX][bounceY], bounceX, bounceY, player, -direction.dx, -direction.dy) &&
        !getPlayerAt(state, bounceX, bounceY, player.id) &&
        !state.glyphs.some(g => g.x === bounceX && g.y === bounceY)) {
      nextPlayer.x = bounceX;
      nextPlayer.y = bounceY;
    }

    for (const color of COLORS) {
      if (nextState.ruleExpiryCounters[color] !== null) {
        nextState.ruleExpiryCounters[color]--;
        if (nextState.ruleExpiryCounters[color] <= 0) {
          nextState.rules[color] = 'STOP';
          nextState.ruleExpiryCounters[color] = null;
        }
      }
    }

    processConveyorsInState(nextState, cells, width, height);
    checkLasersInState(nextState, cells, width, height);

    for (const p of nextState.players) {
      if (isPlayerActive(p)) {
        const pCell = cells[p.x][p.y];
        if (pCell.hasSpikes) {
          const isCovered = nextState.glyphs.some(g => g.x === p.x && g.y === p.y);
          if (!isCovered) {
            p.dead = true;
          }
        }
        if (pCell.isChasm && !nextState.filledChasms.has(`${p.x},${p.y}`)) {
          p.dead = true;
        }
      }
    }

    if (nextState.players.some(p => p.dead)) {
      return null;
    }

    for (const p of nextState.players) {
      if (isPlayerActive(p)) {
        const pCell = cells[p.x][p.y];
        if (pCell.hasPortal || (pCell.identityPortalPlayer === p.id)) {
          p.finished = true;
        }
      }
    }

    return nextState;
  }

  if (blocksPlayerInState(state, targetCell, nextX, nextY, player, direction.dx, direction.dy)) {
    return null;
  }

  if (targetCell.gateColor && !isGateOpenInState(state, targetCell.gateColor, cells)) {
    return null;
  }

  if (targetCell.identityPortalPlayer && targetCell.identityPortalPlayer !== player.id) {
    return null;
  }

  if (getPlayerAt(state, nextX, nextY, player.id)) {
    return null;
  }

  const nextState = cloneState(state);
  const nextPlayer = nextState.players[playerIndex];
  nextState.moves += targetCell.isSoftWall ? 2 : 1;
  nextState.path.push(`${nextPlayer.label || nextPlayer.id.toUpperCase()}:${direction.name}`);

  const glyphIndex = nextState.glyphs.findIndex(g => g.x === nextX && g.y === nextY);
  const targetSpikeWasCovered = targetCell.hasSpikes && glyphIndex !== -1;

  if (glyphIndex !== -1) {
    const glyph = nextState.glyphs[glyphIndex];
    const effectiveRules = getEffectiveRulesInState(nextState.rules, nextState.glyphs, cells);
    let rule = effectiveRules[glyph.type];

    if (cells[glyph.x][glyph.y].isJammer) {
      rule = 'STOP';
    }

    if (glyph.type === 'heavy-2' || glyph.type === 'heavy-3') {
      const reqPlayers = glyph.type === 'heavy-2' ? 2 : 3;
      let lineOk = true;
      for (let i = 1; i < reqPlayers; i++) {
        const checkX = player.x - i * direction.dx;
        const checkY = player.y - i * direction.dy;
        if (!getPlayerAt(state, checkX, checkY)) {
          lineOk = false;
          break;
        }
      }
      if (!lineOk) {
        return null;
      }
      rule = 'PUSH';
    }

    if (rule === 'STOP') {
      return null;
    }

    if (rule === 'PUSH' || rule === 'MERGE') {
      const behindX = nextX + direction.dx;
      const behindY = nextY + direction.dy;

      if (behindX < 0 || behindX >= width || behindY < 0 || behindY >= height) {
        return null;
      }

      const behindCell = cells[behindX][behindY];
      if (isCrackedWallActive(nextState, behindX, behindY, behindCell)) {
        nextState.brokenCrackedWalls.add(`${behindX},${behindY}`);
      } else if (blocksGlyphInState(nextState, behindCell, behindX, behindY, direction.dx, direction.dy)) {
        return null;
      }

      if (behindCell.gateColor && !isGateOpenInState(state, behindCell.gateColor, cells)) {
        return null;
      }

      if (behindCell.identityPortalPlayer) {
        return null;
      }

      if (getPlayerAt(nextState, behindX, behindY, nextPlayer.id)) {
        return null;
      }

      const secondGlyphIndex = nextState.glyphs.findIndex(g => g.x === behindX && g.y === behindY);

      if (secondGlyphIndex !== -1) {
        const secondGlyph = nextState.glyphs[secondGlyphIndex];
        if (rule !== 'MERGE' || glyph.type !== secondGlyph.type || glyph.type === 'heavy-2' || glyph.type === 'heavy-3') {
          return null;
        }

        nextState.glyphs.splice(glyphIndex, 1);
        
        let playerDestX = nextX;
        let playerDestY = nextY;
        const pTele = getTeleportDestinationInState(nextState, playerDestX, playerDestY, cells, width, height);
        if (pTele) {
          playerDestX = pTele.x;
          playerDestY = pTele.y;
        }
        nextPlayer.x = playerDestX;
        nextPlayer.y = playerDestY;
      } else {
        let glyphDestX = behindX;
        let glyphDestY = behindY;
        const gTele = getTeleportDestinationInState(nextState, glyphDestX, glyphDestY, cells, width, height);
        if (gTele) {
          glyphDestX = gTele.x;
          glyphDestY = gTele.y;
        }
        
        const destCell = cells[glyphDestX][glyphDestY];
        const destIsChasm = destCell.isChasm && !nextState.filledChasms.has(`${glyphDestX},${glyphDestY}`);
        if (destIsChasm) {
          nextState.filledChasms.add(`${glyphDestX},${glyphDestY}`);
          nextState.glyphs.splice(glyphIndex, 1);
        } else {
          glyph.x = glyphDestX;
          glyph.y = glyphDestY;
        }
        
        let playerDestX = nextX;
        let playerDestY = nextY;
        const pTele = getTeleportDestinationInState(nextState, playerDestX, playerDestY, cells, width, height);
        if (pTele) {
          playerDestX = pTele.x;
          playerDestY = pTele.y;
        }
        nextPlayer.x = playerDestX;
        nextPlayer.y = playerDestY;
      }
    } else if (rule === 'SWAP') {
      const originalPlayerX = nextPlayer.x;
      const originalPlayerY = nextPlayer.y;

      let playerDestX = nextX;
      let playerDestY = nextY;
      let glyphDestX = originalPlayerX;
      let glyphDestY = originalPlayerY;

      const pTele = getTeleportDestinationInState(nextState, playerDestX, playerDestY, cells, width, height);
      if (pTele) {
        playerDestX = pTele.x;
        playerDestY = pTele.y;
      }

      const gTele = getTeleportDestinationInState(nextState, glyphDestX, glyphDestY, cells, width, height);
      if (gTele) {
        glyphDestX = gTele.x;
        glyphDestY = gTele.y;
      }

      const gCell = cells[glyphDestX][glyphDestY];
      const destIsChasm = gCell.isChasm && !nextState.filledChasms.has(`${glyphDestX},${glyphDestY}`);
      if (destIsChasm) {
        nextState.filledChasms.add(`${glyphDestX},${glyphDestY}`);
        nextState.glyphs.splice(glyphIndex, 1);
      } else {
        glyph.x = glyphDestX;
        glyph.y = glyphDestY;
      }

      nextPlayer.x = playerDestX;
      nextPlayer.y = playerDestY;
    }
  } else {
    let playerDestX = nextX;
    let playerDestY = nextY;
    const pTele = getTeleportDestinationInState(nextState, playerDestX, playerDestY, cells, width, height);
    if (pTele) {
      playerDestX = pTele.x;
      playerDestY = pTele.y;
    }
    nextPlayer.x = playerDestX;
    nextPlayer.y = playerDestY;
  }

  for (const color of COLORS) {
    if (nextState.ruleExpiryCounters[color] !== null) {
      nextState.ruleExpiryCounters[color]--;
      if (nextState.ruleExpiryCounters[color] <= 0) {
        nextState.rules[color] = 'STOP';
        nextState.ruleExpiryCounters[color] = null;
      }
    }
  }

  processConveyorsInState(nextState, cells, width, height);
  checkLasersInState(nextState, cells, width, height);

  for (const p of nextState.players) {
    if (isPlayerActive(p)) {
      const pCell = cells[p.x][p.y];
      if (pCell.hasSpikes) {
        const isCovered = nextState.glyphs.some(g => g.x === p.x && g.y === p.y);
        if (!isCovered && !(p.id === nextPlayer.id && targetSpikeWasCovered)) {
          p.dead = true;
        }
      }
      if (pCell.isChasm && !nextState.filledChasms.has(`${p.x},${p.y}`)) {
        p.dead = true;
      }
    }
  }

  if (nextState.players.some(p => p.dead)) {
    return null;
  }

  for (const p of nextState.players) {
    if (isPlayerActive(p)) {
      const pCell = cells[p.x][p.y];
      if (pCell.hasPortal || (pCell.identityPortalPlayer === p.id)) {
        p.finished = true;
      }
    }
  }

  return nextState;
}

function getAllowedRules(options) {
  const allowedRules = options.allowedRules || {};
  return Object.fromEntries(
    COLORS.map(color => [color, allowedRules[color] || ALL_RULES])
  );
}

function getInitialPlayers(gridEngine) {
  if (Array.isArray(gridEngine.players) && gridEngine.players.length > 0) {
    return gridEngine.players.map((player, index) => ({
      id: player.id || (index === 0 ? 'p1' : 'p2'),
      label: player.label || (index === 0 ? 'P1' : 'P2'),
      x: player.x,
      y: player.y,
      dead: !!player.dead,
      finished: !!player.finished
    }));
  }

  return [{
    id: 'p1',
    label: 'P1',
    x: gridEngine.player.x,
    y: gridEngine.player.y,
    dead: false,
    finished: false
  }];
}

export function solve(gridEngine, activeRules, options = {}) {
  const width = gridEngine.width;
  const height = gridEngine.height;
  const cells = gridEngine.cells;
  const allowedRules = getAllowedRules(options);
  const maxMoves = Number.isFinite(options.maxMoves) ? options.maxMoves : Infinity;

  const initialState = {
    players: getInitialPlayers(gridEngine),
    glyphs: gridEngine.glyphs.map(g => ({ type: g.type, x: g.x, y: g.y })),
    rules: { ...activeRules },
    ruleExpiryCounters: gridEngine.ruleExpiryCounters ? { ...gridEngine.ruleExpiryCounters } : { red: null, blue: null, green: null },
    filledChasms: new Set(),
    brokenCrackedWalls: new Set(),
    moves: 0,
    path: []
  };

  for (const player of initialState.players) {
    if (isPlayerActive(player)) {
      const startCell = cells[player.x][player.y];
      if (startCell.hasPortal || (startCell.identityPortalPlayer === player.id)) {
        player.finished = true;
      }
    }
  }

  if (areAllPlayersFinished(initialState)) {
    return { solved: true, path: [], moves: 0, visitedCount: 0, error: null };
  }

  const queue = [initialState];
  const bestMovesByState = new Map([[getStateKey(initialState), 0]]);
  const maxStates = options.maxStates || 90000;
  let visitedCount = 0;

  while (queue.length > 0) {
    visitedCount += 1;
    if (visitedCount > maxStates) {
      return {
        solved: false,
        path: null,
        moves: null,
        visitedCount,
        error: `Pencarian melebihi batas (${maxStates.toLocaleString()} status).`
      };
    }

    const state = queue.shift();

    if (areAllPlayersFinished(state)) {
      return {
        solved: true,
        path: state.path,
        moves: state.moves,
        visitedCount,
        error: null
      };
    }

    for (const color of COLORS) {
      for (const rule of allowedRules[color]) {
        if (state.rules[color] === rule) {
          continue;
        }

        const nextState = cloneState(state);
        nextState.rules[color] = rule;
        if (rule !== 'STOP') {
          nextState.ruleExpiryCounters[color] = 5;
        } else {
          nextState.ruleExpiryCounters[color] = null;
        }
        nextState.path.push(`${color}=${rule}`);

        const key = getStateKey(nextState);
        if ((bestMovesByState.get(key) ?? Infinity) > nextState.moves) {
          bestMovesByState.set(key, nextState.moves);
          queue.unshift(nextState);
        }
      }
    }

    if (state.moves >= maxMoves) {
      continue;
    }

    for (let playerIndex = 0; playerIndex < state.players.length; playerIndex++) {
      for (const direction of DIRECTIONS) {
        const nextState = getNextMoveState(state, playerIndex, direction, cells, width, height);
        if (!nextState || nextState.moves > maxMoves) {
          continue;
        }

        const key = getStateKey(nextState);
        if ((bestMovesByState.get(key) ?? Infinity) > nextState.moves) {
          bestMovesByState.set(key, nextState.moves);
          queue.push(nextState);
        }
      }
    }
  }

  return {
    solved: false,
    path: null,
    moves: null,
    visitedCount,
    error: 'Tidak ada jalan penyelesaian dengan batas langkah dan rule saat ini.'
  };
}
