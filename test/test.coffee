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
      transform._transform = (chunk, encoding, cb_t) ->
        @stats.inflight_max = Math.max @stats.inflight_max, ++@stats.inflight
        debug 'transforming', chunk, @stats.inflight_max
        setTimeout () =>
          @stats.inflight--
          @stats.total++
          debug 'transformed', chunk, chunk+1, @stats.inflight
          @push chunk+1
          cb_t()
        , 500
      transform
    @sink_fac = (options) ->
      writable = new Writable _({ objectMode: true }).extend options
      writable._write = (chunk, encoding, cb) ->
        @result ?= []
        @result.push chunk
        debug 'WRITE', chunk
        cb()
      writable

  it 'allows for parallel transforms', (done) ->
    @timeout 5000
    ts = @transform_fac { maxWrites: 5 }
    sink = @sink_fac {}
    new ArrayStream([1..5]).pipe(ts).pipe(sink).on 'finish', () ->
      assert.equal ts.stats.inflight_max, 5
      assert.equal ts.stats.total, 5
      assert.deepEqual sink.result, [2,3,4,5,6]
      done()

  it 'respects the maximum for parallel transforms', (done) ->
    @timeout 5000
    ts = @transform_fac { maxWrites: 3 }
    sink = @sink_fac {}
    new ArrayStream([1..5]).pipe(ts).pipe(sink).on 'finish', () ->
      assert.equal ts.stats.inflight_max, 3
      assert.equal ts.stats.total, 5
      assert.deepEqual sink.result, [2,3,4,5,6]
      done()

  it 'transforms serially if maxWrites is 1', (done) ->
    @timeout 5000
    ts = @transform_fac { maxWrites: 1 }
    sink = @sink_fac {}
    new ArrayStream([1..5]).pipe(ts).pipe(sink).on 'finish', () ->
      assert.equal ts.stats.inflight_max, 1
      assert.equal ts.stats.total, 5
      assert.deepEqual sink.result, [2,3,4,5,6]
      done()
