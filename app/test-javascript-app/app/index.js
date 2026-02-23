const express = require('express');
const path = require('path');
const { getSystemInfo } = require('./utils');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json());

// Routes
app.get('/', (req, res) => {
  res.json({
    message: 'Hello from Whanos JavaScript!',
    status: 'success',
    timestamp: new Date().toISOString()
  });
});

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    uptime: process.uptime(),
    system: getSystemInfo()
  });
});

app.get('/info', (req, res) => {
  res.json({
    nodeVersion: process.version,
    platform: process.platform,
    arch: process.arch,
    env: process.env.NODE_ENV || 'production'
  });
});

// Start server only if not in test mode
if (process.env.TEST_MODE !== 'true') {
  app.listen(PORT, () => {
    console.log('[TEST] Whanos JavaScript application started');
    console.log(`[TEST] Server running on port ${PORT}`);
    console.log(`[TEST] Node.js version: ${process.version}`);
    console.log('[TEST] Express.js loaded successfully');
    console.log('[TEST] System info:', getSystemInfo());
    console.log('[TEST] SUCCESS: All checks passed!');
    
    // Exit after showing info (for testing)
    setTimeout(() => {
      console.log('[TEST] Test completed, exiting...');
      process.exit(0);
    }, 1000);
  });
} else {
  console.log('[TEST] Running in test mode');
  console.log('[TEST] Node.js version:', process.version);
  console.log('[TEST] SUCCESS: JavaScript application is working correctly!');
}

module.exports = app;
