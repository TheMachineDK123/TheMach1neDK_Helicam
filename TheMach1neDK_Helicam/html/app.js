const root = document.getElementById('root');

const elAlt = document.getElementById('alt');
const elHdg = document.getElementById('hdg');
const elGps = document.getElementById('gps');
const elFov = document.getElementById('fov');
const elModel = document.getElementById('model');
const elPlate = document.getElementById('plate');
const elSpeed = document.getElementById('speed');
const elDist = document.getElementById('dist');

const stLocked = document.getElementById('stLocked');
const stRec = document.getElementById('stRec');
const stSpot = document.getElementById('stSpot');
const stNV = document.getElementById('stNV');
const stTH = document.getElementById('stTH');

const recLabel = document.getElementById('recLabel');

const toast = document.getElementById('toast');
let toastTimer = null;

function showToast(text) {
  toast.textContent = text;
  toast.classList.add('show');
  if (toastTimer) clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.remove('show'), 900);
}

function setText(el, txt) {
  el.textContent = (txt === null || txt === undefined || txt === '') ? '-' : String(txt);
}

function setPill(el, onText, offText, state) {
  el.textContent = state ? onText : offText;
  if (state) {
    el.classList.add('active');
  } else {
    el.classList.remove('active');
  }
}

function setRecordingMode(recording) {
  if (recording) {
    root.classList.add('rec');
    stRec.classList.add('recording');
    recLabel.classList.remove('hidden');
  } else {
    root.classList.remove('rec');
    stRec.classList.remove('recording');
    recLabel.classList.add('hidden');
  }
}

async function copyToClipboard(text) {
  try {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      await navigator.clipboard.writeText(text);
      return true;
    }
  } catch (_) {}

  try {
    const tmp = document.createElement('textarea');
    tmp.value = text;
    tmp.style.position = 'fixed';
    tmp.style.left = '-1000px';
    tmp.style.top = '-1000px';
    document.body.appendChild(tmp);
    tmp.focus();
    tmp.select();
    const ok = document.execCommand('copy');
    document.body.removeChild(tmp);
    return ok;
  } catch (_) {
    return false;
  }
}

window.addEventListener('message', async (event) => {
  const data = event.data;
  if (!data || !data.type) return;

  if (data.type === 'state') {
    if (data.active) {
      root.classList.remove('hidden');
    } else {
      root.classList.add('hidden');
    }

    const p = data.payload || {};
    setPill(stLocked, 'LÅST', 'ULÅST', !!p.locked);
    setPill(stRec, 'REC', 'NORMAL', !!p.recording);
    setPill(stSpot, 'SPOT: ON', 'SPOT: OFF', !!p.spotlight);
    setPill(stNV, 'NV: ON', 'NV: OFF', !!p.nightVision);
    setPill(stTH, 'TH: ON', 'TH: OFF', !!p.thermal);

    setRecordingMode(!!p.recording);

    return;
  }

  if (data.type === 'update') {
    const p = data.payload || {};

    if (typeof p.alt === 'number') {
      setText(elAlt, `${Math.round(p.alt)} m`);
    }
    if (typeof p.hdg === 'number') {
      setText(elHdg, `${Math.round(p.hdg)}°`);
    }
    if (typeof p.gpsX === 'number' && typeof p.gpsY === 'number') {
      setText(elGps, `${p.gpsX.toFixed(1)}, ${p.gpsY.toFixed(1)}`);
    }
    if (typeof p.fov === 'number') {
      setText(elFov, p.fov.toFixed(1));
    }

    setPill(stLocked, 'LÅST', 'ULÅST', !!p.locked);
    setPill(stRec, 'REC', 'NORMAL', !!p.recording);
    setPill(stSpot, 'SPOT: ON', 'SPOT: OFF', !!p.spotlight);
    setPill(stNV, 'NV: ON', 'NV: OFF', !!p.nightVision);
    setPill(stTH, 'TH: ON', 'TH: OFF', !!p.thermal);

    setRecordingMode(!!p.recording);

    if (p.hasTarget) {
      setText(elModel, p.model);
      setText(elPlate, p.plate);
      setText(elSpeed, `${p.speed} km/t`);
      if (typeof p.dist === 'number') {
        setText(elDist, `${Math.round(p.dist)} m`);
      } else {
        setText(elDist, '-');
      }
    } else {
      setText(elModel, '-');
      setText(elPlate, '-');
      setText(elSpeed, '-');
      setText(elDist, '-');
    }

    return;
  }

  if (data.type === 'copyPlate') {
    const plate = data.plate || '';
    if (!plate) return;

    const ok = await copyToClipboard(plate);
    showToast(ok ? `Kopieret: ${plate}` : `Kunne ikke kopiere: ${plate}`);
    return;
  }
});

window.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    fetch(`https://${GetParentResourceName()}/close`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify({})
    }).catch(() => {});
  }
});
