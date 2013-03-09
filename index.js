require('coffee-script');
var path = __dirname + '/' + (process.env.TEST_WSP_COV ? 'lib-js-cov' : 'lib') + '/writable_stream_parallel';
module.exports = require(path);
