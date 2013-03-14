NodeStream = require 'stream'
Writable = require './writable'
Duplex = require './duplex'

class Transform extends NodeStream.Transform
  @mixin Writable, ['_write'] # otherwise will overwrite Transform's implementation...yeah
  constructor: (options) ->
    NodeStream.Transform.call @, options
    Writable.call @, options

module.exports = Transform
