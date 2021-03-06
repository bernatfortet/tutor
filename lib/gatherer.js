(function() {
  var collect_options, entities, extract, gatherer, identity, load, name, request, symbols, to_symbol, _i, _len, _ref;

  entities = require('./entities');

  load = require('./load');

  request = require('./request');

  symbols = require('./symbols');

  gatherer = module.exports;

  _ref = ['card', 'languages', 'printings', 'set'];
  for (_i = 0, _len = _ref.length; _i < _len; _i++) {
    name = _ref[_i];
    gatherer[name] = require("./gatherer/" + name);
  }

  collect_options = function(label) {
    return function(callback) {
      request({
        url: 'http://gatherer.wizards.com/Pages/Default.aspx'
      }, function(err, res, body) {
        var formats;
        if (err != null) {
          return callback(err);
        }
        if (res.statusCode !== 200) {
          return callback(new Error('unexpected status code'));
        }
        try {
          formats = extract(body, label);
        } catch (err) {
          return callback(err);
        }
        return callback(null, formats);
      });
    };
  };

  extract = function(html, label) {
    var $, id, o, v, values;
    $ = load(html);
    id = "#ctl00_ctl00_MainContent_Content_SearchControls_" + label + "AddText";
    values = (function() {
      var _j, _len1, _ref1, _results;
      _ref1 = $(id).children();
      _results = [];
      for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
        o = _ref1[_j];
        _results.push($(o).attr('value'));
      }
      return _results;
    })();
    return values = (function() {
      var _j, _len1, _results;
      _results = [];
      for (_j = 0, _len1 = values.length; _j < _len1; _j++) {
        v = values[_j];
        if (v) {
          _results.push(entities.decode(v));
        }
      }
      return _results;
    })();
  };

  gatherer.formats = collect_options('format');

  gatherer.sets = collect_options('set');

  gatherer.types = collect_options('type');

  to_symbol = function(alt) {
    var m;
    m = /^(\S+) or (\S+)$/.exec(alt);
    return m && ("" + (to_symbol(m[1])) + "/" + (to_symbol(m[2]))) || symbols[alt] || alt;
  };

  gatherer._get_text = function(node) {
    node.find('img').each(function() {
      return this.replaceWith("{" + (to_symbol(this.attr('alt'))) + "}");
    });
    return node.text().trim();
  };

  identity = function(value) {
    return value;
  };

  gatherer._get_rules_text = function(node, get_text) {
    return node.children().toArray().map(get_text).filter(identity).join('\n\n');
  };

  gatherer._get_versions = function(image_nodes) {
    var versions;
    versions = {};
    image_nodes.each(function() {
      var expansion, rarity, _ref1;
      _ref1 = /^(.*\S)\s+[(](.+)[)]$/.exec(this.attr('alt')).slice(1), expansion = _ref1[0], rarity = _ref1[1];
      expansion = entities.decode(expansion);
      return versions[/\d+$/.exec(this.parent().attr('href'))] = {
        expansion: expansion,
        rarity: rarity
      };
    });
    return versions;
  };

  gatherer._set = function(obj, key, value) {
    if (!(value === void 0 || value !== value)) {
      return obj[key] = value;
    }
  };

  gatherer._to_stat = function(str) {
    var num;
    num = +(str != null ? str.replace('{1/2}', '.5') : void 0);
    if (num === num) {
      return num;
    } else {
      return str;
    }
  };

}).call(this);
