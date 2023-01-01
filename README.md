![Build Status](https://drone.ops.clever.com/github.com/Clever/writable-stream-parallel/status.svg?branch=master)

# writable-stream-parallel

Extension of the new node.js [Writable stream](http://nodejs.org/docs/v0.10.0/api/stream.html#stream_class_stream_writable) interface that allows for parallel writes.

## Installation

```
npm install writable-stream-parallel
```

Currently only works with node v0.9.{11,12} and v0.10.x.

## Motivation

The normal node Writable stream can only perform one write at a time. For example:

```javascript
var Readable = require('stream').Readable;
var Writable = require('stream').Writable

var r = new Readable({ objectMode: true });
r._read = function noop() {}
r.push(1);
r.push(2);
r.push(3);

var writable = new Writable({objectMode: true});
writable._write = function(chunk, encoding, cb) {
    console.log('writing', chunk);
    setTimeout(function() { console.log('wrote', chunk); cb(); }, 100);
};
r.pipe(writable);
```

Output:

```
writing 1
wrote 1
writing 2
wrote 2
writing 3
wrote 3
```

## stream-writable-parallel behavior

Serial writes limit the usefulness of streams in a lot of settings. `stream-writable-parallel` provides a Writable class that parallelizes calls to `_write` up to a certain `maxWrites`:

```javascript
var Writable = require('writable-stream-parallel').Writable;

var writable = new Writable({objectMode: true, maxWrites: 10});
writable._write = function(chunk, encoding, cb) {
    console.log('writing', chunk);
    setTimeout(function() { console.log('wrote', chunk); cb(); }, 100);
};
r.pipe(writable);
```

Output:

```
writing 1
writing 2
writing 3
wrote 1
wrote 2
wrote 3
```
test
