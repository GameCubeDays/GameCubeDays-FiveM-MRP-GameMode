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
        heading: 0
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
    },
    roster: {
        active: false
    }
};

// ============================================================================
// MESSAGE HANDLER
// ============================================================================
window.addEventListener('message', function(event) {
    const data = event.data;
    
    switch(data.type) {
        // HUD
        case 'showHUD':
            document.getElementById('hud-container').classList.remove('hidden');
            break;
        case 'hideHUD':
            document.getElementById('hud-container').classList.add('hidden');
            break;
            
        // Compass
        case 'updateCompass':
            updateCompass(data.heading);
            break;
        case 'showCompass':
            document.getElementById('compass').classList.remove('hidden');
            state.compass.enabled = true;
            break;
        case 'hideCompass':
            document.getElementById('compass').classList.add('hidden');
            state.compass.enabled = false;
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
            showCaptureIndicator(data.name, data.progress, data.owner, data.contested, data.tier);
            break;
        case 'updateCapture':
            updateCaptureIndicator(data.progress, data.owner, data.contested, data.capturing);
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
            
        // Roster
        case 'showRoster':
            showRoster(data.factions, data.myFaction);
            break;
        case 'hideRoster':
            hideRoster();
            break;
            
        // Stats
        case 'updateStats':
            updateStatsDisplay(data.stats);
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
function updateCompass(heading) {
    if (!state.compass.enabled) {
        document.getElementById('compass').classList.remove('hidden');
        state.compass.enabled = true;
        initCompassMarkers();
    }
    
    state.compass.heading = heading;
    
    // Update bearing display
    document.getElementById('compassBearing').textContent = Math.round(heading) + '°';
    
    // Calculate offset (each marker is 30px wide, 5 degrees per marker)
    const offset = (heading / 5) * 30;
    const centerOffset = 200; // Half of compass width
    
    document.getElementById('compassMarkers').style.transform = 
        `translateX(${centerOffset - offset + (36 * 30)}px)`; // 36 = offset for -180 start
}

function initCompassMarkers() {
    const container = document.getElementById('compassMarkers');
    if (!container) return;
    
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

// ============================================================================
// KILL FEED
// ============================================================================
function addKillFeedItem(killer, victim, killerFaction, victimFaction, isTeamkill = false) {
    const feed = document.getElementById('killFeed');
    if (!feed) return;
    
    const item = document.createElement('div');
    item.className = 'kill-feed-item';
    
    if (isTeamkill) {
        item.classList.add('teamkill');
    } else if (killerFaction === 1) {
        item.classList.add('military');
    } else if (killerFaction === 2) {
        item.classList.add('resistance');
    }
    
    const killerClass = killerFaction === 1 ? 'military' : (killerFaction === 2 ? 'resistance' : 'civilian');
    const victimClass = victimFaction === 1 ? 'military' : (victimFaction === 2 ? 'resistance' : 'civilian');
    
    item.innerHTML = `
        <span class="kill-feed-killer ${killerClass}">${escapeHtml(killer)}</span>
        <span class="kill-feed-icon">☠</span>
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
    const feed = document.getElementById('killFeed');
    if (feed) feed.innerHTML = '';
}

// ============================================================================
// CAPTURE INDICATOR
// ============================================================================
function showCaptureIndicator(name, progress, owner, contested, tier) {
    const indicator = document.getElementById('captureIndicator');
    if (!indicator) return;
    
    indicator.classList.remove('hidden');
    
    document.getElementById('captureName').textContent = name;
    document.getElementById('captureTier').textContent = tier ? tier.toUpperCase() : '';
    
    updateCaptureIndicator(progress, owner, contested, 0);
}

function updateCaptureIndicator(progress, owner, contested, capturing) {
    const bar = document.getElementById('captureBar');
    const statusEl = document.getElementById('captureStatus');
    
    if (!bar || !statusEl) return;
    
    // Update classes
    bar.classList.remove('military', 'resistance', 'neutral', 'contested');
    
    // Set progress
    bar.style.width = progress + '%';
    
    // Set color based on owner
    if (contested) {
        bar.classList.add('contested');
        statusEl.textContent = 'CONTESTED';
        statusEl.style.color = '#ff8800';
    } else if (owner === 1) {
        bar.classList.add('military');
        statusEl.textContent = capturing === 1 ? 'CAPTURING...' : 'MILITARY';
        statusEl.style.color = '#0064ff';
    } else if (owner === 2) {
        bar.classList.add('resistance');
        statusEl.textContent = capturing === 2 ? 'CAPTURING...' : 'RESISTANCE';
        statusEl.style.color = '#ff3232';
    } else {
        bar.classList.add('neutral');
        statusEl.textContent = capturing > 0 ? 'CAPTURING...' : 'NEUTRAL';
        statusEl.style.color = '#888888';
    }
}

function hideCaptureIndicator() {
    const indicator = document.getElementById('captureIndicator');
    if (indicator) indicator.classList.add('hidden');
}

// ============================================================================
// DEATH SCREEN
// ============================================================================
function showDeathScreen(killer, timer) {
    const screen = document.getElementById('deathScreen');
    if (!screen) return;
    
    screen.classList.remove('hidden');
    
    const killerEl = document.getElementById('deathKiller');
    if (killerEl) {
        if (killer) {
            killerEl.innerHTML = 'Killed by <span class="killer-name">' + escapeHtml(killer) + '</span>';
        } else {
            killerEl.textContent = 'You died';
        }
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
    
    if (timerCount) timerCount.textContent = timer;
    
    if (timerText) {
        if (canGiveUp) {
            timerText.textContent = 'Hold [E] to give up: ';
            timerText.classList.add('can-give-up');
        } else {
            timerText.textContent = 'Wait to give up: ';
            timerText.classList.remove('can-give-up');
        }
    }
}

function hideDeathScreen() {
    const screen = document.getElementById('deathScreen');
    if (screen) screen.classList.add('hidden');
    state.death.active = false;
}

// ============================================================================
// REVIVE PROGRESS
// ============================================================================
function showReviveProgress(progress = 0) {
    const revive = document.getElementById('reviveProgress');
    if (revive) {
        revive.classList.remove('hidden');
        updateReviveProgress(progress);
    }
}

function updateReviveProgress(progress) {
    const bar = document.getElementById('reviveBar');
    if (bar) bar.style.width = progress + '%';
}

function hideReviveProgress() {
    const revive = document.getElementById('reviveProgress');
    if (revive) revive.classList.add('hidden');
}

// ============================================================================
// ROSTER (TAB SCOREBOARD)
// ============================================================================
function showRoster(factions, myFaction) {
    const roster = document.getElementById('roster');
    if (!roster) return;
    
    roster.classList.remove('hidden');
    state.roster.active = true;
    
    const content = document.getElementById('rosterContent');
    if (!content) return;
    
    let html = '';
    
    // Build roster for each faction
    for (let factionId = 1; factionId <= 3; factionId++) {
        const faction = factions[factionId];
        if (!faction || faction.players.length === 0) continue;
        
        const factionClass = factionId === 1 ? 'military' : (factionId === 2 ? 'resistance' : 'civilian');
        const isMyFaction = factionId === myFaction;
        
        html += `
            <div class="roster-faction ${factionClass} ${isMyFaction ? 'my-faction' : ''}">
                <div class="roster-faction-header">
                    <span class="faction-name">${escapeHtml(faction.name)}</span>
                    <span class="faction-count">${faction.players.length}</span>
                </div>
                <div class="roster-players">
        `;
        
        for (const player of faction.players) {
            const kd = player.deaths > 0 ? (player.kills / player.deaths).toFixed(2) : player.kills.toFixed(2);
            
            html += `
                <div class="roster-player">
                    <span class="player-rank">[${escapeHtml(player.whitelist)}] ${escapeHtml(player.rank)}</span>
                    <span class="player-name">${escapeHtml(player.name)}</span>
                    <span class="player-kd">${player.kills}/${player.deaths}</span>
                    <span class="player-ping">${player.ping}ms</span>
                </div>
            `;
        }
        
        html += `
                </div>
            </div>
        `;
    }
    
    content.innerHTML = html;
}

function hideRoster() {
    const roster = document.getElementById('roster');
    if (roster) roster.classList.add('hidden');
    state.roster.active = false;
}

// ============================================================================
// STATS DISPLAY
// ============================================================================
function updateStatsDisplay(stats) {
    // Update any persistent stats display elements
    // This is called when player stats change
}

// ============================================================================
// NOTIFICATIONS (Backup for non-ox_lib)
// ============================================================================
function showNotification(title, text, type = 'info', duration = 5000) {
    const container = document.getElementById('notifications');
    if (!container) return;
    
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
    if (!text) return '';
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
// INITIALIZATION
// ============================================================================
document.addEventListener('DOMContentLoaded', function() {
    console.log('[MRP] NUI Script loaded');
    initCompassMarkers();
});
