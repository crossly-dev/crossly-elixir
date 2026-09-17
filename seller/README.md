# CrosslySellerAPI

The seller-facing Crossly API — listings, crossposting, orders, analytics. Authenticate with a Personal Access Token (&#x60;Authorization: Bearer crossly_pat_…&#x60;) or a seller OAuth token (&#x60;crossly_oat_…&#x60;), scoped &#x60;&lt;domain&gt;:&lt;read|write&gt;&#x60;. Buyer endpoints are a SEPARATE API with a separate principal — see the Crossly Buyer API.

### Building

To install the required dependencies and to build the elixir project, run:
```
mix local.hex --force
mix do deps.get, compile
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `crossly` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:crossly, "~> 0.1.0"}]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/crossly](https://hexdocs.pm/crossly).
