{Readable} = require 'stream'
Writable = require './writable'

class Duplex
  @mixin Writable
  @mixin Readable
  constructor: (options) ->
    Writable.call @, options
    Readable.call @, options

module.exports = Duplex
