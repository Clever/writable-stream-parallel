module.exports = Writable;

var util = require('util');
var NodeWritable = require("../node_modules/readable-stream/writable");

util.inherits(Writable, NodeWritable);

function WriteReq(stream, len, chunk, encoding, cb) {
  var _this = this;
  this.stream = stream;
  this.len = len;
  this.chunk = chunk;
  this.encoding = encoding;
  this.cb = cb;
  this.onWriteError = function(er) {
    return WriteReq.prototype.onWriteError.apply(_this, arguments);
  };
}

WriteReq.prototype.onWriteError = function(er) {
  var _this = this;
  if (this.sync) {
    return process.nextTick(function() {
      return _this.cb(er);
    });
  } else {
    return this.cb(er);
  }
};

WriteReq.prototype.doWrite = function() {
  var state,
    _this = this;
  state = this.stream._writableState;
  state.writing += 1;
  this.sync = true;
  return this.stream._write(this.chunk, this.encoding, function(er) {
    var afterWrite, finished;
    state.writing -= 1;
    state.length -= _this.len;
    if (er) {
      return _this.onWriteError(er);
    } else {
      finished = finishMaybe(_this.stream, state);
      if (!finished && !state.bufferProcessing && state.buffer.length) {
        clearBuffer(_this.stream, state);
      }
      afterWrite = function() {
        if (!finished) {
          onwriteDrain(_this, state);
        }
        return _this.cb();
      };
      if (_this.sync) {
        return process.nextTick(function() {
          return afterWrite();
        });
      } else {
        return afterWrite();
      }
    }
  });
};

function Writable(options) {
  NodeWritable.call(this, options);
  this._writableState.maxWrites = (options != null ? options.maxWrites : void 0) || 1;
  this._writableState.writing = 0;
}

function writeAfterEnd(stream, state, cb) {
  var er = new Error('write after end');
  // TODO: defer error events consistently everywhere, not just the cb
  stream.emit('error', er);
  process.nextTick(function() {
    cb(er);
  });
}

// If we get something that is not a buffer, string, null, or undefined,
// and we're not in objectMode, then that's an error.
// Otherwise stream chunks are all considered to be of length=1, and the
// watermarks determine how many objects to keep in the buffer, rather than
// how many bytes or characters.
function validChunk(stream, state, chunk, cb) {
  var valid = true;
  if (!Buffer.isBuffer(chunk) &&
      'string' !== typeof chunk &&
      chunk !== null &&
      chunk !== undefined &&
      !state.objectMode) {
    var er = new TypeError('Invalid non-string/buffer chunk');
    stream.emit('error', er);
    process.nextTick(function() {
      cb(er);
    });
    valid = false;
  }
  return valid;
}

Writable.prototype.write = function(chunk, encoding, cb) {
  var state = this._writableState;
  var ret = false;

  if (typeof encoding === 'function') {
    cb = encoding;
    encoding = null;
  }
  if (!encoding)
    encoding = 'utf8';

  if (typeof cb !== 'function')
    cb = function() {};

  if (state.ended)
    writeAfterEnd(this, state, cb);
  else if (validChunk(this, state, chunk, cb))
    ret = writeOrBuffer(this, state, chunk, encoding, cb);

  return ret;
};

function decodeChunk(state, chunk, encoding) {
  if (!state.objectMode &&
      state.decodeStrings !== false &&
      typeof chunk === 'string') {
    chunk = new Buffer(chunk, encoding);
  }
  return chunk;
}

// Only queue the write if maxWrites has been exceeded
function writeOrBuffer(stream, state, chunk, encoding, cb) {
  chunk = decodeChunk(state, chunk, encoding);
  var len = state.objectMode ? 1 : chunk.length;

  state.length += len;

  var ret = state.length < state.highWaterMark;
  state.needDrain = !ret;

  var writeReq = new WriteReq(stream, len, chunk, encoding, cb);
  if (state.writing >= state.maxWrites) {
    state.buffer.push(writeReq);
  } else {
    writeReq.doWrite();
  }

  return ret;
}

// Must force callback to be called on nextTick, so that we don't
// emit 'drain' before the write() consumer gets the 'false' return
// value, and has a chance to attach a 'drain' listener.
function onwriteDrain(stream, state) {
  if (state.length === 0 && state.needDrain) {
    state.needDrain = false;
    stream.emit('drain');
  }
}

// if there's something in the buffer waiting, then process it
function clearBuffer(stream, state) {
  state.bufferProcessing = true;

  for (var c = 0; c < state.buffer.length; c++) {
    var writing_before = state.writing;
    state.buffer[c].doWrite();
    if (writing_before + 1 === state.writing && state.writing >= state.maxWrites) {
      c++;
      break;
    }
    c++;
  }

  state.bufferProcessing = false;
  if (c < state.buffer.length)
    state.buffer = state.buffer.slice(c);
  else
    state.buffer.length = 0;
}

function finishMaybe(stream, state) {
  if (state.ending && state.length === 0 && !state.finished) {
    state.finished = true;
    stream.emit('finish');
  }
  return state.finished;
}
