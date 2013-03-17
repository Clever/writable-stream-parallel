NodeWritable = require "#{__dirname}/../node_modules/readable-stream/writable"

class WriteReq
  constructor: (@stream, @len, @chunk, @encoding, @cb) ->
  onWriteError: (er) =>
    if @sync
      process.nextTick () => @cb er
    else
      @cb er

  doWrite: () =>
    state = @stream._writableState
    state.writing += 1
    @sync = true
    @stream._write @chunk, @encoding, (er) =>
      state.writing -= 1
      state.length -= @len
      if er
        @onWriteError er
      else
        finished = @stream.finishMaybe()
        if not finished and not state.bufferProcessing and state.buffer.length
          @stream.clearBuffer()

        afterWrite = () =>
          @stream.onwriteDrain() if not finished
          @cb()

        if @sync
          process.nextTick () => afterWrite()
        else
          afterWrite()

class Writable extends NodeWritable
  constructor: (options) ->
    super options
    # maximum number of parallel writes
    @_writableState.maxWrites = options?.maxWrites or 1
    # change .writing to a number instead of true/false
    # this indicates how many writes are in-flight
    @_writableState.writing = 0

  write: (chunk, encoding, cb) =>
    state = @_writableState
    ret = false

    if typeof encoding is 'function'
      cb = encoding
      encoding = null
    encoding ?= 'utf8'
    cb = (->) if typeof cb isnt 'function'

    if state.ended
      @writeAfterEnd cb
    else if @validChunk chunk, cb
      ret = @writeOrBuffer chunk, encoding, cb

    ret

  writeAfterEnd: (cb) =>
    er = new Error 'write after end'
    @emit 'error', er
    process.nextTick () -> cb er

  validChunk: (chunk, cb) =>
    state = @_writableState
    valid = true
    if not Buffer.isBuffer(chunk) and 'string' isnt typeof chunk and chunk? and not state.objectMode
      er = new TypeError 'Invalid non-string/buffer chunk'
      @emit 'error', er
      process.nextTick () -> cb er
      valid = false
    valid

  decodeChunk: (chunk, encoding) =>
    state = @_writableState
    if not state.objectMode and state.decodeStrings isnt false and typeof chunk is 'string'
      chunk = new Buffer chunk, encoding
    chunk

  writeOrBuffer: (chunk, encoding, cb) =>
    state = @_writableState
    chunk = @decodeChunk chunk, encoding
    len = if state.objectMode then 1 else chunk.length

    state.length += len

    ret = state.length < state.highWaterMark
    state.needDrain = not ret

    writeReq = new WriteReq @, len, chunk, encoding, cb
    if state.writing >= state.maxWrites
      state.buffer.push writeReq
    else
      writeReq.doWrite()

    ret

  clearBuffer: () =>
    state = @_writableState
    state.bufferProcessing = true
    c = 0
    while c < state.buffer.length
      writing_before = state.writing
      state.buffer[c].doWrite()
      # if we didn't call onwrite immediately, then it means the chunk
      # is still processing so move the buffer count past them
      if writing_before + 1 is state.writing and state.writing >= state.maxWrites
        c++
        break
      c++

    state.bufferProcessing = false
    if c < state.buffer.length
      state.buffer = state.buffer.slice c
    else
      state.buffer.length = 0

  onwriteDrain: () =>
    state = @_writableState
    if state.length is 0 and state.needDrain
      state.needDrain = false
      @emit 'drain'

  finishMaybe: () =>
    state = @_writableState
    if state.ending and state.length is 0 and not state.finished
      state.finished = true
      @emit 'finish'
    state.finished

module.exports = Writable
