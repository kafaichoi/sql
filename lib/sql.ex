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
      def config, do: unquote(opts)
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

  defstruct [:tokens, :query, :params, :module]

  @doc """
  Returns a parameterized SQL.

  ## Examples
      iex(1)> email = "john@example.com"
      iex(2)> SQL.to_sql(~SQL"select id, email from users where email = \#{email}")
      {"select id, email from users where email = $0", ["john@example.com"]}
  """
  @doc since: "0.1.0"
  def to_sql(sql), do: {"#{sql}", sql.params}

  @doc false
  def build(right, {:<<>>, meta, _} = left, _modifiers, env) do
    quote bind_quoted: [right: Macro.unpipe(right), left: left, meta: Macro.escape({meta[:line], meta[:column] || 0, env.file}), e: Macro.escape(env)] do
      {t, p} = Enum.reduce(right, {[], []}, fn
        {[], 0}, acc -> acc
        {v, 0}, {:ok, opts, _, _, _, _, tokens} -> {tokens ++ v.tokens, opts[:params] ++ v.params}
        {v, 0}, {tokens, params} -> {tokens ++ v.tokens, params ++ v.params}
        end)
      {:ok, opts, _, _, _, _, tokens} = SQL.Lexer.lex(left, binding(), meta, p)
      t ++ SQL.Parser.parse(tokens)
      |> SQL.to_query()
      |> Map.merge(%{module: __MODULE__, params: opts[:params]})
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
    {:ok, _opts, _, _, _, _, tokens} = SQL.Lexer.lex(binary, false, {1, 0, nil}, [])
    tokens
    |> SQL.Parser.parse()
    |> to_query()
  end

  @doc false
  @doc since: "0.1.0"
  @acc ~w[for create drop insert alter with update delete select set fetch from join where group having window except intersect union order limit offset lock colon in declare start grant revoke commit rollback open close comment comments into]a
  def to_query([value | _] = tokens) when is_tuple(value) and elem(value, 0) in @acc do
    struct(SQL, tokens: tokens, query: Enum.reduce(@acc, [], fn key, acc -> acc ++ for {k, meta, v} <- Enum.filter(tokens, &(elem(&1, 0) == key)), do: {k, meta, Enum.map(v, &to_query/1)} end))
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

  defimpl Inspect, for: SQL do
    def inspect(sql, _opts) do
      if Kernel.function_exported?(sql.module, :config, 0) do
        Enum.reduce(0..length(sql.params), to_string(sql), &String.replace(&2, sql.module.config()[:adapter].token_to_string({:binding, [], [&1]}), sql.module.config()[:adapter].token_to_string(Enum.at(sql.params, &1)), global: false))
      else
        Enum.reduce(0..length(sql.params), to_string(sql), &String.replace(&2, SQL.String.token_to_sql({:binding, [], [&1]}), SQL.String.token_to_sql(Enum.at(sql.params, &1))))
      end
    end
  end

  defimpl String.Chars, for: SQL do
    def to_string(sql) do
      cond do
        Kernel.function_exported?(sql.module, :config, 0) -> Enum.map(sql.query, &sql.module.config()[:adapter].token_to_string(&1))
        Kernel.function_exported?(sql.module, :token_to_string, 2) -> Enum.map(sql.query, &sql.module.token_to_string(&1))
        true -> Enum.map(sql.query, &SQL.String.token_to_sql(&1))
      end
      |> Enum.reduce("", fn
        v, "" -> v
        <<";", _::binary>> = v, acc -> acc <> v
        v, acc -> acc <> " " <> v
      end)
    end
  end
end
