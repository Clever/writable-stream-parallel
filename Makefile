.PHONY=test
COFFEE=./node_modules/coffee-script/bin/coffee
COFFEE_FILES = $(shell find lib/ -type f -name '*.coffee')
JS_FILES = $(patsubst lib/%.coffee, lib-js/%.js, $(COFFEE_FILES))

all: $(JS_FILES)

lib-js/%.js: lib/%.coffee
	@mkdir -p "$(@D)"
	@echo compiling "$<" to "$@"
	$(COFFEE) -o "$(@D)" -c "$<"

test: all
	. ~/nvm/nvm.sh && nvm use 0.9.12 && node --version && DEBUG=tests NODE_ENV=test node_modules/mocha/bin/mocha --compilers coffee:coffee-script test/test.coffee

clean:
	rm -rf lib-js/*
