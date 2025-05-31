# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 DBVisor
# https://standards.iso.org/iso-iec/9075/-2/ed-6/en/
# https://standards.iso.org/ittf/PubliclyAvailableStandards/ISO_IEC_9075-1_2023_ed_6_-_id_76583_Publication_PDF_(en).zip
# 0. \w(?![^<]*>)
# 1. <[^>]*>\.{3} repeat non-terminal rule
# 2. ({.+}...) repeat group
# 3. <[^>]*> - non-terminal
# 4. \[[^\]]*] - optional
# 5. \|(?![^\[]*\]) - or

defmodule SQL.BNF do
  @moduledoc false

  def parse() do
    File.cwd!()
    |> Path.join("standard/ISO_IEC_9075-2(E)_Foundation.bnf.txt")
    |> File.read!()
    |> parse()
  end

  def parse(binary) do
    Map.new(parse(binary, :symbol, [], [], [], [], []))
  end

  defp parse(<<>>, _type, data, acc, symbol, expr, rules) do
    merge(rules, symbol, expr ++ merge(acc, data))
  end

  defp parse(<<?*, rest::binary>>, :symbol = type, symbol, _acc, _data, _expr, rules) do
    parse(rest, type, [], [], symbol, [], rules)
  end

  defp parse(<<?\n, ?\n, ?<, rest::binary>>, _type, data, acc, symbol, expr, rules) do
    parse(
      <<?<, rest::binary>>,
      :symbol,
      [],
      [],
      [],
      [],
      merge(rules, symbol, expr ++ merge(acc, data))
    )
  end

  defp parse(<<?:, ?:, ?=, rest::binary>>, _type, data, acc, symbol, expr, rules) do
    parse(rest, :expr, [], [], String.trim("#{data}"), [], merge(rules, symbol, expr ++ acc))
  end

  defp parse(<<?., rest::binary>>, type, [?!, ?! | _] = data, acc, symbol, expr, rules) do
    parse(rest, type, [], merge(acc, "#{data ++ [?.]}"), symbol, expr, rules)
  end

  defp parse(<<?., ?., ?., rest::binary>>, type, data, acc, symbol, expr, rules) do
    parse(rest, type, data ++ [?., ?., ?.], acc, symbol, expr, rules)
  end

  defp parse(<<?|, rest::binary>>, type, data, acc, symbol, expr, rules) do
    parse(rest, type, data ++ [?|], acc, symbol, expr, rules)
  end

  defp parse(<<b, rest::binary>>, type, [] = data, acc, symbol, expr, rules)
       when b in [?\s, ?\t, ?\r, ?\n, ?\f] do
    parse(rest, type, data, acc, symbol, expr, rules)
  end

  defp parse(<<b, rest::binary>>, type, data, acc, symbol, expr, rules) when b in [?\n] do
    parse(rest, type, data, acc, symbol, expr, rules)
  end

  defp parse(<<b, rest::binary>>, type, data, acc, symbol, expr, rules) do
    parse(rest, type, data ++ [b], acc, symbol, expr, rules)
  end

  defp merge([], []), do: []
  defp merge(rules, []), do: rules
  defp merge(rules, data), do: rules ++ [data]
  defp merge(rules, [], []), do: rules
  defp merge(rules, rule, expr) when is_list(rule), do: merge(rules, "#{rule}", expr)
  defp merge(rules, rule, expr) when is_list(expr), do: merge(rules, rule, "#{expr}")
  # 32 \u0020
  defp merge(rules, "<space>" = symbol, "!! See the Syntax Rules."),
    do: rules ++ [{symbol, ["\u0020"]}]

  # "Lu", "Ll", "Lt", "Lm", "Lo", or "Nl" Unicode.Set.match?(<<b::utf8>>, "[[:Lu:], [:Ll:], [:Lt:], [:Lm:], [:Lo:], [:Nl:]]")
  defp merge(rules, "<identifier start>" = symbol, "!! See the Syntax Rules."),
    do: rules ++ [{symbol, [:ignore]}]

  # 183 \u00B7 or "Mn", "Mc", "Nd", "Pc", or "Cf" Unicode.Set.match?(<<b::utf8>>, "[[:Mn:], [:Mc:], [:Nd:], [:Pc:], [:Cf:]]")
  defp merge(rules, "<identifier extend>" = symbol, "!! See the Syntax Rules."),
    do: rules ++ [{symbol, [:ignore]}]

  defp merge(rules, "<Unicode escape character>" = symbol, "!! See the Syntax Rules."),
    do: rules ++ [{symbol, ["\\u"]}]

  defp merge(rules, "<non-double quote character>" = symbol, "!! See the Syntax Rules."),
    do: rules ++ [{symbol, [:ignore]}]

  defp merge(rules, "<whitespace>" = symbol, "!! See the Syntax Rules."),
    do:
      rules ++
        [
          {symbol,
           [
             "\u0009",
             "\u000D",
             "\u00A0",
             "\u00A0",
             "\u1680",
             "\u2000",
             "\u2001",
             "\u2002",
             "\u2003",
             "\u2004",
             "\u2005",
             "\u2006",
             "\u2007",
             "\u2008",
             "\u2009",
             "\u200A",
             "\u202F",
             "\u205F",
             "\u3000",
             "\u180E",
             "\u200B",
             "\u200C",
             "\u200D",
             "\u2060",
             "\uFEFF"
           ]}
        ]

  defp merge(rules, "<truncating whitespace>" = symbol, "!! See the Syntax Rules."),
    do: rules ++ [{symbol, [:ignore]}]

  defp merge(rules, "<bracketed comment contents>" = symbol, _expr),
    do: rules ++ [{symbol, [:ignore]}]

  defp merge(rules, "<newline>" = symbol, "!! See the Syntax Rules."),
    do:
      rules ++ [{symbol, ["\u000A", "\u000B", "\u000C", "\u000D", "\u0085", "\u2028", "\u2029"]}]

  defp merge(rules, "<non-quote character>" = symbol, "!! See the Syntax Rules."),
    do: rules ++ [{symbol, [:ignore]}]

  defp merge(rules, "<non-escaped character>" = symbol, "!! See the Syntax Rules."),
    do: rules ++ [{symbol, [:ignore]}]

  defp merge(rules, "<escaped character>" = symbol, "!! See the Syntax Rules."),
    do: rules ++ [{symbol, [:ignore]}]

  defp merge(rules, "<JSON path literal>" = symbol, "!! See the Syntax Rules."),
    do: rules ++ [{symbol, [:ignore]}]

  defp merge(rules, "<JSON path string literal>" = symbol, "!! See the Syntax Rules."),
    do: rules ++ [{symbol, [:ignore]}]

  defp merge(rules, "<JSON path numeric literal>" = symbol, "!! See the Syntax Rules."),
    do: rules ++ [{symbol, [:ignore]}]

  defp merge(rules, "<JSON path identifier>" = symbol, "!! See the Syntax Rules."),
    do: rules ++ [{symbol, [:ignore]}]

  defp merge(rules, "<JSON path key name>" = symbol, "!! See the Syntax Rules."),
    do: rules ++ [{symbol, [:ignore]}]

  defp merge(
         rules,
         "<implementation-defined JSON representation option>" = symbol,
         "!! See the Syntax Rules."
       ),
       do: rules ++ [{symbol, [:ignore]}]

  defp merge(
         rules,
         "<preparable implementation-defined statement>" = symbol,
         "!! See the Syntax Rules."
       ),
       do: rules ++ [{symbol, [:ignore]}]

  defp merge(rules, "<SQLSTATE class code>" = symbol, _expr), do: rules ++ [{symbol, [:ignore]}]

  defp merge(rules, "<SQLSTATE subclass code>" = symbol, _expr),
    do: rules ++ [{symbol, [:ignore]}]

  defp merge(rules, "<host label identifier>" = symbol, "!! See the Syntax Rules."),
    do: rules ++ [{symbol, [:ignore]}]

  defp merge(rules, "<host PL/I label variable>" = symbol, "!! See the Syntax Rules."),
    do: rules ++ [{symbol, [:ignore]}]

  defp merge(rules, "<embedded SQL Ada program>" = symbol, "!! See the Syntax Rules."),
    do: rules ++ [{symbol, [:ignore]}]

  defp merge(rules, "<Ada host identifier>" = symbol, "!! See the Syntax Rules."),
    do: rules ++ [{symbol, [:ignore]}]

  defp merge(rules, "<embedded SQL C program>" = symbol, "!! See the Syntax Rules."),
    do: rules ++ [{symbol, [:ignore]}]

  defp merge(rules, "<C host identifier>" = symbol, "!! See the Syntax Rules."),
    do: rules ++ [{symbol, [:ignore]}]

  defp merge(rules, "<embedded SQL COBOL program>" = symbol, "!! See the Syntax Rules."),
    do: rules ++ [{symbol, [:ignore]}]

  defp merge(rules, "<COBOL host identifier>" = symbol, "!! See the Syntax Rules."),
    do: rules ++ [{symbol, [:ignore]}]

  defp merge(rules, "<embedded SQL Fortran program>" = symbol, "!! See the Syntax Rules."),
    do: rules ++ [{symbol, [:ignore]}]

  defp merge(rules, "<Fortran host identifier>" = symbol, "!! See the Syntax Rules."),
    do: rules ++ [{symbol, [:ignore]}]

  defp merge(rules, "<embedded SQL MUMPS program>" = symbol, "!! See the Syntax Rules."),
    do: rules ++ [{symbol, [:ignore]}]

  defp merge(rules, "<MUMPS host identifier>" = symbol, "!! See the Syntax Rules."),
    do: rules ++ [{symbol, [:ignore]}]

  defp merge(rules, "<embedded SQL Pascal program>" = symbol, "!! See the Syntax Rules."),
    do: rules ++ [{symbol, [:ignore]}]

  defp merge(rules, "<Pascal host identifier>" = symbol, "!! See the Syntax Rules."),
    do: rules ++ [{symbol, [:ignore]}]

  defp merge(rules, "<embedded SQL PL/I program>" = symbol, "!! See the Syntax Rules."),
    do: rules ++ [{symbol, [:ignore]}]

  defp merge(rules, "<PL/I host identifier>" = symbol, "!! See the Syntax Rules."),
    do: rules ++ [{symbol, [:ignore]}]

  defp merge(
         rules,
         "<direct implementation-defined statement>" = symbol,
         "!! See the Syntax Rules."
       ),
       do: rules ++ [{symbol, [:ignore]}]

  defp merge(_rules, symbol, "!! See the Syntax Rules."),
    do:
      raise(
        "Please apply rules for #{symbol} by referencing the PDF or https://github.com/ronsavage/SQL/blob/master/Syntax.rules.txt"
      )

  defp merge(rules, symbol, expr), do: rules ++ [{symbol, expr}]
end
