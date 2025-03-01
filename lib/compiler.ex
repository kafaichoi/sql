# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 DBVisor

defmodule SQL.Compiler do
  @moduledoc false

  @doc false
  def generate(keyword, opts \\ [next: [?\s, ?\t, ?\r, ?\n, ?\f, 194, 160], eos: false]) do
    keyword = String.downcase(keyword)
    {to_match(keyword, opts), to_guard(keyword, opts), to_rest(opts), byte_size(keyword), :"#{keyword}"}
  end

  defp to_rest(opts) do
    if opts[:next] do
      to_node(:<<>>, [to_var(:next)])
    else
      to_var(:rest)
    end
  end

  defp to_match(keyword, opts) do
    if is_list(opts[:next]) do
      to_node(:<<>>, to_vars(keyword) ++ [to_var(:next)])
    else
      to_node(:<<>>, to_vars(keyword))
    end
  end

  defp to_guard(keyword, opts) do
    {value, _n} = to_guard(keyword)
    cond do
      opts[:eos] == true -> to_node(:and, value, to_node(:==, to_var(:rest), ""))
      opts[:next] -> to_node(:and, value, to_node(:in, to_var(:next), opts[:next]))
      true -> value
    end
  end

  defp to_guard(keyword) do
    for <<k <- keyword>>, reduce: {[], 1} do
      {[], n} -> {to_in(<<k>>, n), n+1}
      {left, n} -> {to_node(:and, left, to_in(<<k>>, n)), n+1}
    end
  end

  defp to_vars(keyword), do: (for n <- 1..byte_size(keyword), do: to_var(:"b#{n}"))
  defp to_var(tag), do: {tag, [], Elixir}
  defp to_in(k, n), do: to_node(:in, to_var(:"b#{n}"), ~c"#{k}#{String.upcase(k)}")
  defp to_node(:<<>> = tag, left), do: {tag, [], left ++ [{:"::", [], [to_var(:rest), to_var(:binary)]}]}
  defp to_node(tag, left, right), do: {tag, [context: Elixir, imports: [{2, Kernel}]], [left, right]}
end
