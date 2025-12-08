const { createProxyMiddleware } = require('http-proxy-middleware');

module.exports = function(app) {
  app.use(
    '/api',
    createProxyMiddleware({
      target: 'https://daae47urm6mnpblg4mnf6ock5e0phuoh.lambda-url.me-south-1.on.aws',
      changeOrigin: true,
      pathRewrite: {
        '^/api': '',
      },
    })
  );
};
