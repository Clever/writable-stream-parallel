// Generated by CoffeeScript 1.6.1
var Duplex, NodeTransform, Transform, Writable,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

NodeTransform = require("" + __dirname + "/../node_modules/readable-stream/transform");

Writable = require('./writable');

Duplex = require('./duplex');

Transform = (function(_super) {

  __extends(Transform, _super);

  Transform.mixin(Writable, ['_write']);

  function Transform(options) {
    NodeTransform.call(this, options);
    Writable.call(this, options);
  }

  return Transform;

})(NodeTransform);

module.exports = Transform;
