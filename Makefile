.PHONY=test publish
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

publish:
	$(eval VERSION := $(shell grep version package.json | sed -ne 's/^[ ]*"version":[ ]*"\([0-9\.]*\)",/\1/p';))
	@echo \'$(VERSION)\'
	$(eval REPLY := $(shell read -p "Publish and tag as $(VERSION)? " -n 1 -r; echo $$REPLY))
	@echo \'$(REPLY)\'
	@if [[ $(REPLY) =~ ^[Yy]$$ ]]; then \
	    npm publish; \
	    git tag -a v$(VERSION) -m "version $(VERSION)"; \
	    git push --tags; \
	fi

clean:
	rm -rf lib-js/*
