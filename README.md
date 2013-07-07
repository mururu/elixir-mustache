# Mustache for Elixir

[![Build Status](https://travis-ci.org/mururu/elixir-mustache.png?branch=master)](https://travis-ci.org/mururu/elixir-mustache)

WIP

## Usage

```elixir
Mustache.render("Hello, {{planet}}", [planet: "World!"])
#=> "Hello, World!"
```

## Links

* [mustache(5) -- Logic-less templates.](http://mustache.github.io/mustache.5.html)

## TODO
* Improve error message
* More tests
* Various API
* Support partials
* Support changing delimiter
* Speed improvements
