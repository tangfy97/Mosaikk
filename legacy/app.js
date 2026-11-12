const state = {
  rows: 2,
  cols: 3,
  width: 1200,
  height: 800,
  gap: 16,
  fit: "cover",
  zoom: 1,
  autoZoom: true,
  controlsOpen: false,
  inspectorPinned: false,
  addMenuOpen: false,
  moreMenuOpen: false,
  dragActive: false,
  dragTargetIndex: null,
  selectedIndex: null,
  selectedAnnotationId: null,
  annotations: [],
  images: [],
};

const bounds = {
  rows: [1, 12],
  cols: [1, 12],
  width: [320, 3000],
  height: [240, 3000],
  gap: [0, 80],
  zoom: [0.25, 1.5],
  imageScale: [1, 6],
  annotationSize: [12, 96],
  highlightStroke: [2, 12],
};

const els = {
  appShell: document.querySelector(".app-shell"),
  windowDragStrip: document.querySelector("#windowDragStrip"),
  windowDragBrand: document.querySelector("#windowDragBrand"),
  workspace: document.querySelector(".workspace"),
  controlsPanel: document.querySelector(".panel-left"),
  inspectorPanel: document.querySelector(".panel-right"),
  stage: document.querySelector(".stage"),
  collage: document.querySelector("#collage"),
  stageScroll: document.querySelector("#stageScroll"),
  dropCard: document.querySelector("#dropCard"),
  importVeil: document.querySelector("#importVeil"),
  importVeilTitle: document.querySelector("#importVeilTitle"),
  importVeilDetail: document.querySelector("#importVeilDetail"),
  fileInput: document.querySelector("#fileInput"),
  uploadButton: document.querySelector("#uploadButton"),
  toolbarUploadButton: document.querySelector("#toolbarUploadButton"),
  pasteButton: document.querySelector("#pasteButton"),
  toolbarPasteButton: document.querySelector("#toolbarPasteButton"),
  addTextButton: document.querySelector("#addTextButton"),
  addHighlightButton: document.querySelector("#addHighlightButton"),
  autoLayoutButton: document.querySelector("#autoLayoutButton"),
  addMenuButton: document.querySelector("#addMenuButton"),
  addCommandMenu: document.querySelector("#addCommandMenu"),
  moreMenuButton: document.querySelector("#moreMenuButton"),
  topMoreMenu: document.querySelector("#topMoreMenu"),
  inspectorAddTextButton: document.querySelector("#inspectorAddTextButton"),
  inspectorAddHighlightButton: document.querySelector("#inspectorAddHighlightButton"),
  toggleControlsButton: document.querySelector("#toggleControlsButton"),
  toggleInspectorButton: document.querySelector("#toggleInspectorButton"),
  closeControlsButton: document.querySelector("#closeControlsButton"),
  closeInspectorButton: document.querySelector("#closeInspectorButton"),
  previewButton: document.querySelector("#previewButton"),
  previewModal: document.querySelector("#previewModal"),
  previewBackdrop: document.querySelector("#previewBackdrop"),
  previewImage: document.querySelector("#previewImage"),
  closePreviewButton: document.querySelector("#closePreviewButton"),
  previewExportButton: document.querySelector("#previewExportButton"),
  previewCopyButton: document.querySelector("#previewCopyButton"),
  snapLeftButton: document.querySelector("#snapLeftButton"),
  pasteStatus: document.querySelector("#pasteStatus"),
  rowsInput: document.querySelector("#rowsInput"),
  colsInput: document.querySelector("#colsInput"),
  widthInput: document.querySelector("#widthInput"),
  heightInput: document.querySelector("#heightInput"),
  gapInput: document.querySelector("#gapInput"),
  fillButton: document.querySelector("#fillButton"),
  fitButton: document.querySelector("#fitButton"),
  exportButton: document.querySelector("#exportButton"),
  copyButton: document.querySelector("#copyButton"),
  canvasMeta: document.querySelector("#canvasMeta"),
  zoomValue: document.querySelector("#zoomValue"),
  zoomOutButton: document.querySelector("#zoomOutButton"),
  zoomInButton: document.querySelector("#zoomInButton"),
  imageCount: document.querySelector("#imageCount"),
  selectionSummary: document.querySelector("#selectionSummary"),
  statusLeft: document.querySelector("#statusLeft"),
  selectedTitle: document.querySelector("#selectedTitle"),
  selectedDetail: document.querySelector("#selectedDetail"),
  cropValue: document.querySelector("#cropValue"),
  imageScaleInput: document.querySelector("#imageScaleInput"),
  annotationCount: document.querySelector("#annotationCount"),
  annotationTextInput: document.querySelector("#annotationTextInput"),
  annotationSizeInput: document.querySelector("#annotationSizeInput"),
  annotationSizeLabel: document.querySelector("#annotationSizeLabel"),
  deleteAnnotationButton: document.querySelector("#deleteAnnotationButton"),
  resetCropButton: document.querySelector("#resetCropButton"),
  replaceButton: document.querySelector("#replaceButton"),
  clearSlotButton: document.querySelector("#clearSlotButton"),
  canvasEmptyState: document.querySelector("#canvasEmptyState"),
  emptyUploadButton: document.querySelector("#emptyUploadButton"),
  emptyPasteButton: document.querySelector("#emptyPasteButton"),
  imageContextBar: document.querySelector("#imageContextBar"),
  contextSlotLabel: document.querySelector("#contextSlotLabel"),
  contextScaleInput: document.querySelector("#contextScaleInput"),
  contextScaleValue: document.querySelector("#contextScaleValue"),
  moveImageBackButton: document.querySelector("#moveImageBackButton"),
  moveImageForwardButton: document.querySelector("#moveImageForwardButton"),
  contextResetCropButton: document.querySelector("#contextResetCropButton"),
  contextReplaceButton: document.querySelector("#contextReplaceButton"),
  contextInspectorButton: document.querySelector("#contextInspectorButton"),
  contextClearButton: document.querySelector("#contextClearButton"),
};

const clamp = (value, min, max) => Math.min(Math.max(value, min), max);
const roundTo = (value, step) => Math.round(value / step) * step;

let gestureState = null;
let annotationIdCounter = 1;
let previewUrl = "";
let lastFocusedElement = null;
let projectReady = false;
let saveTimer = null;
let historyLocked = false;
let continuousCheckpoint = null;
let pendingFileImport = null;
let statusNotice = null;
let statusNoticeTimer = null;
const history = [];
const future = [];
const historyLimit = 40;
const projectDatabaseName = "collage-atelier";

function sendNativeMessage(message) {
  const bridge = window.webkit?.messageHandlers?.nativeBridge;
  if (!window.__COLLAGE_NATIVE__ || !bridge) {
    return false;
  }
  bridge.postMessage(message);
  return true;
}

async function addDataUrlImage(dataUrl, sourceLabel = "Pasted", preferredIndex = null) {
  try {
    const response = await fetch(dataUrl);
    const blob = await response.blob();
    const extension = blob.type.split("/")[1] || "png";
    const file = new File([blob], `pasted-${Date.now()}.${extension}`, { type: blob.type || "image/png" });
    addImageFiles([file], sourceLabel, { preferredIndex });
  } catch (error) {
    setStatus("Could not import image", "error");
  }
}

window.receiveNativeClipboardImage = async (dataUrl, preferredIndex = null) => {
  addDataUrlImage(dataUrl, "Pasted", preferredIndex);
};

window.receiveNativeImportedImage = async (dataUrl, sourceLabel = "Dropped", preferredIndex = null) => {
  addDataUrlImage(dataUrl, sourceLabel, preferredIndex);
};

window.receiveNativeStatus = (message, tone = "") => {
  setStatus(message, tone);
};

function getFitZoom() {
  if (!els.stageScroll) {
    return state.zoom;
  }

  const availableWidth = Math.max(280, els.stageScroll.clientWidth - 110);
  const availableHeight = Math.max(240, els.stageScroll.clientHeight - 110);
  const fitZoom = Math.min(1, availableWidth / state.width, availableHeight / state.height);
  return clamp(Math.floor(fitZoom * 100) / 100, bounds.zoom[0], bounds.zoom[1]);
}

function setStatus(message, tone = "") {
  statusNotice = { message, tone };
  window.clearTimeout(statusNoticeTimer);
  statusNoticeTimer = window.setTimeout(() => {
    statusNotice = null;
    syncView();
  }, tone === "error" ? 4200 : 2800);
  els.pasteStatus.classList.remove("success", "error");
  if (tone) {
    els.pasteStatus.classList.add(tone);
  }
  els.pasteStatus.innerHTML = `<span class="shortcut">⌘</span>${message}`;
  els.statusLeft.textContent = message;
  els.statusLeft.dataset.tone = tone;
}

function applyStatusNotice() {
  if (!statusNotice) {
    return;
  }
  els.statusLeft.textContent = statusNotice.message;
  els.statusLeft.dataset.tone = statusNotice.tone;
}

function syncCommandMenus() {
  const compact = window.innerWidth <= 980;
  els.addCommandMenu.hidden = !state.addMenuOpen;
  els.addMenuButton.setAttribute("aria-expanded", String(state.addMenuOpen));
  els.topMoreMenu.hidden = compact && !state.moreMenuOpen;
  els.moreMenuButton.setAttribute("aria-expanded", String(state.moreMenuOpen));
}

function closeCommandMenus() {
  state.addMenuOpen = false;
  state.moreMenuOpen = false;
  syncCommandMenus();
}

function toggleCommandMenu(name) {
  if (name === "add") {
    state.addMenuOpen = !state.addMenuOpen;
    state.moreMenuOpen = false;
  } else {
    state.moreMenuOpen = !state.moreMenuOpen;
    state.addMenuOpen = false;
  }
  syncCommandMenus();

  const openMenu = name === "add" ? els.addCommandMenu : els.topMoreMenu;
  if (!(name === "more" && window.innerWidth > 980)) {
    Array.from(openMenu.querySelectorAll("button")).find((button) => button.offsetParent !== null)?.focus();
  }
}

function createProjectSnapshot() {
  return {
    rows: state.rows,
    cols: state.cols,
    width: state.width,
    height: state.height,
    gap: state.gap,
    fit: state.fit,
    images: state.images.map((item) => (item ? { ...item } : null)),
    annotations: state.annotations.map((annotation) => ({ ...annotation })),
    selectedIndex: state.selectedIndex,
    selectedAnnotationId: state.selectedAnnotationId,
  };
}

function applyProjectSnapshot(snapshot) {
  historyLocked = true;
  state.rows = snapshot.rows;
  state.cols = snapshot.cols;
  state.width = snapshot.width;
  state.height = snapshot.height;
  state.gap = snapshot.gap;
  state.fit = snapshot.fit;
  state.images = snapshot.images.map((item) => (item ? { ...item } : null));
  state.annotations = snapshot.annotations.map((annotation) => ({ ...annotation }));
  state.selectedIndex = snapshot.selectedIndex;
  state.selectedAnnotationId = snapshot.selectedAnnotationId;
  state.inspectorPinned = false;
  constrainAllTransforms();
  constrainAnnotations();
  render();
  historyLocked = false;
}

function pushHistory() {
  if (historyLocked) {
    return;
  }
  history.push(createProjectSnapshot());
  if (history.length > historyLimit) {
    history.shift();
  }
  future.length = 0;
}

function checkpointContinuousAction(key) {
  if (!continuousCheckpoint || continuousCheckpoint.key !== key) {
    pushHistory();
  }
  if (continuousCheckpoint?.timer) {
    window.clearTimeout(continuousCheckpoint.timer);
  }
  continuousCheckpoint = {
    key,
    timer: window.setTimeout(() => {
      continuousCheckpoint = null;
    }, 450),
  };
}

function undoProject() {
  const snapshot = history.pop();
  if (!snapshot) {
    setStatus("Nothing to undo");
    return;
  }
  future.push(createProjectSnapshot());
  applyProjectSnapshot(snapshot);
  setStatus("Undid last change", "success");
}

function redoProject() {
  const snapshot = future.pop();
  if (!snapshot) {
    setStatus("Nothing to redo");
    return;
  }
  history.push(createProjectSnapshot());
  applyProjectSnapshot(snapshot);
  setStatus("Redid last change", "success");
}

function runUndoCommand(redo = false) {
  if (document.activeElement?.matches?.("input, textarea")) {
    document.execCommand(redo ? "redo" : "undo");
    return;
  }
  if (redo) {
    redoProject();
  } else {
    undoProject();
  }
}

function openProjectDatabase() {
  return new Promise((resolve, reject) => {
    if (!window.indexedDB) {
      reject(new Error("IndexedDB unavailable"));
      return;
    }
    const request = indexedDB.open(projectDatabaseName, 1);
    request.onupgradeneeded = () => {
      if (!request.result.objectStoreNames.contains("projects")) {
        request.result.createObjectStore("projects");
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

async function readSavedProject() {
  const database = await openProjectDatabase();
  return new Promise((resolve, reject) => {
    const transaction = database.transaction("projects", "readonly");
    const request = transaction.objectStore("projects").get("current");
    request.onsuccess = () => resolve(request.result || null);
    request.onerror = () => reject(request.error);
    transaction.oncomplete = () => database.close();
  });
}

async function saveProject() {
  if (!projectReady || historyLocked) {
    return;
  }

  const project = {
    version: 1,
    rows: state.rows,
    cols: state.cols,
    width: state.width,
    height: state.height,
    gap: state.gap,
    fit: state.fit,
    annotations: state.annotations.map((annotation) => ({ ...annotation })),
    images: state.images.map((item) =>
      item
        ? {
            name: item.name,
            file: item.file,
            scale: item.scale,
            offsetX: item.offsetX,
            offsetY: item.offsetY,
            fit: item.fit,
          }
        : null,
    ),
    savedAt: Date.now(),
  };

  try {
    const database = await openProjectDatabase();
    await new Promise((resolve, reject) => {
      const transaction = database.transaction("projects", "readwrite");
      transaction.objectStore("projects").put(project, "current");
      transaction.oncomplete = resolve;
      transaction.onerror = () => reject(transaction.error);
    });
    database.close();
  } catch (error) {
    // Editing remains usable when storage is unavailable.
  }
}

function scheduleProjectSave() {
  if (!projectReady || historyLocked) {
    return;
  }
  window.clearTimeout(saveTimer);
  saveTimer = window.setTimeout(saveProject, 350);
}

async function restoreSavedProject() {
  try {
    const project = await readSavedProject();
    if (!project || project.version !== 1) {
      return false;
    }

    state.rows = clamp(Number(project.rows) || 2, bounds.rows[0], bounds.rows[1]);
    state.cols = clamp(Number(project.cols) || 3, bounds.cols[0], bounds.cols[1]);
    state.width = clamp(Number(project.width) || 1200, bounds.width[0], bounds.width[1]);
    state.height = clamp(Number(project.height) || 800, bounds.height[0], bounds.height[1]);
    state.gap = clamp(Number(project.gap) || 0, bounds.gap[0], bounds.gap[1]);
    state.fit = project.fit === "contain" ? "contain" : "cover";
    state.annotations = Array.isArray(project.annotations)
      ? project.annotations.map((annotation) => ({ ...annotation }))
      : [];
    state.images = Array.isArray(project.images)
      ? project.images.map((savedItem, index) => {
          if (!savedItem?.file) {
            return null;
          }
          const sourceFile =
            savedItem.file instanceof File
              ? savedItem.file
              : new File([savedItem.file], savedItem.name || `restored-${index + 1}.png`, {
                  type: savedItem.file.type || "image/png",
                });
          const item = createImageRecord(sourceFile, savedItem.name || `restored-${index + 1}.png`);
          item.scale = savedItem.scale || 1;
          item.offsetX = savedItem.offsetX || 0;
          item.offsetY = savedItem.offsetY || 0;
          item.fit = savedItem.fit === "contain" ? "contain" : savedItem.fit === "cover" ? "cover" : undefined;
          return item;
        })
      : [];
    annotationIdCounter =
      Math.max(
        0,
        ...state.annotations.map((annotation) => Number(String(annotation.id || "").split("-").pop()) || 0),
      ) + 1;
    constrainAllTransforms();
    constrainAnnotations();
    return true;
  } catch (error) {
    return false;
  }
}

function updateImportVeil() {
  if (!els.importVeilTitle || !els.importVeilDetail) {
    return;
  }

  const targetIndex = state.dragTargetIndex ?? getPredictedInsertIndex();
  const addsRow = targetIndex !== null && targetIndex >= getTotalSlots();
  els.importVeilTitle.textContent = targetIndex === null ? "Collage is full" : `Add as Photo ${targetIndex + 1}`;
  els.importVeilDetail.textContent = addsRow
    ? "Release to add a new row"
    : window.__COLLAGE_NATIVE__
      ? "Release a Finder or browser image"
      : "Release anywhere to import";
}

function getTotalSlots() {
  return state.rows * state.cols;
}

function getFilledImageCount() {
  return state.images.filter(Boolean).length;
}

function getAutoLayout(imageCount) {
  const count = clamp(imageCount || 1, 1, bounds.rows[1] * bounds.cols[1]);
  const loadedAspects = state.images
    .filter((item) => item?.naturalWidth && item?.naturalHeight)
    .map((item) => item.naturalWidth / item.naturalHeight)
    .sort((a, b) => a - b);
  const targetCellAspect = loadedAspects.length
    ? loadedAspects[Math.floor(loadedAspects.length / 2)]
    : 1;
  const canvasAspect = state.width / state.height;
  let best = { rows: 1, cols: count, score: Number.POSITIVE_INFINITY };

  for (let rows = 1; rows <= Math.min(bounds.rows[1], count); rows += 1) {
    const cols = Math.ceil(count / rows);
    if (cols > bounds.cols[1]) {
      continue;
    }
    const empty = rows * cols - count;
    const cellAspect = canvasAspect * (rows / cols);
    const aspectMismatch = Math.abs(Math.log(cellAspect / targetCellAspect));
    const shapePenalty = Math.max(0, Math.max(rows, cols) / Math.min(rows, cols) - 3) * 0.4;
    const score = empty * 0.75 + aspectMismatch + shapePenalty;
    if (score < best.score) {
      best = { rows, cols, score };
    }
  }

  return best;
}

function autoArrangeLayout() {
  const imageCount = getFilledImageCount();
  pushHistory();
  const layout = getAutoLayout(imageCount);
  state.rows = layout.rows;
  state.cols = layout.cols;
  normalizeSelection();
  constrainAllTransforms();
  render();
  setStatus(`Arranged ${imageCount || 1} slot${imageCount === 1 ? "" : "s"}`, "success");
}

function moveSelectedImage(direction) {
  if (state.selectedIndex === null || !state.images[state.selectedIndex]) {
    return;
  }
  const targetIndex = state.selectedIndex + direction;
  if (targetIndex < 0 || targetIndex >= getTotalSlots()) {
    return;
  }

  pushHistory();
  const current = state.images[state.selectedIndex];
  state.images[state.selectedIndex] = state.images[targetIndex] || null;
  state.images[targetIndex] = current;
  state.selectedIndex = targetIndex;
  render();
  setStatus(`Moved to slot ${targetIndex + 1}`, "success");
}

function startFreshProject() {
  pushHistory();
  state.rows = 2;
  state.cols = 3;
  state.width = 1200;
  state.height = 800;
  state.gap = 16;
  state.fit = "cover";
  state.images = [];
  state.annotations = [];
  state.selectedIndex = null;
  state.selectedAnnotationId = null;
  state.controlsOpen = false;
  state.inspectorPinned = false;
  state.autoZoom = true;
  render();
  setStatus("New collage ready", "success");
}

function normalizeSelection() {
  const total = getTotalSlots();
  if (state.selectedIndex !== null && (state.selectedIndex < 0 || state.selectedIndex >= total)) {
    state.selectedIndex = total ? total - 1 : null;
  }
  if (state.selectedAnnotationId && !getSelectedAnnotation()) {
    state.selectedAnnotationId = null;
  }
}

function selectSlot(index) {
  const total = getTotalSlots();
  state.selectedIndex = index >= 0 && index < total ? index : null;
  state.selectedAnnotationId = null;
  syncView();
}

function getSelectedAnnotation() {
  return state.annotations.find((annotation) => annotation.id === state.selectedAnnotationId) || null;
}

function selectAnnotation(id) {
  state.selectedAnnotationId = id;
  state.selectedIndex = null;
  state.inspectorPinned = true;
  syncView();
}

function syncSelection() {
  els.collage.querySelectorAll(".slot").forEach((slot) => {
    const index = Number(slot.dataset.index);
    slot.classList.toggle("is-selected", index === state.selectedIndex);
    slot.classList.toggle("is-drop-target", index === state.dragTargetIndex);
  });
}

function syncImageTransforms() {
  els.collage.querySelectorAll(".slot img").forEach((img) => {
    const index = Number(img.closest(".slot")?.dataset.index);
    const item = state.images[index];
    if (!item) {
      return;
    }
    const offsetX = (item.offsetX || 0) * state.zoom;
    const offsetY = (item.offsetY || 0) * state.zoom;
    img.style.objectFit = item.fit || state.fit;
    img.style.transform = `translate(${offsetX}px, ${offsetY}px) scale(${item.scale || 1})`;
  });
}

function positionImageContextBar() {
  if (!els.imageContextBar || !els.stage || !state.images[state.selectedIndex]) {
    return;
  }

  window.requestAnimationFrame(() => {
    const stageRect = els.stage.getBoundingClientRect();
    const collageRect = els.collage.getBoundingClientRect();
    const barHeight = els.imageContextBar.offsetHeight || 42;
    const desiredTop = collageRect.bottom - stageRect.top + 12;
    const minTop = 68;
    const maxTop = Math.max(minTop, stageRect.height - barHeight - 70);
    els.imageContextBar.style.top = `${clamp(desiredTop, minTop, maxTop)}px`;
    els.imageContextBar.style.bottom = "auto";
  });
}

function getAnnotationDefaultFrame(type) {
  const cell =
    state.selectedIndex !== null
      ? getCell(state.selectedIndex)
      : {
          x: state.width * 0.2,
          y: state.height * 0.22,
          width: state.width * 0.6,
          height: state.height * 0.5,
        };

  if (type === "highlight") {
    const width = Math.max(120, cell.width * 0.58);
    const height = Math.max(80, cell.height * 0.36);
    return {
      x: cell.x + (cell.width - width) / 2,
      y: cell.y + (cell.height - height) / 2,
      width,
      height,
    };
  }

  return {
    x: cell.x + cell.width * 0.12,
    y: cell.y + cell.height * 0.12,
    width: Math.max(160, cell.width * 0.62),
    height: 56,
  };
}

function constrainAnnotation(annotation) {
  if (!annotation) {
    return;
  }

  annotation.x = Number.isFinite(annotation.x) ? annotation.x : 0;
  annotation.y = Number.isFinite(annotation.y) ? annotation.y : 0;

  if (annotation.type === "highlight") {
    annotation.width = clamp(annotation.width || 160, 48, state.width);
    annotation.height = clamp(annotation.height || 100, 36, state.height);
    annotation.stroke = clamp(annotation.stroke || 4, bounds.highlightStroke[0], bounds.highlightStroke[1]);
    annotation.x = clamp(annotation.x, 0, Math.max(0, state.width - annotation.width));
    annotation.y = clamp(annotation.y, 0, Math.max(0, state.height - annotation.height));
    return;
  }

  annotation.fontSize = clamp(annotation.fontSize || 28, bounds.annotationSize[0], bounds.annotationSize[1]);
  annotation.x = clamp(annotation.x, 0, state.width - 24);
  annotation.y = clamp(annotation.y, 0, state.height - annotation.fontSize);
}

function constrainAnnotations() {
  state.annotations.forEach(constrainAnnotation);
}

function renderAnnotations() {
  els.collage.querySelector(".annotation-layer")?.remove();

  const layer = document.createElement("div");
  layer.className = "annotation-layer";
  layer.setAttribute("aria-label", "Text and focus annotations");

  state.annotations.forEach((annotation) => {
    constrainAnnotation(annotation);

    const item = document.createElement("button");
    item.type = "button";
    item.className = `annotation-item annotation-${annotation.type}`;
    item.dataset.annotationId = annotation.id;
    item.style.left = `${annotation.x * state.zoom}px`;
    item.style.top = `${annotation.y * state.zoom}px`;
    item.style.setProperty("--annotation-color", annotation.color);
    item.classList.toggle("is-selected", annotation.id === state.selectedAnnotationId);
    item.setAttribute("aria-label", annotation.type === "highlight" ? "Select focus box" : "Select text annotation");

    if (annotation.type === "highlight") {
      item.style.width = `${annotation.width * state.zoom}px`;
      item.style.height = `${annotation.height * state.zoom}px`;
      item.style.borderWidth = `${Math.max(2, (annotation.stroke || 4) * state.zoom)}px`;
      if (annotation.text) {
        const label = document.createElement("span");
        label.className = "annotation-label";
        label.textContent = annotation.text;
        item.append(label);
      }

      const resize = document.createElement("span");
      resize.className = "annotation-resize";
      resize.setAttribute("aria-hidden", "true");
      item.append(resize);
    } else {
      item.style.fontSize = `${annotation.fontSize * state.zoom}px`;
      item.textContent = annotation.text || "Double click to edit";
    }

    item.addEventListener("click", (event) => {
      event.stopPropagation();
      selectAnnotation(annotation.id);
    });
    item.addEventListener("dblclick", (event) => {
      event.stopPropagation();
      selectAnnotation(annotation.id);
      els.annotationTextInput.focus();
      els.annotationTextInput.select();
    });
    item.addEventListener("pointerdown", startAnnotationPointer);
    layer.append(item);
  });

  els.collage.append(layer);
}

function syncView() {
  normalizeSelection();
  if (state.autoZoom) {
    state.zoom = getFitZoom();
  }

  const total = getTotalSlots();
  const filledCount = state.images.slice(0, total).filter(Boolean).length;
  const selectedItem = state.selectedIndex === null ? null : state.images[state.selectedIndex];
  const selectedAnnotation = getSelectedAnnotation();
  const hasAnySelection = state.selectedIndex !== null || !!selectedAnnotation;

  els.rowsInput.value = state.rows;
  els.colsInput.value = state.cols;
  els.widthInput.value = state.width;
  els.heightInput.value = state.height;
  els.gapInput.value = state.gap;

  els.collage.style.setProperty("--canvas-width", `${state.width * state.zoom}px`);
  els.collage.style.setProperty("--canvas-height", `${state.height * state.zoom}px`);
  els.collage.style.setProperty("--gap", `${state.gap * state.zoom}px`);
  els.collage.style.setProperty("--image-fit", state.fit);
  els.collage.style.gridTemplateColumns = `repeat(${state.cols}, minmax(0, 1fr))`;
  els.collage.style.gridTemplateRows = `repeat(${state.rows}, minmax(0, 1fr))`;

  const activeFit = selectedItem?.fit || state.fit;
  els.fillButton.classList.toggle("active", activeFit === "cover");
  els.fitButton.classList.toggle("active", activeFit === "contain");
  els.fillButton.setAttribute("aria-pressed", String(activeFit === "cover"));
  els.fitButton.setAttribute("aria-pressed", String(activeFit === "contain"));
  els.zoomValue.textContent = `${Math.round(state.zoom * 100)}%`;
  els.canvasMeta.textContent =
    window.innerWidth < 760
      ? `${state.width}×${state.height} · ${state.cols}×${state.rows} · ${state.gap}px`
      : `${state.width} × ${state.height} px · ${state.cols} × ${state.rows} · Gap ${state.gap} px`;

  els.imageCount.textContent = `${filledCount} image${filledCount === 1 ? "" : "s"}`;
  els.annotationCount.textContent = `${state.annotations.length} layer${state.annotations.length === 1 ? "" : "s"}`;
  els.statusLeft.dataset.tone = "";

  if (selectedAnnotation) {
    els.selectionSummary.textContent = selectedAnnotation.type === "highlight" ? "Highlight selected" : "Text selected";
    els.statusLeft.textContent = selectedAnnotation.type === "highlight" ? "Editing highlight" : "Editing text";
    els.selectedTitle.textContent = selectedAnnotation.type === "highlight" ? "Highlight" : "Text layer";
    els.selectedDetail.textContent = selectedAnnotation.text || "Drag to position";
  } else {
    els.selectionSummary.textContent =
      state.selectedIndex === null
        ? filledCount
          ? "Select a photo to edit"
          : "Ready for photos"
        : `Photo ${state.selectedIndex + 1} of ${total}`;
    els.statusLeft.textContent =
      state.selectedIndex === null
        ? filledCount
          ? `${filledCount} photo${filledCount === 1 ? "" : "s"} in collage`
          : "Ready for photos"
        : selectedItem
          ? `Editing photo ${state.selectedIndex + 1}`
          : `Empty space ${state.selectedIndex + 1} selected`;
    els.selectedTitle.textContent =
      state.selectedIndex === null ? "No photo selected" : selectedItem ? `Photo ${state.selectedIndex + 1}` : `Empty space ${state.selectedIndex + 1}`;
    els.selectedDetail.textContent = selectedItem?.name || (state.selectedIndex === null ? "Select a photo first" : "Ready for a photo");
  }

  els.cropValue.textContent = selectedItem ? `${Math.round((selectedItem.scale || 1) * 100)}%` : "100%";
  els.imageScaleInput.disabled = !selectedItem;
  els.imageScaleInput.value = String(Math.round((selectedItem?.scale || 1) * 100));
  els.resetCropButton.disabled = !selectedItem;
  els.clearSlotButton.disabled = state.selectedIndex === null || !state.images[state.selectedIndex];
  els.replaceButton.disabled = state.selectedIndex === null;
  els.contextSlotLabel.textContent = state.selectedIndex === null ? "No photo" : `Photo ${state.selectedIndex + 1} of ${total}`;
  els.contextScaleInput.disabled = !selectedItem;
  els.contextScaleInput.value = String(Math.round((selectedItem?.scale || 1) * 100));
  els.contextScaleValue.textContent = selectedItem ? `${Math.round((selectedItem.scale || 1) * 100)}%` : "100%";
  els.moveImageBackButton.disabled = !selectedItem || state.selectedIndex === 0;
  els.moveImageForwardButton.disabled = !selectedItem || state.selectedIndex === total - 1;
  els.contextResetCropButton.disabled = !selectedItem;
  els.contextReplaceButton.disabled = !selectedItem;
  els.contextInspectorButton.disabled = !selectedItem;
  els.contextClearButton.disabled = !selectedItem;
  els.annotationTextInput.disabled = !selectedAnnotation;
  els.annotationTextInput.value = selectedAnnotation?.text || "";
  els.annotationSizeInput.disabled = !selectedAnnotation;
  els.annotationSizeLabel.textContent = selectedAnnotation?.type === "highlight" ? "Stroke" : "Size";
  els.annotationSizeInput.min = selectedAnnotation?.type === "highlight" ? bounds.highlightStroke[0] : bounds.annotationSize[0];
  els.annotationSizeInput.max = selectedAnnotation?.type === "highlight" ? bounds.highlightStroke[1] : bounds.annotationSize[1];
  els.annotationSizeInput.value = String(
    selectedAnnotation?.type === "highlight"
      ? selectedAnnotation.stroke || 4
      : selectedAnnotation?.fontSize || 28,
  );
  els.deleteAnnotationButton.disabled = !selectedAnnotation;
  const controlsVisible = state.controlsOpen;
  const inspectorVisible = state.inspectorPinned;
  els.appShell.classList.toggle("import-active", state.dragActive);
  els.appShell.classList.toggle("controls-open", state.controlsOpen);
  els.appShell.classList.toggle("inspector-open", inspectorVisible);
  els.appShell.classList.toggle("has-selection", hasAnySelection);
  els.appShell.classList.toggle("has-image-selection", !!selectedItem);
  els.toggleControlsButton.setAttribute("aria-pressed", String(state.controlsOpen));
  els.toggleInspectorButton?.setAttribute("aria-pressed", String(inspectorVisible));
  els.controlsPanel.inert = !controlsVisible;
  els.inspectorPanel.inert = !inspectorVisible;
  els.controlsPanel.setAttribute("aria-hidden", String(!controlsVisible));
  els.inspectorPanel.setAttribute("aria-hidden", String(!inspectorVisible));
  els.imageContextBar.inert = !selectedItem;
  els.imageContextBar.setAttribute("aria-hidden", String(!selectedItem));
  const showEmptyState = filledCount === 0 && state.annotations.length === 0;
  els.canvasEmptyState.hidden = !showEmptyState;
  els.canvasEmptyState.inert = !showEmptyState;
  els.canvasEmptyState.setAttribute("aria-hidden", String(!showEmptyState));
  syncCommandMenus();
  document.querySelectorAll("[data-annotation-color]").forEach((button) => {
    button.classList.toggle("active", !!selectedAnnotation && button.dataset.annotationColor === selectedAnnotation.color);
  });

  document.querySelectorAll("[data-preset]").forEach((button) => {
    const [rows, cols] = button.dataset.preset.split(",").map(Number);
    button.classList.toggle("active", rows === state.rows && cols === state.cols);
  });
  document.querySelectorAll("[data-size]").forEach((button) => {
    const [width, height] = button.dataset.size.split(",").map(Number);
    button.classList.toggle("active", width === state.width && height === state.height);
  });

  updateImportVeil();

  syncSelection();
  syncImageTransforms();
  renderAnnotations();
  positionImageContextBar();
  applyStatusNotice();
  scheduleProjectSave();
}

function createResizeHandle() {
  const handle = document.createElement("button");
  handle.className = "resize-handle";
  handle.type = "button";
  handle.setAttribute("aria-label", "Resize collage");
  return handle;
}

function renderSlots() {
  const total = getTotalSlots();
  const nextImportIndex = getPreferredInsertIndex();
  const fragment = document.createDocumentFragment();

  for (let index = 0; index < total; index += 1) {
    const image = state.images[index];

    if (image) {
      const slot = document.createElement("div");
      slot.className = "slot slot-filled";
      slot.dataset.index = String(index);
      slot.tabIndex = 0;
      slot.setAttribute("role", "button");
      slot.setAttribute("aria-label", `Select image slot ${index + 1}`);

      const img = document.createElement("img");
      img.src = image.url;
      img.alt = image.name || `Collage image ${index + 1}`;
      img.draggable = false;

      const remove = document.createElement("button");
      remove.className = "remove-image";
      remove.type = "button";
      remove.setAttribute("aria-label", `Remove image ${index + 1}`);
      remove.textContent = "×";
      remove.addEventListener("click", (event) => {
        event.stopPropagation();
        pushHistory();
        state.images[index] = null;
        state.selectedIndex = index;
        render();
        setStatus(`Removed image ${index + 1}`, "success");
      });

      slot.addEventListener("click", () => selectSlot(index));
      slot.addEventListener("keydown", (event) => {
        if (event.key === "Enter" || event.key === " ") {
          event.preventDefault();
          selectSlot(index);
        }
      });

      slot.append(img, remove);
      fragment.append(slot);
    } else {
      const empty = document.createElement("button");
      const isNextImport = index === nextImportIndex;
      empty.className = `slot slot-empty${isNextImport ? " is-next-import" : ""}`;
      empty.type = "button";
      empty.dataset.index = String(index);
      empty.setAttribute("aria-label", isNextImport ? `Next photo goes to space ${index + 1}` : `Select empty space ${index + 1}`);
      empty.innerHTML = isNextImport
        ? '<span class="plus" aria-hidden="true">+</span><span class="next-slot-label">Next photo</span>'
        : '<span class="plus" aria-hidden="true">+</span>';
      empty.addEventListener("click", () => selectSlot(index));
      empty.addEventListener("dblclick", () => {
        selectSlot(index);
        openFilePicker({ preferredIndex: index });
      });
      fragment.append(empty);
    }
  }

  fragment.append(createResizeHandle());
  els.collage.replaceChildren(fragment);
}

function render() {
  renderSlots();
  syncView();
}

function setNumericValue(key, value, step = 1) {
  const [min, max] = bounds[key];
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    syncView();
    return;
  }

  const nextValue = clamp(roundTo(parsed, step), min, max);
  if (nextValue === state[key]) {
    syncView();
    return;
  }
  pushHistory();
  state[key] = nextValue;
  normalizeSelection();

  if (key === "rows" || key === "cols") {
    constrainAllTransforms();
    renderSlots();
  } else {
    constrainAllTransforms();
  }
  constrainAnnotations();

  syncView();
}

function getPreferredInsertIndex(preferredIndex = state.selectedIndex) {
  const total = getTotalSlots();
  if (!total) {
    return null;
  }

  const validPreferred = preferredIndex !== null && preferredIndex !== undefined && Number.isInteger(Number(preferredIndex)) && Number(preferredIndex) >= 0
    ? clamp(Number(preferredIndex), 0, total - 1)
    : null;
  const startIndex = validPreferred === null
    ? 0
    : state.images[validPreferred]
      ? (validPreferred + 1) % total
      : validPreferred;

  for (let offset = 0; offset < total; offset += 1) {
    const index = (startIndex + offset) % total;
    if (!state.images[index]) {
      return index;
    }
  }

  return null;
}

function getPredictedInsertIndex(preferredIndex = state.selectedIndex) {
  const availableIndex = getPreferredInsertIndex(preferredIndex);
  if (availableIndex !== null) {
    return availableIndex;
  }

  return state.rows < bounds.rows[1] ? getTotalSlots() : null;
}

function ensureImportCapacity(count) {
  const total = getTotalSlots();
  const emptyCount = Array.from({ length: total }, (_, index) => index).filter((index) => !state.images[index]).length;
  const missing = Math.max(0, count - emptyCount);
  if (!missing || state.rows >= bounds.rows[1]) {
    return;
  }

  const rowsNeeded = Math.ceil(missing / state.cols);
  state.rows = Math.min(bounds.rows[1], state.rows + rowsNeeded);
}

function getInsertIndices(count, preferredIndex = state.selectedIndex) {
  const total = getTotalSlots();
  if (!total) {
    return [];
  }

  const firstIndex = getPreferredInsertIndex(preferredIndex);
  if (firstIndex === null) {
    return [];
  }

  const indices = [];
  for (let offset = 0; offset < total && indices.length < count; offset += 1) {
    const index = (firstIndex + offset) % total;
    if (!state.images[index]) {
      indices.push(index);
    }
  }
  return indices;
}

function createImageRecord(file, fallbackName) {
  const url = URL.createObjectURL(file);
  const record = {
    url,
    name: file.name || fallbackName,
    file,
    scale: 1,
    offsetX: 0,
    offsetY: 0,
    naturalWidth: 0,
    naturalHeight: 0,
  };

  loadImage(url)
    .then((image) => {
      record.naturalWidth = image.naturalWidth || image.width;
      record.naturalHeight = image.naturalHeight || image.height;
      constrainAllTransforms();
      syncView();
    })
    .catch(() => {});

  return record;
}

function isLikelyImageFile(file) {
  return file.type.startsWith("image/") || /\.(avif|bmp|gif|heic|jpe?g|png|tiff?|webp)$/i.test(file.name || "");
}

function filenameFromURL(url) {
  try {
    const parsed = new URL(url);
    const tail = parsed.pathname.split("/").filter(Boolean).pop();
    return tail ? decodeURIComponent(tail).slice(0, 80) : `dropped-${Date.now()}.png`;
  } catch (error) {
    return `dropped-${Date.now()}.png`;
  }
}

function addImageFiles(files, sourceLabel = "Added", options = {}) {
  const imageFiles = Array.from(files).filter(isLikelyImageFile);

  if (!imageFiles.length) {
    setStatus("No image found in clipboard", "error");
    return;
  }

  const preferredIndex = options.preferredIndex !== null && options.preferredIndex !== undefined && Number.isInteger(Number(options.preferredIndex)) && Number(options.preferredIndex) >= 0
    ? Number(options.preferredIndex)
    : state.selectedIndex;
  const replaceIndex = options.replaceIndex !== null && options.replaceIndex !== undefined && Number.isInteger(Number(options.replaceIndex)) && Number(options.replaceIndex) >= 0
    ? Number(options.replaceIndex)
    : null;

  const emptyCount = Array.from({ length: getTotalSlots() }, (_, index) => index).filter((index) => !state.images[index]).length;
  const expandableCount = (bounds.rows[1] - state.rows) * state.cols;
  if (replaceIndex === null && emptyCount + expandableCount === 0) {
    setStatus("Collage is full", "error");
    return;
  }

  pushHistory();

  if (replaceIndex !== null && replaceIndex >= 0 && replaceIndex < getTotalSlots()) {
    const file = imageFiles[0];
    state.images[replaceIndex] = createImageRecord(file, `${sourceLabel.toLowerCase()}-${replaceIndex + 1}.png`);
    state.selectedIndex = replaceIndex;
    render();
    setStatus(`Replaced Photo ${replaceIndex + 1}`, "success");
    return;
  }

  ensureImportCapacity(imageFiles.length);
  const insertIndices = getInsertIndices(imageFiles.length, preferredIndex);
  if (!insertIndices.length) {
    setStatus("No slot available", "error");
    return;
  }

  insertIndices.forEach((slotIndex, fileIndex) => {
    state.images[slotIndex] = createImageRecord(
      imageFiles[fileIndex],
      `${sourceLabel.toLowerCase()}-${slotIndex + 1}.png`,
    );
  });

  state.selectedIndex = insertIndices[insertIndices.length - 1];
  render();

  const skipped = imageFiles.length - insertIndices.length;
  if (skipped > 0) {
    setStatus(`${sourceLabel} ${insertIndices.length}; ${skipped} skipped`, "error");
    return;
  }
  const nextIndex = getPredictedInsertIndex(state.selectedIndex);
  const addedLabel = insertIndices.length === 1
    ? `${sourceLabel} as Photo ${insertIndices[0] + 1}`
    : `${sourceLabel} ${insertIndices.length} photos`;
  setStatus(
    nextIndex === null ? `${addedLabel}. Collage is full` : `${addedLabel}. Next import: Photo ${nextIndex + 1}`,
    "success",
  );
}

async function readClipboardImages() {
  const preferredIndex = getPredictedInsertIndex();
  if (sendNativeMessage({ type: "readClipboard", preferredIndex })) {
    setStatus("Reading clipboard...", "");
    return;
  }

  if (!navigator.clipboard?.read) {
    els.collage.focus();
    setStatus("Press Cmd+V now", "");
    return;
  }

  try {
    const items = await navigator.clipboard.read();
    const files = [];

    for (const item of items) {
      const imageType = item.types.find((type) => type.startsWith("image/"));
      if (imageType) {
        const blob = await item.getType(imageType);
        files.push(new File([blob], `pasted-${Date.now()}.${imageType.split("/")[1] || "png"}`, { type: imageType }));
      }
    }

    addImageFiles(files, "Pasted", { preferredIndex });
  } catch (error) {
    els.collage.focus();
    setStatus("Press Cmd+V now", "");
  }
}

function handlePaste(event) {
  const files = [];

  if (event.clipboardData?.items?.length) {
    for (const item of event.clipboardData.items) {
      if (item.type.startsWith("image/")) {
        const file = item.getAsFile();
        if (file) {
          files.push(file);
        }
      }
    }
  }

  if (!files.length && event.clipboardData?.files?.length) {
    files.push(...Array.from(event.clipboardData.files));
  }

  if (files.some((file) => file.type.startsWith("image/"))) {
    event.preventDefault();
    addImageFiles(files, "Pasted");
  }
}

function getTransferTypes(dataTransfer) {
  return Array.from(dataTransfer?.types || []);
}

function transferMayContainImage(dataTransfer) {
  const types = getTransferTypes(dataTransfer);
  return (
    types.includes("Files") ||
    types.includes("text/uri-list") ||
    types.includes("text/html") ||
    types.includes("text/plain")
  );
}

function normalizeURLCandidate(value) {
  const candidate = value?.trim();
  if (!candidate || candidate.startsWith("#")) {
    return "";
  }

  try {
    const url = new URL(candidate, window.location.href);
    return ["http:", "https:", "file:"].includes(url.protocol) ? url.href : "";
  } catch (error) {
    return "";
  }
}

function getImageURLFromTransfer(dataTransfer) {
  const candidates = [];
  const uriList = dataTransfer.getData("text/uri-list");
  if (uriList) {
    candidates.push(...uriList.split(/\r?\n/));
  }

  const html = dataTransfer.getData("text/html");
  if (html) {
    const doc = new DOMParser().parseFromString(html, "text/html");
    const imageSource = doc.querySelector("img[src], source[srcset]")?.getAttribute("src");
    const imageSet = doc.querySelector("source[srcset]")?.getAttribute("srcset")?.split(",")[0]?.trim().split(/\s+/)[0];
    const linkedSource = doc.querySelector("a[href]")?.getAttribute("href");
    candidates.push(imageSource, imageSet, linkedSource);
  }

  const plainText = dataTransfer.getData("text/plain");
  if (plainText) {
    candidates.push(...plainText.split(/\s+/));
  }

  return candidates.map(normalizeURLCandidate).find(Boolean) || "";
}

async function importImageURL(url, sourceLabel = "Dropped", preferredIndex = null) {
  const normalizedURL = normalizeURLCandidate(url);
  if (!normalizedURL) {
    setStatus("No image found in drop", "error");
    return;
  }

  if (sendNativeMessage({ type: "importImageURL", url: normalizedURL, sourceLabel, preferredIndex })) {
    setStatus("Importing image...", "");
    return;
  }

  try {
    const response = await fetch(normalizedURL);
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    const blob = await response.blob();
    if (!blob.type.startsWith("image/")) {
      throw new Error("Dropped URL is not an image");
    }
    const file = new File([blob], filenameFromURL(normalizedURL), { type: blob.type });
    addImageFiles([file], sourceLabel, { preferredIndex });
  } catch (error) {
    setStatus("Could not import dragged image", "error");
  }
}

function setDragVisual(active) {
  state.dragActive = active;
  if (!active) {
    state.dragTargetIndex = null;
  }
  els.appShell.classList.toggle("import-active", active);
  els.collage.classList.toggle("is-dragover", active);
  els.dropCard.classList.toggle("is-dragover", active);
  els.importVeil.setAttribute("aria-hidden", String(!active));
  updateImportVeil();
  syncSelection();
}

function handleDragOver(event) {
  if (!transferMayContainImage(event.dataTransfer)) {
    return;
  }

  event.preventDefault();
  event.stopPropagation();
  event.dataTransfer.dropEffect = "copy";

  const slot = getSlotFromEvent(event);
  const hoveredIndex = slot ? Number(slot.dataset.index) : state.selectedIndex;
  state.dragTargetIndex = getPredictedInsertIndex(hoveredIndex);
  setDragVisual(true);
}

function handleDragLeave(event) {
  if (
    event.clientX <= 0 ||
    event.clientY <= 0 ||
    event.clientX >= window.innerWidth ||
    event.clientY >= window.innerHeight
  ) {
    setDragVisual(false);
  }
}

function handleDrop(event) {
  if (!transferMayContainImage(event.dataTransfer)) {
    return;
  }

  event.preventDefault();
  event.stopPropagation();

  const slot = getSlotFromEvent(event);
  const hoveredIndex = slot ? Number(slot.dataset.index) : state.selectedIndex;
  const preferredIndex = state.dragTargetIndex ?? getPredictedInsertIndex(hoveredIndex);

  const files = Array.from(event.dataTransfer?.files || []).filter(isLikelyImageFile);
  const imageURL = files.length ? "" : getImageURLFromTransfer(event.dataTransfer);
  setDragVisual(false);

  if (files.length) {
    addImageFiles(files, "Dropped", { preferredIndex });
    return;
  }

  importImageURL(imageURL, "Dropped", preferredIndex);
}

function getCell(index) {
  const col = index % state.cols;
  const row = Math.floor(index / state.cols);
  const cellWidth = (state.width - state.gap * (state.cols - 1)) / state.cols;
  const cellHeight = (state.height - state.gap * (state.rows - 1)) / state.rows;

  return {
    x: col * (cellWidth + state.gap),
    y: row * (cellHeight + state.gap),
    width: cellWidth,
    height: cellHeight,
  };
}

function loadImage(src) {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = reject;
    image.src = src;
  });
}

function getBaseDrawRect(imageWidth, imageHeight, cell, fitMode = state.fit) {
  const scale =
    fitMode === "contain"
      ? Math.min(cell.width / imageWidth, cell.height / imageHeight)
      : Math.max(cell.width / imageWidth, cell.height / imageHeight);

  const width = imageWidth * scale;
  const height = imageHeight * scale;

  return {
    width,
    height,
    x: cell.x + (cell.width - width) / 2,
    y: cell.y + (cell.height - height) / 2,
  };
}

function getItemNaturalSize(item) {
  return {
    width: item.naturalWidth || 1,
    height: item.naturalHeight || 1,
  };
}

function constrainTransform(index) {
  const item = state.images[index];
  if (!item) {
    return;
  }

  item.scale = clamp(item.scale || 1, bounds.imageScale[0], bounds.imageScale[1]);

  if (!item.naturalWidth || !item.naturalHeight) {
    return;
  }

  const cell = getCell(index);
  const size = getItemNaturalSize(item);
  const base = getBaseDrawRect(size.width, size.height, cell, item.fit || state.fit);
  const scaledWidth = base.width * item.scale;
  const scaledHeight = base.height * item.scale;
  const maxX = Math.max(0, (scaledWidth - cell.width) / 2);
  const maxY = Math.max(0, (scaledHeight - cell.height) / 2);

  item.offsetX = clamp(item.offsetX || 0, -maxX, maxX);
  item.offsetY = clamp(item.offsetY || 0, -maxY, maxY);
}

function constrainAllTransforms() {
  for (let index = 0; index < getTotalSlots(); index += 1) {
    constrainTransform(index);
  }
}

function drawImageInCell(ctx, image, item, cell) {
  const imageWidth = image.naturalWidth || image.width;
  const imageHeight = image.naturalHeight || image.height;
  const fitMode = item.fit || state.fit;
  const base = getBaseDrawRect(imageWidth, imageHeight, cell, fitMode);
  const scale = item.scale || 1;
  const drawWidth = base.width * scale;
  const drawHeight = base.height * scale;
  const dx = cell.x + cell.width / 2 - drawWidth / 2 + (item.offsetX || 0);
  const dy = cell.y + cell.height / 2 - drawHeight / 2 + (item.offsetY || 0);

  if (fitMode === "contain") {
    ctx.fillStyle = "#f4f7f7";
    ctx.fillRect(cell.x, cell.y, cell.width, cell.height);
  }

  ctx.save();
  ctx.beginPath();
  ctx.rect(cell.x, cell.y, cell.width, cell.height);
  ctx.clip();
  ctx.drawImage(image, dx, dy, drawWidth, drawHeight);
  ctx.restore();
}

function drawRoundedRect(ctx, x, y, width, height, radius) {
  const safeRadius = Math.min(radius, width / 2, height / 2);
  ctx.beginPath();
  ctx.moveTo(x + safeRadius, y);
  ctx.lineTo(x + width - safeRadius, y);
  ctx.quadraticCurveTo(x + width, y, x + width, y + safeRadius);
  ctx.lineTo(x + width, y + height - safeRadius);
  ctx.quadraticCurveTo(x + width, y + height, x + width - safeRadius, y + height);
  ctx.lineTo(x + safeRadius, y + height);
  ctx.quadraticCurveTo(x, y + height, x, y + height - safeRadius);
  ctx.lineTo(x, y + safeRadius);
  ctx.quadraticCurveTo(x, y, x + safeRadius, y);
}

function drawTextAnnotation(ctx, annotation) {
  const text = annotation.text || "";
  const fontSize = annotation.fontSize || 30;
  const lines = text.split("\n").filter(Boolean);
  const safeLines = lines.length ? lines : [" "];
  const paddingX = fontSize * 0.42;
  const paddingY = fontSize * 0.28;
  const lineHeight = fontSize * 1.16;

  ctx.save();
  ctx.font = `650 ${fontSize}px "Avenir Next", "Helvetica Neue", sans-serif`;
  ctx.textBaseline = "top";

  const width = Math.max(...safeLines.map((line) => ctx.measureText(line).width)) + paddingX * 2;
  const height = safeLines.length * lineHeight + paddingY * 2;

  ctx.fillStyle = "rgba(255, 255, 252, 0.72)";
  drawRoundedRect(ctx, annotation.x, annotation.y, width, height, fontSize * 0.42);
  ctx.fill();
  ctx.strokeStyle = "rgba(25, 31, 36, 0.1)";
  ctx.lineWidth = Math.max(1, fontSize * 0.035);
  ctx.stroke();

  ctx.fillStyle = annotation.color || "#171b1f";
  safeLines.forEach((line, index) => {
    ctx.fillText(line, annotation.x + paddingX, annotation.y + paddingY + index * lineHeight);
  });
  ctx.restore();
}

function drawHighlightAnnotation(ctx, annotation) {
  const stroke = annotation.stroke || 4;
  const color = annotation.color || "#ba8359";

  ctx.save();
  ctx.fillStyle = `${color}1f`;
  drawRoundedRect(ctx, annotation.x, annotation.y, annotation.width, annotation.height, 18);
  ctx.fill();
  ctx.strokeStyle = color;
  ctx.lineWidth = stroke;
  ctx.setLineDash([Math.max(10, stroke * 3), Math.max(7, stroke * 2)]);
  drawRoundedRect(ctx, annotation.x, annotation.y, annotation.width, annotation.height, 18);
  ctx.stroke();
  ctx.setLineDash([]);

  if (annotation.text) {
    const fontSize = Math.max(15, stroke * 4.2);
    ctx.font = `700 ${fontSize}px "Avenir Next", "Helvetica Neue", sans-serif`;
    const paddingX = fontSize * 0.52;
    const paddingY = fontSize * 0.28;
    const labelWidth = ctx.measureText(annotation.text).width + paddingX * 2;
    const labelHeight = fontSize + paddingY * 2;
    const labelX = annotation.x + Math.min(14, annotation.width * 0.08);
    const labelY = Math.max(0, annotation.y - labelHeight * 0.48);

    ctx.fillStyle = "rgba(255, 255, 252, 0.88)";
    drawRoundedRect(ctx, labelX, labelY, labelWidth, labelHeight, labelHeight / 2);
    ctx.fill();
    ctx.fillStyle = color;
    ctx.textBaseline = "top";
    ctx.fillText(annotation.text, labelX + paddingX, labelY + paddingY);
  }
  ctx.restore();
}

function drawAnnotations(ctx) {
  state.annotations.forEach((annotation) => {
    constrainAnnotation(annotation);
    if (annotation.type === "highlight") {
      drawHighlightAnnotation(ctx, annotation);
      return;
    }
    drawTextAnnotation(ctx, annotation);
  });
}

async function renderCollageCanvas() {
  const canvas = document.createElement("canvas");
  canvas.width = state.width;
  canvas.height = state.height;

  const ctx = canvas.getContext("2d");
  ctx.fillStyle = "#ffffff";
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  const total = getTotalSlots();

  for (let index = 0; index < total; index += 1) {
    const cell = getCell(index);
    const item = state.images[index];

    if (!item) {
      ctx.fillStyle = "#f8faf9";
      ctx.fillRect(cell.x, cell.y, cell.width, cell.height);
      continue;
    }

    const image = await loadImage(item.url);
    drawImageInCell(ctx, image, item, cell);
  }

  drawAnnotations(ctx);

  return canvas;
}

function canvasToBlob(canvas) {
  return new Promise((resolve) => {
    canvas.toBlob((blob) => resolve(blob), "image/png", 1);
  });
}

async function exportCollage() {
  const canvas = await renderCollageCanvas();
  const fileName = `collage-${state.width}x${state.height}.png`;

  if (
    sendNativeMessage({
      type: "exportImage",
      dataUrl: canvas.toDataURL("image/png", 1),
      suggestedName: fileName,
    })
  ) {
    setStatus("Choose where to save", "");
    return;
  }

  const blob = await canvasToBlob(canvas);
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = fileName;
  document.body.append(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
  setStatus("Exported PNG", "success");
}

async function copyCollage() {
  if (window.__COLLAGE_NATIVE__) {
    try {
      const canvas = await renderCollageCanvas();
      if (sendNativeMessage({ type: "copyImage", dataUrl: canvas.toDataURL("image/png", 1) })) {
        setStatus("Copied collage PNG", "success");
        return;
      }
    } catch (error) {
      setStatus("Could not copy collage", "error");
      return;
    }
  }

  if (!navigator.clipboard?.write || typeof ClipboardItem === "undefined") {
    setStatus("Clipboard copy needs localhost or HTTPS", "error");
    return;
  }

  try {
    const canvas = await renderCollageCanvas();
    const blob = await canvasToBlob(canvas);
    await navigator.clipboard.write([new ClipboardItem({ "image/png": blob })]);
    setStatus("Copied collage PNG", "success");
  } catch (error) {
    setStatus("Copy blocked by browser permission", "error");
  }
}

function closePreview() {
  els.previewModal.hidden = true;
  els.appShell.classList.remove("preview-open");
  if (previewUrl) {
    URL.revokeObjectURL(previewUrl);
    previewUrl = "";
  }
  lastFocusedElement?.focus?.();
  lastFocusedElement = null;
}

async function openPreview() {
  lastFocusedElement = document.activeElement;
  const canvas = await renderCollageCanvas();
  const blob = await canvasToBlob(canvas);
  if (previewUrl) {
    URL.revokeObjectURL(previewUrl);
  }
  previewUrl = URL.createObjectURL(blob);
  els.previewImage.src = previewUrl;
  els.previewModal.hidden = false;
  els.appShell.classList.add("preview-open");
  els.closePreviewButton.focus();
  setStatus("Preview rendered", "success");
}

function adjustImageScale(index, factor) {
  const item = state.images[index];
  if (!item) {
    return;
  }

  item.scale = clamp((item.scale || 1) * factor, bounds.imageScale[0], bounds.imageScale[1]);
  constrainTransform(index);
  syncView();
}

function setImageScale(index, scale) {
  const item = state.images[index];
  if (!item) {
    return;
  }

  item.scale = clamp(scale, bounds.imageScale[0], bounds.imageScale[1]);
  constrainTransform(index);
  syncView();
}

function resetSelectedCrop() {
  const item = state.selectedIndex === null ? null : state.images[state.selectedIndex];
  if (!item) {
    return;
  }

  pushHistory();
  item.scale = 1;
  item.offsetX = 0;
  item.offsetY = 0;
  constrainTransform(state.selectedIndex);
  syncView();
  setStatus("Crop reset", "success");
}

function clearSelectedSlot() {
  if (state.selectedIndex === null) {
    return;
  }

  const item = state.images[state.selectedIndex];
  if (!item) {
    return;
  }

  pushHistory();
  state.images[state.selectedIndex] = null;
  render();
  setStatus("Slot cleared", "success");
}

function nudgeSelectedImage(deltaX, deltaY) {
  const item = state.selectedIndex === null ? null : state.images[state.selectedIndex];
  if (!item) {
    return;
  }

  checkpointContinuousAction("image-nudge");
  item.offsetX = (item.offsetX || 0) + deltaX;
  item.offsetY = (item.offsetY || 0) + deltaY;
  constrainTransform(state.selectedIndex);
  syncView();
}

function createAnnotation(type) {
  pushHistory();
  const frame = getAnnotationDefaultFrame(type);
  const annotation = {
    id: `annotation-${annotationIdCounter}`,
    type,
    x: frame.x,
    y: frame.y,
    color: type === "highlight" ? "#ba8359" : "#171b1f",
    text: type === "highlight" ? "Focus" : "New note",
  };

  annotationIdCounter += 1;

  if (type === "highlight") {
    annotation.width = frame.width;
    annotation.height = frame.height;
    annotation.stroke = 4;
  } else {
    annotation.fontSize = 30;
  }

  constrainAnnotation(annotation);
  state.annotations.push(annotation);
  state.selectedAnnotationId = annotation.id;
  state.selectedIndex = null;
  state.inspectorPinned = true;
  syncView();
  setStatus(type === "highlight" ? "Focus box added" : "Text layer added", "success");
}

function updateSelectedAnnotation(updates) {
  const annotation = getSelectedAnnotation();
  if (!annotation) {
    return;
  }

  Object.assign(annotation, updates);
  constrainAnnotation(annotation);
  syncView();
}

function deleteSelectedAnnotation() {
  if (!state.selectedAnnotationId) {
    return;
  }

  pushHistory();
  state.annotations = state.annotations.filter((annotation) => annotation.id !== state.selectedAnnotationId);
  state.selectedAnnotationId = null;
  syncView();
  setStatus("Annotation removed", "success");
}

function nudgeSelectedAnnotation(deltaX, deltaY) {
  const annotation = getSelectedAnnotation();
  if (!annotation) {
    return;
  }

  checkpointContinuousAction("annotation-nudge");
  annotation.x += deltaX;
  annotation.y += deltaY;
  constrainAnnotation(annotation);
  syncView();
}

function startAnnotationPointer(event) {
  const node = event.currentTarget;
  const annotation = state.annotations.find((item) => item.id === node.dataset.annotationId);
  if (!annotation) {
    return;
  }

  event.preventDefault();
  event.stopPropagation();
  pushHistory();
  state.selectedAnnotationId = annotation.id;
  state.selectedIndex = null;
  state.inspectorPinned = true;

  const resizing = annotation.type === "highlight" && event.target.closest?.(".annotation-resize");
  const startX = event.clientX;
  const startY = event.clientY;
  const startAnnotation = {
    x: annotation.x,
    y: annotation.y,
    width: annotation.width,
    height: annotation.height,
  };

  node.classList.add("is-dragging");
  node.setPointerCapture?.(event.pointerId);

  function move(pointerEvent) {
    const deltaX = (pointerEvent.clientX - startX) / state.zoom;
    const deltaY = (pointerEvent.clientY - startY) / state.zoom;

    if (resizing) {
      annotation.width = startAnnotation.width + deltaX;
      annotation.height = startAnnotation.height + deltaY;
    } else {
      annotation.x = startAnnotation.x + deltaX;
      annotation.y = startAnnotation.y + deltaY;
    }

    constrainAnnotation(annotation);
    syncView();
  }

  function stop() {
    node.classList.remove("is-dragging");
    window.removeEventListener("pointermove", move);
    window.removeEventListener("pointerup", stop);
    window.removeEventListener("pointercancel", stop);
  }

  window.addEventListener("pointermove", move);
  window.addEventListener("pointerup", stop, { once: true });
  window.addEventListener("pointercancel", stop, { once: true });
}

function getSlotFromEvent(event) {
  const slot = event.target.closest?.(".slot");
  if (!slot || !els.collage.contains(slot)) {
    return null;
  }
  return slot;
}

function handleImageWheel(event) {
  const slot = getSlotFromEvent(event);
  if (!slot) {
    return;
  }

  const index = Number(slot.dataset.index);
  if (!state.images[index]) {
    return;
  }

  event.preventDefault();
  selectSlot(index);
  checkpointContinuousAction(`image-wheel-${index}`);
  const factor = Math.exp(-event.deltaY * 0.002);
  adjustImageScale(index, factor);
}

function startImageGesture(event) {
  const slot = getSlotFromEvent(event);
  if (!slot) {
    return;
  }

  const index = Number(slot.dataset.index);
  const item = state.images[index];
  if (!item) {
    return;
  }

  event.preventDefault();
  selectSlot(index);
  pushHistory();
  gestureState = {
    index,
    startScale: item.scale || 1,
  };
}

function changeImageGesture(event) {
  if (!gestureState) {
    return;
  }

  event.preventDefault();
  const item = state.images[gestureState.index];
  if (!item) {
    return;
  }

  item.scale = clamp(gestureState.startScale * event.scale, bounds.imageScale[0], bounds.imageScale[1]);
  constrainTransform(gestureState.index);
  syncView();
}

function endImageGesture() {
  gestureState = null;
}

function startImageDrag(event) {
  const slot = getSlotFromEvent(event);
  if (!slot || event.target.closest?.(".remove-image") || event.target.classList.contains("resize-handle")) {
    return;
  }

  const index = Number(slot.dataset.index);
  const item = state.images[index];
  selectSlot(index);

  if (!item) {
    return;
  }

  event.preventDefault();
  pushHistory();
  slot.classList.add("is-dragging");
  slot.setPointerCapture?.(event.pointerId);

  const startX = event.clientX;
  const startY = event.clientY;
  const startOffsetX = item.offsetX || 0;
  const startOffsetY = item.offsetY || 0;

  function move(pointerEvent) {
    item.offsetX = startOffsetX + (pointerEvent.clientX - startX) / state.zoom;
    item.offsetY = startOffsetY + (pointerEvent.clientY - startY) / state.zoom;
    constrainTransform(index);
    syncView();
  }

  function stop() {
    slot.classList.remove("is-dragging");
    window.removeEventListener("pointermove", move);
    window.removeEventListener("pointerup", stop);
    window.removeEventListener("pointercancel", stop);
  }

  window.addEventListener("pointermove", move);
  window.addEventListener("pointerup", stop, { once: true });
  window.addEventListener("pointercancel", stop, { once: true });
}

function openFilePicker(options = null) {
  pendingFileImport = options;
  els.fileInput.click();
}

function bindControls() {
  [els.windowDragStrip, els.windowDragBrand].forEach((dragRegion) => {
    dragRegion.addEventListener("pointerdown", (event) => {
      if (event.button !== 0 || !sendNativeMessage({ type: "beginWindowDrag" })) {
        return;
      }
      event.preventDefault();
      event.stopPropagation();
    });
  });

  els.uploadButton.addEventListener("click", () => openFilePicker());
  els.toolbarUploadButton.addEventListener("click", () => openFilePicker());
  els.emptyUploadButton.addEventListener("click", () => openFilePicker());
  els.fileInput.addEventListener("change", (event) => {
    const importOptions = pendingFileImport || {};
    pendingFileImport = null;
    addImageFiles(event.target.files, importOptions.replaceIndex === undefined ? "Uploaded" : "Selected", importOptions);
    event.target.value = "";
    closeCommandMenus();
  });

  els.pasteButton.addEventListener("click", readClipboardImages);
  els.toolbarPasteButton.addEventListener("click", readClipboardImages);
  els.emptyPasteButton.addEventListener("click", readClipboardImages);
  els.addMenuButton.addEventListener("click", () => toggleCommandMenu("add"));
  els.moreMenuButton.addEventListener("click", () => toggleCommandMenu("more"));
  els.addTextButton.addEventListener("click", () => {
    closeCommandMenus();
    createAnnotation("text");
  });
  els.addHighlightButton.addEventListener("click", () => {
    closeCommandMenus();
    createAnnotation("highlight");
  });
  els.autoLayoutButton.addEventListener("click", autoArrangeLayout);
  els.inspectorAddTextButton.addEventListener("click", () => createAnnotation("text"));
  els.inspectorAddHighlightButton.addEventListener("click", () => createAnnotation("highlight"));
  els.dropCard.addEventListener("click", () => openFilePicker());
  document.addEventListener("paste", handlePaste);
  els.toggleControlsButton.addEventListener("click", () => {
    state.controlsOpen = !state.controlsOpen;
    syncView();
  });
  els.toggleInspectorButton?.addEventListener("click", () => {
    state.inspectorPinned = !state.inspectorPinned;
    syncView();
  });
  els.closeControlsButton.addEventListener("click", () => {
    state.controlsOpen = false;
    syncView();
  });
  els.closeInspectorButton.addEventListener("click", () => {
    state.inspectorPinned = false;
    syncView();
  });
  document.addEventListener("keydown", (event) => {
    const isTyping = !!event.target.closest?.("input, textarea, [contenteditable='true']");

    if (!isTyping && event.metaKey && event.key.toLowerCase() === "z") {
      event.preventDefault();
      if (event.shiftKey) {
        redoProject();
      } else {
        undoProject();
      }
      return;
    }

    if (!isTyping && event.metaKey && event.key.toLowerCase() === "n") {
      event.preventDefault();
      startFreshProject();
      return;
    }

    if (
      !isTyping &&
      event.altKey &&
      state.selectedIndex !== null &&
      (event.key === "ArrowLeft" || event.key === "ArrowRight")
    ) {
      event.preventDefault();
      moveSelectedImage(event.key === "ArrowLeft" ? -1 : 1);
      return;
    }

    if (
      !isTyping &&
      event.code === "Space" &&
      !event.target.closest?.("button, .slot, .annotation-item")
    ) {
      event.preventDefault();
      if (els.previewModal.hidden) {
        openPreview();
      } else {
        closePreview();
      }
      return;
    }

    if (event.key !== "Escape") {
      if (!isTyping && state.selectedAnnotationId && (event.key === "Delete" || event.key === "Backspace")) {
        event.preventDefault();
        deleteSelectedAnnotation();
        return;
      }

      if (
        !isTyping &&
        state.selectedIndex !== null &&
        state.images[state.selectedIndex] &&
        (event.key === "Delete" || event.key === "Backspace")
      ) {
        event.preventDefault();
        clearSelectedSlot();
        return;
      }

      const annotationNudges = {
        ArrowUp: [0, -1],
        ArrowRight: [1, 0],
        ArrowDown: [0, 1],
        ArrowLeft: [-1, 0],
      };
      if (!isTyping && state.selectedAnnotationId && annotationNudges[event.key]) {
        event.preventDefault();
        const [deltaX, deltaY] = annotationNudges[event.key];
        const multiplier = event.shiftKey ? 12 : 3;
        nudgeSelectedAnnotation(deltaX * multiplier, deltaY * multiplier);
        return;
      }

      return;
    }
    if (!els.previewModal.hidden) {
      closePreview();
      return;
    }
    if (state.addMenuOpen || state.moreMenuOpen) {
      const returnTarget = state.moreMenuOpen ? els.moreMenuButton : els.addMenuButton;
      closeCommandMenus();
      returnTarget.focus();
      return;
    }
    if (state.controlsOpen || state.inspectorPinned) {
      state.controlsOpen = false;
      state.inspectorPinned = false;
      syncView();
      return;
    }
    state.controlsOpen = false;
    state.inspectorPinned = false;
    state.selectedIndex = null;
    state.selectedAnnotationId = null;
    syncView();
  });

  els.rowsInput.addEventListener("change", (event) => setNumericValue("rows", event.target.value));
  els.colsInput.addEventListener("change", (event) => setNumericValue("cols", event.target.value));
  els.widthInput.addEventListener("change", (event) => setNumericValue("width", event.target.value, 10));
  els.heightInput.addEventListener("change", (event) => setNumericValue("height", event.target.value, 10));
  els.gapInput.addEventListener("change", (event) => setNumericValue("gap", event.target.value));

  document.querySelectorAll("[data-step]").forEach((button) => {
    button.addEventListener("click", () => {
      const key = button.dataset.step;
      const delta = Number(button.dataset.delta);
      const step = key === "width" || key === "height" ? 10 : 1;
      setNumericValue(key, state[key] + delta, step);
    });
  });

  document.querySelectorAll("[data-preset]").forEach((button) => {
    button.addEventListener("click", () => {
      const [rows, cols] = button.dataset.preset.split(",").map(Number);
      if (rows === state.rows && cols === state.cols) {
        return;
      }
      pushHistory();
      state.rows = rows;
      state.cols = cols;
      normalizeSelection();
      constrainAllTransforms();
      render();
      setStatus(`${cols}×${rows} layout`, "success");
    });
  });

  document.querySelectorAll("[data-size]").forEach((button) => {
    button.addEventListener("click", () => {
      const [width, height] = button.dataset.size.split(",").map(Number);
      if (width === state.width && height === state.height) {
        return;
      }
      pushHistory();
      state.width = clamp(width, bounds.width[0], bounds.width[1]);
      state.height = clamp(height, bounds.height[0], bounds.height[1]);
      constrainAllTransforms();
      constrainAnnotations();
      syncView();
      setStatus(`${state.width}×${state.height} canvas`, "success");
    });
  });

  els.fillButton.addEventListener("click", () => {
    const item = state.selectedIndex === null ? null : state.images[state.selectedIndex];
    if ((item?.fit || state.fit) === "cover") {
      return;
    }
    pushHistory();
    if (item) {
      item.fit = "cover";
    } else {
      state.fit = "cover";
    }
    constrainAllTransforms();
    syncView();
  });
  els.fitButton.addEventListener("click", () => {
    const item = state.selectedIndex === null ? null : state.images[state.selectedIndex];
    if ((item?.fit || state.fit) === "contain") {
      return;
    }
    pushHistory();
    if (item) {
      item.fit = "contain";
    } else {
      state.fit = "contain";
    }
    constrainAllTransforms();
    syncView();
  });

  els.zoomOutButton.addEventListener("click", () => {
    state.autoZoom = false;
    state.zoom = clamp(Number((state.zoom - 0.1).toFixed(2)), bounds.zoom[0], bounds.zoom[1]);
    syncView();
  });
  els.zoomInButton.addEventListener("click", () => {
    state.autoZoom = false;
    state.zoom = clamp(Number((state.zoom + 0.1).toFixed(2)), bounds.zoom[0], bounds.zoom[1]);
    syncView();
  });

  els.imageScaleInput.addEventListener("input", (event) => {
    if (state.selectedIndex === null) {
      return;
    }
    setImageScale(state.selectedIndex, Number(event.target.value) / 100);
  });
  els.imageScaleInput.addEventListener("pointerdown", () => pushHistory());

  els.contextScaleInput.addEventListener("input", (event) => {
    if (state.selectedIndex === null) {
      return;
    }
    setImageScale(state.selectedIndex, Number(event.target.value) / 100);
  });
  els.contextScaleInput.addEventListener("pointerdown", () => pushHistory());

  els.annotationTextInput.addEventListener("focus", () => pushHistory());
  els.annotationTextInput.addEventListener("input", (event) => {
    updateSelectedAnnotation({ text: event.target.value });
  });

  els.annotationSizeInput.addEventListener("input", (event) => {
    const annotation = getSelectedAnnotation();
    if (!annotation) {
      return;
    }
    const value = Number(event.target.value);
    updateSelectedAnnotation(annotation.type === "highlight" ? { stroke: value } : { fontSize: value });
  });
  els.annotationSizeInput.addEventListener("pointerdown", () => pushHistory());

  document.querySelectorAll("[data-annotation-color]").forEach((button) => {
    button.style.setProperty("--swatch-color", button.dataset.annotationColor);
    button.addEventListener("click", () => {
      pushHistory();
      updateSelectedAnnotation({ color: button.dataset.annotationColor });
    });
  });

  document.querySelectorAll("[data-nudge]").forEach((button) => {
    button.addEventListener("click", () => {
      const [deltaX, deltaY] = button.dataset.nudge.split(",").map(Number);
      nudgeSelectedImage(deltaX, deltaY);
    });
  });

  els.resetCropButton.addEventListener("click", resetSelectedCrop);
  els.clearSlotButton.addEventListener("click", clearSelectedSlot);
  els.replaceButton.addEventListener("click", () => openFilePicker({ replaceIndex: state.selectedIndex }));
  els.deleteAnnotationButton.addEventListener("click", deleteSelectedAnnotation);
  els.moveImageBackButton.addEventListener("click", () => moveSelectedImage(-1));
  els.moveImageForwardButton.addEventListener("click", () => moveSelectedImage(1));
  els.contextResetCropButton.addEventListener("click", resetSelectedCrop);
  els.contextReplaceButton.addEventListener("click", () => openFilePicker({ replaceIndex: state.selectedIndex }));
  els.contextInspectorButton.addEventListener("click", () => {
    state.inspectorPinned = true;
    syncView();
  });
  els.contextClearButton.addEventListener("click", clearSelectedSlot);

  els.previewButton.addEventListener("click", () => {
    closeCommandMenus();
    openPreview();
  });
  els.exportButton.addEventListener("click", () => {
    closeCommandMenus();
    exportCollage();
  });
  els.copyButton.addEventListener("click", copyCollage);
  els.snapLeftButton?.addEventListener("click", () => {
    closeCommandMenus();
    if (sendNativeMessage({ type: "snapLeft" })) {
      setStatus("Ready for split view", "success");
      return;
    }
    setStatus("Split view is available in the Mac app", "error");
  });
  els.closePreviewButton.addEventListener("click", closePreview);
  els.previewBackdrop.addEventListener("click", closePreview);
  els.previewExportButton.addEventListener("click", exportCollage);
  els.previewCopyButton.addEventListener("click", copyCollage);

  document.addEventListener("pointerdown", (event) => {
    if (!event.target.closest?.(".command-menu-wrap")) {
      closeCommandMenus();
    }
  });

  els.workspace.addEventListener("dragover", handleDragOver);
  els.workspace.addEventListener("drop", handleDrop);
  els.collage.addEventListener("pointerdown", startResize);
  els.collage.addEventListener("pointerdown", startImageDrag);
  els.collage.addEventListener("wheel", handleImageWheel, { passive: false });
  els.collage.addEventListener("gesturestart", startImageGesture, { passive: false });
  els.collage.addEventListener("gesturechange", changeImageGesture, { passive: false });
  els.collage.addEventListener("gestureend", endImageGesture);
  els.collage.addEventListener("gesturecancel", endImageGesture);
  els.collage.addEventListener("dragover", handleDragOver);
  els.collage.addEventListener("dragleave", handleDragLeave);
  els.collage.addEventListener("drop", handleDrop);
  els.dropCard.addEventListener("dragover", handleDragOver);
  els.dropCard.addEventListener("dragleave", handleDragLeave);
  els.dropCard.addEventListener("drop", handleDrop);
  window.addEventListener("dragleave", handleDragLeave);
  window.addEventListener("dragend", () => setDragVisual(false));
  els.stageScroll.addEventListener("scroll", positionImageContextBar, { passive: true });
  window.addEventListener("beforeunload", () => {
    state.images.forEach((image) => {
      if (image?.url) {
        URL.revokeObjectURL(image.url);
      }
    });
  });
  window.addEventListener("resize", () => {
    syncCommandMenus();
    if (state.autoZoom) {
      syncView();
    }
  });
}

function startResize(event) {
  if (!event.target.classList.contains("resize-handle")) {
    return;
  }

  event.preventDefault();
  pushHistory();
  const startX = event.clientX;
  const startY = event.clientY;
  const startWidth = state.width;
  const startHeight = state.height;

  function move(pointerEvent) {
    const nextWidth = startWidth + (pointerEvent.clientX - startX) / state.zoom;
    const nextHeight = startHeight + (pointerEvent.clientY - startY) / state.zoom;
    state.width = clamp(roundTo(nextWidth, 10), bounds.width[0], bounds.width[1]);
    state.height = clamp(roundTo(nextHeight, 10), bounds.height[0], bounds.height[1]);
    constrainAllTransforms();
    constrainAnnotations();
    syncView();
  }

  function stop() {
    window.removeEventListener("pointermove", move);
    window.removeEventListener("pointerup", stop);
  }

  window.addEventListener("pointermove", move);
  window.addEventListener("pointerup", stop, { once: true });
}

async function initializeApp() {
  bindControls();
  const restored = await restoreSavedProject();
  projectReady = true;
  render();
  if (restored && (getFilledImageCount() || state.annotations.length)) {
    setStatus("Restored your last collage", "success");
  }
}

initializeApp();

window.collageAtelierCommands = {
  copy: copyCollage,
  export: exportCollage,
  preview: openPreview,
  newProject: startFreshProject,
  undo: () => runUndoCommand(false),
  redo: () => runUndoCommand(true),
};
