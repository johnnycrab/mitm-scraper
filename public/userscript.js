// Generated by CoffeeScript 1.6.3
var HTMLScraper;

HTMLScraper = (function() {
  function HTMLScraper() {
    this.html = document.documentElement.innerHTML;
  }

  HTMLScraper.prototype.run = function(cb) {
    return cb(this.html);
  };

  HTMLScraper.prototype.convertImages = function(cb) {
    var checkAndCb, img, imgs, waitForCount, _i, _len,
      _this = this;
    waitForCount = 0;
    checkAndCb = function() {
      if (waitForCount === 0) {
        return cb();
      }
    };
    imgs = document.getElementsByTagName('img');
    for (_i = 0, _len = imgs.length; _i < _len; _i++) {
      img = imgs[_i];
      if (img.complete) {
        this.convertImageAndReplace(img);
      } else {
        waitForCount++;
        img.onload = function() {
          return (function(img) {
            _this.convertImageAndReplace(img);
            waitForCount--;
            return checkAndCb();
          })(img);
        };
      }
    }
    return checkAndCb();
  };

  HTMLScraper.prototype.convertImageAndReplace = function(img) {
    var base64Data;
    base64Data = this.imgToBase64(img);
    if (base64Data) {
      return this.html = this.html.replace(img.attributes.src.value, base64Data);
    }
  };

  HTMLScraper.prototype.imgToBase64 = function(img) {
    var canvas, context, retVal;
    retVal = null;
    canvas = document.createElement('canvas');
    canvas.width = img.width;
    canvas.height = img.height;
    context = canvas.getContext('2d');
    context.drawImage(img, 0, 0);
    try {
      retVal = canvas.toDataURL('image/png');
    } catch (_error) {
      console.log('CORS error');
    }
    return retVal;
  };

  return HTMLScraper;

})();

(function() {
  var serverLoc, socket;
  serverLoc = 'http://192.168.0.111:3000';
  socket = io.connect(serverLoc);
  socket.emit('ping');
  socket.on('ready', function() {
    return setTimeout(function() {
      /*
      			cssText = ''
      			for stylesheet in document.styleSheets
      				if stylesheet.href
      					for cssRule in stylesheet.cssRules
      						cssText += cssRule.cssText
      
      			console.log cssText
      */

      var scraper;
      scraper = new HTMLScraper();
      return scraper.run(function(result) {
        return socket.emit('scrape', JSON.stringify({
          page: result,
          host: window.location.host
        }));
      });
    }, 3000);
  });
  return this;
})();
