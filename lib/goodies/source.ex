defprotocol Goodies.Source.Protocol do
  @moduledoc false

  @spec local(t()) :: String.t()
  def local(source)

  @spec update(t()) :: t()
  def update(source)

  @spec request(t()) :: t()
  def request(source)
end

defmodule Goodies.Source.Error do
  defexception [:message, :reason]

  def message(e) do
    "source error #{inspect(e.reason)}"
  end
end

defmodule Goodies.Source do
  @moduledoc """
  Common for sources
  """
  alias __MODULE__
  alias Goodies.Downloader

  @type t :: Source.Protocol.t()
  @type fetch_opt :: {:progress, boolean()}

  @doc false
  def source_dir do
    :goodies
    |> Application.get_env(:source_dir)
    |> resolve_path()
  end

  @doc false
  def local(source) do
    Path.join(source_dir(), Source.Protocol.local(source))
  end

  @doc false
  @spec fetch!(t(), [fetch_opt()]) :: t()
  def fetch!(source, opts \\ []) do
    to = local(source)
    :ok = File.mkdir_p!(Path.dirname(to))
    dest = File.stream!(to)
    source = Source.Protocol.update(source)

    source
    |> Source.Protocol.request()
    |> Downloader.request(opts)
    |> Stream.into(dest)
    |> Stream.run()

    source
  end

  ###
  ### Priv
  ###
  defp resolve_path({:app, path}) do
    Application.app_dir(:goodies, path)
  end

  defp resolve_path(path) when is_binary(path) do
    path
  end
end
