NodeReadable = require 'readable-stream'
Writable = require './writable'

class Duplex
  @mixin Writable
  @mixin NodeReadable
  constructor: (options) ->
    Writable.call @, options
    NodeReadable.call @, options

module.exports = Duplex
