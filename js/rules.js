/**
 * Rules Configuration and Metadata for Rule Glyph Lab
 */

export const GLYPH_TYPES = {
  RED: 'red',      // Glyph 'A'
  BLUE: 'blue',    // Glyph 'B'
  GREEN: 'green'   // Glyph 'C'
};

export const RULE_TYPES = {
  STOP: 'STOP',    // Solid wall behavior
  PUSH: 'PUSH',    // Pushable block behavior
  SWAP: 'SWAP',    // Swap positions with player behavior
  MERGE: 'MERGE'   // Pushable + combines with same-color glyph on contact
};

// Map map characters to color channels
export const CHAR_TO_COLOR = {
  'A': GLYPH_TYPES.RED,
  'B': GLYPH_TYPES.BLUE,
  'C': GLYPH_TYPES.GREEN
};

// Default styling labels & colors for UI
export const GLYPH_DETAILS = {
  [GLYPH_TYPES.RED]: {
    name: "Alpha",
    symbol: "▲",
    color: "#ff2a5f"
  },
  [GLYPH_TYPES.BLUE]: {
    name: "Beta",
    symbol: "■",
    color: "#2a6fff"
  },
  [GLYPH_TYPES.GREEN]: {
    name: "Gamma",
    symbol: "●",
    color: "#39ff14"
  }
};
