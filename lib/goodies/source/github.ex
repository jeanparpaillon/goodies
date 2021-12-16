defmodule Goodies.Source.Github do
  @moduledoc """
  Represent a github volume source
  """
  alias Goodies.Github.Api
  alias Goodies.Source
  alias HTTPoison.Request

  defstruct org: nil, repo: nil, asset_name: nil, asset: nil, req: nil, opts: [], valid?: nil

  @type t :: %__MODULE__{}
  @type org() :: String.t()
  @type repo() :: String.t()
  @type asset() :: String.t() | Regex.t()
  @type new_opt() :: {:token, String.t()}
  @type fetch_opt() :: {:progress, boolean()}

  @doc """
  Creates github source
  """
  @spec new(org(), repo(), asset(), Version.requirement(), [new_opt()]) :: t()
  def new(org, repo, asset_name, requirement, opts \\ [])
      when is_binary(org) and is_binary(repo) do
    %__MODULE__{org: org, repo: repo, asset_name: asset_name, req: requirement, opts: opts}
  end

  @doc """
  Returns local name for source
  """
  @spec local(t()) :: String.t()
  def local(%__MODULE__{org: org, repo: repo, asset: asset, req: req}) do
    {org, repo, asset, req}
    |> :erlang.phash2()
    |> Integer.to_string(16)
  end

  @doc """
  Update source: fetch github asset matching repo and version requirements
  """
  @spec validate(t()) :: t()
  def validate(%{valid?: nil} = source) do
    releases = Api.releases(source.org, source.repo, source.opts)

    with {:release, [release | _]} <-
           {:release, filter_releases(releases, requirement: source.req)},
         {:asset, [asset]} <- {:asset, filter_assets(release, source.asset_name)} do
      %{source | asset: asset, valid?: true}
    else
      {:release, []} ->
        %{source | valid?: false}

      {:asset, []} ->
        %{source | valid?: false}
    end
  end

  def validate(%{valid?: true} = source), do: source

  @doc """
  Returns request for fetching source
  """
  @spec request(t()) :: Request.t() | nil
  def request(%__MODULE__{asset: nil}), do: nil

  def request(%__MODULE__{asset: %{"url" => url}} = source) do
    headers =
      [{"accept", "application/octet-stream"}]
      |> Api.add_auth_header(source.opts)

    %Request{url: url, headers: headers}
  end

  ###
  ### Priv
  ###
  defp filter_assets(release, name) when is_binary(name) do
    release
    |> Map.get("assets")
    |> Enum.filter(&(Map.get(&1, "name") == name))
  end

  defp filter_assets(release, %Regex{} = re) do
    release
    |> Map.get("assets")
    |> Enum.filter(&Regex.match?(re, Map.get(&1, "name")))
  end

  defp filter_releases(releases, opts) do
    releases
    |> Enum.map(&cast_release/1)
    |> filter_versions(Keyword.get(opts, :requirement))
    |> Enum.sort_by(& &1.version, &(Version.compare(&1, &2) == :gt))
    |> Enum.map(& &1.json)
  end

  defp cast_release(%{"tag_name" => tag_name} = json) do
    %{json: json, version: tag_to_version(tag_name)}
  end

  defp tag_to_version("v" <> tag), do: tag_to_version(tag)

  defp tag_to_version(tag) do
    Version.parse!(tag)
  rescue
    Version.InvalidVersionError ->
      Version.parse("0.0.0")
  end

  defp filter_versions(releases, nil), do: releases

  defp filter_versions(releases, req) when is_binary(req) do
    filter_versions(releases, Version.parse_requirement!(req))
  end

  defp filter_versions(releases, req) do
    Enum.filter(releases, &Version.match?(&1.version, req))
  end

  defimpl Goodies.Source.Protocol do
    @moduledoc false
    alias Goodies.Source.Github

    def local(source), do: Github.local(source)

    def update(source), do: Github.update(source)

    def request(source), do: Github.request(source)
  end
end
