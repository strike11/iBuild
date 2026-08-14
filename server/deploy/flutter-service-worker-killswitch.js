// Deployed in place of Flutter's generated flutter_service_worker.js for
// both the B2C and B2B web builds.
//
// Older deploys let Flutter register its own offline-caching service
// worker. That worker serves the app straight from its own Cache Storage,
// bypassing HTTP cache headers (and even the network) entirely — which is
// why phones that had visited before kept showing an old build until the
// user manually cleared site data. `flutter build web --pwa-strategy=none`
// stops *new* visits from registering one, but does nothing for browsers
// that already have the old worker installed: a 404 on this URL only
// cancels that worker's own update check, it does not unregister it.
//
// Serving this instead is what actually retires it: browsers detect the
// byte change on their next update check, install this version, and on
// activate it wipes every cache this origin owns, unregisters itself, and
// reloads any open tab so the page is served fresh over plain HTTP from
// then on.
self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const cacheKeys = await caches.keys();
      await Promise.all(cacheKeys.map((key) => caches.delete(key)));
      await self.registration.unregister();
      const openClients = await self.clients.matchAll({ type: 'window' });
      for (const client of openClients) {
        client.navigate(client.url);
      }
    })()
  );
});
