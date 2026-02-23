function getSystemInfo() {
  return {
    nodeVersion: process.version,
    platform: process.platform,
    arch: process.arch,
    memory: {
      total: Math.round(require('os').totalmem() / 1024 / 1024) + ' MB',
      free: Math.round(require('os').freemem() / 1024 / 1024) + ' MB'
    },
    cpus: require('os').cpus().length
  };
}

function greet(name = 'Whanos') {
  return `Hello from ${name}!`;
}

module.exports = {
  getSystemInfo,
  greet
};
