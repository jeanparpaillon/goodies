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
  def new(source) do
    %__MODULE__{source: source}
  end

  @doc """
  Ensure volume has been fetched
  """
  @spec fetch(t(), [Source.fetch_opt()]) :: t()
  def fetch(volume, opts \\ []) do
    local = Source.local(volume.source)

    if not File.exists?(local) do
      _ = Source.fetch!(volume.source, opts)
    end

    %{volume | local: local}
  end
end
