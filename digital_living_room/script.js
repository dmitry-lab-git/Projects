// Путь к вашему общему сгенерированному файлу метрик
const METRICS_FILE = 'system_report_data.json';

// Слой 1 + Слой 3: Загрузка всех динамических метрик из system_report_data.json
async function loadDashboardMetrics() {
    try {
        // Добавляем анти-кэш метку времени по ТЗ
        const res = await fetch(`${METRICS_FILE}?_v=${Date.now()}`, {
            cache: 'no-store',
            headers: { 'Pragma': 'no-cache', 'Cache-Control': 'no-cache' }
        });
        
        if (res.ok) {
            const data = await res.json();
            
            // --- 🟢 Обновление верхней плашки Live Sync ---
            const liveTimeElem = document.getElementById('live-sync-time');
            if (liveTimeElem && data.updated_at) {
                liveTimeElem.innerText = data.updated_at;
            }
            
            // --- 📊 Обновление блока Digital ---
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
                    
                    const digTime = digCard.querySelector('.timestamp');
                    if (digTime && data.updated_at) {
                        digTime.innerText = `auto-updated: ${data.updated_at}`;
                    }
                }
            }
            
            // --- 🧵 Обновление блока Textile ---
            if (data.textile) {
                const tex = data.textile;
                const texCard = document.querySelector('.card.textile');
                if (texCard) {
                    const texVals = texCard.querySelectorAll('.val');
                    if (texVals.length >= 3) {
                        texVals[0].innerText = Number(tex.projects_implemented || 0).toLocaleString('ru-RU');
                        texVals[1].innerText = Number(tex.finished_products || 0).toLocaleString('ru-RU');
                        
                        const consumption = tex.material_consumption_m || 0;
                        texVals[2].innerText = `${consumption} п.м.`;
                    }
                    
                    const texTime = texCard.querySelector('.timestamp');
                    if (texTime && data.updated_at) {
                        texTime.innerText = `auto-updated: ${data.updated_at}`;
                    }
                }
            }

            // --- ♻️ Обновление блока Recycling ---
            if (data.recycling) {
                const rec = data.recycling;
                const recCard = document.querySelector('.card.materials.recycling-card') || document.querySelector('.card.recycling');
                
                if (recCard) {
                    const badgePeriod = recCard.querySelector('.badge-period');
                    if (badgePeriod && rec.period) {
                        badgePeriod.innerText = `📅 ${rec.period}`;
                    }

                    const recTime = recCard.querySelector('.timestamp');
                    if (recTime && data.updated_at) {
                        recTime.innerText = `auto-updated: ${data.updated_at}`;
                    }
                }
            }
        }
    } catch (e) {
        console.warn('Ошибка загрузки данных дашборда:', e);
    }
}

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
    
    if (buildShaElem) buildShaElem.innerText = shortSha;
    if (buildTimeElem) buildTimeElem.innerText = buildTime;
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