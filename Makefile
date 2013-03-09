test:
	DEBUG=tests NODE_ENV=test node_modules/mocha/bin/mocha --compilers coffee:coffee-script test/test.coffee
