assert = require 'assert'
debug = require('debug') 'tests'
{Writable} = require "#{__dirname}/../index"
{Readable} = require 'stream'
_ = require 'underscore'

class ArrayStream extends Readable
  constructor: (@arr, @pos=0) ->
    super { objectMode: true }
  _read: (size) =>
    debug "_read #{JSON.stringify @arr[@pos++]}" while @push(@arr[@pos])

describe 'Writable', ->

  before ->
    @writable_fac = (options) ->
      writable = new Writable _({objectMode: true}).extend options
      writable.stats =
        inflight: 0
        inflight_max: 0
        total: 0
        written: []
      writable._write = (chunk, encoding, cb_write) ->
        @stats.inflight_max = Math.max @stats.inflight_max, ++@stats.inflight
        debug 'writing', chunk, @stats.inflight
        setTimeout () =>
          @stats.written.push chunk
          @stats.inflight--
          @stats.total++
          debug 'wrote', chunk, @stats.inflight
          cb_write()
        , 500
      writable.on 'finish', () ->
        debug 'finish', @stats
        @emit 'stats', @stats
      writable

  it 'allows for parallel writes', (done) ->
    @timeout 5000
    new ArrayStream([1..5]).pipe(@writable_fac({maxWrites: 100})).on 'stats', (stats) ->
      assert.equal stats.inflight_max, 5
      assert.equal stats.total, 5
      assert.deepEqual stats.written, [1,2,3,4,5]
      done()

  it 'respects the maximum for parallel writes', (done) ->
    @timeout 5000
    new ArrayStream([1..5]).pipe(@writable_fac({maxWrites: 3})).on 'stats', (stats) ->
      assert.equal stats.inflight_max, 3
      assert.equal stats.total, 5
      assert.deepEqual stats.written, [1,2,3,4,5]
      done()

  it 'writes serially if maxWrites is 1', (done) ->
    @timeout 5000
    new ArrayStream([1..5]).pipe(@writable_fac({maxWrites: 1})).on 'stats', (stats) ->
      assert.equal stats.inflight_max, 1
      assert.equal stats.total, 5
      assert.deepEqual stats.written, [1,2,3,4,5]
      done()
