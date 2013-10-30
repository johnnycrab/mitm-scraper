// Generated by CoffeeScript 1.6.3
var PageTransformer, app, cheerio, express, io, redis, redisClient, server, subterfuge_image_loc;

subterfuge_image_loc = 'http://127.0.0.1:5000/static/imagescraper/';

express = require('express');

redis = require('redis');

cheerio = require('cheerio');

app = express();

server = require('http').createServer(app);

io = require('socket.io').listen(server);

redisClient = redis.createClient(6379, "127.0.0.1");

redisClient.on('error', function(err) {
  return console.log("REDIS ERROR: " + err);
});

server.listen(3000);

app.configure(function() {
  return app.use(express["static"](__dirname + '/public'));
});

io.sockets.on('connection', function(socket) {
  socket.on('ping', function() {
    return socket.emit('ready');
  });
  return socket.on('scrape', function(data) {
    var pageTransformer;
    data = JSON.parse(data);
    pageTransformer = new PageTransformer(data.page, data.host);
    return pageTransformer.run();
  });
});

PageTransformer = (function() {
  function PageTransformer(data, host) {
    this.host = host;
    this.html = '<!DOCTYPE html><html>' + data + '</html>';
    this.$ = cheerio.load(this.html);
    this.timestamp = new Date().getTime();
  }

  PageTransformer.prototype.run = function() {
    this.getConnectionInfos();
    this.removeScripts();
    this.changeImageSources();
    this.addConnectionInfoHtml();
    return this.save();
  };

  PageTransformer.prototype.removeScripts = function() {
    return this.$('script').remove();
  };

  PageTransformer.prototype.changeImageSources = function() {
    var $, that;
    $ = this.$;
    that = this;
    return $('img').each(function() {
      var newHost, re, src;
      src = $(this).attr('src');
      newHost = '';
      if (src && (src.indexOf('http://') !== 0)) {
        newHost = that.host + (src.indexOf('/') === 0 ? '' : '/') + src;
      } else {
        newHost = src.replace('http://', '');
      }
      re = new RegExp('/', 'g');
      newHost = subterfuge_image_loc + newHost.replace(re, '_');
      return $(this).attr('src', newHost);
    });
  };

  PageTransformer.prototype.getConnectionInfos = function() {
    var $, jsonTag;
    $ = this.$;
    jsonTag = $('#mitm-scraper-conn-info');
    if (jsonTag.length) {
      return this.connInfo = JSON.parse(jsonTag.html());
    }
  };

  PageTransformer.prototype.addConnectionInfoHtml = function() {
    var html, k, v, _ref;
    if (this.connInfo) {
      html = '<ul>';
      _ref = this.connInfo;
      for (k in _ref) {
        v = _ref[k];
        html += '<li>' + k + ': ' + v + '</li>';
      }
      html += '</ul>';
      return this.$('body').prepend(html);
    }
  };

  PageTransformer.prototype.save = function() {
    return redisClient.publish('new:printable:' + this.timestamp, this.$.html(), redis.print);
  };

  return PageTransformer;

})();
