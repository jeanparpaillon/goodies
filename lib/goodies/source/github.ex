defmodule Goodies.Source.Github do
  @moduledoc """
  Represent a github volume source
  """
  alias Goodies.Github.Api
  alias HTTPoison.Request

  defstruct org: nil,
            repo: nil,
            asset_name: nil,
            asset: nil,
            req: nil,
            opts: [],
            valid?: nil,
            errors: []

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
    validate_releases(source, Api.releases(source.org, source.repo, source.opts), %{})
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

  @doc false
  def errors(%{errors: errors}), do: errors

  ###
  ### Priv
  ###
  defp validate_releases(source, [], _acc) do
    error = """
    Can not fetch releases from GitHub repo `#{source.org}/#{source.repo}`
    """

    %{source | valid?: false, errors: [error | source.errors]}
  end

  defp validate_releases(source, releases, acc) do
    validate_release(
      source,
      filter_releases(releases, requirement: source.req),
      Map.put(acc, :releases, releases)
    )
  end

  defp validate_release(source, [], %{releases: releases}) do
    error =
      """
      No release matching `#{source.req}` in GitHub repo `#{source.org}/#{source.repo}`

      Releases:
      """ <> Enum.map_join(releases, "\n", &"  * `#{&1["tag_name"]}`") <> "\n"

    %{source | valid?: false, errors: [error | source.errors]}
  end

  defp validate_release(source, [release | _], acc) do
    validate_asset(
      source,
      filter_assets(release, source.asset_name),
      Map.put(acc, :release, release)
    )
  end

  defp validate_asset(source, [], %{release: release}) do
    error =
      """
      Can not find asset `#{format_re(source.asset_name)}` (#{source.req}) in GitHub repo `#{
        source.org
      }/#{source.repo}`

      Available assets:
      """ <> Enum.map_join(release["assets"], "\n", &"  * `#{&1["name"]}`") <> "\n"

    %{source | valid?: false, errors: [error | source.errors]}
  end

  defp validate_asset(source, [asset], _acc) do
    %{source | asset: asset, valid?: true}
  end

  defp filter_assets(release, name) when is_binary(name) do
    IO.inspect(name, label: "ASSET_1")
    release
    |> Map.get("assets")
    |> Enum.filter(&(Map.get(&1, "name") == name))
  end

  defp filter_assets(release, %Regex{} = re) do
    IO.inspect(re.source, label: "ASSET_2")
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

  defp format_re(name) when is_binary(name), do: name

  defp format_re(%Regex{} = re), do: re.source

  defimpl Goodies.Source.Protocol do
    @moduledoc false
    alias Goodies.Source.Github

    def local(source), do: Github.local(source)

    def validate(source), do: Github.validate(source)

    def request(source), do: Github.request(source)

    def errors(source), do: Github.errors(source)
  end
end
