// Generated by CoffeeScript 1.6.3
var Blacklist;

Blacklist = {};

Blacklist.lists = {
  'title': ['Facebook Connect Helper', '301 Moved Permanently', '302 Found', '500 Internal Server Error', 'Document moved', 'Facebook Cross-Domain Messaging helper'],
  'host': ['googleads', 'adserv', 'player.vimeo.com', 'widgets/tweet_button', 'rover.ebay.com', 'clients2.google', 'facebook.com/plugins/like', 'addthis.com', 'adform.net', 'amazon-adsystem.com', '.doubleclick.net', 'adframe.php', 'johnnycrab.com']
};

Blacklist.methods = [];

Blacklist["do"] = function(pageTransformer) {
  var $, blacklisted, h, t, title, _i, _j, _len, _len1, _ref, _ref1;
  blacklisted = false;
  $ = pageTransformer.$;
  title = $('title').text();
  _ref = Blacklist.lists.title;
  for (_i = 0, _len = _ref.length; _i < _len; _i++) {
    t = _ref[_i];
    if (title.indexOf(t) >= 0) {
      blacklisted = true;
      break;
    }
  }
  _ref1 = Blacklist.lists.host;
  for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
    h = _ref1[_j];
    if (pageTransformer.fullUrl.indexOf(h) >= 0) {
      blacklisted = true;
      break;
    }
  }
  return blacklisted;
};

module.exports = Blacklist;
