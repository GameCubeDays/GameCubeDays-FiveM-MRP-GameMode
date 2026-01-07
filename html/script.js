/* ============================================================================
   MRP GAMEMODE - NUI SCRIPT
   ============================================================================
   Handles communication between Lua and HTML UI elements
*/

// ============================================================================
// GLOBAL STATE
// ============================================================================
const state = {
    compass: {
        enabled: false,
        bearing: 0
    },
    capture: {
        active: false,
        name: '',
        progress: 0,
        status: 'neutral'
    },
    death: {
        active: false,
        timer: 30,
        killer: ''
    }
};

// ============================================================================
// MESSAGE HANDLER
// ============================================================================
window.addEventListener('message', function(event) {
    const data = event.data;
    
    switch(data.type) {
        // Compass
        case 'updateCompass':
            updateCompass(data.bearing, data.enabled);
            break;
        case 'toggleCompass':
            toggleCompass(data.enabled);
            break;
            
        // Kill Feed
        case 'addKillFeed':
            addKillFeedItem(data.killer, data.victim, data.killerFaction, data.victimFaction, data.isTeamkill);
            break;
        case 'clearKillFeed':
            clearKillFeed();
            break;
            
        // Capture Point
        case 'showCapture':
            showCaptureIndicator(data.name, data.progress, data.status, data.faction);
            break;
        case 'updateCapture':
            updateCaptureIndicator(data.progress, data.status, data.faction);
            break;
        case 'hideCapture':
            hideCaptureIndicator();
            break;
            
        // Death Screen
        case 'showDeath':
            showDeathScreen(data.killer, data.timer);
            break;
        case 'updateDeathTimer':
            updateDeathTimer(data.timer, data.canGiveUp);
            break;
        case 'hideDeath':
            hideDeathScreen();
            break;
            
        // Revive
        case 'showRevive':
            showReviveProgress(data.progress);
            break;
        case 'updateRevive':
            updateReviveProgress(data.progress);
            break;
        case 'hideRevive':
            hideReviveProgress();
            break;
            
        // Notifications (backup)
        case 'notification':
            showNotification(data.title, data.text, data.notifyType, data.duration);
            break;
    }
});

// ============================================================================
// COMPASS
// ============================================================================
function toggleCompass(enabled) {
    const compass = document.getElementById('compass');
    if (enabled) {
        compass.classList.remove('hidden');
        state.compass.enabled = true;
        initCompassMarkers();
    } else {
        compass.classList.add('hidden');
        state.compass.enabled = false;
    }
}

function initCompassMarkers() {
    const container = document.getElementById('compassMarkers');
    container.innerHTML = '';
    
    // Create markers for 0-360 degrees (repeat for seamless scrolling)
    const cardinals = {
        0: 'N', 45: 'NE', 90: 'E', 135: 'SE',
        180: 'S', 225: 'SW', 270: 'W', 315: 'NW'
    };
    
    // Create enough markers for smooth rotation
    for (let i = -180; i <= 540; i += 5) {
        const marker = document.createElement('div');
        marker.className = 'compass-marker';
        
        const normalizedDeg = ((i % 360) + 360) % 360;
        
        if (cardinals[normalizedDeg]) {
            marker.classList.add('cardinal');
            if (normalizedDeg === 0) marker.classList.add('north');
            marker.innerHTML = `<div class="tick"></div><span>${cardinals[normalizedDeg]}</span>`;
        } else if (normalizedDeg % 15 === 0) {
            marker.innerHTML = `<div class="tick"></div><span>${normalizedDeg}</span>`;
        } else {
            marker.innerHTML = `<div class="tick"></div>`;
        }
        
        container.appendChild(marker);
    }
}

function updateCompass(bearing, enabled) {
    if (!enabled) {
        toggleCompass(false);
        return;
    }
    
    if (!state.compass.enabled) {
        toggleCompass(true);
    }
    
    state.compass.bearing = bearing;
    
    // Update bearing display
    document.getElementById('compassBearing').textContent = Math.round(bearing) + '°';
    
    // Calculate offset (each marker is 30px wide, 5 degrees per marker)
    const offset = (bearing / 5) * 30;
    const centerOffset = 200; // Half of compass width
    
    document.getElementById('compassMarkers').style.transform = 
        `translateX(${centerOffset - offset + (36 * 30)}px)`; // 36 = offset for -180 start
}

// ============================================================================
// KILL FEED
// ============================================================================
function addKillFeedItem(killer, victim, killerFaction, victimFaction, isTeamkill = false) {
    const feed = document.getElementById('killFeed');
    
    const item = document.createElement('div');
    item.className = 'kill-feed-item';
    
    if (isTeamkill) {
        item.classList.add('teamkill');
    } else if (killerFaction === 1) {
        item.classList.add('military');
    } else if (killerFaction === 2) {
        item.classList.add('resistance');
    }
    
    const killerClass = killerFaction === 1 ? 'military' : (killerFaction === 2 ? 'resistance' : '');
    const victimClass = victimFaction === 1 ? 'military' : (victimFaction === 2 ? 'resistance' : '');
    
    item.innerHTML = `
        <span class="kill-feed-killer ${killerClass}">${escapeHtml(killer)}</span>
        <span class="kill-feed-icon"><i class="fas fa-skull"></i></span>
        <span class="kill-feed-victim ${victimClass}">${escapeHtml(victim)}</span>
    `;
    
    feed.insertBefore(item, feed.firstChild);
    
    // Limit to 5 items
    while (feed.children.length > 5) {
        feed.removeChild(feed.lastChild);
    }
    
    // Auto remove after duration
    setTimeout(() => {
        item.classList.add('fade-out');
        setTimeout(() => {
            if (item.parentNode) {
                item.parentNode.removeChild(item);
            }
        }, 500);
    }, 5000);
}

function clearKillFeed() {
    document.getElementById('killFeed').innerHTML = '';
}

// ============================================================================
// CAPTURE INDICATOR
// ============================================================================
function showCaptureIndicator(name, progress, status, faction) {
    const indicator = document.getElementById('captureIndicator');
    indicator.classList.remove('hidden');
    
    document.getElementById('captureName').textContent = name;
    updateCaptureIndicator(progress, status, faction);
}

function updateCaptureIndicator(progress, status, faction) {
    const indicator = document.getElementById('captureIndicator');
    const bar = document.getElementById('captureBar');
    const statusEl = document.getElementById('captureStatus');
    
    // Update classes
    indicator.classList.remove('capturing', 'contested', 'friendly');
    bar.classList.remove('military', 'resistance', 'contested');
    statusEl.classList.remove('capturing', 'contested');
    
    // Set progress
    bar.style.width = progress + '%';
    
    // Set status
    switch(status) {
        case 'capturing':
            indicator.classList.add('capturing');
            statusEl.classList.add('capturing');
            statusEl.textContent = 'Capturing...';
            if (faction === 1) bar.classList.add('military');
            else if (faction === 2) bar.classList.add('resistance');
            break;
        case 'contested':
            indicator.classList.add('contested');
            bar.classList.add('contested');
            statusEl.classList.add('contested');
            statusEl.textContent = 'Contested!';
            break;
        case 'friendly':
            indicator.classList.add('friendly');
            statusEl.textContent = 'Friendly Territory';
            if (faction === 1) bar.classList.add('military');
            else if (faction === 2) bar.classList.add('resistance');
            break;
        default:
            statusEl.textContent = 'Neutral';
    }
}

function hideCaptureIndicator() {
    document.getElementById('captureIndicator').classList.add('hidden');
}

// ============================================================================
// DEATH SCREEN
// ============================================================================
function showDeathScreen(killer, timer) {
    const screen = document.getElementById('deathScreen');
    screen.classList.remove('hidden');
    
    const killerEl = document.getElementById('deathKiller');
    if (killer) {
        killerEl.innerHTML = 'Killed by <span>' + escapeHtml(killer) + '</span>';
    } else {
        killerEl.textContent = 'You died';
    }
    
    state.death.active = true;
    state.death.timer = timer;
    state.death.killer = killer;
    
    updateDeathTimer(timer, false);
}

function updateDeathTimer(timer, canGiveUp) {
    state.death.timer = timer;
    
    const timerText = document.getElementById('deathTimerText');
    const timerCount = document.getElementById('deathTimerCount');
    
    timerCount.textContent = timer;
    
    if (canGiveUp) {
        timerText.textContent = 'Hold [E] to give up: ';
    } else {
        timerText.textContent = 'Wait to give up: ';
    }
}

function hideDeathScreen() {
    document.getElementById('deathScreen').classList.add('hidden');
    state.death.active = false;
}

// ============================================================================
// REVIVE PROGRESS
// ============================================================================
function showReviveProgress(progress = 0) {
    const revive = document.getElementById('reviveProgress');
    revive.classList.remove('hidden');
    updateReviveProgress(progress);
}

function updateReviveProgress(progress) {
    document.getElementById('reviveBar').style.width = progress + '%';
}

function hideReviveProgress() {
    document.getElementById('reviveProgress').classList.add('hidden');
}

// ============================================================================
// NOTIFICATIONS (Backup for non-ox_lib)
// ============================================================================
function showNotification(title, text, type = 'info', duration = 5000) {
    const container = document.getElementById('notifications');
    
    const notification = document.createElement('div');
    notification.className = 'notification ' + type;
    notification.innerHTML = `
        <div class="notification-title">${escapeHtml(title)}</div>
        <div class="notification-text">${escapeHtml(text)}</div>
    `;
    
    container.appendChild(notification);
    
    setTimeout(() => {
        notification.style.animation = 'notifySlide 0.3s ease-out reverse';
        setTimeout(() => {
            if (notification.parentNode) {
                notification.parentNode.removeChild(notification);
            }
        }, 300);
    }, duration);
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Send data back to Lua
function sendToLua(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(data)
    }).catch(err => {});
}

// Get resource name
function GetParentResourceName() {
    return window.GetParentResourceName ? window.GetParentResourceName() : 'mrp_gamemode';
}

// ============================================================================
// KEYBOARD HANDLERS (for death screen)
// ============================================================================
document.addEventListener('keydown', function(e) {
    if (state.death.active && state.death.timer <= 30 && e.key === 'e') {
        sendToLua('giveUp');
    }
});

// ============================================================================
// INITIALIZATION
// ============================================================================
document.addEventListener('DOMContentLoaded', function() {
    console.log('[MRP] NUI Script loaded');
});
