# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 DBVisor

defmodule SQL.Adapters.ANSI do
  @moduledoc """
    A SQL adapter for [ANSI](https://blog.ansi.org/sql-standard-iso-iec-9075-2023-ansi-x3-135/).
  """
  @moduledoc since: "0.2.0"

  use SQL.Token

  @doc false
  def token_to_string(value, mod \\ __MODULE__)
  def token_to_string(value, mod) when is_struct(value) do
    to_string(%{value | module: mod})
  end
  def token_to_string({tag, _, [{:parens, _, _} = value]}, mod) when tag in ~w[integer float update]a do
    "#{mod.token_to_string(tag)}#{mod.token_to_string(value)}"
  end
  def token_to_string({tag, _, value}, _mod) when tag in ~w[ident integer float]a do
    "#{value}"
  end
  def token_to_string({tag, _}, mod) do
    mod.token_to_string(tag)
  end
  def token_to_string({:comment, _, value}, _mod) do
    "-- #{value}"
  end
  def token_to_string({:comments, _, value}, _mod) do
    "\\* #{value} *\\"
  end
  def token_to_string({:double_quote, _, value}, _mod) do
    "\"#{value}\""
  end
  def token_to_string({:quote, _, value}, _mod) do
    "'#{value}'"
  end
  def token_to_string({:parens, _, value}, mod) do
    "(#{mod.token_to_string(value)})"
  end
  def token_to_string({:bracket, _, value}, mod) do
    "[#{mod.token_to_string(value)}]"
  end
  def token_to_string({:colon, _, value}, mod) do
    "; #{mod.token_to_string(value)}"
  end
  def token_to_string({:comma, _, value}, mod) do
    ", #{mod.token_to_string(value)}"
  end
  def token_to_string({tag, _, []}, mod) do
    mod.token_to_string(tag)
  end
  def token_to_string({tag, _, [[_ | _] = left, right]}, mod) when tag in ~w[join]a do
    "#{mod.token_to_string(left)} #{mod.token_to_string(tag)} #{mod.token_to_string(right)}"
  end
  def token_to_string({tag, _, [{:with = t, _, [left, right]}]}, mod) when tag in ~w[to]a do
    "#{mod.token_to_string(tag)} #{mod.token_to_string(left)} #{mod.token_to_string(t)} #{mod.token_to_string(right)}"
  end
  def token_to_string({tag, _, value}, mod) when tag in ~w[select from fetch limit where order offset group having with join by distinct create type drop insert alter table add into delete update start grant revoke set declare open close commit rollback references recursive]a do
    "#{mod.token_to_string(tag)} #{mod.token_to_string(value)}"
  end
  def token_to_string({:on = tag, _, [source, as, value]}, mod) do
    "#{mod.token_to_string(source)} #{mod.token_to_string(as)} #{mod.token_to_string(tag)} #{mod.token_to_string(value)}"
  end
  def token_to_string({tag, _, [left, [{:all = t, _, right}]]}, mod) when tag in ~w[union except intersect]a do
    "#{mod.token_to_string(left)} #{mod.token_to_string(tag)} #{mod.token_to_string(t)} #{mod.token_to_string(right)}"
  end
  def token_to_string({:between = tag, _, [{:not = t, _, right}, left]}, mod) do
    "#{mod.token_to_string(right)} #{mod.token_to_string(t)} #{mod.token_to_string(tag)} #{mod.token_to_string(left)}"
  end
  def token_to_string({tag, _, [left, right]}, mod) when tag in ~w[:: [\] <> <= >= != || + - ^ * / % < > = like ilike as union except intersect between and or on is not in cursor for to]a do
    "#{mod.token_to_string(left)} #{mod.token_to_string(tag)} #{mod.token_to_string(right)}"
  end
  def token_to_string({tag, _, [{:parens, _, _} = value]}, mod) when tag not in ~w[in on]a do
    "#{mod.token_to_string(tag)}#{mod.token_to_string(value)}"
  end
  def token_to_string({tag, _, values}, mod) when tag in ~w[not all between symmetric absolute relative forward backward on in for without]a do
    "#{mod.token_to_string(tag)} #{mod.token_to_string(values)}"
  end
  def token_to_string({tag, _, [left, right]}, mod) when tag in ~w[.]a do
    "#{mod.token_to_string(left)}.#{mod.token_to_string(right)}"
  end
  def token_to_string({tag, _, [left]}, mod) when tag in ~w[not]a do
    "#{mod.token_to_string(left)} #{mod.token_to_string(tag)}"
  end
  def token_to_string({tag, _, [left]}, mod) when tag in ~w[asc desc isnull notnull]a do
    "#{mod.token_to_string(left)} #{mod.token_to_string(tag)}"
  end
  def token_to_string({:binding, _, [idx]}, _mod) when is_integer(idx) do
    "?"
  end
  def token_to_string({:binding, _, value}, _mod) do
    "{{#{value}}}"
  end
  def token_to_string(:asterisk, _mod) do
    "*"
  end
  def token_to_string(value, _mod) when is_atom(value) do
    "#{value}"
  end
  def token_to_string(value, _mod) when is_binary(value) do
    "'#{value}'"
  end
  def token_to_string(values, mod) when is_list(values) do
    values
    |> Enum.reduce([], fn
      token, [] = acc -> [acc | mod.token_to_string(token)]
      {:comma, _, _} = token, acc -> [acc | mod.token_to_string(token)]
      token, acc -> [acc, " "  | mod.token_to_string(token)]
    end)
  end
end
