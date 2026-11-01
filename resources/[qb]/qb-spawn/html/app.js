// Aurora spawn select — presentation only. Stock protocol preserved:
//   in : showUi { status, translations } / setupLocations { locations, houses, isNew }
//        / setupAppartements { locations, isNew }
//   out: setCam { posname, type } / spawnplayer { spawnloc, typeLoc }
//        / chooseAppa { appType }
// client.lua's spawn/camera logic is untouched.

const resource = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'qb-spawn';
const post = (name, data) => fetch(`https://${resource}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data || {}),
});

const app = document.getElementById('app');
const cardsEl = document.getElementById('cards');
const confirmBtn = document.getElementById('confirm');
const subEl = document.getElementById('titlecard-sub');
const hintConfirmEl = document.getElementById('hint-confirm');

const META = { current: 'Continue', normal: 'District', house: 'Residence', appartment: 'Apartment' };

let options = [];        // { type, name, label }
let selected = -1;
let translations = {};
let lastSetup = null;    // most recent setup* payload, re-rendered once translations arrive
let previewTimer = null;

function t(key, fallback) {
    return (translations && translations[key]) || fallback;
}

function buildOptions() {
    options = [];
    if (!lastSetup) return;
    if (lastSetup.kind === 'locations') {
        if (!lastSetup.isNew) {
            options.push({ type: 'current', name: 'current', label: t('last_location', 'Last Location') });
        }
        for (const key of Object.keys(lastSetup.locations || {})) {
            options.push({ type: 'normal', name: key, label: lastSetup.locations[key].label || key });
        }
        // an empty Lua table arrives as {} (object), not [] - never for..of it
        const houses = Array.isArray(lastSetup.houses) ? lastSetup.houses
            : Object.values(lastSetup.houses || {});
        for (const h of houses) {
            options.push({ type: 'house', name: h.house, label: h.label || h.house });
        }
    } else { // apartments (fresh character with Apartments.Starting)
        for (const key of Object.keys(lastSetup.locations || {})) {
            options.push({ type: 'appartment', name: key, label: lastSetup.locations[key].label || key });
        }
    }
}

function render() {
    buildOptions();
    cardsEl.innerHTML = '';
    options.forEach((opt, i) => {
        const card = document.createElement('div');
        card.className = 'card' + (i === selected ? ' selected' : '');
        const tl = document.createElement('div'); tl.className = 'corner tl';
        const br = document.createElement('div'); br.className = 'corner br';
        const label = document.createElement('div'); label.className = 'card-label'; label.textContent = opt.label;
        const meta = document.createElement('div'); meta.className = 'card-meta'; meta.textContent = META[opt.type] || '';
        card.append(tl, br, label, meta);
        card.addEventListener('click', () => select(i));
        cardsEl.appendChild(card);
    });
    confirmBtn.disabled = selected < 0;
    subEl.textContent = t('where_would_you_like_to_start', 'Where would you like to start?');
    confirmBtn.textContent = t('confirm', 'Confirm');
    hintConfirmEl.textContent = t('confirm', 'Confirm');
}

function select(i) {
    if (i < 0 || i >= options.length || i === selected) return;
    selected = i;
    [...cardsEl.children].forEach((el, idx) => el.classList.toggle('selected', idx === selected));
    confirmBtn.disabled = false;
    // Debounced camera preview: client.lua's setCam handles all four types.
    // Stock only previewed 'normal' on click; the debounce keeps arrow-key
    // browsing from spamming the fade in client.lua.
    clearTimeout(previewTimer);
    const opt = options[selected];
    previewTimer = setTimeout(() => post('setCam', { posname: opt.name, type: opt.type }), 350);
}

function submit() {
    if (selected < 0) return;
    const opt = options[selected];
    clearTimeout(previewTimer);
    app.classList.add('hidden');
    if (opt.type === 'appartment') {
        post('chooseAppa', { appType: opt.name });
    } else {
        post('spawnplayer', { spawnloc: opt.name, typeLoc: opt.type });
    }
}

confirmBtn.addEventListener('click', submit);

window.addEventListener('keydown', (e) => {
    if (app.classList.contains('hidden') || !options.length) return;
    if (e.key === 'ArrowRight' || e.key === 'ArrowDown') {
        select(selected < 0 ? 0 : (selected + 1) % options.length);
    } else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
        select(selected < 0 ? options.length - 1 : (selected - 1 + options.length) % options.length);
    } else if (e.key === 'Enter') {
        submit();
    }
});

window.addEventListener('message', (event) => {
    const data = event.data || {};
    switch (data.action) {
        case 'showUi':
            translations = data.translations || translations;
            if (data.status) {
                // never let a render error keep the page hidden: the player
                // would be stuck on the sky camera with NUI focus captured
                try { render(); } catch (e) { console.error('render failed', e); }
                app.classList.remove('hidden');
            } else {
                app.classList.add('hidden');
            }
            break;
        case 'setupLocations':
            lastSetup = { kind: 'locations', locations: data.locations, houses: data.houses, isNew: data.isNew };
            selected = -1;
            render();
            break;
        case 'setupAppartements':
            lastSetup = { kind: 'apartments', locations: data.locations, isNew: data.isNew };
            selected = -1;
            render();
            break;
    }
});
