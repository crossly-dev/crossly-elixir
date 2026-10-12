defmodule CrosslyWebhooks do
  @moduledoc """
  Verify a Crossly webhook.

      Crossly-Signature: t=<unix seconds>,v1=<hex HMAC-SHA256>

  signed over `"\#{t}.\#{raw_body}"` with the endpoint's signing secret.

  Three ways to get this wrong, all silent:

    1. Verifying a re-serialised body. `Jason.decode!` then `Jason.encode!`
       does not round-trip byte for byte, so genuine payloads fail and the
       usual fix is to stop verifying. In Phoenix this is the big one — the
       default `Plug.Parsers` consumes the body and you cannot get it back.
       Use a custom body reader that stashes the raw body in `conn.assigns`.

    2. Comparing with `==`. Elixir's binary equality returns early on the first
       differing byte. `:crypto.hash_equals/2` does not.

    3. Ignoring the timestamp. Without it a captured request replays forever.
       The timestamp is INSIDE the signed message, so it cannot be edited to
       look fresh.

  No dependencies — `:crypto` ships with OTP.

  ## Phoenix body reader

      defmodule MyApp.CachingBodyReader do
        def read_body(conn, opts) do
          {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
          {:ok, body, Plug.Conn.assign(conn, :raw_body, body)}
        end
      end

  Then in `endpoint.ex`, pass `body_reader: {MyApp.CachingBodyReader, :read_body, []}`
  to `Plug.Parsers`.
  """

  @default_tolerance_seconds 300

  defmodule VerificationError do
    @moduledoc """
    Raised when a webhook does not verify.

    `reason` is stable across every language port, so one alerting rule can
    tell a forged request from a clock problem.
    """
    defexception [:reason, :message]

    @type t :: %__MODULE__{
            reason:
              :malformed_header | :bad_signature | :timestamp_out_of_tolerance | :missing_secret,
            message: String.t()
          }
  end

  @doc """
  Verify a webhook and return `{:ok, raw_body}` or `{:error, %VerificationError{}}`.

  A tagged tuple rather than a bare boolean, so a `case` that forgets a clause
  is a compiler warning rather than a silent acceptance.

  `raw_body` must be the EXACT bytes received. `:now` overrides the clock, for
  tests.
  """
  @spec verify(binary(), String.t() | nil, String.t(), keyword()) ::
          {:ok, binary()} | {:error, VerificationError.t()}
  def verify(raw_body, signature_header, secret, opts \\ []) do
    tolerance = Keyword.get(opts, :tolerance_seconds, @default_tolerance_seconds)
    now = Keyword.get(opts, :now, System.system_time(:second))

    with :ok <- check_secret(secret),
         {:ok, header} <- check_header(signature_header),
         {:ok, timestamp, provided} <- parse_signature_header(header),
         :ok <- check_signature(raw_body, timestamp, provided, secret),
         :ok <- check_freshness(timestamp, now, tolerance) do
      {:ok, raw_body}
    end
  end

  @doc """
  Same as `verify/4` but raises on failure.
  """
  @spec verify!(binary(), String.t() | nil, String.t(), keyword()) :: binary()
  def verify!(raw_body, signature_header, secret, opts \\ []) do
    case verify(raw_body, signature_header, secret, opts) do
      {:ok, body} -> body
      {:error, error} -> raise error
    end
  end

  defp check_secret(secret) when is_binary(secret) and byte_size(secret) > 0, do: :ok

  defp check_secret(_),
    do:
      {:error,
       %VerificationError{
         reason: :missing_secret,
         message: "A webhook signing secret is required."
       }}

  defp check_header(header) when is_binary(header) and byte_size(header) > 0, do: {:ok, header}

  defp check_header(_),
    do:
      {:error,
       %VerificationError{
         reason: :malformed_header,
         message: "No Crossly-Signature header on the request."
       }}

  # Field-wise rather than one regex, so a future v2= alongside v1= does not
  # break existing verifiers — the entire reason the scheme is versioned.
  defp parse_signature_header(header) do
    parsed =
      header
      |> String.split(",")
      |> Enum.reduce(%{}, fn part, acc ->
        case String.split(part, "=", parts: 2) do
          [key, value] -> Map.put(acc, String.trim(key), String.trim(value))
          _ -> acc
        end
      end)

    with {:ok, raw_t} <- fetch(parsed, "t"),
         {t, ""} <- Integer.parse(raw_t),
         {:ok, v1} <- fetch(parsed, "v1"),
         true <- v1 != "" do
      {:ok, t, v1}
    else
      _ ->
        {:error,
         %VerificationError{
           reason: :malformed_header,
           message:
             ~s(Could not parse Crossly-Signature: expected "t=<unix>,v1=<hex>", got ") <>
               String.slice(header, 0, 60) <> ~s(".)
         }}
    end
  end

  defp fetch(map, key) do
    case Map.fetch(map, key) do
      {:ok, value} -> {:ok, value}
      :error -> :error
    end
  end

  defp check_signature(raw_body, timestamp, provided, secret) do
    expected =
      :crypto.mac(:hmac, :sha256, secret, "#{timestamp}.#{raw_body}")
      |> Base.encode16(case: :lower)

    # hash_equals is constant time and returns false on a length mismatch —
    # which a truncated signature produces — rather than raising.
    if :crypto.hash_equals(expected, provided) do
      :ok
    else
      {:error,
       %VerificationError{
         reason: :bad_signature,
         message:
           "Signature did not match. If genuine payloads are failing, you are almost " <>
             "certainly verifying a re-serialised body — in Phoenix you need a caching " <>
             "body reader, because Plug.Parsers consumes the body."
       }}
    end
  end

  # Freshness AFTER the signature, so an attacker learns nothing about
  # timestamps without already holding a valid signature.
  defp check_freshness(timestamp, now, tolerance) do
    drift = abs(now - timestamp)

    if drift <= tolerance do
      :ok
    else
      {:error,
       %VerificationError{
         reason: :timestamp_out_of_tolerance,
         message:
           "Timestamp is #{drift}s away from now (tolerance #{tolerance}s). " <>
             "This is a replay guard — if it fires on live traffic, check your server clock."
       }}
    end
  end
end
