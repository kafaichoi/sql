# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 DBVisor

defmodule SQL.String do
  @moduledoc false

  def token_to_sql(value, mod \\ __MODULE__)
  def token_to_sql(value, _mod) when is_struct(value) do
    to_string(value)
  end
  def token_to_sql({tag, _, []}, mod) do
    "#{mod.token_to_sql(tag)}"
  end
  def token_to_sql({tag, _, value}, _mod) when tag in ~w[ident integer float]a do
    "#{value}"
  end
  def token_to_sql({:"", _, value}, mod) do
    "\"#{mod.token_to_sql(value)}\""
  end
  def token_to_sql({:"''", _, value}, mod) do
    "'#{mod.token_to_sql(value)}'"
  end
  def token_to_sql({:"()", _, value}, mod) do
    "(#{mod.token_to_sql(value)})"
  end
  def token_to_sql({:"\#{}", _, [value]}, _mod) do
    "\#{#{value}}"
  end
  def token_to_sql({:in, _, [right, {:binding, _, _} = left]}, mod) do
    "#{mod.token_to_sql(right)} = ANY(#{mod.token_to_sql(left)})"
  end
  def token_to_sql({tag, _, value}, mod) when tag in ~w[; ,]a do
    "#{mod.token_to_sql(value)}#{mod.token_to_sql(tag)}"
  end
  def token_to_sql({:distinct = t1, _, [{:from, _, _} = left]}, mod) do
    "#{mod.token_to_sql(t1)} #{mod.token_to_sql(left)}"
  end
  def token_to_sql({:distinct = t1, _, [{:on = t2, _, [{:"()", _, values}]}]}, mod) do
    "#{mod.token_to_sql(t1)} #{mod.token_to_sql(t2)} (#{Enum.map_join(values, " ", &mod.token_to_sql/1)})"
  end
  def token_to_sql({:in = t1, _, [ident, {:"()", _, values}]}, mod) do
    "#{mod.token_to_sql(ident)} #{mod.token_to_sql(t1)} (#{Enum.map_join(values, " ", &mod.token_to_sql/1)})"
  end
  def token_to_sql({:recursive = t1, _, [ident, {:"()", _, values}]}, mod) do
    "#{mod.token_to_sql(t1)} #{mod.token_to_sql(ident)} (#{Enum.map_join(values, " ", &mod.token_to_sql/1)})"
  end
  def token_to_sql({:is = t1, _, [ident, distinct, from]}, mod) do
    "#{mod.token_to_sql(ident)} #{mod.token_to_sql(t1)} #{mod.token_to_sql(distinct)} #{mod.token_to_sql(from)}"
  end
  def token_to_sql({tag, _, values}, mod) when tag in ~w[all]a do
    "#{mod.token_to_sql(tag)} #{mod.token_to_sql(values)}"
  end
  def token_to_sql({:select = tag, _, [{:distinct, _, _} = distinct | rest]}, mod) do
    "#{mod.token_to_sql(tag)} #{mod.token_to_sql(distinct)} #{Enum.map_join(rest, " ", &mod.token_to_sql/1)}"
  end
  def token_to_sql({tag, _, value}, mod) when tag in ~w[select from by]a do
    "#{mod.token_to_sql(tag)} #{Enum.map_join(value, " ", &mod.token_to_sql/1)}"
  end
  def token_to_sql({tag, _, [[_ | _] = left, right]}, mod) when tag in ~w[join]a do
    "#{Enum.map_join(left, " ", &mod.token_to_sql/1)} #{mod.token_to_sql(tag)} #{mod.token_to_sql(right)}"
  end
  def token_to_sql({tag, _, value}, mod) when tag in ~w[fetch limit where order offset group having with join]a do
    "#{mod.token_to_sql(tag)} #{mod.token_to_sql(value)}"
  end
  def token_to_sql({tag, _, [left, right]}, mod) when tag in ~w[:: [\] <> <= >= != || + - ^ * / % < > = like ilike as union except intersect between and or on is not all in]a do
    "#{mod.token_to_sql(left)} #{mod.token_to_sql(tag)} #{mod.token_to_sql(right)}"
  end
  def token_to_sql({tag, _, [left, right]}, mod) when tag in ~w[.]a do
    "#{mod.token_to_sql(left)}#{mod.token_to_sql(tag)}#{mod.token_to_sql(right)}"
  end
  def token_to_sql({tag, _, [{t, _, _} = right]}, mod) when tag in ~w[not]a and t in ~w[null false true unknown distinct]a do
    "#{mod.token_to_sql(tag)} #{mod.token_to_sql(right)}"
  end
  def token_to_sql({tag, _, [left]}, mod) when tag in ~w[not]a do
    "#{mod.token_to_sql(left)} #{mod.token_to_sql(tag)}"
  end
  def token_to_sql({tag, _, [right]}, mod) when tag in ~w[not all between symmetric absolute relative forward backward]a do
    "#{mod.token_to_sql(tag)} #{mod.token_to_sql(right)}"
  end
  def token_to_sql({tag, _, [left]}, mod) when tag in ~w[asc desc isnull notnull]a do
    "#{mod.token_to_sql(left)} #{mod.token_to_sql(tag)}"
  end
  def token_to_sql({:binding, _, [idx]}, _mod) do
    "$#{idx}"
  end
  def token_to_sql(value, _mod) when is_atom(value) do
    "#{value}"
  end
  def token_to_sql(value, _mod) when is_binary(value) do
    "'#{value}'"
  end
  def token_to_sql(value, _mod) when is_number(value) do
    "#{value}"
  end
  def token_to_sql(values, mod) when is_list(values) do
    Enum.map_join(values, " ", &mod.token_to_sql/1)
  end
end
