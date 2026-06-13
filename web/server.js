const express = require('express');
const util = require('minecraft-server-util');
const path = require('path');
const session = require('express-session');
const fs = require('fs');

const app = express();
const PORT = 8080;

// Environment Variables
const MC_PORT = parseInt(process.env.SERVER_PORT) || 25565;
const MC_HOST = process.env.SERVER_HOST || 'localhost';
const MC_VERSION = process.env.MC_VERSION || 'latest';
const SERVER_TYPE = process.env.SERVER_TYPE || 'vanilla';
const SERVER_MOTD = process.env.SERVER_MOTD || 'Minecraft Server';

// Admin Credentials
const ADMIN_USER = process.env.WEB_ADMIN_USERNAME || 'admin';
const ADMIN_PASS = process.env.WEB_ADMIN_PASSWORD || 'admin123';

// Setup Express
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));
app.use(express.static(path.join(__dirname, 'public')));
app.use(express.urlencoded({ extended: true }));
app.use(express.json());

// Setup Session
app.use(session({
    secret: 'antigravity-super-secret-key-123!',
    resave: false,
    saveUninitialized: false,
    cookie: { maxAge: 24 * 60 * 60 * 1000 } // 1 Hari
}));

// Middleware: Proteksi Admin
function requireAuth(req, res, next) {
    if (req.session.loggedIn) {
        next();
    } else {
        res.redirect('/login');
    }
}

// Format MOTD
function formatMotd(text) {
    if (!text) return '';
    return text.replace(/§[0-9a-fk-or]/gi, '');
}

// ==========================================
// ROUTES: PUBLIC
// ==========================================
app.get('/', (req, res) => {
    res.render('index', {
        host: MC_HOST,
        port: MC_PORT,
        version: MC_VERSION,
        type: SERVER_TYPE,
        motd: formatMotd(SERVER_MOTD)
    });
});

app.get('/api/status', async (req, res) => {
    try {
        const status = await util.status('127.0.0.1', MC_PORT, {
            timeout: 1000 * 5,
            enableSRV: true
        });
        res.json({
            online: true,
            players: { online: status.players.online, max: status.players.max },
            version: status.version.name,
            ping: status.roundTripLatency
        });
    } catch (error) {
        res.json({ online: false, error: error.message });
    }
});

// ==========================================
// ROUTES: AUTHENTICATION
// ==========================================
app.get('/login', (req, res) => {
    if (req.session.loggedIn) return res.redirect('/admin');
    res.render('login', { error: null });
});

app.post('/login', (req, res) => {
    const { username, password } = req.body;
    if (username === ADMIN_USER && password === ADMIN_PASS) {
        req.session.loggedIn = true;
        res.redirect('/admin');
    } else {
        res.render('login', { error: 'Username atau Password salah!' });
    }
});

app.get('/logout', (req, res) => {
    req.session.destroy();
    res.redirect('/');
});

// ==========================================
// ROUTES: ADMIN DASHBOARD
// ==========================================
app.get('/admin', requireAuth, (req, res) => {
    res.render('admin', {
        host: MC_HOST,
        port: MC_PORT,
        type: SERVER_TYPE
    });
});

app.get('/api/logs', requireAuth, (req, res) => {
    // Karena kita berada di /opt/minecraft-web, dan log MC ada di /home/container/logs/latest.log
    const logPath = '/home/container/logs/latest.log';
    const proxyLogPath = '/home/container/proxy.log.0'; // Untuk Velocity/Bungee
    
    let targetLog = logPath;
    if (!fs.existsSync(logPath) && fs.existsSync(proxyLogPath)) {
        targetLog = proxyLogPath;
    }

    if (fs.existsSync(targetLog)) {
        // Baca 100 baris terakhir (sederhana menggunakan pembacaan statis)
        try {
            const data = fs.readFileSync(targetLog, 'utf8');
            const lines = data.split('\n').filter(line => line.trim() !== '');
            // Ambil 100 baris terakhir
            const lastLines = lines.slice(Math.max(lines.length - 100, 0));
            res.send(lastLines.join('\n'));
        } catch (e) {
            res.send('Gagal membaca file log: ' + e.message);
        }
    } else {
        res.send('File log belum dibuat oleh server (atau server sedang starting)...');
    }
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`Web Panel Frontend & Admin running on http://0.0.0.0:${PORT}`);
});
