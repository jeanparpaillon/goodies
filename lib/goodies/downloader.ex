defmodule Goodies.Downloader do
  @moduledoc """
  Downloader
  """
  alias Goodies.Progress
  alias HTTPoison.Request

  defmodule Response do
    @moduledoc false
    defstruct req: nil,
              conn: nil,
              ref: nil,
              code: nil,
              headers: %{},
              data: [],
              error: nil,
              halt: false,
              opts: [],
              progress: false,
              progress_status: nil,
              bytes: 0,
              length: nil
  end

  defmodule Error do
    defexception [:message, :code, :error]
  end

  @type header :: {String.t(), String.t()}
  @type opt :: {:progress, boolean()}

  @doc """
  Get
  """
  @spec get(binary(), [header()], [opt()]) :: Enumerable.t()
  def get(uri, headers \\ [], opts \\ []) when is_binary(uri) do
    request(%Request{method: :get, url: uri, headers: headers}, opts)
  end

  @spec request(Request.t(), [opt()]) :: Enumerable.t()
  def request(%Request{} = req, opts \\ []) do
    Stream.resource(fn -> init_req(req, opts) end, &continue_req/1, &end_req/1)
  end

  defp init_req(req, opts) do
    {:ok, _} = Application.ensure_all_started(:hackney)

    %URI{path: path, query: query} = uri = URI.parse(req.url)
    {:ok, conn} = Mint.HTTP.connect(scheme(uri), uri.host, port(uri))
    path = "#{path}?#{query}"

    with {:ok, conn, ref} <- Mint.HTTP.request(conn, method(req), path, req.headers, req.body) do
      %Response{
        req: req,
        conn: conn,
        ref: ref,
        progress: Keyword.get(opts, :progress, false),
        opts: opts
      }
    end
  end

  defp continue_req({:error, reason}), do: {:halt, {:error, reason}}

  defp continue_req(%Response{halt: true} = resp), do: {:halt, resp}

  defp continue_req(resp) do
    receive do
      msg ->
        case Mint.HTTP.stream(resp.conn, msg) do
          :unknown ->
            continue_req(resp)

          {:ok, conn, responses} ->
            handle_responses(responses, %{resp | conn: conn})
        end
    end
  end

  defp handle_responses(responses, resp) do
    case Enum.reduce_while(responses, resp, &handle_http/2) do
      %Response{error: nil} = resp -> {Enum.reverse(resp.data), %{resp | data: []}}
      resp -> {:halt, resp}
    end
  end

  defp handle_http({:status, ref, 200}, %{ref: ref} = acc),
    do: {:cont, %{acc | code: 200}}

  defp handle_http({:status, ref, code}, %{ref: ref} = acc) when code in [301, 302],
    do: {:cont, %{acc | code: code}}

  defp handle_http({:status, ref, code}, %{ref: ref} = acc),
    do: {:halt, %{acc | code: code, error: [code: code]}}

  defp handle_http({:headers, ref, headers}, %{ref: ref} = acc) do
    headers = Enum.reduce(headers, acc.headers, &normalize_header/2)
    handle_headers(%{acc | headers: headers})
  end

  defp handle_http({:done, ref}, %{ref: ref, progress: false} = acc),
    do: {:halt, %{acc | halt: true}}

  defp handle_http(
         {:done, ref},
         %{ref: ref, progress: true, progress_status: progress_status} = acc
       ) do
    Progress.done(progress_status)
    {:halt, %{acc | halt: true}}
  end

  defp handle_http({:error, ref, reason}, %{ref: ref} = acc),
    do: {:halt, %{acc | error: [error: reason]}}

  defp handle_http({:pong, ref}, %{ref: ref} = acc),
    do: {:cont, acc}

  defp handle_http({:pong, ref}, %{ref: ref} = acc),
    do: {:cont, acc}

  defp handle_http({:push_promise, ref, _, _}, %{ref: ref} = acc),
    do: {:cont, acc}

  defp handle_http({:data, ref, bin}, %{progress: false, ref: ref} = acc),
    do: {:cont, %{acc | data: [bin | acc.data]}}

  defp handle_http({:data, ref, bin}, %{ref: ref, progress: true, progress_status: nil} = acc) do
    progress_status =
      case acc.length do
        nil -> Progress.init_indeterminate()
        l -> Progress.init(l)
      end
      |> Progress.update(byte_size(bin))

    {:cont, %{acc | progress_status: progress_status, data: [bin | acc.data]}}
  end

  defp handle_http(
         {:data, ref, bin},
         %{ref: ref, progress: true, progress_status: progress_status} = acc
       ) do
    {:cont,
     %{
       acc
       | progress_status: Progress.update(progress_status, byte_size(bin)),
         data: [bin | acc.data]
     }}
  end

  defp handle_headers(%{headers: %{"location" => [location | _]}, code: code} = acc)
       when code in [301, 302] do
    {:ok, _} = Mint.HTTP.close(acc.conn)
    {:halt, init_req(%{acc.req | url: location}, acc.opts)}
  end

  defp handle_headers(%{code: code} = acc) when code in [301, 302] do
    {:halt, %{acc | error: :redirect_no_location}}
  end

  defp handle_headers(%{headers: headers} = resp) do
    resp =
      case Map.get(headers, "content-length") do
        nil -> resp
        [bytes | _] -> %{resp | length: cast_integer(bytes, nil)}
      end

    {:cont, resp}
  end

  defp normalize_header({name, header}, acc) do
    values = String.split(header, ",", trim: true)
    Map.update(acc, String.downcase(name), values, &(&1 ++ values))
  end

  defp end_req(%Response{error: nil} = resp), do: Mint.HTTP.close(resp.conn)

  defp end_req(%Response{error: error}) do
    raise Error, error
  end

  defp scheme(%URI{scheme: "http"}), do: :http

  defp scheme(%URI{scheme: "https"}), do: :https

  defp port(%URI{port: nil, scheme: "http"}), do: 80

  defp port(%URI{port: nil, scheme: "https"}), do: 443

  defp port(%URI{port: port}) when is_integer(port), do: port

  defp method(%Request{method: :get}), do: "GET"

  defp cast_integer(s, default) do
    String.to_integer(s)
  rescue
    ArgumentError ->
      default
  end
end
