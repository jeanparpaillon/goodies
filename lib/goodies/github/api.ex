defmodule Goodies.Github.Api do
  @moduledoc false
  use HTTPoison.Base

  alias HTTPoison.Response

  @endpoint "https://api.github.com"

  def releases(org, repo, credentials) do
    {:ok, %{body: releases}} = get("/repos/#{org}/#{repo}/releases", [], credentials)
    releases
  end

  def process_url("http" <> _ = url), do: url

  def process_url(url), do: @endpoint <> url

  def request(method, url, body, headers, options) do
    headers = add_auth_header(headers, options)
    super(method, url, body, headers, Keyword.drop(options, [:token]))
  end

  def process_response(%Response{body: body, headers: headers} = response) do
    case content_type(headers) do
      {"application", "json", _} -> %{response | body: Jason.decode!(body)}
      _ -> response
    end
  end

  def add_auth_header(headers, options) do
    [{"authorization", "token #{Keyword.get(options, :token)}"} | headers]
  end

  defp content_type(headers) do
    headers
    |> Enum.find_value(fn
      {"Content-Type", ct} -> parse_content_type(ct)
      _ -> false
    end)
  end

  defp parse_content_type(ct) do
    [ct | opts] = String.split(ct, ";", trim: true)
    [ct1, ct2] = String.split(ct, "/", parts: 2, trim: true)
    {ct1, ct2, opts}
  end
end
