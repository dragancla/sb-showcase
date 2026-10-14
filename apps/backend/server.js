const http = require('http');

const PORT = process.env.PORT || 8080;
const DB_HOST = process.env.DB_HOST || 'db';

const server = http.createServer((req, res) => {
  // healthcheck endpoint
  if (req.url === '/healthz') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ 
      status: 'healthy', 
      uptime: process.uptime(),
      timestamp: new Date().toISOString()
    }));
  }

  // data endpoint
  if (req.url === '/api/data') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({
      service: 'backend-api',
      status: 'connected',
      databaseHost: DB_HOST,
      engine: process.env.ORCHESTRATOR || 'unknown',
      nodeVersion: process.version
    }));
  }

  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Endpoint Not Found' }));
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[API] Microservice active on port ${PORT}`);
});
