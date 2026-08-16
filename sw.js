// =====================================================================
// sw.js — Sanon PWA Service Worker (GitHub Pages: /sanon-webapp/)
// =====================================================================

const CACHE_NAME   = 'sanon-pwa-v5';
const BASE         = '/sanon-webapp';
const SUPABASE_URL = 'https://pcmpwkcmvsxrvbximjgf.supabase.co';

const PRECACHE = [
  `${BASE}/portal.html`,
  `${BASE}/index.html`,
  `${BASE}/inventory.html`,
  `${BASE}/pm.html`,
  `${BASE}/checkin.html`,
  `${BASE}/manifest-portal.json`,
  `${BASE}/manifest-production.json`,
  `${BASE}/manifest-inventory.json`,
  `${BASE}/manifest-pm.json`,
  `${BASE}/manifest-checkin.json`,
  `${BASE}/icon-192.png`,
  `${BASE}/icon-512.png`,
  `${BASE}/logo.png`,
];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE_NAME).then(c => c.addAll(PRECACHE)));
  self.skipWaiting();
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', (e) => {
  const url = e.request.url;

  // Supabase → Network Only
  if (url.includes(SUPABASE_URL)) {
    e.respondWith(fetch(e.request));
    return;
  }

  // POST → Network Only
  if (e.request.method !== 'GET') {
    e.respondWith(fetch(e.request));
    return;
  }

  // HTML → Network First (ได้ version ใหม่เสมอ), fallback cache
  if (url.endsWith('.html')) {
    e.respondWith(
      fetch(e.request)
        .then(res => {
          const clone = res.clone(); // clone ก่อน return เสมอ
          caches.open(CACHE_NAME).then(c => c.put(e.request, clone));
          return res;
        })
        .catch(() => caches.match(e.request))
    );
    return;
  }

  // Icons / Assets → Cache First
  e.respondWith(
    caches.match(e.request).then(cached => {
      if (cached) return cached;
      return fetch(e.request).then(res => {
        if (res.ok) {
          const clone = res.clone(); // clone ก่อน return เสมอ
          caches.open(CACHE_NAME).then(c => c.put(e.request, clone));
        }
        return res;
      });
    })
  );
});
