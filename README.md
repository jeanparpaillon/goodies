# Goodies

Small volume manager
## Usage

```elixir
s = Goodies.Source.Github.new("jeanparpaillon", "goodies", ~r/goodies.*/, ">= 0.0.0")
s |> Goodies.Volume.new() |> Goodies.Volume.fetch(progress: true)
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `goodies` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:goodies, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/goodies](https://hexdocs.pm/goodies).

