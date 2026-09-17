# CrosslyBuyerAPI

The buyer-facing Crossly API — cart, orders, wishlists, offers, cashback. A DIFFERENT principal from the seller API: authenticated by a buyer OAuth token scoped &#x60;buyer:*&#x60; and resolved by &#x60;resolveBuyer&#x60;. A seller Personal Access Token will NOT authenticate these endpoints.

### Building

To install the required dependencies and to build the elixir project, run:
```
mix local.hex --force
mix do deps.get, compile
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `crossly_buyer` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:crossly_buyer, "~> 0.1.0"}]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/crossly_buyer](https://hexdocs.pm/crossly_buyer).
