var path = __dirname + '/' + (process.env.TEST_WSP_COV ? 'lib-cov' : 'lib') + '/writable_stream_parallel';
module.exports = require(path);
