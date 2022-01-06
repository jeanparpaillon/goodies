defprotocol Goodies.Source.Protocol do
  @moduledoc false

  @spec local(t()) :: String.t()
  def local(source)

  @spec validate(t()) :: t()
  def validate(source)

  @spec request(t()) :: t()
  def request(source)

  @spec errors(t()) :: [String.t()]
  def errors(source)
end

defmodule Goodies.Source.Error do
  defexception [:message, :reason, :source]

  alias Goodies.Source

  def message(%{source: source}) when not is_nil(source) do
    """
    Error fetching asset:

    """
    <> Enum.join(Source.Protocol.errors(source), "\n")
  end

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
  @spec fetch!(t(), Path.t()[fetch_opt()]) :: t()
  def fetch!(source, to, opts \\ []) do
    :ok = File.mkdir_p!(Path.dirname(to))
    dest = File.stream!(to)

    source
    |> Source.Protocol.validate()
    |> case do
      %{valid?: true} = source ->
        source
        |> Source.Protocol.request()
        |> Downloader.request(opts)
        |> Stream.into(dest)
        |> Stream.run()

      %{valid?: false} = source ->
        raise Goodies.Source.Error, source: source
    end
  end

  ###
  ### Priv
  ###
  defp resolve_path({:app, path}), do: Application.app_dir(:goodies, path)

  defp resolve_path(path) when is_binary(path), do: path
end
