/**
 * Central Game Orchestrator and Entry Point (Editor & Solver Enabled)
 */

import { LEVELS, LEVELS_BY_MODE, loadLevels, EXTRA_CHAPTERS, CHAPTER_1_TITLE } from './levels.js?v=1.0.6';
import { GridEngine } from './grid.js';
import { UIManager } from './ui.js?v=1.0.6';
import { AudioEngine } from './audio.js';
import { solve } from './solver.js';

const localStorage = {
  getItem(key) {
    try {
      return window.localStorage.getItem(key);
    } catch (e) {
      return null;
    }
  },
  setItem(key, value) {
    try {
      window.localStorage.setItem(key, value);
    } catch (e) {}
  },
  removeItem(key) {
    try {
      window.localStorage.removeItem(key);
    } catch (e) {}
  }
};

const DEFAULT_RULES = { red: 'STOP', blue: 'STOP', green: 'STOP' };
const ALL_RULES = ['STOP', 'PUSH', 'SWAP', 'MERGE'];
const ALL_ALLOWED_RULES = {
  red: ALL_RULES,
  blue: ALL_RULES,
  green: ALL_RULES
};
const CAMPAIGN_VERSION = 'local-coop-campaign-2026-06-15';
const BASE_LEVEL_COUNT = 22;
const START_IN_EDITOR = true;

function cloneAllowedRules(allowedRules = ALL_ALLOWED_RULES) {
  return Object.fromEntries(
    Object.entries(ALL_ALLOWED_RULES).map(([color, fallback]) => [
      color,
      [...(allowedRules[color] || fallback)]
    ])
  );
}

class GameController {
  constructor() {
    this.currentMode = '1'; // Default: 1 Player Mode
    this.currentLevelIndex = 0;
    this.currentLevelData = null;
    this.currentMoveLimit = 0;
    this.movesLeft = 0;
    this.activeRules = { ...DEFAULT_RULES };
    this.allowedRules = cloneAllowedRules();
    this.ruleExpiryCounters = { red: null, blue: null, green: null };
    this.undoStack = [];
    this.isGameActive = true;

    // Editor-specific states
    this.isEditorMode = false;
    this.savedPlayLevelIndex = 0; // To restore play state when leaving editor
    this.customLevelData = null; // Temp storage for play-testing custom levels
    this.editorLevelData = null; // Currently drawn editor level
    this.solvedPath = null;
    this.autoplayIntervalId = null;
    this.isAutoplayActive = false;
    this.diskAutosaveTimerId = null;
    this.diskAutosaveWarningShown = false;

    // Cache DOM containers
    const boardDom = document.getElementById('game-board');
    const gridBgDom = document.getElementById('grid-bg-overlay');

    // Instantiate engine components
    this.gridEngine = new GridEngine(boardDom, gridBgDom);
    this.uiManager = new UIManager({
      onRuleChanged: (color, rule) => this.handleRuleChange(color, rule),
      onLevelSelected: (idx) => {
        this.isEditorMode = false;
        this.uiManager.setEditorModeActive(false);
        this.loadLevel(idx);
      },
      onUndo: () => this.handleUndo(),
      onReset: () => this.handleReset(),
      onNextLevel: () => this.handleNextLevel(),
      
      // Editor bindings
      onToggleEditor: () => this.toggleEditorMode(),
      onGridResize: (cols, rows, steps) => this.handleGridResize(cols, rows, steps),
      onCellPainted: (x, y, brush) => this.handleCellPainted(x, y, brush),
      onTestLevel: () => this.handleTestLevel(),
      onSolveLevel: () => this.handleSolveLevel(),
      onExportLevel: () => this.handleExportLevel(),
      onImportLevel: (data) => this.handleImportLevel(data),
      onAutoplay: () => this.handleAutoplay(),
      onLoadEditorTemplate: (idx) => this.handleLoadEditorTemplate(idx),
      onResetCampaignEditor: () => this.handleResetCampaignEditor(),
      onAllowedRulesChanged: () => this.handleEditorAllowedRulesChanged(),
      getActiveMode: () => this.currentMode,
      onModeChanged: (mode) => this.handleModeChanged(mode),
      onCreateLevel: () => this.handleCreateLevel(),
      onDeleteLevel: () => this.handleDeleteLevel(),
      onLevelInfoChanged: (name, desc) => this.handleLevelInfoChanged(name, desc),
      onDeleteChapter: (chapId) => this.handleDeleteChapter(chapId),
      onCreateChapter: (name) => this.handleCreateChapter(name),
      onChapterInfoChanged: () => this.handleChapterInfoChanged(),
      onWallImageUploaded: (slotIndex, base64) => {
        if (!this.isEditorMode || !this.editorLevelData) return;
        this.editorLevelData[`custom_wall_${slotIndex}`] = base64;
        if (slotIndex === 0) {
          localStorage.setItem('rule_glyph_custom_wall_image', base64);
          this.uiManager.applyCustomWallImage(base64);
        }
        this.gridEngine.loadLevel(this.editorLevelData);
        this.autoSaveEditorState();
      },
      onWallImageReset: (slotIndex) => {
        if (!this.isEditorMode || !this.editorLevelData) return;
        // Keep a null tombstone so cleanLevelForExport does not restore fallback data.
        this.editorLevelData[`custom_wall_${slotIndex}`] = null;
        if (slotIndex === 0) {
          localStorage.removeItem('rule_glyph_custom_wall_image');
          this.uiManager.applyCustomWallImage(null);
        }
        this.gridEngine.loadLevel(this.editorLevelData);
        this.autoSaveEditorState();
      },
      onFloorImageUploaded: (slotKey, base64) => {
        if (!this.isEditorMode || !this.editorLevelData) return;
        if (slotKey === 'bg') {
          this.editorLevelData.custom_floor = base64;
        } else {
          this.editorLevelData[`custom_floor_${slotKey}`] = base64;
        }
        this.gridEngine.loadLevel(this.editorLevelData);
        this.autoSaveEditorState();
      },
      onFloorImageReset: (slotKey) => {
        if (!this.isEditorMode || !this.editorLevelData) return;
        if (slotKey === 'bg') {
          this.editorLevelData.custom_floor = null;
        } else {
          this.editorLevelData[`custom_floor_${slotKey}`] = null;
        }
        this.gridEngine.loadLevel(this.editorLevelData);
        this.autoSaveEditorState();
      },
      
      onSelectGameMode: (mode) => this.handleSelectGameMode(mode),
      onGoToMainMenu: () => this.handleGoToMainMenu(),
      onDpadMove: (dx, dy) => this.executeMove(dx, dy, 'p1'),
      
      getGridWidth: () => this.gridEngine.width,
      getGridHeight: () => this.gridEngine.height
    });

    this.editingTemplateIndex = parseInt(localStorage.getItem(`rule_glyph_editing_template_index_${this.currentMode}`) || '-1', 10);

    this.initKeyboard();
    this.initSwipe();

    if (localStorage.getItem('rule_glyph_campaign_version') !== CAMPAIGN_VERSION) {
      localStorage.setItem('rule_glyph_campaign_version', CAMPAIGN_VERSION);
      for (const mode of ['1', '2', '3', '4']) {
        localStorage.setItem(`rule_glyph_unlocked_level_${mode}`, '0');
        localStorage.removeItem(`rule_glyph_completed_levels_${mode}`);
        localStorage.removeItem(`rule_glyph_editor_level_data_${mode}`);
        localStorage.removeItem(`rule_glyph_editing_template_index_${mode}`);
      }
      localStorage.removeItem('rule_glyph_editor_level_data');
      localStorage.removeItem('rule_glyph_editing_template_index');
    }
    
    // Load the first campaign level for new players.
    const savedUnlocked = parseInt(localStorage.getItem('rule_glyph_unlocked_level_1') || '0', 10);
    const initialIdx = Math.min(savedUnlocked, LEVELS.length - 1);
    
    // This web build is primarily the Android campaign authoring tool.
    if (!START_IN_EDITOR && !localStorage.getItem('rule_glyph_played_before')) {
      this.uiManager.showModal(this.uiManager.modalHelp);
      localStorage.setItem('rule_glyph_played_before', 'true');
    }
    
    this.loadLevel(initialIdx);

    if (START_IN_EDITOR) {
      this.toggleEditorMode(true);
      const modeLevels = LEVELS_BY_MODE[this.currentMode] || LEVELS;
      const restoredIndex = Number.isInteger(this.editingTemplateIndex)
        ? this.editingTemplateIndex
        : -1;

      if (restoredIndex >= 0 && restoredIndex < modeLevels.length) {
        this.uiManager.syncEditorTemplateSelection(restoredIndex);
      } else if (modeLevels.length > 0) {
        // A fresh session edits a real campaign level immediately, ensuring
        // subsequent changes are included in Android JSON autosave.
        this.handleLoadEditorTemplate(Math.min(initialIdx, modeLevels.length - 1));
      }
    }
  }

  getAllowedRules(levelData) {
    return cloneAllowedRules(levelData?.allowedRules);
  }

  normalizeRules(rules, allowedRules) {
    const normalized = { ...DEFAULT_RULES, ...(rules || {}) };

    for (const color of Object.keys(DEFAULT_RULES)) {
      if (!allowedRules[color].includes(normalized[color])) {
        normalized[color] = allowedRules[color][0] || 'STOP';
      }
    }

    return normalized;
  }

  isRuleAllowed(color, rule) {
    return (this.allowedRules[color] || ALL_RULES).includes(rule);
  }

  getCurrentMoveLimit() {
    return this.currentMoveLimit || this.currentLevelData?.movesLimit || 0;
  }

  getCoopMoveLimit(levelData) {
    if (Number.isFinite(levelData?.coopMovesLimit)) {
      return levelData.coopMovesLimit;
    }

    return Math.ceil((levelData?.movesLimit || 0) * 2.15) + 4;
  }

  /**
   * Initialize a level
   */
  loadLevel(levelIndex) {
    this.stopAutoplay();
    
    let levelData;
    const modeLevels = LEVELS_BY_MODE[this.currentMode] || LEVELS;
    if (levelIndex === -1) {
      // Play testing a custom level
      this.currentLevelIndex = -1;
      levelData = this.customLevelData;
      this.uiManager.updateLevelHeader(-1, modeLevels.length, "Custom Playtest");
      document.getElementById('level-display').textContent = 'LEVEL: CUSTOM';
    } else {
      this.currentLevelIndex = levelIndex;
      const stored = localStorage.getItem(`rule_glyph_campaign_edit_${this.currentMode}_${levelIndex}`);
      if (stored) {
        try {
          const storedLevelData = JSON.parse(stored);
          levelData = storedLevelData.campaignVersion === CAMPAIGN_VERSION
            ? { ...modeLevels[levelIndex], ...storedLevelData }
            : modeLevels[levelIndex];
        } catch (e) {
          console.warn("Failed to parse stored level template edits", e);
          levelData = modeLevels[levelIndex];
        }
      } else {
        levelData = modeLevels[levelIndex];
      }
      
      if (!levelData) {
        levelData = modeLevels[0] || LEVELS[0];
        this.currentLevelIndex = 0;
      }
      this.uiManager.updateLevelHeader(this.currentLevelIndex, modeLevels.length, levelData.name);
    }

    this.currentLevelData = levelData;
    this.allowedRules = this.getAllowedRules(levelData);
    this.activeRules = this.normalizeRules(levelData.initialRules, this.allowedRules);
    this.ruleExpiryCounters = { red: null, blue: null, green: null };
    this.undoStack = [];
    this.isGameActive = true;
    
    // Initialize Grid physics engine
    this.gridEngine.loadLevel(levelData);

    // Determine moves limit based on whether player 2 is present in the level
    const hasP2 = this.gridEngine.getPlayer('p2').x !== -1;
    if (hasP2) {
      this.currentMoveLimit = this.getCoopMoveLimit(levelData);
    } else {
      this.currentMoveLimit = levelData.movesLimit || 15;
    }
    this.movesLeft = this.currentMoveLimit;
    
    
    // Sync UI display
    this.uiManager.applyAllowedRules(this.allowedRules);
    this.uiManager.syncRulesPanel(this.activeRules);
    this.uiManager.updateRuleCounters(this.ruleExpiryCounters);
    this.uiManager.updateMoves(this.movesLeft, this.getCurrentMoveLimit());
    this.uiManager.setUndoEnabled(false);
    
    // Reset any glitch overlays on reload
    document.getElementById('board-container').classList.remove('shake-glitch');
  }

  /**
   * Process on-screen rule toggling callbacks
   */
  handleRuleChange(color, rule) {
    if (this.isAutoplayActive) return;
    if (!this.isGameActive && !this.isEditorMode) return;
    if (this.gridEngine.hasAnyPlayerDead() && !this.isEditorMode) return;
    if (!this.isRuleAllowed(color, rule)) {
      this.uiManager.syncRulesPanel(this.activeRules);
      return;
    }
    if (this.activeRules[color] === rule) return;
    
    if (!this.isEditorMode) {
      // Take an Undo snapshot of rules change so players can undo rules config changes
      this.pushUndoSnapshot();
    }
    
    this.activeRules[color] = rule;
    if (rule !== 'STOP') {
      this.ruleExpiryCounters[color] = 5;
    } else {
      this.ruleExpiryCounters[color] = null;
    }
    this.uiManager.updateRuleCounters(this.ruleExpiryCounters);
    
    // Recalculate physical grid gate/plate states (e.g. if rule changed to PUSH, glyph might trigger a plate immediately)
    this.gridEngine.updateTriggers(false);
    this.gridEngine.render();

    // If editor mode and solver results were shown, rule change might affect solve, so clear solver panel
    if (this.isEditorMode) {
      this.uiManager.clearSolverResults();
      this.autoSaveEditorState();
    }
  }

  /**
   * Core execution of directional move steps
   */
  executeMove(dx, dy, playerId = 'p1') {
    const player = this.gridEngine.getPlayer(playerId);
    if (!this.isGameActive || this.gridEngine.hasAnyPlayerDead() || this.movesLeft <= 0 || !this.gridEngine.isPlayerActive(player)) return;
    
    // Take snapshot before moving
    this.pushUndoSnapshot();
    
    // Run movement physics check
    const result = this.gridEngine.tryMove(dx, dy, this.activeRules, playerId);
    
    if (result.moved) {
      const moveCost = result.moveCost || 1;
      if (moveCost > this.movesLeft) {
        this.performUndo();
        this.handleOutOfSteps();
        return;
      }
      this.movesLeft -= moveCost;
      
      // Decay active rule timers
      let didRevert = false;
      for (const color of ['red', 'blue', 'green']) {
        if (this.ruleExpiryCounters[color] !== null) {
          this.ruleExpiryCounters[color]--;
          if (this.ruleExpiryCounters[color] <= 0) {
            this.activeRules[color] = 'STOP';
            this.ruleExpiryCounters[color] = null;
            didRevert = true;
          }
        }
      }
      if (didRevert) {
        AudioEngine.playRuleChange();
      }
      
      this.uiManager.syncRulesPanel(this.activeRules);
      this.uiManager.updateRuleCounters(this.ruleExpiryCounters);
      this.uiManager.updateMoves(this.movesLeft, this.getCurrentMoveLimit());
      this.uiManager.setUndoEnabled(true);
      
      if (result.won) {
        this.handleWin();
      } else if (result.dead) {
        this.handleDeath();
      } else if (this.movesLeft <= 0) {
        this.handleOutOfSteps();
      }
    } else {
      // Discard snapshot if movement was blocked and did not execute
      this.undoStack.pop();
      if (this.undoStack.length === 0) {
        this.uiManager.setUndoEnabled(false);
      }
    }
  }

  isCustomMode() {
    return this.currentLevelIndex === -1;
  }

  /**
   * Handle Level Complete sequence
   */
  handleWin() {
    this.isGameActive = false;
    this.stopAutoplay();

    if (this.isCustomMode()) {
      document.getElementById('win-stats').textContent = `Langkah Digunakan: ${this.getCurrentMoveLimit() - this.movesLeft} / ${this.getCurrentMoveLimit()}`;
      document.getElementById('win-message').textContent = 'Custom Playtest Berhasil!';
      this.uiManager.showModal(this.uiManager.modalWin);
      
      // Override Next button callback to return to editor
      this.uiManager.callbacks.onNextLevel = () => {
        this.uiManager.hideModal(this.uiManager.modalWin);
        this.toggleEditorMode(true); // Return to editor mode explicitly
      };
      return;
    }

    // Normal progression unlocks next level indices
    const modeLevels = LEVELS_BY_MODE[this.currentMode] || LEVELS;
    const currentUnlocked = parseInt(localStorage.getItem(`rule_glyph_unlocked_level_${this.currentMode}`) || '0', 10);
    if (this.currentLevelIndex === currentUnlocked && this.currentLevelIndex < modeLevels.length - 1) {
      localStorage.setItem(`rule_glyph_unlocked_level_${this.currentMode}`, (this.currentLevelIndex + 1).toString());
    }
    
    // Save completion checks
    const completedList = JSON.parse(localStorage.getItem(`rule_glyph_completed_levels_${this.currentMode}`) || '[]');
    if (!completedList.includes(this.currentLevelIndex)) {
      completedList.push(this.currentLevelIndex);
      localStorage.setItem(`rule_glyph_completed_levels_${this.currentMode}`, JSON.stringify(completedList));
    }
    
    const movesUsed = this.getCurrentMoveLimit() - this.movesLeft;
    
    if (this.currentLevelIndex === modeLevels.length - 1) {
      // Game completed! Show ending congratulations screen
      this.uiManager.showFinishedModal();
    } else {
      // Normal win popup
      document.getElementById('win-message').textContent = 'Eksperimen Berhasil!';
      this.uiManager.showWinModal({
        movesUsed,
        movesLimit: this.getCurrentMoveLimit()
      });
      // Reset Next Level callback in case it was modified by custom playtest
      this.uiManager.callbacks.onNextLevel = () => this.handleNextLevel();
    }
  }

  /**
   * Handle spike hazard contact death
   */
  handleDeath() {
    this.isGameActive = false;
    this.stopAutoplay();
    this.uiManager.showFailModal();
  }

  /**
   * Handle step limit exhaustion fail
   */
  handleOutOfSteps() {
    this.isGameActive = false;
    this.stopAutoplay();
    AudioEngine.playFail();
    this.uiManager.showFailModal();
  }

  /**
   * Capture game state snapshot and push to history buffer
   */
  pushUndoSnapshot() {
    const snapshot = {
      gridState: this.gridEngine.getStateSnapshot(),
      rules: { ...this.activeRules },
      ruleExpiryCounters: { ...this.ruleExpiryCounters },
      movesLeft: this.movesLeft
    };
    this.undoStack.push(snapshot);
  }

  /**
   * Restore previous step from stack
   */
  handleUndo() {
    if (this.isAutoplayActive) return;
    if (this.undoStack.length === 0) return;
    
    const snapshot = this.undoStack.pop();
    
    // Revert logic states
    this.activeRules = { ...snapshot.rules };
    this.ruleExpiryCounters = { ...snapshot.ruleExpiryCounters };
    this.movesLeft = snapshot.movesLeft;
    this.isGameActive = true;
    
    // Revert grid coordinates positions
    this.gridEngine.restoreStateSnapshot(snapshot.gridState);
    
    // Sync displays
    this.uiManager.syncRulesPanel(this.activeRules);
    this.uiManager.updateRuleCounters(this.ruleExpiryCounters);
    this.uiManager.updateMoves(this.movesLeft, this.getCurrentMoveLimit());
    this.uiManager.setUndoEnabled(this.undoStack.length > 0);
    
    AudioEngine.playRuleChange();
  }

  /**
   * Reset current level to its default blueprint
   */
  handleReset() {
    if (this.isAutoplayActive) return;
    AudioEngine.playRuleChange();
    this.loadLevel(this.isCustomMode() ? -1 : this.currentLevelIndex);
  }

  handleModeChanged(mode) {
    this.currentMode = mode;
    
    if (this.isEditorMode) {
      // Synchronize editor level templates dropdown with the active mode
      this.uiManager.populateEditorLevelSelect();

      // Load or restore editor session for the new mode
      const savedData = localStorage.getItem(`rule_glyph_editor_level_data_${this.currentMode}`);
      if (savedData) {
        try {
          const parsed = JSON.parse(savedData);
          if (parsed.campaignVersion === CAMPAIGN_VERSION) {
            this.editorLevelData = parsed;
            this.editingTemplateIndex = parseInt(localStorage.getItem(`rule_glyph_editing_template_index_${this.currentMode}`) || '-1', 10);
            this.activeRules = parsed.initialRules || { ...DEFAULT_RULES };
            this.uiManager.syncEditorInputs(parsed.width, parsed.height, parsed.movesLimit, parsed.name, parsed.description);
          } else {
            this.editorLevelData = null;
          }
        } catch (e) {
          console.warn("Failed to restore saved editor layout", e);
          this.editorLevelData = null;
        }
      } else {
        this.editorLevelData = null;
      }
      
      if (!this.editorLevelData) {
        const modeLevels = LEVELS_BY_MODE[this.currentMode] || [];
        if (modeLevels.length > 0) {
          this.handleLoadEditorTemplate(0);
          return;
        }

        const cols = parseInt(this.uiManager.editorColsInput.value, 10) || 7;
        const rows = parseInt(this.uiManager.editorRowsInput.value, 10) || 7;
        const steps = parseInt(this.uiManager.editorStepsInput.value, 10) || 15;
        this.editorLevelData = this.createEmptyEditorLevel(cols, rows, steps);
        this.editingTemplateIndex = -1;
      }
      
      this.allowedRules = this.getAllowedRules(this.editorLevelData);
      this.activeRules = this.normalizeRules(this.activeRules, this.allowedRules);
      this.uiManager.applyAllowedRules(this.allowedRules);
      this.gridEngine.loadLevel(this.editorLevelData);
      this.uiManager.syncRulesPanel(this.activeRules);
      this.uiManager.syncEditorTemplateSelection(this.editingTemplateIndex);
      
      // Auto-save the restored state for the new mode
      this.autoSaveEditorState();
    } else {
      this.editingTemplateIndex = -1;
      this.loadLevel(0);
    }
  }

  handleSelectGameMode(mode) {
    try {
      this.currentMode = mode;
      this.uiManager.syncModeUI(mode);
      
      let savedUnlocked = parseInt(localStorage.getItem(`rule_glyph_unlocked_level_${mode}`) || '0', 10);
      if (isNaN(savedUnlocked)) {
        savedUnlocked = 0;
      }
      
      const modeLevels = LEVELS_BY_MODE[mode] || LEVELS;
      const initialIdx = Math.max(0, Math.min(savedUnlocked, modeLevels.length - 1));
      
      this.loadLevel(initialIdx);
      document.body.classList.add('in-game');
    } catch (e) {
      console.error("Error in handleSelectGameMode:", e);
    }
  }

  handleGoToMainMenu() {
    this.stopAutoplay();
    if (this.isEditorMode) {
      this.toggleEditorMode(false);
    }
    document.body.classList.remove('in-game');
  }

  /**
   * Advance to next level or loop back to menu
   */
  handleNextLevel() {
    const modeLevels = LEVELS_BY_MODE[this.currentMode] || LEVELS;
    const nextIdx = this.currentLevelIndex + 1;
    if (nextIdx < modeLevels.length) {
      this.loadLevel(nextIdx);
    } else {
      // All levels completed, show levels menu
      this.uiManager.populateLevelsMenu();
      this.uiManager.showModal(this.uiManager.modalLevels);
    }
  }

  // ==========================================
  // LEVEL EDITOR & SOLVER CONTROLLER METHODS
  // ==========================================

  /**
   * Toggle between Play Mode and Editor Mode
   */
  toggleEditorMode(forceActiveState = null) {
    this.stopAutoplay();
    
    if (forceActiveState !== null) {
      this.isEditorMode = forceActiveState;
    } else {
      this.isEditorMode = !this.isEditorMode;
    }

    this.uiManager.setEditorModeActive(this.isEditorMode);
    
    if (this.isEditorMode) {
      document.body.classList.add('in-game');
      // Synchronize editor level template selector options with active mode
      this.uiManager.populateEditorLevelSelect();

      // Save current playing level index so we can restore it if they quit editor
      if (!this.isCustomMode()) {
        this.savedPlayLevelIndex = this.currentLevelIndex;
      }
      
      // Attempt to restore saved editor session from mode-specific localStorage
      const savedData = localStorage.getItem(`rule_glyph_editor_level_data_${this.currentMode}`);
      if (savedData) {
        try {
          const parsed = JSON.parse(savedData);
          if (parsed.campaignVersion === CAMPAIGN_VERSION) {
            this.editorLevelData = parsed;
            this.editingTemplateIndex = parseInt(localStorage.getItem(`rule_glyph_editing_template_index_${this.currentMode}`) || '-1', 10);
            this.activeRules = parsed.initialRules || { ...DEFAULT_RULES };
            this.uiManager.syncEditorInputs(parsed.width, parsed.height, parsed.movesLimit);
          } else {
            this.editorLevelData = null;
          }
        } catch (e) {
          console.warn("Failed to restore saved editor layout", e);
          this.editorLevelData = null;
        }
      }
      
      // Default to empty editor template if nothing restored
      if (!this.editorLevelData) {
        const cols = parseInt(this.uiManager.editorColsInput.value, 10) || 7;
        const rows = parseInt(this.uiManager.editorRowsInput.value, 10) || 7;
        const steps = parseInt(this.uiManager.editorStepsInput.value, 10) || 15;
        this.editorLevelData = this.createEmptyEditorLevel(cols, rows, steps);
        this.editingTemplateIndex = -1;
      }
      
      this.allowedRules = this.getAllowedRules(this.editorLevelData);
      this.activeRules = this.normalizeRules(this.activeRules, this.allowedRules);
      this.uiManager.applyAllowedRules(this.allowedRules);
      this.uiManager.syncEditorAllowedRules(this.allowedRules);
      this.gridEngine.loadLevel(this.editorLevelData);
      this.uiManager.syncRulesPanel(this.activeRules);
    } else {
      // Return to standard play mode: restore original level or play the edited template level
      const targetLevelIdx = this.editingTemplateIndex !== -1 ? this.editingTemplateIndex : this.savedPlayLevelIndex;
      this.loadLevel(targetLevelIdx);
    }
  }

  /**
   * Create basic border outline level layout template
   */
  createEmptyEditorLevel(cols, rows, steps) {
    const map = [];
    const mode = this.currentMode || '1';
    for (let y = 0; y < rows; y++) {
      let row = '';
      for (let x = 0; x < cols; x++) {
        if (x === 0 || x === cols - 1 || y === 0 || y === rows - 1) {
          row += '#';
        } else if (x === 1 && y === 1) {
          row += '@';
        } else if (mode >= '2' && x === 1 && y === 2 && rows > 3) {
          row += '%'; // P2
        } else if (mode >= '3' && x === 1 && y === 3 && rows > 4) {
          row += '*'; // P3
        } else if (mode >= '4' && x === 1 && y === 4 && rows > 5) {
          row += '$'; // P4
        } else if (x === cols - 2 && y === rows - 2) {
          row += 'X';
        } else {
          row += '.';
        }
      }
      map.push(row);
    }
    return {
      width: cols,
      height: rows,
      movesLimit: steps,
      initialRules: { red: 'STOP', blue: 'STOP', green: 'STOP' },
      map: map
    };
  }

  /**
   * Handle Editor cell click/drag painting
   */
  handleCellPainted(x, y, brush) {
    if (!this.isEditorMode) return;
    this.gridEngine.paintCell(x, y, brush);
    this.uiManager.clearSolverResults(); // solver result is now stale
    this.autoSaveEditorState();
  }

  /**
   * Handle resizing editor dimensions, padding content to match new width/height boundaries
   */
  handleGridResize(cols, rows, steps) {
    if (!this.isEditorMode) return;
    
    // Serialize what is on board now
    const currentStepsLimit = parseInt(this.uiManager.editorStepsInput.value, 10) || 15;
    const currentData = this.gridEngine.serializeLevelData(currentStepsLimit);
    
    // Build resized layout matrix
    const resizedData = {
      width: cols,
      height: rows,
      movesLimit: steps,
      initialRules: { ...this.activeRules },
      allowedRules: cloneAllowedRules(this.allowedRules),
      campaignVersion: CAMPAIGN_VERSION,
      map: []
    };
    
    for (let y = 0; y < rows; y++) {
      let row = '';
      for (let x = 0; x < cols; x++) {
        // Carry over content if within old dimensions
        if (x < currentData.width && y < currentData.height) {
          row += currentData.map[y][x];
        } else {
          // Pad boundaries with walls, inner with empty floor
          if (x === 0 || x === cols - 1 || y === 0 || y === rows - 1) {
            row += '#';
          } else {
            row += '.';
          }
        }
      }
      resizedData.map.push(row);
    }

    // Build parallel custom floor map matrix if it was present
    const oldFloorMap = currentData.custom_floor_map || this.editorLevelData?.custom_floor_map;
    if (oldFloorMap) {
      resizedData.custom_floor_map = [];
      for (let y = 0; y < rows; y++) {
        let floorRow = '';
        for (let x = 0; x < cols; x++) {
          if (y < oldFloorMap.length && x < oldFloorMap[y].length) {
            floorRow += oldFloorMap[y][x];
          } else {
            floorRow += '.';
          }
        }
        resizedData.custom_floor_map.push(floorRow);
      }
    }

    // Copy metadata and custom images from old editorLevelData to prevent loss during resize/step updates
    if (this.editorLevelData) {
      if (this.editorLevelData.id !== undefined) resizedData.id = this.editorLevelData.id;
      if (this.editorLevelData.name !== undefined) resizedData.name = this.editorLevelData.name;
      if (this.editorLevelData.description !== undefined) resizedData.description = this.editorLevelData.description;
      if (this.editorLevelData.custom_floor !== undefined) resizedData.custom_floor = this.editorLevelData.custom_floor;
      
      for (let i = 0; i <= 6; i++) {
        const wallKey = `custom_wall_${i}`;
        if (this.editorLevelData[wallKey] !== undefined) {
          resizedData[wallKey] = this.editorLevelData[wallKey];
        }
        const floorKey = `custom_floor_${i}`;
        if (this.editorLevelData[floorKey] !== undefined) {
          resizedData[floorKey] = this.editorLevelData[floorKey];
        }
      }
    }
    
    this.editorLevelData = resizedData;
    this.gridEngine.loadLevel(resizedData);
    this.uiManager.clearSolverResults();
    this.autoSaveEditorState();
  }

  /**
   * Play test current editor level: exits editor mode and loads level as custom
   */
  handleTestLevel() {
    if (this.gridEngine.player.x === -1) {
      alert("Letakkan player (◈) terlebih dahulu sebelum menguji level!");
      AudioEngine.playFail();
      return;
    }
    
    const steps = parseInt(this.uiManager.editorStepsInput.value, 10) || 15;
    this.customLevelData = this.gridEngine.serializeLevelData(steps);
    // Preserves rules toggles set by designer
    this.customLevelData.initialRules = { ...this.activeRules };
    this.customLevelData.allowedRules = cloneAllowedRules(this.allowedRules);
    this.customLevelData.campaignVersion = CAMPAIGN_VERSION;
    
    // Exit editor mode visually and load as playtest custom level
    this.isEditorMode = false;
    this.uiManager.setEditorModeActive(false);
    this.loadLevel(-1);
  }

  /**
   * Run BFS Solver bot to find path
   */
  handleSolveLevel() {
    if (this.gridEngine.player.x === -1) {
      alert("Letakkan player (◈) terlebih dahulu sebelum memecahkan level!");
      AudioEngine.playFail();
      return;
    }
    
    const steps = parseInt(this.uiManager.editorStepsInput.value, 10) || this.getCurrentMoveLimit();
    const hasP2 = this.gridEngine.getPlayer('p2').x !== -1;
    const maxMoves = hasP2 ? this.getCoopMoveLimit({ movesLimit: steps }) : steps;
    const result = solve(this.gridEngine, this.activeRules, {
      allowedRules: this.allowedRules,
      maxMoves: maxMoves
    });
    
    if (result.solved) {
      this.solvedPath = result.path;
    } else {
      this.solvedPath = null;
      AudioEngine.playFail();
    }
    
    this.uiManager.updateSolverResults(result);
  }

  /**
   * Auto Play solver solution sequence step-by-step
   */
  handleAutoplay() {
    if (!this.solvedPath || this.solvedPath.length === 0 || this.isAutoplayActive) return;

    // Reset board before autoplay
    const currentStepsLimit = parseInt(this.uiManager.editorStepsInput.value, 10) || 15;
    this.customLevelData = this.gridEngine.serializeLevelData(currentStepsLimit);
    this.customLevelData.initialRules = { ...this.activeRules };
    this.customLevelData.allowedRules = cloneAllowedRules(this.allowedRules);
    this.customLevelData.campaignVersion = CAMPAIGN_VERSION;
    
    // Temp exit editor mode visually for play verification
    this.isEditorMode = false;
    this.uiManager.setEditorModeActive(false);
    this.loadLevel(-1);

    this.isAutoplayActive = true;
    this.uiManager.btnSolverAutoplay.textContent = 'Autoplay Active...';
    this.uiManager.btnSolverAutoplay.disabled = true;
    
    let pathIndex = 0;
    
    this.autoplayIntervalId = window.setInterval(() => {
      if (pathIndex >= this.solvedPath.length) {
        this.stopAutoplay();
        return;
      }
      
      const move = this.solvedPath[pathIndex++];

      if (move.includes('=')) {
        const [color, rule] = move.split('=');
        if (this.isRuleAllowed(color, rule)) {
          this.activeRules[color] = rule;
          this.uiManager.syncRulesPanel(this.activeRules);
          this.gridEngine.updateTriggers(false);
          this.gridEngine.render();
        }
        return;
      }

      let playerId = 'p1';
      let moveDirection = move;
      if (move.includes(':')) {
        const [playerLabel, directionName] = move.split(':');
        playerId = playerLabel.toLowerCase();
        moveDirection = directionName;
      }

      let dx = 0, dy = 0;
      switch (moveDirection) {
        case 'U': dy = -1; break;
        case 'D': dy = 1; break;
        case 'L': dx = -1; break;
        case 'R': dx = 1; break;
      }
      
      this.executeMove(dx, dy, playerId);
      
      // If player died or win screen triggered, stop loop
      if (!this.isGameActive || this.gridEngine.hasAnyPlayerDead()) {
        this.stopAutoplay();
      }
    }, 350);
  }

  /**
   * Stop any active autoplay intervals
   */
  stopAutoplay() {
    if (this.autoplayIntervalId) {
      window.clearInterval(this.autoplayIntervalId);
      this.autoplayIntervalId = null;
    }
    this.isAutoplayActive = false;
    this.uiManager.btnSolverAutoplay.textContent = '▶ Autoplay Solusi';
    this.uiManager.btnSolverAutoplay.disabled = false;
  }

  /**
   * Serialize editor canvas layout to JSON format
   */
  handleExportLevel() {
    const steps = parseInt(this.uiManager.editorStepsInput.value, 10) || 15;
    const data = this.gridEngine.serializeLevelData(steps);
    
    // Attempt to retrieve current template details to preserve metadata
    let id = 1;
    let name = "Level Kustom";
    let description = "Capai portal dengan memanipulasi aturan.";
    
    if (this.editingTemplateIndex !== null && this.editingTemplateIndex !== undefined && this.editingTemplateIndex !== -1) {
      const modeLevels = LEVELS_BY_MODE[this.currentMode] || LEVELS;
      const tpl = modeLevels[this.editingTemplateIndex];
      if (tpl) {
        id = tpl.id || (this.editingTemplateIndex + 1);
        name = tpl.name || `Level ${id}`;
        description = tpl.description || "Tantangan logika aturan grid.";
      }
    } else if (this.editorLevelData) {
      id = this.editorLevelData.id || 1;
      name = this.editorLevelData.name || "Level Impor";
      description = this.editorLevelData.description || "Level hasil impor.";
    }

    // Construct object with exactly ordered properties to match JSON files
    const exportData = {
      id: id,
      name: name,
      description: description,
      width: data.width,
      height: data.height,
      movesLimit: data.movesLimit,
      initialRules: { ...this.activeRules },
      allowedRules: cloneAllowedRules(this.allowedRules),
      map: data.map
    };

    if (data.custom_floor_map) {
      exportData.custom_floor_map = data.custom_floor_map;
    }

    for (let i = 0; i <= 6; i++) {
      if (this.editorLevelData && this.editorLevelData[`custom_wall_${i}`] !== undefined) {
        exportData[`custom_wall_${i}`] = this.editorLevelData[`custom_wall_${i}`];
      }
      if (this.editorLevelData && this.editorLevelData[`custom_floor_${i}`] !== undefined) {
        exportData[`custom_floor_${i}`] = this.editorLevelData[`custom_floor_${i}`];
      }
    }
    if (this.editorLevelData && this.editorLevelData.custom_floor !== undefined) {
      exportData.custom_floor = this.editorLevelData.custom_floor;
    }

    return exportData;
  }

  /**
   * Handle onAllowedRulesChanged from Editor Checkboxes panel
   */
  handleEditorAllowedRulesChanged() {
    if (!this.isEditorMode) return;
    
    const allowed = {
      red: ['STOP'],
      blue: ['STOP'],
      green: ['STOP']
    };
    
    if (this.uiManager.chkAllowRedPush.checked) allowed.red.push('PUSH');
    if (this.uiManager.chkAllowRedSwap.checked) allowed.red.push('SWAP');
    if (this.uiManager.chkAllowRedMerge.checked) allowed.red.push('MERGE');
    
    if (this.uiManager.chkAllowBluePush.checked) allowed.blue.push('PUSH');
    if (this.uiManager.chkAllowBlueSwap.checked) allowed.blue.push('SWAP');
    if (this.uiManager.chkAllowBlueMerge.checked) allowed.blue.push('MERGE');
    
    if (this.uiManager.chkAllowGreenPush.checked) allowed.green.push('PUSH');
    if (this.uiManager.chkAllowGreenSwap.checked) allowed.green.push('SWAP');
    if (this.uiManager.chkAllowGreenMerge.checked) allowed.green.push('MERGE');
    
    this.allowedRules = allowed;
    
    this.uiManager.applyAllowedRules(this.allowedRules);
    this.activeRules = this.normalizeRules(this.activeRules, this.allowedRules);
    this.uiManager.syncRulesPanel(this.activeRules);
    
    if (this.editorLevelData) {
      this.editorLevelData.allowedRules = cloneAllowedRules(this.allowedRules);
      this.autoSaveEditorState();
    }
  }

  /**
   * Import level layout data from JSON structure
   */
  handleImportLevel(data) {
    this.uiManager.syncEditorInputs(data.width, data.height, data.movesLimit, data.name, data.description);
    
    this.allowedRules = this.getAllowedRules(data);
    this.activeRules = this.normalizeRules(data.initialRules, this.allowedRules);
    data.initialRules = { ...this.activeRules };
    data.allowedRules = cloneAllowedRules(this.allowedRules);
    data.campaignVersion = CAMPAIGN_VERSION;
    
    this.editorLevelData = data;
    this.gridEngine.loadLevel(data);
    this.uiManager.applyAllowedRules(this.allowedRules);
    this.uiManager.syncEditorAllowedRules(this.allowedRules);
    this.uiManager.syncRulesPanel(this.activeRules);
    this.uiManager.clearSolverResults();
    this.autoSaveEditorState();
  }

  /**
   * Load saved campaign level template into Editor mode
   */
  handleLoadEditorTemplate(idx) {
    if (!this.isEditorMode) return;
    
    this.editingTemplateIndex = idx;
    localStorage.setItem(`rule_glyph_editing_template_index_${this.currentMode}`, idx.toString());
    this.uiManager.syncEditorTemplateSelection(idx);
    
    const modeLevels = LEVELS_BY_MODE[this.currentMode] || LEVELS;
    const levelData = modeLevels[idx];
    if (!levelData) return;
    
    this.editorLevelData = null; // Clear old reference to force reload
    
    const stored = localStorage.getItem(`rule_glyph_campaign_edit_${this.currentMode}_${idx}`);
    if (stored) {
      try {
        const storedLevelData = JSON.parse(stored);
        this.editorLevelData = storedLevelData.campaignVersion === CAMPAIGN_VERSION
          ? { ...levelData, ...storedLevelData }
          : null;
      } catch (e) {
        console.warn("Failed to parse stored level template edits", e);
        this.editorLevelData = null;
      }
    }
    
    if (!this.editorLevelData) {
      // Deep copy mapping layout to keep original clean
      this.editorLevelData = {
        id: levelData.id,
        name: levelData.name,
        description: levelData.description,
        width: levelData.width,
        height: levelData.height,
        movesLimit: levelData.movesLimit,
        initialRules: { ...levelData.initialRules },
        allowedRules: cloneAllowedRules(levelData.allowedRules),
        campaignVersion: CAMPAIGN_VERSION,
        map: [...levelData.map]
      };
    }
    
    // Always normalize loaded level template ID sequentially
    if (this.editorLevelData) {
      this.editorLevelData.id = idx + 1;
    }
    
    this.allowedRules = this.getAllowedRules(this.editorLevelData);
    this.activeRules = this.normalizeRules(
      this.editorLevelData.initialRules || levelData.initialRules,
      this.allowedRules
    );
    
    // Sync UI settings input values
    this.uiManager.syncEditorInputs(
      this.editorLevelData.width,
      this.editorLevelData.height,
      this.editorLevelData.movesLimit,
      this.editorLevelData.name,
      this.editorLevelData.description
    );
    this.uiManager.applyAllowedRules(this.allowedRules);
    this.uiManager.syncEditorAllowedRules(this.allowedRules);
    this.uiManager.syncRulesPanel(this.activeRules);
    
    // Load grid state and draw
    this.gridEngine.loadLevel(this.editorLevelData);
    this.uiManager.clearSolverResults();
    
    this.autoSaveEditorState();
    
    AudioEngine.playUnlock();
  }

  /**
   * Revert currently selected editor campaign level back to defaults
   */
  handleResetCampaignEditor() {
    if (!this.isEditorMode || this.editingTemplateIndex === -1) {
      alert("Pilih salah satu level kampanye terlebih dahulu untuk direset!");
      AudioEngine.playFail();
      return;
    }
    
    if (confirm("Apakah Anda yakin ingin mengembalikan level ini ke tata letak bawaan kampanye asli? Semua modifikasi Anda pada level ini akan dihapus.")) {
      localStorage.removeItem(`rule_glyph_campaign_edit_${this.currentMode}_${this.editingTemplateIndex}`);
      
      const modeLevels = LEVELS_BY_MODE[this.currentMode] || LEVELS;
      const levelData = modeLevels[this.editingTemplateIndex];
      this.editorLevelData = {
        width: levelData.width,
        height: levelData.height,
        movesLimit: levelData.movesLimit,
        initialRules: { ...levelData.initialRules },
        allowedRules: cloneAllowedRules(levelData.allowedRules),
        campaignVersion: CAMPAIGN_VERSION,
        map: [...levelData.map]
      };
      
      this.allowedRules = this.getAllowedRules(this.editorLevelData);
      this.activeRules = this.normalizeRules(levelData.initialRules, this.allowedRules);
      
      this.uiManager.syncEditorInputs(levelData.width, levelData.height, levelData.movesLimit, levelData.name, levelData.description);
      this.uiManager.applyAllowedRules(this.allowedRules);
      this.uiManager.syncRulesPanel(this.activeRules);
      
      this.gridEngine.loadLevel(this.editorLevelData);
      this.uiManager.clearSolverResults();
      
      this.autoSaveEditorState();
      AudioEngine.playUnlock();
    }
  }

  handleCreateLevel() {
    if (!this.isEditorMode) return;
    const modeLevels = LEVELS_BY_MODE[this.currentMode] || LEVELS;
    const newIndex = modeLevels.length;
    const newId = newIndex + 1;
    
    // Create new level
    const newLevel = this.createEmptyEditorLevel(7, 7, 15);
    newLevel.id = newId;
    newLevel.name = `Level Baru ${newId}`;
    newLevel.description = "Desain level kustom Anda.";
    newLevel.initialRules = { red: 'STOP', blue: 'STOP', green: 'STOP' };
    newLevel.allowedRules = { red: ['STOP'], blue: ['STOP'], green: ['STOP'] };
    
    modeLevels.push(newLevel);
    if (this.currentMode === '1' && LEVELS !== modeLevels) {
      LEVELS.push(newLevel);
    }
    
    // Re-index all levels sequentially
    for (let i = 0; i < modeLevels.length; i++) {
      modeLevels[i].id = i + 1;
    }
    if (this.currentMode === '1' && LEVELS !== modeLevels) {
      for (let i = 0; i < LEVELS.length; i++) {
        LEVELS[i].id = i + 1;
      }
    }
    
    this.editingTemplateIndex = newIndex;
    localStorage.setItem(`rule_glyph_editing_template_index_${this.currentMode}`, newIndex.toString());
    
    // Reset chapter filter to ensure the new level is visible
    this.uiManager.editorChapterSelect.value = '0';
    this.uiManager.populateEditorLevelSelect();
    this.uiManager.syncEditorTemplateSelection(newIndex);
    
    // Load it
    this.handleLoadEditorTemplate(newIndex);
  }

  handleDeleteLevel() {
    if (!this.isEditorMode) return;
    if (this.editingTemplateIndex === -1) {
      alert("Pilih salah satu level kampanye terlebih dahulu untuk dihapus!");
      AudioEngine.playFail();
      return;
    }
    
    const modeLevels = LEVELS_BY_MODE[this.currentMode] || LEVELS;
    if (modeLevels.length <= 1) {
      alert("Minimal harus ada 1 level dalam kampanye!");
      AudioEngine.playFail();
      return;
    }
    
    if (confirm(`Apakah Anda yakin ingin menghapus level "${modeLevels[this.editingTemplateIndex].name}"? Semua modifikasi Anda pada level ini akan dihapus permanen.`)) {
      const idx = this.editingTemplateIndex;
      
      // Shift localStorage edits
      localStorage.removeItem(`rule_glyph_campaign_edit_${this.currentMode}_${idx}`);
      for (let i = idx + 1; i < modeLevels.length; i++) {
        const key = `rule_glyph_campaign_edit_${this.currentMode}_${i}`;
        const data = localStorage.getItem(key);
        if (data !== null) {
          localStorage.setItem(`rule_glyph_campaign_edit_${this.currentMode}_${i - 1}`, data);
          localStorage.removeItem(key);
        } else {
          localStorage.removeItem(`rule_glyph_campaign_edit_${this.currentMode}_${i - 1}`);
        }
      }
      
      // Delete in memory (cache index in LEVELS first before splicing)
      const globalIdx = (this.currentMode === '1' && LEVELS !== modeLevels)
        ? LEVELS.indexOf(modeLevels[idx])
        : -1;
      
      modeLevels.splice(idx, 1);
      if (globalIdx !== -1) {
        LEVELS.splice(globalIdx, 1);
      }
      
      // Re-index all levels sequentially
      for (let i = 0; i < modeLevels.length; i++) {
        modeLevels[i].id = i + 1;
      }
      if (this.currentMode === '1' && LEVELS !== modeLevels) {
        for (let i = 0; i < LEVELS.length; i++) {
          LEVELS[i].id = i + 1;
        }
      }
      
      // Adjust editing template selection
      const newIndex = Math.max(0, idx - 1);
      this.editingTemplateIndex = newIndex;
      localStorage.setItem(`rule_glyph_editing_template_index_${this.currentMode}`, newIndex.toString());
      
      // Reset chapter filter
      this.uiManager.editorChapterSelect.value = '0';
      this.uiManager.populateEditorLevelSelect();
      this.uiManager.syncEditorTemplateSelection(newIndex);
      
      // Load the selected template
      this.handleLoadEditorTemplate(newIndex);
    }
  }

  handleLevelInfoChanged(name, desc) {
    if (!this.isEditorMode || this.editingTemplateIndex === -1) return;
    
    if (this.editorLevelData) {
      this.editorLevelData.name = name;
      this.editorLevelData.description = desc;
    }
    
    const modeLevels = LEVELS_BY_MODE[this.currentMode] || LEVELS;
    const level = modeLevels[this.editingTemplateIndex];
    if (level) {
      level.name = name;
      level.description = desc;
      
      // Dynamically update dropdown option text
      const option = this.uiManager.editorLevelSelect.querySelector(`option[value="${this.editingTemplateIndex}"]`);
      if (option) {
        option.textContent = `Level ${level.id}: ${name}`;
      }
    }
    
    this.autoSaveEditorState();
  }

  handleCreateChapter(name) {
    if (!this.isEditorMode || this.currentMode !== '1') return;

    // margin calculation: Math.max(0, 7 - EXTRA_CHAPTERS.length)
    const margin = Math.max(0, 7 - EXTRA_CHAPTERS.length);
    const newChapter = { title: name, margin: margin };
    EXTRA_CHAPTERS.push(newChapter);

    // Clone 12 advanced levels to append to LEVELS
    const modeLevels = LEVELS_BY_MODE[this.currentMode] || LEVELS;
    const baseLevelsList = modeLevels.slice(10, 22); // ADVANCED_LEVELS are index 10 to 21 (12 levels)

    const newLevels = baseLevelsList.map((base, baseIndex) => {
      // Create new level layout
      const newLvl = this.createEmptyEditorLevel(base.width, base.height, base.movesLimit);
      newLvl.name = `${name} ${baseIndex + 1}`;
      newLvl.description = `Tantangan bab ${name}.`;
      newLvl.initialRules = { ...base.initialRules };
      newLvl.allowedRules = cloneAllowedRules(base.allowedRules);
      return newLvl;
    });

    // Push new levels to modeLevels
    newLevels.forEach(newLvl => {
      modeLevels.push(newLvl);
    });

    if (LEVELS !== modeLevels) {
      newLevels.forEach(newLvl => {
        LEVELS.push(newLvl);
      });
    }

    // Re-index all levels sequentially
    for (let i = 0; i < modeLevels.length; i++) {
      modeLevels[i].id = i + 1;
    }
    if (LEVELS !== modeLevels) {
      for (let i = 0; i < LEVELS.length; i++) {
        LEVELS[i].id = i + 1;
      }
    }

    // Update active editing index to the first level of the new chapter
    const firstLevelOfNewChapterIdx = modeLevels.length - 12;
    this.editingTemplateIndex = firstLevelOfNewChapterIdx;
    localStorage.setItem(`rule_glyph_editing_template_index_${this.currentMode}`, firstLevelOfNewChapterIdx.toString());

    // Re-populate selects
    this.uiManager.populateChapterSelects();
    // Select the new chapter
    const newChapterId = 1 + EXTRA_CHAPTERS.length; // 1-based chapter ID for the new chapter
    this.uiManager.editorChapterSelect.value = newChapterId.toString();
    this.uiManager.populateEditorLevelSelect();
    this.uiManager.syncEditorTemplateSelection(firstLevelOfNewChapterIdx);

    // Load it
    this.handleLoadEditorTemplate(firstLevelOfNewChapterIdx);

    // Save to disk
    this.autoSaveEditorState();
  }

  handleChapterInfoChanged() {
    this.autoSaveEditorState();
  }

  handleDeleteChapter(chapId) {
    if (!this.isEditorMode || this.currentMode !== '1') return;
    const modeLevels = LEVELS_BY_MODE[this.currentMode] || LEVELS;
    
    // Chapter 1 is base (22 levels). Subsequent chapters are 12 levels each.
    const startIdx = 22 + (chapId - 2) * 12;
    if (startIdx >= modeLevels.length) {
      alert("Error: Bab ini tidak memiliki level!");
      return;
    }
    
    // Shift localStorage edits down by 12 starting from startIdx
    for (let i = startIdx; i < startIdx + 12; i++) {
      localStorage.removeItem(`rule_glyph_campaign_edit_${this.currentMode}_${i}`);
    }
    
    for (let i = startIdx + 12; i < modeLevels.length; i++) {
      const oldKey = `rule_glyph_campaign_edit_${this.currentMode}_${i}`;
      const newKey = `rule_glyph_campaign_edit_${this.currentMode}_${i - 12}`;
      const data = localStorage.getItem(oldKey);
      if (data !== null) {
        localStorage.setItem(newKey, data);
        localStorage.removeItem(oldKey);
      } else {
        localStorage.removeItem(newKey);
      }
    }
    
    // Splicing out the 12 levels from LEVELS database
    modeLevels.splice(startIdx, 12);
    if (LEVELS !== modeLevels) {
      LEVELS.splice(startIdx, 12);
    }
    
    // Splicing the chapter out of EXTRA_CHAPTERS
    EXTRA_CHAPTERS.splice(chapId - 2, 1);
    
    // Re-adjust template indices for levels sequentially
    for (let i = 0; i < modeLevels.length; i++) {
      modeLevels[i].id = i + 1;
    }
    if (LEVELS !== modeLevels) {
      for (let i = 0; i < LEVELS.length; i++) {
        LEVELS[i].id = i + 1;
      }
    }
    
    // Reset selection index to the start of the chapter index (or previous valid)
    const newIdx = Math.max(0, startIdx - 1);
    this.editingTemplateIndex = newIdx;
    localStorage.setItem(`rule_glyph_editing_template_index_${this.currentMode}`, newIdx.toString());
    
    // Re-populate and sync
    this.uiManager.editorChapterSelect.value = '0'; // reset to Semua Bab
    this.uiManager.populateChapterSelects();
    this.uiManager.populateEditorLevelSelect();
    this.uiManager.syncEditorTemplateSelection(newIdx);
    this.handleLoadEditorTemplate(newIdx);
    
    // Save to disk
    this.autoSaveEditorState();
  }

  /**
   * Serialize editor state and write to localStorage
   */
  autoSaveEditorState() {
    if (!this.isEditorMode) return;
    
    const steps = parseInt(this.uiManager.editorStepsInput.value, 10) || 15;
    const data = this.gridEngine.serializeLevelData(steps);
    data.initialRules = { ...this.activeRules };
    data.allowedRules = cloneAllowedRules(this.allowedRules);
    data.campaignVersion = CAMPAIGN_VERSION;
    
    if (this.editorLevelData) {
      // Enforce correct sequential 1-based ID when autosaving
      data.id = this.editingTemplateIndex !== -1 ? (this.editingTemplateIndex + 1) : 1;
      this.editorLevelData.id = data.id;
      if (this.editorLevelData.name !== undefined) data.name = this.editorLevelData.name;
      if (this.editorLevelData.description !== undefined) data.description = this.editorLevelData.description;
    }
    
    for (let i = 0; i <= 6; i++) {
      if (this.editorLevelData && this.editorLevelData[`custom_wall_${i}`] !== undefined) {
        data[`custom_wall_${i}`] = this.editorLevelData[`custom_wall_${i}`];
      }
      if (this.editorLevelData && this.editorLevelData[`custom_floor_${i}`] !== undefined) {
        data[`custom_floor_${i}`] = this.editorLevelData[`custom_floor_${i}`];
      }
    }
    if (this.editorLevelData && this.editorLevelData.custom_floor !== undefined) {
      data.custom_floor = this.editorLevelData.custom_floor;
    }
    
    localStorage.setItem(`rule_glyph_editor_level_data_${this.currentMode}`, JSON.stringify(data));
    localStorage.setItem(`rule_glyph_editing_template_index_${this.currentMode}`, this.editingTemplateIndex.toString());
    
    if (this.editingTemplateIndex !== -1) {
      localStorage.setItem(`rule_glyph_campaign_edit_${this.currentMode}_${this.editingTemplateIndex}`, JSON.stringify(data));
    }

    this.scheduleDiskAutosave();
  }

  cleanLevelForExport(levelData, fallback, fallbackIndex) {
    const base = fallback || {};
    const merged = { ...base, ...(levelData || {}) };
    const cleaned = {
      id: fallbackIndex + 1,
      name: merged.name || base.name || `Level ${fallbackIndex + 1}`,
      description: merged.description || base.description || 'Capai portal dengan memanipulasi aturan.',
      width: merged.width,
      height: merged.height,
      movesLimit: merged.movesLimit,
      initialRules: { ...DEFAULT_RULES, ...(merged.initialRules || {}) },
      allowedRules: cloneAllowedRules(merged.allowedRules),
      map: Array.isArray(merged.map) ? [...merged.map] : []
    };
    for (let i = 0; i <= 6; i++) {
      if (merged[`custom_wall_${i}`] !== undefined) {
        cleaned[`custom_wall_${i}`] = merged[`custom_wall_${i}`];
      }
      if (merged[`custom_floor_${i}`] !== undefined) {
        cleaned[`custom_floor_${i}`] = merged[`custom_floor_${i}`];
      }
    }
    if (merged.custom_floor !== undefined) {
      cleaned.custom_floor = merged.custom_floor;
    }
    if (merged.custom_floor_map !== undefined) {
      cleaned.custom_floor_map = merged.custom_floor_map;
    }
    return cleaned;
  }

  getStoredCampaignLevel(mode, index, fallback) {
    const stored = localStorage.getItem(`rule_glyph_campaign_edit_${mode}_${index}`);
    if (!stored) {
      return this.cleanLevelForExport(fallback, fallback, index);
    }

    try {
      const parsed = JSON.parse(stored);
      if (parsed.campaignVersion !== CAMPAIGN_VERSION) {
        return this.cleanLevelForExport(fallback, fallback, index);
      }

      return this.cleanLevelForExport(parsed, fallback, index);
    } catch (e) {
      console.warn('Failed to export saved campaign edit', e);
      return this.cleanLevelForExport(fallback, fallback, index);
    }
  }

  buildCampaignJsonExport() {
    const levelsByMode = {};

    for (const mode of ['1', '2', '3', '4']) {
      const source = LEVELS_BY_MODE[mode] || (mode === '1' ? LEVELS : []);
      levelsByMode[mode] = source.map((level, index) =>
        this.getStoredCampaignLevel(mode, index, level)
      );
    }

    const payloadChapters = [
      { title: CHAPTER_1_TITLE, margin: 0 },
      ...EXTRA_CHAPTERS
    ];

    return {
      chapters: payloadChapters,
      base_levels: levelsByMode['1'].slice(0, BASE_LEVEL_COUNT),
      levels_by_mode: levelsByMode,
      custom_wall_image: localStorage.getItem('rule_glyph_custom_wall_image') || ""
    };
  }

  scheduleDiskAutosave() {
    if (this.diskAutosaveTimerId) {
      window.clearTimeout(this.diskAutosaveTimerId);
    }

    this.diskAutosaveTimerId = window.setTimeout(() => {
      this.diskAutosaveTimerId = null;
      this.autosaveCampaignToDisk();
    }, 600);
    this.uiManager.setEditorSaveStatus('saving', 'SAVING…');
  }

  async autosaveCampaignToDisk() {
    const payload = this.buildCampaignJsonExport();

    try {
      const response = await fetch('/__autosave_levels', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }

      const result = await response.json();
      this.applyServerTextureSanitization(result.removedLogoFloors);
      console.log(`Autosaved Android JSON: ${result.soloLevels || 0} solo levels.`);
      this.diskAutosaveWarningShown = false;
      this.uiManager.setEditorSaveStatus('saved', 'ANDROID JSON SAVED');
    } catch (e) {
      this.uiManager.setEditorSaveStatus('error', 'AUTOSAVE OFFLINE');
      if (!this.diskAutosaveWarningShown) {
        this.diskAutosaveWarningShown = true;
        console.warn('Disk autosave is unavailable. Run run_web.bat with Dart so Android JSON can be updated automatically.', e);
      }
    }
  }

  applyServerTextureSanitization(entries) {
    if (!Array.isArray(entries) || entries.length === 0) return;

    let reloadActiveLevel = false;
    entries.forEach((entry) => {
      const mode = String(entry.mode);
      const index = Number(entry.index);
      const field = String(entry.field);
      if (!/^custom_floor(?:_[0-6])?$/.test(field) || !Number.isInteger(index)) return;

      const sourceLevel = LEVELS_BY_MODE[mode]?.[index];
      if (sourceLevel) sourceLevel[field] = null;

      const storageKey = `rule_glyph_campaign_edit_${mode}_${index}`;
      try {
        const stored = localStorage.getItem(storageKey);
        if (stored) {
          const level = JSON.parse(stored);
          level[field] = null;
          localStorage.setItem(storageKey, JSON.stringify(level));
        }
      } catch (error) {
        console.warn('Failed to clean sanitized floor texture from local storage', error);
      }

      if (mode === this.currentMode && index === this.editingTemplateIndex && this.editorLevelData) {
        this.editorLevelData[field] = null;
        reloadActiveLevel = true;
      }
    });

    if (reloadActiveLevel) {
      localStorage.setItem(
        `rule_glyph_editor_level_data_${this.currentMode}`,
        JSON.stringify(this.editorLevelData)
      );
      this.gridEngine.loadLevel(this.editorLevelData);
    }
  }

  /**
   * Keyboard control mappings listener
   */
  initKeyboard() {
    window.addEventListener('keydown', (e) => {
      // Disable movement controls if user is interacting with text inputs or help modals are active
      if (document.querySelectorAll('.modal-overlay.active').length > 0) {
        if (e.key === 'Escape') {
          // Close all open modals on Escape key
          document.querySelectorAll('.modal-overlay.active').forEach(modal => {
            modal.classList.remove('active');
          });
        }
        return;
      }
      
      // Block controls during bot autoplay
      if (this.isAutoplayActive) return;
      
      // Focus check: in editor mode, don't execute moves via keyboard arrows if we are editing text inputs
      if (this.isEditorMode && document.activeElement && document.activeElement.tagName === 'INPUT') {
        return;
      }

      switch (e.key) {
        case 'w':
        case 'W':
          e.preventDefault();
          if (!this.isEditorMode) this.executeMove(0, -1, 'p1');
          break;
        case 's':
        case 'S':
          e.preventDefault();
          if (!this.isEditorMode) this.executeMove(0, 1, 'p1');
          break;
        case 'a':
        case 'A':
          e.preventDefault();
          if (!this.isEditorMode) this.executeMove(-1, 0, 'p1');
          break;
        case 'd':
        case 'D':
          e.preventDefault();
          if (!this.isEditorMode) this.executeMove(1, 0, 'p1');
          break;
        case 'ArrowUp':
          e.preventDefault();
          if (!this.isEditorMode) {
            const hasP2 = this.gridEngine.getPlayer('p2').x !== -1;
            this.executeMove(0, -1, hasP2 ? 'p2' : 'p1');
          }
          break;
        case 'ArrowDown':
          e.preventDefault();
          if (!this.isEditorMode) {
            const hasP2 = this.gridEngine.getPlayer('p2').x !== -1;
            this.executeMove(0, 1, hasP2 ? 'p2' : 'p1');
          }
          break;
        case 'ArrowLeft':
          e.preventDefault();
          if (!this.isEditorMode) {
            const hasP2 = this.gridEngine.getPlayer('p2').x !== -1;
            this.executeMove(-1, 0, hasP2 ? 'p2' : 'p1');
          }
          break;
        case 'ArrowRight':
          e.preventDefault();
          if (!this.isEditorMode) {
            const hasP2 = this.gridEngine.getPlayer('p2').x !== -1;
            this.executeMove(1, 0, hasP2 ? 'p2' : 'p1');
          }
          break;
        
        // Player 3 (IJKL)
        case 'i':
        case 'I':
          e.preventDefault();
          if (!this.isEditorMode) {
            const hasP3 = this.gridEngine.getPlayer('p3').x !== -1;
            this.executeMove(0, -1, hasP3 ? 'p3' : 'p1');
          }
          break;
        case 'k':
        case 'K':
          e.preventDefault();
          if (!this.isEditorMode) {
            const hasP3 = this.gridEngine.getPlayer('p3').x !== -1;
            this.executeMove(0, 1, hasP3 ? 'p3' : 'p1');
          }
          break;
        case 'j':
        case 'J':
          e.preventDefault();
          if (!this.isEditorMode) {
            const hasP3 = this.gridEngine.getPlayer('p3').x !== -1;
            this.executeMove(-1, 0, hasP3 ? 'p3' : 'p1');
          }
          break;
        case 'l':
        case 'L':
          e.preventDefault();
          if (!this.isEditorMode) {
            const hasP3 = this.gridEngine.getPlayer('p3').x !== -1;
            this.executeMove(1, 0, hasP3 ? 'p3' : 'p1');
          }
          break;

        // Player 4 (TFGH)
        case 't':
        case 'T':
          e.preventDefault();
          if (!this.isEditorMode) {
            const hasP4 = this.gridEngine.getPlayer('p4').x !== -1;
            this.executeMove(0, -1, hasP4 ? 'p4' : 'p1');
          }
          break;
        case 'g':
        case 'G':
          e.preventDefault();
          if (!this.isEditorMode) {
            const hasP4 = this.gridEngine.getPlayer('p4').x !== -1;
            this.executeMove(0, 1, hasP4 ? 'p4' : 'p1');
          }
          break;
        case 'f':
        case 'F':
          e.preventDefault();
          if (!this.isEditorMode) {
            const hasP4 = this.gridEngine.getPlayer('p4').x !== -1;
            this.executeMove(-1, 0, hasP4 ? 'p4' : 'p1');
          }
          break;
        case 'h':
        case 'H':
          e.preventDefault();
          if (!this.isEditorMode) {
            const hasP4 = this.gridEngine.getPlayer('p4').x !== -1;
            this.executeMove(1, 0, hasP4 ? 'p4' : 'p1');
          }
          break;
        case 'z':
        case 'Z':
          // Ctrl+Z or standalone Z to undo
          e.preventDefault();
          if (!this.isEditorMode) this.handleUndo();
          break;
        case 'r':
        case 'R':
          e.preventDefault();
          if (!this.isEditorMode) this.handleReset();
          break;
      }
    });
  }

  /**
   * Mobile touch swipe guesture mappings listener
   */
  initSwipe() {
    const board = document.getElementById('game-board');
    let startX = 0;
    let startY = 0;
    
    board.addEventListener('touchstart', (e) => {
      startX = e.touches[0].clientX;
      startY = e.touches[0].clientY;
    }, { passive: true });
    
    board.addEventListener('touchend', (e) => {
      if (this.isEditorMode || this.isAutoplayActive) return;
      if (!this.isGameActive || this.gridEngine.hasAnyPlayerDead()) return;
      
      const deltaX = e.changedTouches[0].clientX - startX;
      const deltaY = e.changedTouches[0].clientY - startY;
      
      const threshold = 30; // Min drag distance in pixels
      
      if (Math.max(Math.abs(deltaX), Math.abs(deltaY)) < threshold) return;
      
      if (Math.abs(deltaX) > Math.abs(deltaY)) {
        // Horizontal move
        if (deltaX > 0) {
          this.executeMove(1, 0);
        } else {
          this.executeMove(-1, 0);
        }
      } else {
        // Vertical move
        if (deltaY > 0) {
          this.executeMove(0, 1);
        } else {
          this.executeMove(0, -1);
        }
      }
    }, { passive: true });
  }
}

// Start Game on window load
window.addEventListener('DOMContentLoaded', async () => {
  try {
    await loadLevels();
  } catch (err) {
    console.error("Failed to load levels JSON:", err);
  }
  new GameController();
});
