# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 DBVisor

defmodule SQL do
  @moduledoc "README.md"
               |> File.read!()
               |> String.split("<!-- MDOC !-->")
               |> Enum.fetch!(1)
  @moduledoc since: "0.1.0"

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @doc false
      @behaviour SQL
      import SQL
      def sql_config, do: unquote(opts)
      def token_to_sql(token), do: token_to_sql(token)
      defoverridable token_to_sql: 1
    end
  end
  @optional_callbacks token_to_sql: 1

  @doc """
  Returns a SQL string for a given token.
  """
  @doc since: "0.1.0"
  @doc deprecated: "Use SQL.Token.token_to_string/1 instead"
  @callback token_to_sql(token :: {atom, keyword, list}) :: String.t()

  defstruct [:tokens, :params, :module, :id]

  @doc """
  Returns a parameterized SQL.

  ## Examples
      iex(1)> email = "john@example.com"
      iex(2)> SQL.to_sql(~SQL"select id, email from users where email = \#{email}")
      {"select id, email from users where email = $0", ["john@example.com"]}
  """
  @doc since: "0.1.0"
  def to_sql(sql), do: {:persistent_term.get(sql.id), sql.params}

  @doc false
  def build(right, {:<<>>, meta, _} = left, _modifiers, env) do
    quote bind_quoted: [right: Macro.unpipe(right), left: left, meta: Macro.escape({meta[:line], meta[:column] || 0, env.file}), e: Macro.escape(env)] do
      {t, p} = Enum.reduce(right, {[], []}, fn
        {[], 0}, acc -> acc
        {v, 0}, {tokens, params} -> {tokens ++ v.tokens, params ++ v.params}
        end)
      binding = binding()
      id = {__MODULE__, :binary.decode_unsigned(left), meta}
      {tokens, params} = tokens(left, meta, length(p), id)
      tokens = t ++ tokens
      params = Enum.reduce(params, p, fn
          {:var, var}, acc -> acc ++ [binding[String.to_atom(var)]]
          {:code, code}, acc -> acc ++ [elem(Code.eval_string(code, binding), 0)]
      end)
      struct(SQL, params: params, tokens: tokens, id: plan(id, tokens), module: __MODULE__)
    end
  end

  def tokens(left, meta, p, id) do
    if result = :persistent_term.get(id, nil) do
      result
    else
      {:ok, opts, _, _, _, _, tokens} = SQL.Lexer.lex(left, meta, p)
      result = {tokens, opts[:binding]}
      :persistent_term.put(id, result)
      result
    end
  end

  def plan(id, tokens) do
    if uid = :persistent_term.get(tokens, nil) do
      uid
    else
      uid = System.unique_integer([:positive])
      :persistent_term.put(tokens, uid)
      :persistent_term.put(uid, to_string(SQL.to_query(SQL.Parser.parse(tokens)), elem(id, 0)))
      uid
    end
  end

  @doc """
  Handles the sigil `~SQL` for SQL.

  It returns a `%SQL{}` struct that can be transformed to a parameterized query.

  ## Examples
      iex(1)> ~SQL"from users select id, email"
      "select id, email from users"
  """
  @doc since: "0.1.0"
  defmacro sigil_SQL(left \\ [], right, modifiers) do
    SQL.build(left, right, modifiers, __CALLER__)
  end

  @doc false
  @doc since: "0.1.0"
  def parse(binary) do
    {:ok, _opts, _, _, _, _, tokens} = SQL.Lexer.lex(binary, {1, 0, nil}, 0, [format: true])
    tokens
    |> SQL.Parser.parse()
    |> to_query()
    |> to_string(SQL.String)
  end

  @doc false
  @doc since: "0.1.0"
  @acc ~w[for create drop insert alter with update delete select set fetch from join where group having window except intersect union order limit offset lock colon in declare start grant revoke commit rollback open close comment comments into]a
  def to_query([value | _] = tokens) when is_tuple(value) and elem(value, 0) in @acc do
    Enum.reduce(@acc, [], fn key, acc -> acc ++ for {k, meta, v} <- Enum.filter(tokens, &(elem(&1, 0) == key)), do: {k, meta, Enum.map(v, &to_query/1)} end)
  end
  def to_query({:parens = tag, meta, values}) do
    {tag, meta, to_query(values)}
  end
  def to_query({tag, meta, values}) do
    {tag, meta, Enum.map(values, &to_query/1)}
  end
  def to_query(tokens) when is_list(tokens) do
    Enum.map(tokens, &to_query/1)
  end
  def to_query(token) do
    token
  end


  def to_string(tokens, module) do
    fun = cond do
      Kernel.function_exported?(module, :sql_config, 0) -> &module.sql_config()[:adapter].token_to_string(&1)
      Kernel.function_exported?(module, :token_to_string, 2) -> &module.token_to_string(&1)
      true -> &SQL.String.token_to_sql(&1)
    end
    tokens
    |> Enum.reduce([], fn
      token, [] = acc -> [acc | fun.(token)]
      token, acc ->
      case fun.(token) do
        <<";", _::binary>> = v -> [acc | v]
        v -> [acc, " " | v]
      end
    end)
    |> IO.iodata_to_binary()
  end


  defimpl Inspect, for: SQL do
    def inspect(sql, _opts) do
      if Kernel.function_exported?(sql.module, :sql_config, 0) do
        Enum.reduce(0..length(sql.params), :persistent_term.get(sql.id), &String.replace(&2, sql.module.sql_config()[:adapter].token_to_string({:binding, [], [&1]}), sql.module.sql_config()[:adapter].token_to_string(Enum.at(sql.params, &1)), global: false))
      else
        Enum.reduce(0..length(sql.params), :persistent_term.get(sql.id), &String.replace(&2, SQL.String.token_to_sql({:binding, [], [&1]}), SQL.String.token_to_sql(Enum.at(sql.params, &1))))
      end
    end
  end

  defimpl String.Chars, for: SQL do
    def to_string(%{id: id}), do: :persistent_term.get(id)
    def to_string(%{tokens: tokens, module: module}), do: SQL.to_string(tokens, module)
  end
end
