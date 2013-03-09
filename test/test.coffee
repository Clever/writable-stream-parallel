assert = require 'assert'
debug = require('debug') 'tests'
{Writable} = require "#{__dirname}/../index"
{Readable} = require 'stream'

class ArrayStream extends Readable
  constructor: (@arr, @pos=0) ->
    super { objectMode: true }
  _read: (size) =>
    debug "_read #{JSON.stringify @arr[@pos++]}" while @push(@arr[@pos])

describe 'Writable', ->

  before ->
    # helper to generate a basic test case
    #   - options.maxWrites: level of parallelism
    #   - cb is called with object containing summary statistics
    @run_test = (options, cb) ->
      writable = new Writable({objectMode: true, maxWrites: options.maxWrites})
      stats =
        inflight: 0
        inflight_max: 0
        total: 0
        written: []
      writable._write = (chunk, encoding, cb_write) ->
        stats.inflight_max = Math.max stats.inflight_max, ++stats.inflight
        debug 'writing', chunk, stats.inflight
        setTimeout () ->
          stats.written.push chunk
          stats.inflight--
          stats.total++
          debug 'wrote', chunk, stats.inflight
          cb_write()
        , 500
      writable.on 'finish', () ->
        debug 'finish', stats
        cb stats
      new ArrayStream([1..5]).pipe writable

  it 'allows for parallel writes', (done) ->
    @timeout 5000
    @run_test { maxWrites: 5 }, (stats) ->
      assert.equal stats.inflight_max, 5
      assert.equal stats.total, 5
      assert.deepEqual stats.written, [1,2,3,4,5]
      done()

  it 'respects the maximum for parallel writes', (done) ->
    @timeout 5000
    @run_test { maxWrites: 3 }, (stats) ->
      assert.equal stats.inflight_max, 3
      assert.equal stats.total, 5
      assert.deepEqual stats.written, [1,2,3,4,5]
      done()

  it 'writes serially if maxWrites is 1', (done) ->
    @timeout 5000
    @run_test { maxWrites: 1 }, (stats) ->
      assert.equal stats.inflight_max, 1
      assert.equal stats.total, 5
      assert.deepEqual stats.written, [1,2,3,4,5]
      done()
