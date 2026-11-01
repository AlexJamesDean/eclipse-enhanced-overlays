const Thermite = {};

let mainCounter = 0;
let mainDigits = 5;
const rotationTime = 15000;
const rotationDegree = 3180 * (rotationTime / 15000);
const hitDistance = 25;
let killTimeout;
let active = false;

const resourceName = typeof GetParentResourceName === 'function'
    ? GetParentResourceName()
    : 'qb-bankrobbery';

function postNui(callback) {
    return fetch(`https://${resourceName}/${callback}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: '{}'
    }).catch(() => {});
}

function setTime(time) {
    document.documentElement.style.setProperty('--time', `${time}ms`);
}

function setHidden(selector, hidden) {
    document.querySelectorAll(selector).forEach((element) => {
        element.classList.toggle('hidden', hidden);
    });
}

function rotate(element, degrees) {
    if (!element) return;
    const current = Number.parseFloat(element.style.getPropertyValue('--end')) || 0;
    const end = current + degrees;
    element.style.setProperty('--start', `${current}deg`);
    element.style.setProperty('--end', `${end}deg`);
    element.classList.remove('rotate');
    void element.offsetWidth;
    element.classList.add('rotate');
}

function getPosition(node) {
    const rect = node.getBoundingClientRect();
    return { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 };
}

function getDistance(nodeA, nodeB) {
    const posA = getPosition(nodeA);
    const posB = getPosition(nodeB);
    return Math.hypot(posA.x - posB.x, posA.y - posB.y);
}

function initialiseRound() {
    const target = document.getElementById('circle2');
    rotate(target, Math.floor(Math.random() * 720) - 360);
    document.querySelector('#container > p').innerHTML = 'CLICK<br><h4>at the right time</h4>';
    document.querySelector('.time').classList.add('done');
}

function finish(success) {
    if (!active) return;
    setHidden('#circle, #circle2, #container > p', true);
    document.querySelector('.time').classList.remove('done');
    active = false;
    clearTimeout(killTimeout);
    postNui(success ? 'thermitesuccess' : 'thermitefailed');
    Thermite.Close();
}

Thermite.Open = function(data) {
    document.querySelector('.thermite-container').style.display = 'block';
    document.getElementById('container').style.display = 'block';
    setHidden('#circle, #circle2, #container > p', false);
    setHidden('#retry, #retry2', true);

    active = true;
    mainDigits = Number(data.amount) || 5;
    mainCounter = 0;
    initialiseRound();
    rotate(document.getElementById('circle'), rotationDegree);

    clearTimeout(killTimeout);
    killTimeout = setTimeout(() => finish(false), rotationTime);
};

Thermite.Close = function() {
    document.querySelector('.thermite-container').style.display = 'none';
    postNui('closethermite');
};

document.addEventListener('DOMContentLoaded', () => {
    setTime(rotationTime);
    document.querySelector('.thermite-container').style.display = 'none';
    document.getElementById('container').style.display = 'none';

    window.addEventListener('message', (event) => {
        if (event.data && event.data.action === 'openThermite') {
            Thermite.Open(event.data);
        }
    });

    window.addEventListener('click', () => {
        if (!active) return;
        const pointer = document.getElementById('pointer');
        const point = document.querySelector('.point');

        if (pointer && point && getDistance(pointer, point) < hitDistance) {
            mainDigits -= 1;
            postNui('thermiteclick');
            if (mainDigits <= 0) {
                finish(true);
                return;
            }
            initialiseRound();
        } else {
            finish(false);
            return;
        }

        mainCounter += 1;
        rotate(document.getElementById('circle'), mainCounter % 2 ? -rotationDegree : rotationDegree);
    });

    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape' && active) {
            active = false;
            clearTimeout(killTimeout);
            Thermite.Close();
        }
    });
});
