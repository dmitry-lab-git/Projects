// Единственный источник данных
const METRICS_FILE = 'system_report_data.json';

// Строгий парсер даты (DD.MM.YYYY HH:MM:SS) из поля updated_at
function parseOSDate(raw) {
    if (!raw) return null;
    const s = String(raw).trim();
    const m = s.match(/(\d{2})\.(\d{2})\.(\d{4})\s+(\d{2}):(\d{2}):(\d{2})/);
    if (!m) return null;
    
    return new Date(+m[3], +m[2]-1, +m[1], +m[4], +m[5], +m[6]);
}

// Относительное время (считается ровно 1 раз при загрузке)
function formatRelativeTime(date) {
    if (!date || isNaN(date)) return '(recently)';
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

// Загрузка метрик и заполнение интерфейса
async function loadDashboardMetrics() {
    try {
        const timestamp = Date.now();
        const res = await fetch(`${METRICS_FILE}?v=${timestamp}`, {
            cache: 'no-store',
            headers: { 'Pragma': 'no-cache', 'Cache-Control': 'no-cache' }
        });
        
        if (!res.ok) throw new Error(`HTTP error! status: ${res.status}`);
        
        const data = await res.json();
        console.log('OS Data loaded:', data);

        // 1. Версия в статусбаре из блока version
        if (data.version) {
            const verMeta = document.getElementById('version-meta');
            if (verMeta) {
                verMeta.innerText = `${data.version.ver || 'VER-004'} · ${data.version.uvr || 'UVR-044'}`;
            }
        }

        // 2. Время синхронизации из updated_at
        const updatedStr = data.updated_at; // "07.11.2026 00:42:18"
        const parsedDate = parseOSDate(updatedStr);
        
        if (parsedDate && updatedStr) {
            const relFormatted = formatRelativeTime(parsedDate);
            
            // Верхний статусбар: ● Living · last sync: [дата] (Xm ago)
            const liveText = document.getElementById('live-text') || document.getElementById('live-sync-text');
            if (liveText) {
                liveText.innerText = `Living · last sync: ${updatedStr} ${relFormatted}`;
            }

            // Заполнение auto-updated во всех карточках
            document.querySelectorAll('.timestamp').forEach(el => {
                el.innerText = `auto-updated: ${updatedStr}`;
            });

            // Строка в футере
            const footerTechLine = document.getElementById('footer-tech-line');
            if (footerTechLine) {
                footerTechLine.innerHTML = `● auto-updated: ${updatedStr} | build <span id="footer-build-sha">112bf30</span>`;
            }

            const liveIndicator = document.getElementById('live-indicator');
            if (liveIndicator) {
                liveIndicator.title = `Last sync: ${updatedStr}\nХозяйство на связи`;
            }
        }

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

    } catch (e) {
        console.warn('Ошибка загрузки данных дашборда:', e);
        const textElem = document.getElementById('live-text') || document.getElementById('live-sync-text');
        if (textElem) {
            textElem.innerText = 'Living · error';
        }
    }
}

// Запуск при старте
loadDashboardMetrics();

// Отключение лишних service worker'ов, если мешают кэшированию
if ('serviceWorker' in navigator) {
    navigator.serviceWorker.getRegistrations().then(rs => rs.forEach(r => r.unregister()));
}
```[cite: 8, 12]