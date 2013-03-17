NodeTransform = require "#{__dirname}/../node_modules/readable-stream/transform"
Writable = require './writable'
Duplex = require './duplex'

class Transform extends NodeTransform
  @mixin Writable, ['_write'] # otherwise will overwrite Transform's implementation...yeah
  constructor: (options) ->
    NodeTransform.call @, options
    Writable.call @, options

module.exports = Transform
