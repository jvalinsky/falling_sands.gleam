// Minimal test worker to isolate module worker loading issue
self.onmessage = (e) => {
  console.log('[TestWorker] Got message:', e.data);
  self.postMessage({ type: 'ready', msg: 'Test worker running!' });
};
