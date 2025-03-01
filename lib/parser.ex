# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 DBVisor

defmodule SQL.Parser do
  @moduledoc false

  def context(?'), do: :"''"
  def context(?"), do: :""
  def context(?[), do: :"[]"
  def context(?(), do: :"()"

  def type(?., :integer), do: :float
  def type(b, type) when b in ?0..?9 and type in ~w[nil integer float]a, do: type || :integer
  def type(_b, _type), do: :ident

  def node(context, metadata, acc, opts), do: {context, List.wrap(if opts[:metadata], do: metadata), List.wrap(acc)}

  ##### This is a mess, we might do better by leveraging the associatity rules instead of pattern matching while merging the nodes
  defguard is_ident(value) when elem(value, 0) in [:., :ident, :"", :"''", :"[]"]
  defguard is_bool(value) when elem(value, 0) in ~w[null true false unknown]a
  defguard is_bool_op(value) when elem(value, 0) in ~w[<> <= >= != < > = like ilike is in]a
  defguard is_op(value) when elem(value, 0) in ~w[:: || + - ^ * / % as from]a
  defguard is_lop(value) when elem(value, 0) in ~w[and or]a
  defguard is_numeric(value) when elem(value, 0) in ~w[float integer]a
  defguard is_expr(value) when elem(value, 0) in [:"()", :"\#{}", :binding]
  defguard is_datatype(value) when is_ident(value) or is_numeric(value) or is_bool(value) or is_expr(value)
  defguard is_operator(value) when is_bool_op(value) or is_op(value)

  def merge([{:is, _, _}, {tag, _, _}] = rest) when tag in ~w[not distinct]a, do: rest
  def merge([{:is = tag, meta, acc}, {:distinct = t, m, []}, {:from = t2, m2, []}, right | rest]), do: merge([{tag, meta, acc ++ [{t, m, [{t2, m2, [right]}]}]} | rest])
  def merge([{:is = tag, meta, acc}, {:from = t, m, []}, right | rest]), do: merge([{tag, meta, acc ++ [{t, m, [right]}]} | rest])
  def merge([right, {:is = tag, meta, []} | rest]) when is_ident(right) or is_numeric(right) or is_expr(right), do: merge([{tag, meta, [right]} | rest])
  def merge([{:is = tag, meta, acc}, {:not = t, m, []}, right | rest]), do: merge([{tag, meta, acc ++ [{t, m, [right]}]} | rest])
  def merge([{:is = tag, meta, acc}, right | rest]), do: merge([{tag, meta, acc ++ [right]} | rest])
  def merge([{_, _, _} = right, {tag, meta, [] = acc} | rest]) when tag in ~w[not]a, do: merge([{tag, meta, acc ++ [right]} | rest])
  def merge([{_, _, _} = right, {tag, meta, [] = acc} | rest]) when tag in ~w[asc desc isnull notnull]a, do: merge([{tag, meta, acc ++ [right]} | rest])
  def merge([{tag, meta, []}, {:integer, _, _} = left | rest]) when tag in ~w[absolute relative]a, do: merge([{tag, meta, [left]} | rest])
  def merge([{tag, meta, []}, {t, _, _} = left | rest]) when tag in ~w[forward backward]a and t in ~w[integer all]a, do: merge([{tag, meta, [left]} | rest])
  def merge([{tag, _, _} = right, {t, m, []} | left]) when tag in ~w[next prior first last absolute relative all forward backward]a and t in ~w[in from]a, do: merge([{t, m, [right | left]}])
  def merge([{:distinct = tag, meta, []}, {:on = t, m, []}, {:"()", _, _} = right | rest]), do: merge([{tag, meta, [{:on = t, m, [right]}]} | rest])
  def merge([left, {:on = tag, meta, []}, {:"()", _, _} = right | rest]), do: merge([{tag, meta, [left, right]} | rest])

  def merge([left, {:all = tag, meta, []}, {:"()", _, _} = right | rest]), do: merge([left, {tag, meta, [right]} | rest])

  def merge([left, {:on = tag, meta, []} | right]), do: merge([{tag, meta, [left] ++ right}])
  def merge([l1, l2, {:on = tag, meta, []} | right]), do: merge([{tag, meta, [[l1, l2]] ++ right}])
  def merge([left, {:all = tag, meta, [] = acc} | right]), do: merge([left, {tag, meta, acc ++ right}])
  def merge([{:by = tag, meta, acc}, {_, _, _} = right | rest]), do: merge([{tag, meta, acc ++ [right]} | rest])
  def merge([op, right, {:. = tag, meta, []}, left | rest]) when (is_bool_op(op) or is_lop(op) or is_op(op)) and is_ident(right) and is_ident(left), do: merge([op, {tag, meta, [right, left]} | rest])
  def merge([lop, op, right, {:. = tag, meta, []}, left | rest]) when is_lop(lop) and is_bool_op(op) and is_ident(right) and is_ident(left), do: merge([lop, op, {tag, meta, [right, left]} | rest])
  def merge([right, {:. = tag, meta, []}, left | rest]) when is_ident(right) and is_ident(left), do: merge([{tag, meta, [right, left]} | rest])
  def merge([op, l, {:between = tag, meta, []}, right, {:and = t, m, []}, left | rest]) when is_lop(op) and is_datatype(l) and is_datatype(right) and is_datatype(left), do: merge([op, {tag, meta, [l, {t, m, [right, left]}]} | rest])

  def merge([op, l, {:between = tag, meta, []}, {:symmetric = t, m, []}, right, {:and = t2, m2, []}, left | rest]) when is_lop(op) and is_datatype(l) and is_datatype(right) and is_datatype(left), do: merge([op, {tag, meta, [l, {t, m, [{t2, m2, [right, left]}]}]} | rest])

  def merge([l, {:between = tag, meta, []}, {:symmetric = t, m, []}, right, {:and = t2, m2, []}, left | rest]) when (is_datatype(l) or elem(l, 0) == :not) and is_datatype(right) and is_datatype(left), do: merge([{tag, meta, [l, {t, m, [{t2, m2, [right, left]}]}]} | rest])
  def merge([l, {:between = tag, meta, []}, right, {:and = t, m, []}, left | rest]) when (is_datatype(l) or elem(l, 0) == :not) and is_datatype(right) and is_datatype(left), do: merge([{tag, meta, [l, {t, m, [right, left]}]} | rest])
  def merge([{t, m, [r]} = op, {:between, _, _} = left | rest]) when is_lop(op), do: merge([{t, m, [r, left]} | rest])
  def merge([right, {t, m, []} = op, left | rest]) when is_lop(right) and is_lop(op) and is_bool(left), do: merge([{t, m, [right, left]} | rest])
  def merge([right, {tag, meta, []} = left | rest]) when is_datatype(right) and is_op(left), do: merge([{tag, meta, [right]} | rest])
  def merge([right, {tag, meta, []} = left | rest]) when is_datatype(right) and is_bool_op(left), do: merge([{tag, meta, [right]} | rest])
  def merge([op, right, {tag, meta, []} = left | rest]) when (is_bool_op(op) or is_lop(op) or is_op(op)) and is_datatype(right) and is_operator(left), do: merge([op, {tag, meta, [right]} | rest])
  def merge([{t, m, [r]} = lop, {t2, m2, [r2]} = op, left, {t3, m3, []} = lop2 | rest]) when is_lop(lop) and is_lop(lop2) and is_bool_op(op) and is_datatype(left), do: merge([{t3, m3, [{t, m, [r, {t2, m2, [r2, left]}]}]} | rest])

  def merge([op, right, {tag, meta, []} = left | rest]) when is_lop(op) and is_datatype(right) and is_bool_op(left), do: merge([op, {tag, meta, [right]} | rest])
  def merge([{tag, meta, [right]} = op, left, lop | rest]) when is_bool_op(op) and is_datatype(left) and is_lop(lop), do: merge([{tag, meta, [right, left]}, lop | rest])

  def merge([{tag, meta, [right]} = op, left | rest]) when (is_bool_op(op) or is_op(op)) and is_datatype(left), do: merge([{tag, meta, [right, left]} | rest])
  def merge([{_, _, [_, _]} = right, {tag, meta, []} = left | rest]) when is_bool_op(right) and is_lop(left), do: merge([{tag, meta, [right]} | rest])

  def merge([{tag, meta, [right]} = lop, {_, _, [_, _]} = left | rest]) when is_bool_op(left) and is_lop(lop), do: merge([{tag, meta, [right, left]} | rest])

  def merge([{tag, meta, [right]} = lop, {_, _, []} = left | rest]) when is_bool(left) and is_lop(lop), do: merge([{tag, meta, [right, left]} | rest])
  def merge([{:recursive = t, m, []}, {:as = t2, m2, [l, r]}]), do: merge([{t2, m2, [{t, m, l}, r]}])
  def merge([{:ident, _, _} = l1, {:"()", _, _} = l2, {:as = t2, m2, []}, {:"()", _, _} = r]), do: merge([{t2, m2, [[l1, l2], r]}])
  def merge(unit), do: unit
  #####

  def merge(unit, nil, _data, _line, _column, _opts), do: merge(unit)
  def merge(unit, type, data, line, column, opts) when is_integer(line) and type != nil, do: merge(unit ++ [node(type, [line: line, column: column - length(data), end_line: line, end_column: column], [data], opts)])

  def merge(root, [], _metadata, acc, unit, _opts), do: root ++ merge(acc ++ unit)
  def merge([] = root, :"()", _metadata, [], [], _opts), do: root
  def merge(root, context, metadata, acc, unit, opts) do
    root ++ [node(context, metadata, merge(acc ++ unit), opts)]
  end

  def expected_delimiter(:"()"), do: :")"
  def expected_delimiter(:"''"), do: :"'"
  def expected_delimiter(:""), do: :"\""

  def opening_delimiter(:"()"), do: :"("
  def opening_delimiter(:"''"), do: :"'"
  def opening_delimiter(:""), do: :"\""

  def error!(attrs), do: raise(TokenMissingError, attrs)

  def parse(binary, binding, _meta, params \\ [], opts \\ [metadata: true]) do
    case parse(binary, binary, opts ++ [binding: binding, params: params], 0, 0, nil, [], [], [], [], [], []) do
      {"", _binary, opts, line, column, type, data, unit, context, metadata, acc, root} ->
          {:ok, merge(root, context, metadata ++ [end_line: line, end_column: column], acc, merge(unit, type, data, line, column, opts), opts), opts[:params]}
    end
  end
  def parse(<<b, rest::binary>>, binary, opts, line, column, type, data, unit, :"" = context, metadata, acc, root) when b != ?" do
    parse(rest, binary, opts, line, column+1, type(b, type), data ++ [b], unit, context, metadata, acc, root)
  end
  def parse(<<b, rest::binary>>, binary, opts, line, column, type, data, unit, :"''" = context, metadata, acc, root) when b != ?' do
    parse(rest, binary, opts, line, column+1, type(b, type), data ++ [b], unit, context, metadata, acc, root)
  end
  def parse("" = rest, binary, opts, line, column, type, data, unit, context, metadata, acc, root) do
    {rest, binary, opts, line, column, type, data, unit, context, metadata, acc, root}
  end
  def parse(<<b, rest::binary>>, binary, opts, line, column, nil = type, [] = data, [] = unit, context, metadata, acc, root) when b == ?+ or b == ?- do
    parse(rest, binary, opts, line, column+1, type, data ++ [b], unit, context, metadata, acc, root)
  end
  def parse(<<b, rest::binary>>, binary, opts, line, column, type, data, unit, context, metadata, acc, root) when type in ~w[float integer]a and (b == ?. or b >= ?0 and b <= ?9) do
    parse(rest, binary, opts, line, column+1, type(b, type), data ++ [b], unit, context, metadata, acc, root)
  end
  for keyword <- ~w[with select where group having order offset limit fetch] do
    {match, guard, rest, len, tag} = SQL.Compiler.generate(keyword)
    def parse(unquote(match), binary, opts, line, end_column, nil = type, [] = data, unit, context, metadata, acc, root) when unquote(guard) do
      column = end_column+unquote(len)
      parse(unquote(rest), binary, opts, line, column, type, data, [], unquote(tag), [line: line, column: column], [], merge(root, context, metadata ++ [end_line: line, end_column: end_column], acc, unit, opts))
    end
  end
  for keyword <- ~w[inner natural left right full cross] do
    {match, guard, rest, len, tag} = SQL.Compiler.generate(keyword)
    def parse(unquote(match), binary, opts, line, column, nil = type, [] = data, unit, context, metadata, acc, root) when unquote(guard) do
      end_column = column+unquote(len)
      parse(unquote(rest), binary, opts, line, end_column, type, data, [], :join, [line: line, column: end_column], [node(unquote(tag), [line: line, column: column, end_line: line, end_column: end_column], [], opts)], merge(root, context, metadata ++ [end_line: line, end_column: column], acc, unit, opts))
    end
  end
  for keyword <- ~w[outer on by recursive] do
    {match, guard, rest, len, tag} = SQL.Compiler.generate(keyword)
    def parse(unquote(match), binary, opts, line, end_column, nil = type, [] = data, unit, context, metadata, acc, root) when unquote(guard) do
      parse(unquote(rest), binary, opts, line, end_column+unquote(len), type, data, [], context, [line: line, column: end_column], acc ++ unit ++ [node(unquote(tag), metadata ++ [end_line: line, end_column: end_column], [], opts)], root)
    end
  end
  for keyword <- ~w[except intersect union] do
    {match, guard, rest, len, tag} = SQL.Compiler.generate(keyword)
    def parse(unquote(match), binary, opts, line, column, type, data, unit, context, metadata, acc, root) when unquote(guard) do
      left = case merge(root, context, metadata ++ [end_line: line, end_column: column], acc, merge(unit, type, data, line, column, opts), opts) do
        [{tag, _, _}] = left when tag in ~w[all ()]a -> left
        left -> [left]
      end
      column = column+unquote(len)
      case parse(unquote(rest), binary, opts, line, column, nil, [], [], unquote(tag), [line: line, column: column], [], []) do
        {rest, binary, opts, line, column, type, data, unit, context, metadata, acc, [{unquote(tag), meta, []} | right]} ->
          {rest, binary, opts, line, column, nil, [], [], [], metadata, [], [{unquote(tag), meta, left ++ [merge(right, context, metadata ++ [end_line: line, end_column: column], acc, merge(unit, type, data, line, column, opts), opts)]}]}
        {rest, binary, opts, line, column, type, data, unit, context, metadata, acc, root} ->
          {rest, binary, opts, line, column, nil, [], [], [], metadata, acc, merge(root, context, metadata ++ [end_line: line, end_column: column], left ++ acc, merge(unit, type, data, line, column, opts), opts)}
      end
    end
  end
  for keyword <- ~w[all] do
    {match, guard, rest, len, tag} = SQL.Compiler.generate(keyword)
    def parse(unquote(match), binary, opts, line, column, nil = type, [] = data, unit, :fetch = context, metadata, acc, root) when unquote(guard) do
      end_column = column+unquote(len)
      parse(unquote(rest), binary, opts, line, end_column, type, data, unit ++ [node(unquote(tag), [line: line, column: column, end_line: line, end_column: end_column], [], opts)], context, metadata, acc, root)
    end
    def parse(unquote(match), binary, opts, line, column, nil = type, [] = data, unit, context, metadata, acc, root) when unquote(guard) do
      case parse(unquote(rest), binary, opts, line, column+unquote(len), type, data, [], unquote(tag), [line: line, column: column], [], []) do
         {rest, end_line, end_column, result} ->
           parse(rest, binary, opts, end_line, end_column, type, data, unit ++ result, context, metadata, acc, root)
         {rest, binary, opts, end_line, end_column, t, d, u, c, m, a, r} ->
           {rest, binary, opts, end_line, end_column, type, data, unit ++ merge(r, c, m ++ [end_line: end_line, end_column: end_column], a, merge(u, t, d, end_line, end_column, opts), opts), context, metadata, acc, root}
      end
    end
  end
  for keyword <- ~w[is isnull not notnull as at in collate next prior first last absolute relative forward backward distinct any exists some between symmetric ilike like similar operator count] do
    {match, guard, rest, len, tag} = SQL.Compiler.generate(keyword)
    def parse(unquote(match), binary, opts, line, column, nil = type, [] = data, unit, context, metadata, acc, root) when unquote(guard) do
      end_column = column+unquote(len)
      parse(unquote(rest), binary, opts, line, end_column, type, data, unit ++ [node(unquote(tag), [line: line, column: column, end_line: line, end_column: end_column], [], opts)], context, metadata, acc, root)
    end
  end
  for keyword <- ~w[unknown true false null isnull notnull asc desc] do
    {match, guard, rest, len, tag} = SQL.Compiler.generate(keyword, next: [?\s, ?\t, ?\r, ?\n, ?\f, 194, 160, ?,])
    def parse(unquote(match), binary, opts, line, column, nil = type, [] = data, unit, context, metadata, acc, root) when unquote(guard) do
      end_column = column+unquote(len)
      parse(unquote(rest), binary, opts, line, end_column, type, data, unit ++ [node(unquote(tag), [line: line, column: column, end_line: line, end_column: end_column], [], opts)], context, metadata, acc, root)
    end
    {match, guard, rest, len, tag} = SQL.Compiler.generate(keyword, eos: true)
    def parse(unquote(match), binary, opts, line, column, nil = type, [] = data, unit, context, metadata, acc, root) when unquote(guard) do
      end_column = column+unquote(len)
      parse(unquote(rest), binary, opts, line, end_column, type, data, unit ++ [node(unquote(tag), [line: line, column: column, end_line: line, end_column: end_column], [], opts)], context, metadata, acc, root)
    end
  end
  for keyword <- ~w[and or] do
    {match, guard, rest, len, tag} = SQL.Compiler.generate(keyword)
    def parse(unquote(match), binary, opts, line, column, nil = type, [] = data, unit, context, metadata, acc, root) when unquote(guard) do
      end_column = column+unquote(len)
      parse(unquote(rest), binary, opts, line, end_column, type, data, merge(unit, type, data, line, column, opts) ++ [node(unquote(tag), [line: line, column: column, end_line: line, end_column: end_column], [], opts)], context, metadata, acc, root)
    end
  end
  for keyword <- ~w{:: [] <> <= >= != !< !> += -= *= /= %= &= ^-= |*= <=> || . + - ^ * / % & < > =} do
    {match, guard, rest, len, tag} = SQL.Compiler.generate(keyword, next: false)
    def parse(unquote(match), binary, opts, line, column, type, data, unit, context, metadata, acc, root) when unquote(guard) do
      end_column = column+unquote(len)
      meta = [line: line, column: column, end_line: line, end_column: end_column]
      unit = merge(unit, type, data, line, column, opts)
      parse(unquote(rest), binary, opts, line, end_column, nil, [], unit ++ [node(unquote(tag), meta, [], opts)], context, metadata, acc, root)
    end
  end
  for keyword <- ~w[from join] do
    {match, guard, rest, len, tag} = SQL.Compiler.generate(keyword)
    def parse(unquote(match), binary, opts, line, column, nil = type, [] = data, unit, context, metadata, acc, root) when unquote(guard) do
      end_column = column+unquote(len)
      metadata = metadata ++ [end_line: line, end_column: end_column]
      tag = Enum.at(unit, 0)
      cond do
        context == :join ->
          acc = if acc == [], do: acc, else: [acc]
          parse(unquote({:rest, [], Elixir}), binary, opts, line, end_column, type, data, unit, context, metadata, acc, root)
        is_tuple(tag) and elem(tag, 0) == :is and context in ~w[where having]a ->
          parse(unquote({:rest, [], Elixir}), binary, opts, line, end_column, type, data, unit ++ [node(unquote(tag), [], [], opts)], context, metadata, acc, root)
        true ->
          parse(unquote(rest), binary, opts, line, end_column, type, data, [], unquote(tag), [line: line, column: column], [], merge(root, context, metadata, acc, unit, opts))
      end
    end
  end
  def parse(<<?#, ?{, rest::binary>>, binary, opts, line, column, _type, data, unit, context, metadata, acc, root) do
    column = column+2
    binding = opts[:binding]
    case interpolation(rest, line, column) do
      {:error, "", end_line, end_column, _acc} ->
        error!([line: line, column: column, end_line: end_line, end_column: end_column, file: "", snippet: binary, opening_delimiter: :"\#{", expected_delimiter: :"}"])
      {rest, end_line, end_column, result} when binding == false ->
        parse(rest, binary, opts, end_line, end_column, nil, data, unit ++ [{:"\#{}", [line: line, column: column, end_line: end_line, end_column: end_column], [result]}], context, metadata, acc, root)
      {rest, end_line, end_column, result} when is_atom(result) ->
        if param = binding[result] do
          parse(rest, binary, update_in(opts, [:params], &(&1++[param])), end_line, end_column, nil, data, unit ++ [{:binding, [line: line, column: column, end_line: end_line, end_column: end_column], [length(opts[:params])]}], context, metadata, acc, root)
        else
          raise ArgumentError, "The variable #{result} is not defined"
        end
      {rest, end_line, end_column, result} ->
        parse(rest, binary, update_in(opts, [:params], &(&1++[result])), end_line, end_column, nil, data, unit ++ [{:binding, [line: line, column: column, end_line: end_line, end_column: end_column], [length(opts[:params])]}], context, metadata, acc, root)
    end
  end
  def parse(<<?), rest::binary>>, _binary, opts, line, column, type, data, unit, :"()" = context, metadata, acc, root) do
    column = column+1
    {rest, line, column, merge(root, context, metadata ++ [end_line: line, end_column: column], acc, merge(unit, type, data, line, column, opts), opts)}
  end
  def parse(<<?], rest::binary>>, _binary, opts, line, column, type, data, unit, :"[]" = context, metadata, acc, root) do
    {rest, line, column, merge(root, context, metadata ++ [end_line: line, end_column: column], acc, merge(unit, type, data, line, column, opts), opts)}
  end
  def parse(<<?", rest::binary>>, _binary, opts, line, column, type, data, unit, :"" = context, metadata, acc, root) do
    {rest, line, column, merge(root, context, metadata ++ [end_line: line, end_column: column], acc, merge(unit, type, data, line, column, opts), opts)}
  end
  def parse(<<?', rest::binary>>, _binary, opts, line, column, type, data, unit, :"''" = context, metadata, acc, root) do
    {rest, line, column, merge(root, context, metadata ++ [end_line: line, end_column: column], acc, merge(unit, type, data, line, column, opts), opts)}
  end
  def parse(<<b, rest::binary>>, binary, opts, line, column, type, data, unit, context, metadata, acc, root) when b in [?(, ?[, ?", ?'] do
    unit = merge(unit, type, data, line, column, opts)
    column = column+1
    tag = context(b)
    case parse(rest, binary, opts, line, column, nil, [], [], tag, [line: line, column: column], [], [])  do
      {rest, end_line, end_column, [{^tag, _, _}] = result} ->
        parse(rest, binary, opts, end_line, end_column, nil, data, unit ++ result, context, metadata, acc, root)
      {rest, end_line, end_column, result} ->
        parse(rest, binary, opts, end_line, end_column, nil, data, unit ++ [node(tag, [line: line, column: column, end_line: end_line, end_column: end_column], result, opts)], context, metadata, acc, root)
      {"" = rest, binary, opts, end_line, end_column, nil, [], [], [], _meta, [], nodes} when nodes != [] ->
        {rest, binary, opts, end_line, end_column, type, data, unit ++ [node(tag, [line: line, column: column, end_line: end_line, end_column: end_column], nodes, opts)], context, metadata, acc, root}
      {"", binary, _, end_line, end_column, _, _, _, _, _, _, _} ->
        error!([line: line, column: column, end_line: end_line, end_column: end_column, file: "", snippet: binary, opening_delimiter: opening_delimiter(tag), expected_delimiter: expected_delimiter(tag)])
    end
  end
  def parse(<<b, rest::binary>>, _binary, opts, line, column, type, data, unit, context, metadata, acc, root) when b in [?), ?], ?", ?'] do
    column = column+1
    {rest, line, column, merge(root, context, metadata ++ [end_line: line, end_column: column], acc, merge(unit, type, data, line, column, opts), opts)}
  end
  def parse(<<?,, rest::binary>>, binary, opts, line, column, type, data, unit, context, metadata, acc, root) do
    parse(rest, binary, opts, line, column+1, nil, [], [], context, metadata, acc ++ [{:",", [line: line, column: column, end_line: line, end_column: column+1], merge(merge(unit, type, data, line, column, opts))}], root)
  end
  def parse(<<?;, rest::binary>>, binary, opts, line, column, type, data, unit, context, metadata, acc, root) do
    end_column = column+1
    node = node(:";", [line: line, column: column, end_line: line, end_column: end_column], merge(root, context, metadata ++ [end_line: line, end_column: column], acc, merge(unit, type, data, line, column, opts), opts), opts)
    parse(rest, binary, opts, line, end_column, nil, [], [], [], [], [], [] ++ [node])
  end
  def parse(<<?\n, rest::binary>>, binary, opts, line, column, type, data, unit, context, metadata, acc, root) do
    parse(rest, binary, opts, line+1, column, nil, [], merge(unit, type, data, line, column, opts), context, metadata, acc, root)
  end
  def parse(<<b, rest::binary>>, binary, opts, line, column, type, data, unit, context, metadata, acc, root) when b in [?\s, ?\t, ?\r, ?\f, 194, 160] do
    parse(rest, binary, opts, line, column+1, nil, [], merge(unit, type, data, line, column, opts), context, metadata, acc, root)
  end
  def parse(<<b, rest::binary>>, binary, opts, line, column, type, data, unit, context, metadata, acc, root) do
    parse(rest, binary, opts, line, column+1, type(b, type), data ++ [b], unit, context, metadata, acc, root)
  end

  def interpolation(binary, line, column, type \\ :var, acc \\ [], n \\ 0)
  def interpolation("" = rest, line, column, _type,  acc, 0), do: {:error, rest, line, column, acc}
  def interpolation(<<?}, rest::binary>>, line, column, :var, acc, 0) do
    {<<rest::binary>>, line, column+1, List.to_atom(acc)}
  end
  def interpolation(<<?}, rest::binary>>, line, column, :code, acc, 0) do
    {<<rest::binary>>, line, column+1, acc}
  end
  def interpolation(<<?{, rest::binary>>, line, column, _type, acc, n) do
    interpolation(rest, line, column, :code, acc ++ [?{], n+1)
  end
  def interpolation(<<?}, rest::binary>>, line, column, type, acc, n) do
    interpolation(rest, line, column+1, type, acc ++ [?}], n-1)
  end
  def interpolation(<<v, rest::binary>>, line, column, :var = type, acc, n) when v in ?a..?z or v in ?A..?Z or (v == ?_ and acc != [])  do
    interpolation(rest, line+1, column, type, acc ++ [v], n)
  end
  def interpolation(<<?\n, rest::binary>>, line, column, _type, acc, n) do
    interpolation(rest, line+1, column, :code, acc ++ [?\n], n)
  end
  def interpolation(<<v, rest::binary>>, line, column, _type, acc, n) do
    interpolation(rest, line, column+1, :code, acc ++ [v], n)
  end
end
