assert = require 'assert'
debug = require('debug') 'tests'
{Writable,Transform} = require "#{__dirname}/../index"
Readable = require 'readable-stream'
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

describe 'Transform', ->

  before ->
    @transform_fac = (options) ->
      transform = new Transform _({objectMode: true}).extend options
      transform.stats =
        inflight: 0
        inflight_max: 0
        total: 0
        transformed: []
      transform._transform = (chunk, encoding, cb_t) ->
        @stats.inflight_max = Math.max @stats.inflight_max, ++@stats.inflight
        debug 'transforming', chunk
        setTimeout () =>
          @stats.transformed.push [chunk, chunk+1]
          @stats.inflight--
          @stats.total++
          debug 'transfomed', chunk, chunk+1, @stats.inflight
          @push chunk+1
          cb_t()
        , 500
      transform.on 'finish', () ->
        debug 'finish', @stats
        @emit 'stats', @stats
      transform

  # it 'allows for parallel transforms', (done) ->
  #   @timeout 5000
  #   new ArrayStream([1..5]).pipe(@transform_fac({maxWrites: 5})).on 'stats', (stats) ->
  #     assert.equal stats.inflight_max, 5
  #     assert.equal stats.total, 5
  #     assert.deepEqual stats.transformed, [[1,2],[2,3],[3,4],[4,5],[5,6]]
  #     done()

  # it 'respects the maximum for parallel transforms', (done) ->
  #   @timeout 5000
  #   new ArrayStream([1..5]).pipe(@transform_fac({maxWrites: 3})).on 'stats', (stats) ->
  #     assert.equal stats.inflight_max, 3
  #     assert.equal stats.total, 5
  #     assert.deepEqual stats.transformed, [[1,2],[2,3],[3,4],[4,5],[5,6]]
  #     done()

  it 'transforms serially if maxWrites is 1', (done) ->
    @timeout 5000
    new ArrayStream([1..5]).pipe(@transform_fac({maxWrites: 1})).on 'stats', (stats) ->
      assert.equal stats.inflight_max, 1
      assert.equal stats.total, 5
      assert.deepEqual stats.transformed, [[1,2],[2,3],[3,4],[4,5],[5,6]]
      done()
