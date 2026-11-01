const ui = document.getElementById('death-ui');
const el = (id) => document.getElementById(id);
let currentPhase = null;
let currentAidocStage = null;

const stageCopy = {
    idle: ['REQUEST PRIVATE PARAMEDIC', 'Available now · call-out fee applies', 'READY'],
    requesting: ['CONTACTING MEDICAL NETWORK', 'Checking availability and payment', 'CONNECTING'],
    enroute: ['PRIVATE PARAMEDIC DISPATCHED', 'Track the responding ambulance on your map', 'EN ROUTE'],
    arriving: ['PARAMEDIC ON SCENE', 'The doctor is approaching your position', 'ARRIVING'],
    extracting: ['CASUALTY EXTRACTION', 'The doctor is pulling you clear of the vehicle', 'EXTRACTING'],
    treating: ['EMERGENCY TREATMENT', 'Remain still while the doctor stabilises you', 'TREATING'],
    offline: ['PRIVATE PARAMEDIC UNAVAILABLE', 'Medical dispatch is currently offline', 'OFFLINE']
};

function time(value) {
    const seconds = Math.max(0, Number(value) || 0);
    return `${String(Math.floor(seconds / 60)).padStart(2, '0')}:${String(seconds % 60).padStart(2, '0')}`;
}

function money(value) {
    return new Intl.NumberFormat('en-GB').format(Number(value) || 0);
}

function colour(value) {
    let hex = String(value || '#8e1722').replace('#', '').trim();
    if (hex.length === 3) hex = hex.split('').map((part) => part + part).join('');
    const parsed = Number.parseInt(hex, 16);
    if (hex.length !== 6 || Number.isNaN(parsed)) return [142, 23, 34];
    return [(parsed >> 16) & 255, (parsed >> 8) & 255, parsed & 255];
}

function setMedicalVeil(overlay = {}) {
    const rgb = colour(overlay.colour);
    const style = el('medical-veil').style;
    style.setProperty('--med-r', rgb[0]);
    style.setProperty('--med-g', rgb[1]);
    style.setProperty('--med-b', rgb[2]);
    style.setProperty('--med-tint', Number(overlay.tint) || 0);
    style.setProperty('--med-haze', Number(overlay.haze) || 0);
    style.setProperty('--med-bright', Number(overlay.brightness) || 0);
    style.setProperty('--med-pulse', `${Number(overlay.pulse) || 3.8}s`);
}

function show() {
    if (!ui.classList.contains('hidden')) return;
    ui.classList.remove('hidden');
    ui.classList.add('entering');
    setTimeout(() => ui.classList.remove('entering'), 750);
}

function setTimer(value) {
    const timer = el('timer-value');
    const next = String(value);
    if (timer.textContent === next) return;
    timer.textContent = next;
    const shell = timer.parentElement;
    shell.classList.remove('tick');
    void shell.offsetWidth;
    shell.classList.add('tick');
}

function setPhase(phase) {
    if (currentPhase === phase) return;
    const wasDown = currentPhase !== null;
    currentPhase = phase;
    ui.classList.remove('phase-change', 'flatline-hit');
    void ui.offsetWidth;
    if (wasDown) ui.classList.add('phase-change');
    if (phase === 'dead' && wasDown) ui.classList.add('flatline-hit');
    setTimeout(() => ui.classList.remove('phase-change', 'flatline-hit'), 900);
}

function updateLaststand(data) {
    setPhase('laststand');
    setMedicalVeil(data.overlay);
    ui.classList.remove('dead');
    el('telemetry-label').textContent = 'TRAUMA RESPONSE';
    el('phase-kicker').textContent = 'CRITICAL CONDITION';
    el('phase-title').textContent = 'Stay conscious.';
    el('phase-detail').textContent = 'Your condition is deteriorating. Help can still reach you.';
    el('timer-label').textContent = 'BLEEDOUT';
    setTimer(time(data.seconds));

    el('laststand-actions').classList.remove('hidden');
    el('dead-action').classList.add('hidden');

    const aidoc = data.aidoc || {};
    const stage = aidoc.available === false ? 'offline' : (aidoc.stage || 'idle');
    const copy = stageCopy[stage] || stageCopy.idle;
    const card = el('aidoc-action');
    if (currentAidocStage !== stage) {
        currentAidocStage = stage;
        card.classList.remove('stage-change');
        void card.offsetWidth;
        card.classList.add('stage-change');
    }
    card.classList.toggle('locked', stage === 'offline');
    card.classList.toggle('active', !['idle', 'offline'].includes(stage));
    card.classList.toggle('responding', ['requesting', 'enroute', 'arriving', 'extracting', 'treating'].includes(stage));
    el('aidoc-key').textContent = aidoc.key || 'H';
    el('aidoc-title').textContent = copy[0];
    el('aidoc-detail').textContent = stage === 'idle' && aidoc.price
        ? `Available now · £${money(aidoc.price)} call-out fee`
        : copy[1];
    el('aidoc-status').textContent = copy[2];

    const ems = el('ems-action');
    const notified = Boolean(data.emsNotified);
    ems.classList.toggle('locked', !data.canAlertEms || notified);
    el('ems-detail').textContent = notified
        ? 'Your location has been sent to on-duty medics'
        : data.canAlertEms
            ? 'Send your current position to emergency dispatch'
            : 'Emergency dispatch is monitoring your condition';
    el('ems-status').textContent = notified ? 'SENT' : data.canAlertEms ? 'AVAILABLE' : 'STANDBY';
}

function updateDead(data) {
    setPhase('dead');
    ui.classList.add('dead');
    el('telemetry-label').textContent = 'VITAL LINK LOST';
    el('phase-kicker').textContent = 'LIFE SIGNS LOST';
    el('phase-title').textContent = 'Cardiac arrest.';
    el('phase-detail').textContent = data.defibAttempted
        ? 'Defibrillation has been attempted. Await hospital transfer.'
        : 'One defibrillation attempt may still restore a pulse.';
    el('timer-label').textContent = data.respawnReady ? 'TRANSFER READY' : 'RECOVERY WINDOW';
    setTimer(data.respawnReady ? '00:00' : time(data.seconds));

    el('laststand-actions').classList.add('hidden');
    el('dead-action').classList.remove('hidden');

    const card = el('respawn-action');
    const hold = Math.max(0, Math.min(5, Number(data.respawnHold) || 0));
    card.classList.toggle('locked', !data.respawnReady);
    el('respawn-title').textContent = data.respawnReady ? 'HOLD TO TRANSFER TO HOSPITAL' : 'HOSPITAL TRANSFER LOCKED';
    el('respawn-detail').textContent = data.respawnReady
        ? `Hold E · treatment charge £${money(data.respawnCost)}`
        : data.defibAttempted
            ? `Available in ${time(data.seconds)} · defibrillation exhausted`
            : `Available in ${time(data.seconds)} · one defibrillation attempt remains`;
    el('respawn-status').textContent = data.respawnReady ? (hold < 5 ? `${hold} SEC` : 'HOLD E') : 'WAIT';
    el('hold-progress').style.setProperty('--hold', `${data.respawnReady ? ((5 - hold) / 5) * 100 : 0}%`);
}

window.addEventListener('message', ({ data }) => {
    if (!data || !data.action) return;

    if (data.action === 'death:hide') {
        ui.classList.add('hidden');
        ui.classList.remove('dead', 'entering', 'phase-change', 'flatline-hit');
        currentPhase = null;
        currentAidocStage = null;
        return;
    }

    if (data.action !== 'death:update') return;
    show();
    if (data.phase === 'laststand') updateLaststand(data);
    else updateDead(data);
});
