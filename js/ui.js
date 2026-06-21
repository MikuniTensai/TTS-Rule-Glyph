/**
 * UI and Interface Manager for Rule Glyph Lab (Editor & Solver Enabled)
 */

import { AudioEngine } from './audio.js';
import { GLYPH_DETAILS } from './rules.js';
import { LEVELS, LEVELS_BY_MODE, validateLevelData, EXTRA_CHAPTERS, CHAPTER_1_TITLE, setChapter1Title } from './levels.js?v=1.0.6';

const safeStorage = {
  getItem(key) {
    try {
      return localStorage.getItem(key);
    } catch (e) {
      return null;
    }
  },
  setItem(key, value) {
    try {
      localStorage.setItem(key, value);
    } catch (e) {}
  },
  removeItem(key) {
    try {
      localStorage.removeItem(key);
    } catch (e) {}
  }
};

export class UIManager {
  constructor(callbacks) {
    this.callbacks = callbacks; 
    // callbacks: { onRuleChanged, onLevelSelected, onUndo, onReset, onNextLevel, onToggleEditor, onGridResize, onCellPainted, onTestLevel, onSolveLevel, onExportLevel, onImportLevel, onAutoplay }
    
    // Core HTML nodes cache
    this.gameBoardDom = document.getElementById('game-board');
    this.movesCounterDom = document.getElementById('moves-counter');
    this.movesDisplayDom = document.getElementById('moves-display');
    this.levelDisplayDom = document.getElementById('level-display');
    this.btnUndo = document.getElementById('btn-undo');
    this.btnReset = document.getElementById('btn-reset');
    this.btnMute = document.getElementById('btn-mute');
    
    // Editor controls
    this.btnEditorToggle = document.getElementById('btn-options-editor');
    this.btnHome = document.getElementById('btn-home');
    this.editorPanel = document.getElementById('editor-panel');
    this.editorSaveStatus = document.getElementById('editor-save-status');
    this.ruleLabPanel = document.querySelector('.rule-lab:not(#editor-panel)');
    this.gameContainer = document.querySelector('.game-container');
    this.analogControlPanel = document.getElementById('analog-control-panel');
    this.editorColsInput = document.getElementById('editor-cols');
    this.editorRowsInput = document.getElementById('editor-rows');
    this.editorStepsInput = document.getElementById('editor-steps');
    this.btnEditorTest = document.getElementById('btn-editor-test');
    this.btnEditorSolve = document.getElementById('btn-editor-solve');
    this.btnEditorExport = document.getElementById('btn-editor-export');
    this.btnEditorImport = document.getElementById('btn-editor-import');
    this.editorLevelSelect = document.getElementById('editor-level-select');
    this.btnEditorResetCampaign = document.getElementById('btn-editor-reset-campaign');
    
    // Chapter filters
    this.playChapterFilterContainer = document.getElementById('play-chapter-filter-container');
    this.playChapterSelect = document.getElementById('play-chapter-select');
    this.editorChapterSelect = document.getElementById('editor-chapter-select');
    this.editorChapterNameInput = document.getElementById('editor-chapter-name-input');
    
    // Level info inputs
    this.editorLevelName = document.getElementById('editor-level-name');
    this.editorLevelDesc = document.getElementById('editor-level-desc');
    
    // Level create/delete buttons
    this.btnEditorCreateLevel = document.getElementById('btn-editor-create-level');
    this.btnEditorDeleteLevel = document.getElementById('btn-editor-delete-level');
    this.btnEditorCreateChapter = document.getElementById('btn-editor-create-chapter');
    this.btnEditorRenameChapter = document.getElementById('btn-editor-rename-chapter');
    this.btnEditorDeleteChapter = document.getElementById('btn-editor-delete-chapter');
    
    // Editor allowed rules checkboxes
    this.chkAllowRedPush = document.getElementById('chk-allow-red-push');
    this.chkAllowRedSwap = document.getElementById('chk-allow-red-swap');
    this.chkAllowRedMerge = document.getElementById('chk-allow-red-merge');
    this.chkAllowBluePush = document.getElementById('chk-allow-blue-push');
    this.chkAllowBlueSwap = document.getElementById('chk-allow-blue-swap');
    this.chkAllowBlueMerge = document.getElementById('chk-allow-blue-merge');
    this.chkAllowGreenPush = document.getElementById('chk-allow-green-push');
    this.chkAllowGreenSwap = document.getElementById('chk-allow-green-swap');
    this.chkAllowGreenMerge = document.getElementById('chk-allow-green-merge');
    
    // Modals
    this.modalHelp = document.getElementById('modal-help');
    this.modalLevels = document.getElementById('modal-levels');
    this.modalWin = document.getElementById('modal-win');
    this.modalFail = document.getElementById('modal-fail');
    this.modalImport = document.getElementById('modal-import');
    this.modalExport = document.getElementById('modal-export');
    this.modalFinished = document.getElementById('modal-finished');
    this.modalOptions = document.getElementById('modal-options');
    this.modalCredits = document.getElementById('modal-credits');
    
    // Import/Export areas
    this.importArea = document.getElementById('import-json-area');
    this.importErrorMsg = document.getElementById('import-error-msg');
    this.exportArea = document.getElementById('export-json-area');
    
    // Solver readout nodes
    this.solverResultPanel = document.getElementById('solver-result-panel');
    this.solverStatusText = document.getElementById('solver-status-text');
    this.btnSolverAutoplay = document.getElementById('btn-solver-autoplay');
    
    // Level Select Grid
    this.levelGrid = document.getElementById('level-select-grid');
    
    this.activeBrush = 'clear';
    this.isDrawing = false;
    this.lastPaintedCell = null; // To avoid redundant drawings in drag
    
    this.initMuteState();
    this.populateChapterSelects();
    this.populateEditorLevelSelect();
    const finishedLevelCount = document.getElementById('finished-level-count');
    if (finishedLevelCount) {
      finishedLevelCount.textContent = LEVELS.length;
    }
    
    // Load and apply custom wall image if exists
    const customWall = safeStorage.getItem('rule_glyph_custom_wall_image');
    this.applyCustomWallImage(customWall);
    
    this.bindEvents();
  }

  /**
   * Build the editor campaign selector from the current level database.
   */
  getChaptersList(mode) {
    if (mode !== '1') {
      return [{ id: 1, name: 'Co-Op Mode' }];
    }
    const list = [
      { id: 0, name: 'Semua Bab' },
      { id: 1, name: CHAPTER_1_TITLE }
    ];
    EXTRA_CHAPTERS.forEach((ch, idx) => {
      list.push({ id: 2 + idx, name: ch.title });
    });
    return list;
  }

  getChapterOfLevel(index) {
    if (index < 22) {
      return 1; // Bab 1
    }
    const advIndex = index - 22;
    const chapterIdx = Math.floor(advIndex / 12);
    return Math.min(2 + chapterIdx, 1 + EXTRA_CHAPTERS.length);
  }

  applyCustomWallImage(base64) {
    if (base64) {
      document.documentElement.style.setProperty('--custom-wall-image', `url(${base64})`);
      document.body.classList.add('has-custom-wall');
    } else {
      document.documentElement.style.removeProperty('--custom-wall-image');
      document.body.classList.remove('has-custom-wall');
    }
  }

  populateChapterSelects() {
    const activeMode = this.callbacks.getActiveMode ? this.callbacks.getActiveMode() : '1';
    const chapters = this.getChaptersList(activeMode);
    
    // Populate editor chapter select
    const prevEditorChapter = this.editorChapterSelect.value;
    this.editorChapterSelect.innerHTML = '';
    chapters.forEach(c => {
      const option = document.createElement('option');
      option.value = c.id;
      option.textContent = c.name;
      this.editorChapterSelect.appendChild(option);
    });
    if (activeMode === '1') {
      this.editorChapterSelect.value = prevEditorChapter && [...this.editorChapterSelect.options].some(o => o.value === prevEditorChapter)
        ? prevEditorChapter
        : '0'; // default: Semua Bab
    } else {
      this.editorChapterSelect.value = '1';
    }
    
    // Populate play chapter select
    const prevPlayChapter = this.playChapterSelect.value;
    this.playChapterSelect.innerHTML = '';
    chapters.forEach(c => {
      const option = document.createElement('option');
      option.value = c.id;
      option.textContent = c.name;
      this.playChapterSelect.appendChild(option);
    });
    
    if (activeMode === '1') {
      this.playChapterSelect.value = prevPlayChapter && [...this.playChapterSelect.options].some(o => o.value === prevPlayChapter)
        ? prevPlayChapter
        : '0'; // default: Semua Bab
      this.playChapterFilterContainer.style.display = 'flex';
    } else {
      this.playChapterSelect.value = '1';
      this.playChapterFilterContainer.style.display = 'none';
    }
  }

  populateEditorLevelSelect() {
    this.editorLevelSelect.innerHTML = '';

    const placeholder = document.createElement('option');
    placeholder.value = '';
    placeholder.disabled = true;
    placeholder.selected = true;
    placeholder.textContent = '-- Select level to edit --';
    this.editorLevelSelect.appendChild(placeholder);

    const activeMode = this.callbacks.getActiveMode ? this.callbacks.getActiveMode() : '1';
    const modeLevels = LEVELS_BY_MODE[activeMode] || LEVELS;
    const selectedChapter = this.editorChapterSelect ? parseInt(this.editorChapterSelect.value, 10) || 0 : 0;

    modeLevels.forEach((level, index) => {
      if (activeMode === '1' && selectedChapter !== 0) {
        const chap = this.getChapterOfLevel(index);
        if (chap !== selectedChapter) return;
      }
      
      const option = document.createElement('option');
      option.value = index;
      option.textContent = `Level ${level.id}: ${level.name}`;
      this.editorLevelSelect.appendChild(option);
    });
  }

  /**
   * Synchronize active class state across all mode select tab controls
   */
  syncModeUI(mode) {
    document.querySelectorAll('.mode-tab').forEach(t => {
      t.classList.toggle('active', t.dataset.mode === mode);
    });
    document.querySelectorAll('.editor-mode-tab').forEach(t => {
      t.classList.toggle('active', t.dataset.mode === mode);
    });
  }

  /**
   * Read and set initial sound mute UI
   */
  initMuteState() {
    const isMuted = AudioEngine.isMuted();
    this.btnMute.innerHTML = isMuted ? '🔇' : '🔊';
  }

  /**
   * Bind event listeners for UI buttons and grid canvas painting
   */
  bindEvents() {
    // Sound Toggle
    this.btnMute.addEventListener('click', () => {
      const isMuted = AudioEngine.toggleMute();
      this.btnMute.innerHTML = isMuted ? '🔇' : '🔊';
      AudioEngine.playRuleChange();
    });

    // Help Button
    document.getElementById('btn-help').addEventListener('click', () => {
      this.showModal(this.modalHelp);
      AudioEngine.playRuleChange();
    });
    document.getElementById('btn-close-help').addEventListener('click', () => {
      this.hideModal(this.modalHelp);
      AudioEngine.playRuleChange();
    });

    // Level Select Menu
    document.getElementById('btn-levels-menu').addEventListener('click', () => {
      this.populateLevelsMenu();
      this.showModal(this.modalLevels);
      AudioEngine.playRuleChange();
    });
    document.getElementById('btn-close-levels').addEventListener('click', () => {
      this.hideModal(this.modalLevels);
      AudioEngine.playRuleChange();
    });

    // Mode tabs event listeners
    document.querySelectorAll('.mode-tab').forEach(tab => {
      tab.addEventListener('click', () => {
        const mode = tab.dataset.mode;
        this.syncModeUI(mode);
        AudioEngine.playRuleChange();
        this.callbacks.onModeChanged(mode);
        this.populateChapterSelects();
        this.populateLevelsMenu();
        this.populateEditorLevelSelect();
      });
    });

    // Editor Mode tabs event listeners
    document.querySelectorAll('.editor-mode-tab').forEach(tab => {
      tab.addEventListener('click', () => {
        const mode = tab.dataset.mode;
        this.syncModeUI(mode);
        AudioEngine.playRuleChange();
        this.callbacks.onModeChanged(mode);
        this.populateChapterSelects();
        this.populateLevelsMenu();
        this.populateEditorLevelSelect();
      });
    });

    // Undo & Reset Action buttons
    this.btnUndo.addEventListener('click', () => this.callbacks.onUndo());
    this.btnReset.addEventListener('click', () => this.callbacks.onReset());

    // Fail Screen Actions
    document.getElementById('btn-fail-undo').addEventListener('click', () => {
      this.hideModal(this.modalFail);
      document.getElementById('board-container').classList.remove('shake-glitch');
      this.callbacks.onUndo();
    });
    document.getElementById('btn-fail-retry').addEventListener('click', () => {
      this.hideModal(this.modalFail);
      document.getElementById('board-container').classList.remove('shake-glitch');
      this.callbacks.onReset();
    });

    // Success Screen Next button
    document.getElementById('btn-next-level').addEventListener('click', () => {
      this.hideModal(this.modalWin);
      this.callbacks.onNextLevel();
    });

    // Rule Lab Config Option buttons
    document.querySelectorAll('.rules-options').forEach(optionContainer => {
      const glyphColor = optionContainer.dataset.glyph;
      optionContainer.querySelectorAll('.rule-opt').forEach(btn => {
        btn.addEventListener('click', () => {
          const ruleType = btn.dataset.rule;
          this.setRuleOptionActive(glyphColor, ruleType);
          AudioEngine.playRuleChange();
          this.callbacks.onRuleChanged(glyphColor, ruleType);
        });
      });
    });

    // ==========================================
    // EDITOR BINDINGS
    // ==========================================

    // Toggle Editor Mode
    if (this.btnEditorToggle) {
      this.btnEditorToggle.addEventListener('click', () => {
        this.hideModal(this.modalOptions);
        AudioEngine.playRuleChange();
        this.callbacks.onToggleEditor();
      });
    }

    // Select chapter filters
    this.playChapterSelect.addEventListener('change', () => {
      AudioEngine.playRuleChange();
      this.populateLevelsMenu();
    });

    this.editorChapterSelect.addEventListener('change', () => {
      AudioEngine.playRuleChange();
      this.populateEditorLevelSelect();
    });

    if (this.btnEditorCreateChapter) {
      const toggleCreateChapterInput = (show) => {
        if (show) {
          this.editorChapterSelect.style.display = 'none';
          this.editorChapterNameInput.style.display = 'inline-block';
          this.editorChapterNameInput.value = '';
          this.editorChapterNameInput.focus();
          this.btnEditorCreateChapter.textContent = '✔️';
          this.btnEditorCreateChapter.title = 'Simpan Bab Baru';
        } else {
          this.editorChapterNameInput.style.display = 'none';
          this.editorChapterSelect.style.display = 'inline-block';
          this.btnEditorCreateChapter.textContent = '➕';
          this.btnEditorCreateChapter.title = 'Tambah Bab Baru';
        }
      };

      this.btnEditorCreateChapter.addEventListener('click', () => {
        const activeMode = this.callbacks.getActiveMode ? this.callbacks.getActiveMode() : '1';
        if (activeMode !== '1') {
          alert("Tambah bab hanya didukung di Mode 1 (Survival)!");
          AudioEngine.playFail();
          return;
        }

        // Safety check to limit chapters count to 9 (as allowed by pubspec.yaml asset mapping)
        if (EXTRA_CHAPTERS.length >= 8) {
          alert("Batas maksimal bab adalah 9! Tidak dapat menambah bab lagi.");
          AudioEngine.playFail();
          return;
        }

        const isInputVisible = this.editorChapterNameInput.style.display !== 'none';
        if (!isInputVisible) {
          toggleCreateChapterInput(true);
        } else {
          const val = this.editorChapterNameInput.value.trim();
          if (val !== "") {
            AudioEngine.playRuleChange();
            if (this.callbacks.onCreateChapter) {
              this.callbacks.onCreateChapter(val);
            }
            toggleCreateChapterInput(false);
          } else {
            toggleCreateChapterInput(false); // cancel on empty
          }
        }
      });

      this.editorChapterNameInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
          e.preventDefault();
          this.btnEditorCreateChapter.click();
        } else if (e.key === 'Escape') {
          e.preventDefault();
          toggleCreateChapterInput(false);
        }
      });
    }

    if (this.btnEditorRenameChapter) {
      this.btnEditorRenameChapter.addEventListener('click', () => {
        const activeMode = this.callbacks.getActiveMode ? this.callbacks.getActiveMode() : '1';
        if (activeMode !== '1') {
          alert("Ganti nama bab hanya didukung di Mode 1 (Survival)!");
          AudioEngine.playFail();
          return;
        }
        const val = parseInt(this.editorChapterSelect.value, 10) || 0;
        if (val === 0) {
          alert("Silakan pilih bab tertentu untuk diubah namanya!");
          AudioEngine.playFail();
          return;
        }
        const currentName = val === 1 ? CHAPTER_1_TITLE : EXTRA_CHAPTERS[val - 2].title;
        const newName = prompt("Masukkan nama baru untuk Bab ini:", currentName);
        if (newName && newName.trim() !== "") {
          AudioEngine.playRuleChange();
          if (val === 1) {
            setChapter1Title(newName.trim());
          } else {
            EXTRA_CHAPTERS[val - 2].title = newName.trim();
          }
          this.populateChapterSelects();
          this.editorChapterSelect.value = val;
          // Trigger save via callbacks
          if (this.callbacks.onChapterInfoChanged) {
            this.callbacks.onChapterInfoChanged();
          }
        }
      });
    }

    if (this.btnEditorDeleteChapter) {
      this.btnEditorDeleteChapter.addEventListener('click', () => {
        const activeMode = this.callbacks.getActiveMode ? this.callbacks.getActiveMode() : '1';
        if (activeMode !== '1') {
          alert("Hapus bab hanya didukung di Mode 1 (Survival)!");
          AudioEngine.playFail();
          return;
        }
        const val = parseInt(this.editorChapterSelect.value, 10) || 0;
        if (val === 0) {
          alert("Silakan pilih bab tertentu untuk dihapus!");
          AudioEngine.playFail();
          return;
        }
        if (val === 1) {
          alert("Bab 1 (Dasar & Mekanik) tidak dapat dihapus karena berisi level tutorial dasar!");
          AudioEngine.playFail();
          return;
        }
        const currentName = EXTRA_CHAPTERS[val - 2].title;
        if (confirm(`Apakah Anda yakin ingin menghapus "${currentName}" beserta seluruh level di dalamnya? Tindakan ini akan menghapus 12 level secara permanen!`)) {
          AudioEngine.playFail();
          if (this.callbacks.onDeleteChapter) {
            this.callbacks.onDeleteChapter(val);
          }
        }
      });
    }

    // Select level template to edit
    this.editorLevelSelect.addEventListener('change', () => {
      const val = this.editorLevelSelect.value;
      if (val !== "") {
        const idx = parseInt(val, 10);
        this.callbacks.onLoadEditorTemplate(idx);
      }
    });

    // Edit level name and description
    const handleInfoChanged = () => {
      this.callbacks.onLevelInfoChanged(this.editorLevelName.value, this.editorLevelDesc.value);
    };
    this.editorLevelName.addEventListener('input', handleInfoChanged);
    this.editorLevelDesc.addEventListener('input', handleInfoChanged);

    // Create and delete level actions
    this.btnEditorCreateLevel.addEventListener('click', () => {
      AudioEngine.playRuleChange();
      this.callbacks.onCreateLevel();
    });

    this.btnEditorDeleteLevel.addEventListener('click', () => {
      AudioEngine.playRuleChange();
      this.callbacks.onDeleteLevel();
    });

    // Reset campaign level to default configuration
    this.btnEditorResetCampaign.addEventListener('click', () => {
      AudioEngine.playRuleChange();
      this.callbacks.onResetCampaignEditor();
    });

    // Brushes selection
    document.querySelectorAll('.brush-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const selectedBrush = btn.dataset.brush;
        document.querySelectorAll('.brush-btn').forEach(b => {
          b.classList.toggle('active', b.dataset.brush === selectedBrush);
        });
        this.activeBrush = selectedBrush;
        AudioEngine.playRuleChange();
      });
    });

    // Inputs resize triggers
    const triggerResize = () => {
      const cols = Math.min(Math.max(parseInt(this.editorColsInput.value, 10) || 7, 3), 20);
      const rows = Math.min(Math.max(parseInt(this.editorRowsInput.value, 10) || 7, 3), 20);
      const steps = Math.min(Math.max(parseInt(this.editorStepsInput.value, 10) || 15, 5), 99);
      
      this.editorColsInput.value = cols;
      this.editorRowsInput.value = rows;
      this.editorStepsInput.value = steps;
      
      this.callbacks.onGridResize(cols, rows, steps);
    };
    this.editorColsInput.addEventListener('input', triggerResize);
    this.editorRowsInput.addEventListener('input', triggerResize);
    this.editorStepsInput.addEventListener('input', triggerResize);

    // Allowed rules checkboxes change triggers
    const triggerAllowedRulesChange = () => {
      this.callbacks.onAllowedRulesChanged();
    };
    [
      this.chkAllowRedPush, this.chkAllowRedSwap, this.chkAllowRedMerge,
      this.chkAllowBluePush, this.chkAllowBlueSwap, this.chkAllowBlueMerge,
      this.chkAllowGreenPush, this.chkAllowGreenSwap, this.chkAllowGreenMerge
    ].forEach(chk => {
      if (chk) {
        chk.addEventListener('change', triggerAllowedRulesChange);
      }
    });

    // Grid Drawing (Click & Drag painting)
    const handleDrawMove = (e) => {
      if (!this.isDrawing) return;
      const rect = this.gameBoardDom.getBoundingClientRect();
      const clientX = e.touches ? e.touches[0].clientX : e.clientX;
      const clientY = e.touches ? e.touches[0].clientY : e.clientY;
      
      const xOffset = clientX - rect.left;
      const yOffset = clientY - rect.top;
      
      // Calculate target grid coordinate
      const cellWidth = rect.width / this.callbacks.getGridWidth();
      const cellHeight = rect.height / this.callbacks.getGridHeight();
      const gridX = Math.floor(xOffset / cellWidth);
      const gridY = Math.floor(yOffset / cellHeight);
      
      const cellKey = `${gridX},${gridY}`;
      if (cellKey !== this.lastPaintedCell) {
        this.lastPaintedCell = cellKey;
        this.callbacks.onCellPainted(gridX, gridY, this.activeBrush);
      }
    };

    this.gameBoardDom.addEventListener('mousedown', (e) => {
      if (!this.gameBoardDom.classList.contains('editor-mode')) return;
      this.isDrawing = true;
      this.lastPaintedCell = null;
      handleDrawMove(e);
    });
    this.gameBoardDom.addEventListener('mousemove', handleDrawMove);
    window.addEventListener('mouseup', () => {
      this.isDrawing = false;
    });

    // Touch support for editor painting on mobile
    this.gameBoardDom.addEventListener('touchstart', (e) => {
      if (!this.gameBoardDom.classList.contains('editor-mode')) return;
      this.isDrawing = true;
      this.lastPaintedCell = null;
      handleDrawMove(e);
    }, { passive: true });
    this.gameBoardDom.addEventListener('touchmove', handleDrawMove, { passive: true });
    this.gameBoardDom.addEventListener('touchend', () => {
      this.isDrawing = false;
    });

    // Editor Play Test
    this.btnEditorTest.addEventListener('click', () => {
      AudioEngine.playRuleChange();
      this.callbacks.onTestLevel();
    });

    // Editor Solve Bot
    this.btnEditorSolve.addEventListener('click', () => {
      AudioEngine.playRuleChange();
      this.callbacks.onSolveLevel();
    });

    // Autoplay Bot Solution
    this.btnSolverAutoplay.addEventListener('click', () => {
      this.callbacks.onAutoplay();
    });

    // Export Level modal opens
    this.btnEditorExport.addEventListener('click', () => {
      AudioEngine.playRuleChange();
      const serialized = this.callbacks.onExportLevel();
      this.exportArea.value = JSON.stringify(serialized, null, 2);
      this.showModal(this.modalExport);
      this.exportArea.focus();
      this.exportArea.select();
    });
    document.getElementById('btn-close-export').addEventListener('click', () => {
      this.hideModal(this.modalExport);
      AudioEngine.playRuleChange();
    });
    document.getElementById('btn-copy-export').addEventListener('click', () => {
      navigator.clipboard.writeText(this.exportArea.value);
      const copyBtn = document.getElementById('btn-copy-export');
      copyBtn.textContent = 'COPIED!';
      AudioEngine.playUnlock();
      setTimeout(() => {
        copyBtn.textContent = 'Copy Code';
      }, 1500);
    });

    // Import Level modal opens
    this.btnEditorImport.addEventListener('click', () => {
      AudioEngine.playRuleChange();
      this.importArea.value = '';
      this.importErrorMsg.style.display = 'none';
      this.showModal(this.modalImport);
    });
    document.getElementById('btn-cancel-import').addEventListener('click', () => {
      this.hideModal(this.modalImport);
      AudioEngine.playRuleChange();
    });
    document.getElementById('btn-submit-import').addEventListener('click', () => {
      try {
        const data = JSON.parse(this.importArea.value);
        const activeMode = this.callbacks.getActiveMode ? this.callbacks.getActiveMode() : '1';
        validateLevelData(data, activeMode);
        AudioEngine.playUnlock();
        this.hideModal(this.modalImport);
        this.callbacks.onImportLevel(data);
      } catch (e) {
        this.importErrorMsg.textContent = e.message || 'JSON level tidak valid.';
        this.importErrorMsg.style.display = 'block';
        AudioEngine.playFail();
      }
    });
    
    // Finished Game Screen Actions
    document.getElementById('btn-finished-creator').addEventListener('click', () => {
      this.hideModal(this.modalFinished);
      AudioEngine.playRuleChange();
      this.callbacks.onToggleEditor();
    });
    document.getElementById('btn-finished-levels').addEventListener('click', () => {
      this.hideModal(this.modalFinished);
      AudioEngine.playRuleChange();
      this.populateLevelsMenu();
      this.showModal(this.modalLevels);
    });

    // Home button in play header
    if (this.btnHome) {
      this.btnHome.addEventListener('click', () => {
        AudioEngine.playRuleChange();
        this.callbacks.onGoToMainMenu();
      });
    }

    // Main Menu bindings
    const btnMenuSurvival = document.getElementById('btn-menu-survival');
    const btnMenuCoop2 = document.getElementById('btn-menu-coop2');
    const btnMenuCoop34 = document.getElementById('btn-menu-coop34');
    const btnMenuOptions = document.getElementById('btn-menu-options');
    const btnMenuCredits = document.getElementById('btn-menu-credits');

    if (btnMenuSurvival) {
      btnMenuSurvival.addEventListener('click', () => {
        AudioEngine.playRuleChange();
        this.callbacks.onSelectGameMode('1');
      });
    }
    if (btnMenuCoop2) {
      btnMenuCoop2.addEventListener('click', () => {
        AudioEngine.playRuleChange();
        this.callbacks.onSelectGameMode('2');
      });
    }
    if (btnMenuCoop34) {
      btnMenuCoop34.addEventListener('click', () => {
        AudioEngine.playRuleChange();
        this.showModal(document.getElementById('modal-coop-select'));
      });
    }
    if (btnMenuOptions) {
      btnMenuOptions.addEventListener('click', () => {
        AudioEngine.playRuleChange();
        const isMuted = AudioEngine.isMuted();
        document.getElementById('btn-options-mute').innerHTML = isMuted ? '🔇 Off' : '🔊 On';
        this.showModal(this.modalOptions);
      });
    }
    if (btnMenuCredits) {
      btnMenuCredits.addEventListener('click', () => {
        AudioEngine.playRuleChange();
        this.showModal(this.modalCredits);
      });
    }

    // Options Modal bindings
    const btnOptionsMute = document.getElementById('btn-options-mute');
    if (btnOptionsMute) {
      btnOptionsMute.addEventListener('click', () => {
        const isMuted = AudioEngine.toggleMute();
        btnOptionsMute.innerHTML = isMuted ? '🔇 Off' : '🔊 On';
        this.btnMute.innerHTML = isMuted ? '🔇' : '🔊';
        AudioEngine.playRuleChange();
      });
    }
    const btnCloseOptions = document.getElementById('btn-close-options');
    if (btnCloseOptions) {
      btnCloseOptions.addEventListener('click', () => {
        AudioEngine.playRuleChange();
        this.hideModal(this.modalOptions);
      });
    }

    // Wall texture image upload
    const wallUpload = document.getElementById('wall-image-upload');
    const wallSlotSelect = document.getElementById('wall-slot-select');
    if (wallUpload) {
      wallUpload.addEventListener('change', (e) => {
        const file = e.target.files[0];
        if (file) {
          const reader = new FileReader();
          reader.onload = (event) => {
            const base64 = event.target.result;
            const slotIndex = parseInt(wallSlotSelect ? wallSlotSelect.value : '0', 10) || 0;
            AudioEngine.playUnlock();
            if (this.callbacks.onWallImageUploaded) {
              this.callbacks.onWallImageUploaded(slotIndex, base64);
            }
          };
          reader.readAsDataURL(file);
        }
      });
    }

    const btnResetWall = document.getElementById('btn-reset-wall');
    if (btnResetWall) {
      btnResetWall.addEventListener('click', () => {
        const slotIndex = parseInt(wallSlotSelect ? wallSlotSelect.value : '0', 10) || 0;
        AudioEngine.playRuleChange();
        if (this.callbacks.onWallImageReset) {
          this.callbacks.onWallImageReset(slotIndex);
        }
      });
    }

    // Floor texture image upload
    const floorSlotSelect = document.getElementById('floor-slot-select');
    const floorUpload = document.getElementById('floor-image-upload');
    if (floorUpload) {
      floorUpload.addEventListener('change', (e) => {
        const file = e.target.files[0];
        if (file) {
          const reader = new FileReader();
          reader.onload = (event) => {
            const base64 = event.target.result;
            AudioEngine.playUnlock();
            const slotKey = floorSlotSelect ? floorSlotSelect.value : 'bg';
            if (this.callbacks.onFloorImageUploaded) {
              this.callbacks.onFloorImageUploaded(slotKey, base64);
            }
          };
          reader.readAsDataURL(file);
        }
      });
    }

    const btnResetFloor = document.getElementById('btn-reset-floor');
    if (btnResetFloor) {
      btnResetFloor.addEventListener('click', () => {
        AudioEngine.playRuleChange();
        const slotKey = floorSlotSelect ? floorSlotSelect.value : 'bg';
        if (this.callbacks.onFloorImageReset) {
          this.callbacks.onFloorImageReset(slotKey);
        }
      });
    }

    // Credits Modal close button
    const btnCloseCredits = document.getElementById('btn-close-credits');
    if (btnCloseCredits) {
      btnCloseCredits.addEventListener('click', () => {
        AudioEngine.playRuleChange();
        this.hideModal(this.modalCredits);
      });
    }

    // Coop Select Modal controls
    const btnCoopSelect3 = document.getElementById('btn-coop-select-3');
    const btnCoopSelect4 = document.getElementById('btn-coop-select-4');
    const btnCloseCoopSelect = document.getElementById('btn-close-coop-select');
    if (btnCoopSelect3) {
      btnCoopSelect3.addEventListener('click', () => {
        this.hideModal(document.getElementById('modal-coop-select'));
        AudioEngine.playRuleChange();
        this.callbacks.onSelectGameMode('3');
      });
    }
    if (btnCoopSelect4) {
      btnCoopSelect4.addEventListener('click', () => {
        this.hideModal(document.getElementById('modal-coop-select'));
        AudioEngine.playRuleChange();
        this.callbacks.onSelectGameMode('4');
      });
    }
    if (btnCloseCoopSelect) {
      btnCloseCoopSelect.addEventListener('click', () => {
        AudioEngine.playRuleChange();
        this.hideModal(document.getElementById('modal-coop-select'));
      });
    }

    // Virtual D-Pad Analog button bindings
    const btnDpadUp = document.getElementById('btn-dpad-up');
    const btnDpadDown = document.getElementById('btn-dpad-down');
    const btnDpadLeft = document.getElementById('btn-dpad-left');
    const btnDpadRight = document.getElementById('btn-dpad-right');

    const bindDpadBtn = (btn, dx, dy) => {
      btn.addEventListener('pointerdown', (e) => {
        e.preventDefault();
        this.callbacks.onDpadMove(dx, dy);
      });
    };

    if (btnDpadUp) bindDpadBtn(btnDpadUp, 0, -1);
    if (btnDpadDown) bindDpadBtn(btnDpadDown, 0, 1);
    if (btnDpadLeft) bindDpadBtn(btnDpadLeft, -1, 0);
    if (btnDpadRight) bindDpadBtn(btnDpadRight, 1, 0);

    // Background click closes modals
    [this.modalImport, this.modalExport, this.modalHelp, this.modalLevels, this.modalFinished, this.modalOptions, this.modalCredits, document.getElementById('modal-coop-select')].forEach(modal => {
      if (modal) {
        modal.addEventListener('click', (e) => {
          if (e.target === modal) {
            this.hideModal(modal);
            AudioEngine.playRuleChange();
          }
        });
      }
    });
  }

  /**
   * Toggle between Play Mode and Editor Mode display
   */
  setEditorModeActive(active) {
    this.btnEditorToggle.classList.toggle('active', active);
    this.gameBoardDom.classList.toggle('editor-mode', active);
    this.gameContainer.classList.toggle('editor-active', active);
    this.ruleLabPanel.style.display = active ? 'none' : 'flex';
    this.analogControlPanel.style.display = active ? 'none' : 'flex';
    
    if (active) {
      const activeMode = this.callbacks.getActiveMode ? this.callbacks.getActiveMode() : '1';
      this.syncModeUI(activeMode);
      this.editorPanel.style.display = 'flex';
      this.levelDisplayDom.textContent = 'LEVEL: CREATOR';
      this.movesDisplayDom.style.visibility = 'hidden';
      this.btnUndo.style.display = 'none';
      this.btnReset.style.display = 'none';
      this.solverResultPanel.style.display = 'none';
    } else {
      this.editorPanel.style.display = 'none';
      this.movesDisplayDom.style.visibility = 'visible';
      this.btnUndo.style.display = 'flex';
      this.btnReset.style.display = 'flex';
    }
  }

  /**
   * Show a modal overlay
   */
  showModal(modal) {
    modal.classList.add('active');
  }

  /**
   * Hide a modal overlay
   */
  hideModal(modal) {
    modal.classList.remove('active');
  }

  /**
   * Set active visual class on rules selector buttons
   */
  setRuleOptionActive(glyphColor, ruleType) {
    const container = document.querySelector(`.rules-options[data-glyph="${glyphColor}"]`);
    if (!container) return;
    
    container.querySelectorAll('.rule-opt').forEach(btn => {
      const active = btn.dataset.rule === ruleType;
      btn.classList.toggle('active', active);
    });
  }

  /**
   * Sync whole rules panel visual state with current rules configurations
   */
  syncRulesPanel(activeRules) {
    for (const [color, rule] of Object.entries(activeRules)) {
      this.setRuleOptionActive(color, rule);
    }
  }

  /**
   * Disable rule buttons that are not available in the current level.
   */
  applyAllowedRules(allowedRules) {
    document.querySelectorAll('.rules-options').forEach(optionContainer => {
      const glyphColor = optionContainer.dataset.glyph;
      const allowed = allowedRules[glyphColor] || ['STOP', 'PUSH', 'SWAP', 'MERGE'];

      optionContainer.querySelectorAll('.rule-opt').forEach(btn => {
        const isAllowed = allowed.includes(btn.dataset.rule);
        btn.disabled = !isAllowed;
        btn.classList.toggle('locked', !isAllowed);
      });
    });
  }

  /**
   * Sync editor rules configuration checkboxes with active allowedRules map
   */
  syncEditorAllowedRules(allowedRules) {
    const check = (chk, color, rule) => {
      if (chk) {
        chk.checked = (allowedRules[color] || []).includes(rule);
      }
    };
    
    check(this.chkAllowRedPush, 'red', 'PUSH');
    check(this.chkAllowRedSwap, 'red', 'SWAP');
    check(this.chkAllowRedMerge, 'red', 'MERGE');
    
    check(this.chkAllowBluePush, 'blue', 'PUSH');
    check(this.chkAllowBlueSwap, 'blue', 'SWAP');
    check(this.chkAllowBlueMerge, 'blue', 'MERGE');
    
    check(this.chkAllowGreenPush, 'green', 'PUSH');
    check(this.chkAllowGreenSwap, 'green', 'SWAP');
    check(this.chkAllowGreenMerge, 'green', 'MERGE');
  }

  /**
   * Update moves left visual count and alarms
   */
  updateMoves(current, limit) {
    this.movesCounterDom.textContent = current;
    
    this.movesCounterDom.classList.remove('warning', 'danger');
    
    if (current <= 2) {
      this.movesCounterDom.classList.add('danger');
    } else if (current <= 5) {
      this.movesCounterDom.classList.add('warning');
    }
  }

  /**
   * Update header metadata
   */
  updateLevelHeader(currentIdx, total, levelName) {
    this.levelDisplayDom.textContent = `LEVEL: ${currentIdx + 1}/${total}`;
    
    // Add subtitle or info in panel
    const displayName = levelName || "Level";
    document.getElementById('lab-indicator').textContent = displayName.toUpperCase();
  }

  /**
   * Enable/disable undo button
   */
  setUndoEnabled(enabled) {
    this.btnUndo.disabled = !enabled;
  }

  /**
   * Sync Editor config inputs when loading a template level
   */
  syncEditorInputs(width, height, movesLimit, name = '', description = '') {
    this.editorColsInput.value = width;
    this.editorRowsInput.value = height;
    this.editorStepsInput.value = movesLimit;
    if (this.editorLevelName) this.editorLevelName.value = name || '';
    if (this.editorLevelDesc) this.editorLevelDesc.value = description || '';
  }

  syncEditorTemplateSelection(index) {
    this.editorLevelSelect.value = String(index);
  }

  setEditorSaveStatus(state, label) {
    if (!this.editorSaveStatus) return;
    this.editorSaveStatus.dataset.state = state;
    this.editorSaveStatus.textContent = label;
  }

  /**
   * Show Level Complete Modal
   */
  showWinModal(stats) {
    document.getElementById('win-stats').textContent = `Langkah Digunakan: ${stats.movesUsed} / ${stats.movesLimit}`;
    this.showModal(this.modalWin);
  }

  /**
   * Show Game Finished Modal (Ending screen)
   */
  showFinishedModal() {
    this.showModal(this.modalFinished);
  }

  /**
   * Show Game Over Modal and trigger shake glitch animation on board
   */
  showFailModal() {
    document.getElementById('board-container').classList.add('shake-glitch');
    this.showModal(this.modalFail);
  }

  /**
   * Build level selection layout buttons based on current unlocks and completions
   */
  populateLevelsMenu() {
    this.levelGrid.innerHTML = '';
    
    const activeMode = this.callbacks.getActiveMode ? this.callbacks.getActiveMode() : '1';
    const modeLevels = LEVELS_BY_MODE[activeMode] || LEVELS;
    const totalLevelsCount = modeLevels.length;
    const unlockedIdx = parseInt(safeStorage.getItem(`rule_glyph_unlocked_level_${activeMode}`) || '0', 10);
    const completedList = JSON.parse(safeStorage.getItem(`rule_glyph_completed_levels_${activeMode}`) || '[]');
    
    const finishedLevelCount = document.getElementById('finished-level-count');
    if (finishedLevelCount) {
      finishedLevelCount.textContent = totalLevelsCount;
    }

    const selectedChapter = this.playChapterSelect ? parseInt(this.playChapterSelect.value, 10) || 0 : 0;
    
    for (let i = 0; i < totalLevelsCount; i++) {
      if (activeMode === '1' && selectedChapter !== 0) {
        const chap = this.getChapterOfLevel(i);
        if (chap !== selectedChapter) continue;
      }
      
      const card = document.createElement('div');
      card.className = 'level-card';
      card.textContent = i + 1;
      
      const isUnlocked = i <= unlockedIdx;
      const isCompleted = completedList.includes(i);
      
      if (isUnlocked) {
        card.classList.add('unlocked');
        if (isCompleted) card.classList.add('completed');
        
        card.addEventListener('click', () => {
          this.hideModal(this.modalLevels);
          AudioEngine.playRuleChange();
          this.callbacks.onLevelSelected(i);
        });
      } else {
        card.classList.add('locked');
      }
      
      this.levelGrid.appendChild(card);
    }
  }

  /**
   * Update the solver bot results readout panel
   */
  updateSolverResults(result) {
    this.solverResultPanel.style.display = 'block';
    
    if (result.solved) {
      this.solverStatusText.style.color = 'var(--neon-green)';
      this.solverStatusText.innerHTML = `Bot: SOLVED!<br>Langkah: ${result.moves}<br>Aksi rule+gerak: ${result.path.length}<br>Visited: ${result.visitedCount} status`;
      this.btnSolverAutoplay.style.display = 'block';
    } else {
      this.solverStatusText.style.color = 'var(--neon-red)';
      this.solverStatusText.innerHTML = `Bot: UNSOLVABLE<br>${result.error || 'Tidak ada jalur!'}`;
      this.btnSolverAutoplay.style.display = 'none';
    }
  }

  /**
   * Reset solver results panel
   */
  clearSolverResults() {
    this.solverResultPanel.style.display = 'none';
    this.btnSolverAutoplay.style.display = 'none';
  }

  updateRuleCounters(counters) {
    for (const color of ['red', 'blue', 'green']) {
      const label = document.querySelector(`.rule-row-${color} .glyph-label span:not(.label-dot)`);
      if (label) {
        let baseText = label.textContent.replace(/\s*\[\d+s\]/gi, '');
        if (counters && counters[color] !== null && counters[color] !== undefined) {
          label.textContent = `${baseText} [${counters[color]}s]`;
        } else {
          label.textContent = baseText;
        }
      }
    }
  }
}
