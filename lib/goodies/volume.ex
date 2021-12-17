defmodule Goodies.Volume do
  @moduledoc """
  Represents and handle volume
  """

  alias Goodies.Source

  defstruct source: nil, local: nil

  @type t() :: %__MODULE__{}
  @type source() :: Source.Github.t()

  @doc """
  Creates a volume structure
  """
  @spec new(source()) :: t()
  def new(source), do: %__MODULE__{source: source}

  @doc """
  Ensure volume has been fetched
  """
  @spec fetch(t(), [Source.fetch_opt()]) :: t()
  def fetch(s, opts \\ [])

  def fetch(%__MODULE__{} = volume, opts) do
    local = Source.local(volume.source)

    source =
      if not File.exists?(local) do
        Source.fetch!(volume.source, local, opts)
      else
        volume.source
      end

    %{volume | local: local, source: source}
  end

  def fetch(source, opts) do
    source
    |> Source.Protocol.impl_for()
    |> case do
      nil -> raise ArgumentError, "invalid source #{inspect source}"
      _ -> source |> new() |> fetch(opts)
    end
  end

  @doc """
  Delete downloaded volume
  """
  @spec clean(t()) :: :ok | {:error, term()}
  def clean(volume) do
    with {:ok, _} <- File.rm_rf(Source.local(volume.source)) do
      :ok
    end
  end

  @doc """
  Mount volume:

  * if volume is already mounted on destination, noop
  * if volume is mounted on a different destination, remount
  """
  @spec mount(t(), Path.t()) :: :ok | {:error, term()}
  def mount(%__MODULE__{local: nil}, _to) do
    {:error, :unfetched}
  end

  def mount(volume, to) do
    case mounted_on(volume) do
      ^to ->
        :ok

      nil ->
        do_mount(volume.local, to)

      to ->
        with :ok <- umount(volume) do
          do_mount(volume.local, to)
        end
    end
  end

  @doc """
  Umount volume, if mounted, noop otherwise
  """
  @spec umount(t()) :: :ok | {:error, term()}
  def umount(%__MODULE__{local: nil}), do: {:error, :unfetched}

  def umount(volume) do
    case mounted_on(volume) do
      nil -> :ok
      _to -> do_umount(volume.local)
    end
  end

  @doc """
  Returns path where volume is mounted, nil otherwise
  """
  @spec mounted_on(t()) :: Path.t() | nil
  def mounted_on(%__MODULE__{local: nil}), do: nil

  def mounted_on(volume) do
    re = ~r/^#{volume.local}[[:blank:]]/

    "/proc/mounts"
    |> File.read!()
    |> String.split("\n")
    |> Enum.filter(&Regex.match?(re, &1))
    |> Enum.map(&String.split(&1, " ", trim: true))
    |> case do
      [ [_source, dest | _] ] ->  dest
      _ -> nil
    end
  end

  ###
  ### Priv
  ###
  defp do_mount(src, dest) do
    case System.cmd("mount", [src, dest]) do
      {_, 0} -> :ok
      {_, code} -> {:error, {:mount, code}}
    end
  end

  defp do_umount(src) do
    case System.cmd("umount", [src]) do
      {_, 0} -> :ok
      {_, code} -> {:error, {:umount, code}}
    end
  end
end
