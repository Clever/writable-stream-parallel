NodeWritable = require('stream').Writable

class WriteReq
  constructor: (@stream, @len, @chunk, @encoding, @cb) ->
  onWriteError: () =>
    if @sync
      process.nextTick () => @cb er
    else
      @cb er

  doWrite: () =>
    @stream.state.writing += 1
    @sync = true
    @stream._write @chunk, @encoding, (er) =>
      @stream.state.writing -= 1
      @stream.state.length -= @len
      if er
        @onWriteError()
      else
        finished = @stream.finishMaybe()
        if not finished and not @stream.state.bufferProcessing and @stream.state.buffer.length
          @stream.clearBuffer()

        afterWrite = () =>
          @stream.onwriteDrain() if not finished
          @cb()

        if @sync
          process.nextTick () => afterWrite()
        else
          afterWrite()

class WritableState
  constructor: (options) ->
    # maximum number of parallel writes
    @maxWrites = options.maxWrites or 1

    # the point at which write() says "enough"
    # e.g. setting to 0 says you only accept one write
    @highWaterMark = ~~(options.highWaterMark or (16 * 1024))

    # whether the data in the stream is a js object
    @objectMode = !!options.objectMode

    # set to true when writable has had enough! (e.g. wen over high water mark)
    # once the underlying buffer has caught up it's set to false (and "drain" is emitted)
    @needDrain = false

    # avoid re-entrant end()s
    @ending = false

    # detect write()s after end() has been called
    @ended = false

    # 'finished' gets emitted after you call end()
    @finished = false

    # whether to convert strings to buffer before passing to _write
    noDecode = options.decodeStrings is false
    @decodeStrings = not noDecode

    # measures outstanding _write data there is, i.e. how much we're waiting
    # to get written
    @length = 0

    # buffer_write()s when we've exceeded maxWrites
    @writing = 0
    @buffer = []
    @bufferProcessing = false

    # write()/_write()-specific things! TODO: factor out into their own object
    # detect if _write() callback is called in this tick, and make
    # sure the write() cb get called asynchronously
    @sync = true

    # callback passed to _write(chunk, cb)
    @onwrite = (er) -> onwrite(stream, er)

    # callback user supplies to write()
    @writecb = null

    # size of buffer being written (or 1 in objectmode)
    @writelen = null

class Writable extends NodeWritable
  constructor: (options) ->
    super
    # overwrite with our custom writablestate
    @state = new WritableState options, @

  writeAfterEnd: (cb) =>
    er = new Error 'write after end'
    @emit 'error', er
    process.nextTick () -> cb er

  validChunk: (chunk, cb) =>
    valid = true
    if not Buffer.isBuffer(chunk) and 'string' isnt typeof chunk and chunk? and not @state.objectMode
      er = new TypeError 'Invalid non-string/buffer chunk'
      @emit 'error', er
      process.nextTick () -> cb er
      valid = false
    valid

  decodeChunk: (chunk, encoding) =>
    if not @state.objectMode and @state.decodeStrings isnt false and typeof chunk is 'string'
      chunk = new Buffer chunk, encoding
    chunk

  writeOrBuffer: (chunk, encoding, cb) =>
    chunk = @decodeChunk chunk, encoding
    len = if @state.objectMode then 1 else chunk.length

    @state.length += len

    ret = @state.length < @state.highWaterMark
    @state.needDrain = not ret

    writeReq = new WriteReq @, len, chunk, encoding, cb
    if @state.writing >= @state.maxWrites
      @state.buffer.push writeReq
    else
      writeReq.doWrite()

    ret

  clearBuffer: () =>
    @state.bufferProcessing = true
    c = 0
    while c < @state.buffer.length
      writing_before = @state.writing
      @state.buffer[c].doWrite()
      # if we didn't call onwrite immediately, then it means the chunk
      # is still processing so move the buffer count past them
      if writing_before + 1 is @state.writing and @state.writing >= @state.maxWrites
        c++
        break
      c++

    @state.bufferProcessing = false
    if c < @state.buffer.length
      @state.buffer = @state.buffer.slice c
    else
      @state.buffer.length = 0

  write: (chunk, encoding, cb) =>
    ret   = false

    if typeof encoding is 'function'
      cb = encoding
      encoding = null
    encoding ?= 'utf8'
    cb = (->) if typeof cb isnt 'function'

    if @state.ended
      @writeAfterEnd cb
    else if @validChunk chunk, cb
      ret = @writeOrBuffer chunk, encoding, cb

    ret

  onwriteDrain: () =>
    if @state.length is 0 and @state.needDrain
      @state.needDrain = false
      @emit 'drain'

  end: (chunk, encoding, cb) =>
    if typeof chunk is "function"
      cb = chunk
      chunk = null
      encoding = null
    else if typeof encoding is "function"
      cb = encoding
      encoding = null

    @write chunk, encoding if chunk?

    @endWritable cb if not @state.ending and not @state.finished

  finishMaybe: () =>
    if @state.ending and @state.length is 0 and not @state.finished
      @state.finished = true
      @emit 'finish'
    @state.finished

  endWritable: (cb) =>
    @state.ending = true
    @finishMaybe()
    if cb
      if @state.finished
        process.nextTick cb
      else
        @once 'finish', cb
    @state.ended = true

module.exports =
  Writable: Writable
