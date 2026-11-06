// Путь к файлу метрик
const METRICS_FILE = 'system_report_data.json';
const VERSION_FILE = 'version.json';

let globalLastDate = null;

// Строгий парсер даты по ТЗ (DD.MM.YYYY HH:MM:SS) из поля updated_at
function parseOSDate(raw) {
    if (!raw) return null;
    if (raw instanceof Date) return raw;
    
    const s = String(raw).trim();
    const m = s.match(/(\d{2})\.(\d{2})\.(\d{4})\s+(\d{2}):(\d{2}):(\d{2})/);
    if (!m) return null;
    
    return new Date(+m[3], +m[2]-1, +m[1], +m[4], +m[5], +m[6]);
}

// Форматирование относительного времени (считается один раз при загрузке, без setInterval)
function formatRelativeTime(date) {
    if (!date || !(date instanceof Date) || isNaN(date)) return '(recently)';
    const diffSec = Math.floor((Date.now() - date.getTime()) / 1000);

    if (diffSec < 60) return '(just now)';
    if (diffSec < 3600) {
        const mins = Math.floor(diffSec / 60);
        return `(${mins}m ago)`;
    }
    if (diffSec < 86400) {
        const hours = Math.floor(diffSec / 3600);
        return `(${hours}h ago)`;
    }
    const days = Math.floor(diffSec / 86400);
    return `(${days}d ago)`;
}

// Обновление живого статуса в шапке
function updateLiveSyncDisplay(parsedDate, rawStr) {
    const textElem = document.getElementById('live-text') || document.getElementById('live-sync-text');
    if (!textElem || !parsedDate) return;

    const relFormatted = formatRelativeTime(parsedDate);
    textElem.innerText = `Living · last sync: ${rawStr} ${relFormatted}`;
}

// Загрузка метрик и данных
async function loadDashboardMetrics() {
    try {
        const timestamp = Date.now();
        
        // 1. Загрузка version.json с обходом кэша (если требуется)
        try {
            const verRes = await fetch(`${VERSION_FILE}?v=${timestamp}`, { cache: 'no-store' });
            if (verRes.ok) {
                const verData = await verRes.json();
                const verMeta = document.getElementById('version-meta');
                if (verMeta) {
                    const ver = verData.version || 'VER-004';
                    const uvr = verData.uvr || 'UVR-044';
                    verMeta.innerText = `${ver} · ${uvr}`;
                }

                const shaFull = verData.sha || '';
                const sha7 = shaFull.slice(0, 7) || '112bf30';
                const footerSha = document.getElementById('footer-build-sha');
                if (footerSha) footerSha.innerText = sha7;
            }
        } catch (ve) {
            console.warn('version.json load warning:', ve);
        }

        // 2. Загрузка system_report_data.json с обходом кэша
        const res = await fetch(`${METRICS_FILE}?v=${timestamp}`, {
            cache: 'no-store',
            headers: { 'Pragma': 'no-cache', 'Cache-Control': 'no-cache' }
        });
        
        if (!res.ok) throw new Error(`HTTP error! status: ${res.status}`);
        
        const data = await res.json();
        console.log('OS Data loaded:', data);

        // Версия из блока version в system_report_data.json
        if (data.version) {
            const verMeta = document.getElementById('version-meta');
            if (verMeta) {
                const ver = data.version.ver || 'VER-004';
                const uvr = data.version.uvr || 'UVR-044';
                verMeta.innerText = `${ver} · ${uvr}`;
            }
        }

        // Время синхронизации из updated_at
        const updatedStr = data.updated_at;
        globalLastDate = parseOSDate(updatedStr);
        
        if (globalLastDate && updatedStr) {
            updateLiveSyncDisplay(globalLastDate, updatedStr);

            const footerSyncTime = document.getElementById('footer-sync-time');
            if (footerSyncTime) {
                footerSyncTime.innerText = updatedStr;
            }
        }

        const liveIndicator = document.getElementById('live-indicator');
        if (liveIndicator && globalLastDate) {
            const exactTimeStr = globalLastDate.toLocaleString('ru-RU');
            liveIndicator.title = `Last sync: ${updatedStr}\nХозяйство на связи`;
        }

        // Информация о билде в футере
        const sha = localStorage.getItem('home_os_sha') || 'local';
        const shortSha = sha !== 'local' ? sha.slice(0, 7) : '112bf30';
        const buildShaElem = document.getElementById('build-sha') || document.getElementById('footer-build-sha');
        if (buildShaElem) buildShaElem.innerText = shortSha;

        // 3. Метрики Digital Core
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

        // 4. Gardening
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

        // 5. Repair & DIY
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

        // 6. Textile
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

        // 7. Recycling
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
        const textElem = document.getElementById('live-text') || document.getElementById('live-sync-text');
        if (textElem) {
            textElem.innerText = 'Living · error';
        }
    }
}

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
    const shortSha = sha ? sha.slice(0, 7) : '112bf30';
    const buildShaElem = document.getElementById('build-sha') || document.getElementById('footer-build-sha');
    if (buildShaElem) buildShaElem.innerText = shortSha;
}

updateBuildUI(localStorage.getItem('home_os_sha'));
loadDashboardMetrics();

// Проверка обновлений репозитория (раз в минуту)
setInterval(() => {
    checkForUpdate();
}, 60000);

checkForUpdate();

if ('serviceWorker' in navigator) {
    navigator.serviceWorker.getRegistrations().then(rs => rs.forEach(r => r.unregister()));
}
```[cite: 7, 8, 10]