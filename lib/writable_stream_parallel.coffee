Object.prototype.mixin = (Klass, exclude=[]) ->
  # assign class properties
  for key, value of Klass
    @[key] = value

  # assign instance properties
  for key, value of Klass.prototype when key not in exclude #and key not in ['constructor']
    @::[key] = value
  @

module.exports =
  Writable: require "#{__dirname}/writable"
  Duplex: require "#{__dirname}/duplex"
  Transform: require "#{__dirname}/transform"
