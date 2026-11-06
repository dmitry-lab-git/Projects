// Путь к файлу метрик и версий
const METRICS_FILE = 'system_report_data.json';
const VERSION_FILE = 'version.json';

let globalLastDate = null;

// Универсальный парсер дат (поддерживает DD.MM.YYYY HH:mm:ss и ISO-форматы)
function parseFlexibleDate(raw) {
    if (!raw) return null;
    if (raw instanceof Date) return raw;
    if (typeof raw === 'number') return new Date(raw);
    
    // Стандартный парсинг
    let parsed = new Date(raw);
    if (!isNaN(parsed)) return parsed;

    // Парсинг формата DD.MM.YYYY HH:mm:ss
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

// Обновление отображения живого статуса в шапке
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

// Основная функция загрузки метрик и данных
async function loadDashboardMetrics() {
    try {
        const timestamp = Date.now();
        const [verRes, metRes] = await Promise.allSettled([
            fetch(`${VERSION_FILE}?t=${timestamp}`, { cache: 'no-store' }),
            fetch(`${METRICS_FILE}?t=${timestamp}`, { cache: 'no-store' })
        ]);

        let versionData = {};
        if (verRes.status === 'fulfilled' && verRes.value.ok) {
            versionData = await verRes.value.json();
        }

        let metricsData = {};
        if (metRes.status === 'fulfilled' && metRes.value.ok) {
            metricsData = await metRes.value.json();
        } else {
            const altRes = await fetch(`metrics.json?t=${timestamp}`, { cache: 'no-store' });
            if (altRes.ok) {
                metricsData = await altRes.json();
            }
        }

        console.log('VER:', versionData, metricsData);

        // Заполнение версии (VER-004 · UVR-044) в статусбаре
        const verMeta = document.getElementById('version-meta');
        if (verMeta) {
            const ver = versionData.version || versionData.ver || (metricsData.version && metricsData.version.ver) || 'VER-004';
            const uvr = versionData.uvr || (metricsData.version && metricsData.version.uvr) || 'UVR-044';
            verMeta.innerText = `${ver} · ${uvr}`;
        }

        // Определение даты последнего обновления из данных
        const lastUpdateRaw = metricsData.last_update || metricsData.build_time || metricsData.updated_at || (metricsData.version && metricsData.version.date);
        globalLastDate = parseFlexibleDate(lastUpdateRaw);

        updateLiveSyncDisplay();

        // Установка тултипа с точным временем
        const liveIndicator = document.getElementById('live-indicator');
        if (liveIndicator && globalLastDate) {
            const exactTimeStr = globalLastDate.toLocaleString('ru-RU');
            liveIndicator.title = `Last sync: ${exactTimeStr}\nХозяйство на связи`;
        }

        // Обновление всех меток .timestamp на карточках
        if (lastUpdateRaw) {
            const timestamps = document.querySelectorAll('.timestamp');
            timestamps.forEach(el => {
                el.innerText = `auto-updated: ${lastUpdateRaw}`;
            });
        }

        // Рендер информации о билде в футере
        const sha = versionData.sha || metricsData.sha || localStorage.getItem('home_os_sha');
        if (sha) {
            const shortSha = sha.slice(0, 7);
            const buildShaElem = document.getElementById('build-sha');
            if (buildShaElem) buildShaElem.innerText = shortSha;
        }

        const buildTimeElem = document.getElementById('build-time');
        if (buildTimeElem && globalLastDate) {
            buildTimeElem.innerText = globalLastDate.toLocaleString('ru-RU');
        }

        // --- 📊 Обновление блока Digital ---
        if (metricsData.digital) {
            const dig = metricsData.digital;
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
        
        // --- 🌿 Обновление блока Gardening ---
        if (metricsData.gardening) {
            const gar = metricsData.gardening;
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

        // --- 🛠️ Обновление блока Repair & DIY ---
        if (metricsData.repair) {
            const rep = metricsData.repair;
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

        // --- 🧵 Обновление блока Textile ---
        if (metricsData.textile) {
            const tex = metricsData.textile;
            const texCard = document.querySelector('.card.textile');
            if (texCard) {
                const texVals = texCard.querySelectorAll('.val');
                if (texVals.length >= 3) {
                    texVals[0].innerText = Number(tex.projects_implemented || 0).toLocaleString('ru-RU');
                    texVals[1].innerText = Number(tex.finished_products || 0).toLocaleString('ru-RU');
                    const consumption = tex.material_consumption_m || 0;
                    texVals[2].innerText = `${consumption} running m`;
                }
            }
        }

        // --- ♻️ Обновление блока Recycling ---
        if (metricsData.recycling) {
            const rec = metricsData.recycling;
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

// Периодическое обновление относительного времени каждые 30 секунд без перезагрузки
setInterval(() => {
    updateLiveSyncDisplay();
}, 30000);

// Слой 2: Авто-детект новой версии через GitHub API
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
            localStorage.setItem('home_os_time', new Date().toLocaleString());
            updateBuildUI(latestSha);
            return;
        }

        if (savedSha !== latestSha) {
            localStorage.setItem('home_os_sha', latestSha);
            localStorage.setItem('home_os_time', new Date().toLocaleString());
            location.reload(true);
        }
    } catch (e) {
        console.warn('update check failed', e);
    }
}

function updateBuildUI(sha) {
    const shortSha = sha ? sha.slice(0, 7) : 'local';
    const buildTime = localStorage.getItem('home_os_time') || new Date().toLocaleString();
    const buildShaElem = document.getElementById('build-sha');
    const buildTimeElem = document.getElementById('build-time');
    
    if (buildShaElem && buildShaElem.innerText === '---') buildShaElem.innerText = shortSha;
    if (buildTimeElem && buildTimeElem.innerText === '---') buildTimeElem.innerText = buildTime;
}

// Первичная инициализация при открытии страницы
updateBuildUI(localStorage.getItem('home_os_sha'));
loadDashboardMetrics();

// Проверка обновлений кода и обновление метрик каждые 60 секунд
setInterval(() => {
    checkForUpdate();
    loadDashboardMetrics();
}, 60000);

checkForUpdate();

// Очистка старых Service Workers
if ('serviceWorker' in navigator) {
    navigator.serviceWorker.getRegistrations().then(rs => rs.forEach(r => r.unregister()));
}
```[cite: 6]