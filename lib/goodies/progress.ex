defmodule Goodies.Progress do
  @moduledoc """
  Handle progress bar
  """

  defstruct total: nil, ref: nil, bar: nil, length: 0

  @doc false
  def init(total) when is_integer(total) do
    %__MODULE__{total: total}
  end

  @doc false
  def init_indeterminate do
    owner = self()
    ref = make_ref()

    p =
      spawn_link(fn ->
        ProgressBar.render_indeterminate(fn ->
          receive do
            {:done, {^owner, ^ref}} -> :ok
          end
        end)
      end)

    %__MODULE__{ref: ref, bar: p}
  end

  @doc false
  def update(%__MODULE__{bar: nil, total: total} = s, length) do
    s = %{s | length: s.length + length}
    ProgressBar.render(s.length, total, suffix: :bytes)
    s
  end

  def update(%__MODULE__{bar: _pid} = s, _length), do: s

  @doc false
  def done(%__MODULE__{bar: nil}), do: :ok

  def done(%__MODULE__{bar: pid, ref: ref}) do
    send(pid, {:done, {self(), ref}})
  end
end
