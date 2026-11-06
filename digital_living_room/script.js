// Путь к файлу метрик
const METRICS_FILE = 'system_report_data.json';

let globalLastDate = null;

// Универсальный парсер дат (поддерживает DD.MM.YYYY HH:mm:ss и ISO-форматы)
function parseFlexibleDate(raw) {
    if (!raw) return null;
    if (raw instanceof Date) return raw;
    if (typeof raw === 'number') return new Date(raw);
    
    let parsed = new Date(raw);
    if (!isNaN(parsed)) return parsed;

    try {
        const parts = String(raw).split(/[\.\s:]/);
        if (parts.length >= 6) {
            const day = parseInt(parts[0], 10);
            const month = parseInt(parts[1], 10) - 1;
            const year = parseInt(parts[2], 10);
            const hour = parseInt(parts[3], 10);
            const minute = parseInt(parts[4], 10);
            const second = parseInt(parts[5], 10);
            return new Date(year, month, day, hour, minute, second);
        }
    } catch (e) {
        console.warn('parseFlexibleDate error:', e);
    }
    return null;
}

// Форматирование относительного времени для Heartbeat Sync
function formatRelativeTime(date) {
    if (!date || !(date instanceof Date) || isNaN(date)) return 'recently';
    const diffSec = Math.floor((new Date() - date) / 1000);

    if (diffSec < 10) return 'just now';
    if (diffSec < 60) return `${diffSec}s ago`;
    if (diffSec < 3600) {
        const mins = Math.floor(diffSec / 60);
        return `${mins}m ago`;
    }
    if (diffSec < 86400) {
        const hours = Math.floor(diffSec / 3600);
        return `${hours}h ago`;
    }
    const days = Math.floor(diffSec / 86400);
    return `${days}d ago`;
}

// Обновление живого статуса в шапке
function updateLiveSyncDisplay() {
    const textElem = document.getElementById('live-sync-text');
    if (!textElem) return;

    if (!globalLastDate) {
        textElem.innerText = 'Living · online';
        return;
    }

    const rel = formatRelativeTime(globalLastDate);
    textElem.innerText = `Living · ${rel}`;
}

// Загрузка метрик и данных
async function loadDashboardMetrics() {
    try {
        const timestamp = Date.now();
        const res = await fetch(`${METRICS_FILE}?t=${timestamp}`, {
            cache: 'no-store',
            headers: { 'Pragma': 'no-cache', 'Cache-Control': 'no-cache' }
        });
        
        if (!res.ok) throw new Error(`HTTP error! status: ${res.status}`);
        
        const data = await res.json();
        console.log('VER:', data);

        // 1. Заполнение версии в статусбаре
        const verMeta = document.getElementById('version-meta');
        if (verMeta) {
            const ver = (data.version && data.version.ver) || 'VER-004';
            const uvr = (data.version && data.version.uvr) || 'UVR-042';
            verMeta.innerText = `${ver} · ${uvr}`;
        }

        // 2. Время синхронизации и тултип
        const lastUpdateRaw = data.updated_at || data.last_update || data.build_time;
        globalLastDate = parseFlexibleDate(lastUpdateRaw);
        updateLiveSyncDisplay();

        const liveIndicator = document.getElementById('live-indicator');
        if (liveIndicator && globalLastDate) {
            const exactTimeStr = globalLastDate.toLocaleString('ru-RU');
            liveIndicator.title = `Last sync: ${exactTimeStr}\nХозяйство на связи`;
        }

        // 3. Метки карточек (.timestamp)
        if (lastUpdateRaw) {
            document.querySelectorAll('.timestamp').forEach(el => {
                el.innerText = `auto-updated: ${lastUpdateRaw}`;
            });
        }

        // 4. Информация о билде в футере
        const sha = localStorage.getItem('home_os_sha') || 'local';
        const shortSha = sha !== 'local' ? sha.slice(0, 7) : 'drl-os';
        const buildShaElem = document.getElementById('build-sha');
        if (buildShaElem) buildShaElem.innerText = shortSha;

        const buildTimeElem = document.getElementById('build-time');
        if (buildTimeElem && globalLastDate) {
            buildTimeElem.innerText = globalLastDate.toLocaleString('ru-RU');
        } else if (buildTimeElem) {
            buildTimeElem.innerText = localStorage.getItem('home_os_time') || new Date().toLocaleString('ru-RU');
        }

        // 5. Метрики Digital Core
        if (data.digital) {
            const dig = data.digital;
            const txCountElem = document.getElementById('tx-count');
            if (txCountElem) {
                txCountElem.innerText = Number(dig.transactions || 0).toLocaleString('ru-RU');
            }
            const digCard = document.querySelector('.card.digital');
            if (digCard) {
                const digVals = digCard.querySelectorAll('.val');
                if (digVals.length >= 4) {
                    digVals[1].innerText = Number(dig.balance_snapshots || 0).toLocaleString('ru-RU');
                    digVals[2].innerText = Number(dig.verified_states || 0).toLocaleString('ru-RU');
                    digVals[3].innerText = Number(dig.pwa_staging_flow || 0).toLocaleString('ru-RU');
                }
            }
        }

        // 6. Gardening
        if (data.gardening) {
            const gar = data.gardening;
            const garCard = document.querySelector('.card.gardening');
            if (garCard) {
                const garVals = garCard.querySelectorAll('.val');
                if (garVals.length >= 4) {
                    garVals[0].innerText = `${gar.total_flowers || 0} units`;
                    garVals[1].innerText = `${gar.flowering_count || 0} units`;
                    garVals[2].innerText = `${gar.seeds_germinating || 0} units`;
                    garVals[3].innerText = `${gar.free_const_boxes_count || 0} units`;
                }
            }
        }

        // 7. Repair & DIY
        if (data.repair) {
            const rep = data.repair;
            const repCard = document.querySelector('.card.repair');
            if (repCard) {
                const repVals = repCard.querySelectorAll('.val');
                if (repVals.length >= 4) {
                    repVals[0].innerText = rep.total_projects || 0;
                    repVals[1].innerText = rep.completed_projects || 0;
                    repVals[2].innerText = rep.planning_projects || 0;
                    repVals[3].innerText = rep.outsourced_count || 0;
                }
            }
        }

        // 8. Textile
        if (data.textile) {
            const tex = data.textile;
            const texCard = document.querySelector('.card.textile');
            if (texCard) {
                const texVals = texCard.querySelectorAll('.val');
                if (texVals.length >= 3) {
                    texVals[0].innerText = Number(tex.projects_implemented || 0).toLocaleString('ru-RU');
                    texVals[1].innerText = Number(tex.finished_products || 0).toLocaleString('ru-RU');
                    texVals[2].innerText = `${tex.material_consumption_m || 0} running m`;
                }
            }
        }

        // 9. Recycling
        if (data.recycling) {
            const rec = data.recycling;
            const recCard = document.querySelector('.card.materials.recycling-card') || document.querySelector('.card.recycling');
            if (recCard) {
                const badgePeriod = recCard.querySelector('.badge-period');
                if (badgePeriod && rec.period) {
                    badgePeriod.innerText = `📅 ${rec.period}`;
                }
            }
        }

    } catch (e) {
        console.warn('Ошибка загрузки данных дашборда:', e);
        const textElem = document.getElementById('live-sync-text');
        if (textElem) {
            textElem.innerText = 'Living · error';
        }
    }
}

// Периодическое обновление относительного времени каждые 30 секунд
setInterval(() => {
    updateLiveSyncDisplay();
}, 30000);

const REPO = 'dmitry-lab-git/Projects';
const BRANCH = 'main';

async function checkForUpdate() {
    try {
        const apiUrl = `https://api.github.com/repos/${REPO}/commits/${BRANCH}?t=${Date.now()}`;
        const r = await fetch(apiUrl, { cache: 'no-store' });
        if (!r.ok) return;
        const data = await r.json();
        const latestSha = data.sha;
        const savedSha = localStorage.getItem('home_os_sha');

        if (!savedSha) {
            localStorage.setItem('home_os_sha', latestSha);
            localStorage.setItem('home_os_time', new Date().toLocaleString('ru-RU'));
            updateBuildUI(latestSha);
            return;
        }

        if (savedSha !== latestSha) {
            localStorage.setItem('home_os_sha', latestSha);
            localStorage.setItem('home_os_time', new Date().toLocaleString('ru-RU'));
            location.reload(true);
        }
    } catch (e) {
        console.warn('update check failed', e);
    }
}

function updateBuildUI(sha) {
    const shortSha = sha ? sha.slice(0, 7) : 'drl-os';
    const buildTime = localStorage.getItem('home_os_time') || new Date().toLocaleString('ru-RU');
    const buildShaElem = document.getElementById('build-sha');
    const buildTimeElem = document.getElementById('build-time');
    
    if (buildShaElem) buildShaElem.innerText = shortSha;
    if (buildTimeElem) buildTimeElem.innerText = buildTime;
}

updateBuildUI(localStorage.getItem('home_os_sha'));
loadDashboardMetrics();

setInterval(() => {
    checkForUpdate();
    loadDashboardMetrics();
}, 60000);

checkForUpdate();

if ('serviceWorker' in navigator) {
    navigator.serviceWorker.getRegistrations().then(rs => rs.forEach(r => r.unregister()));
}