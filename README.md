<!--
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 DBVisor
-->

# SQL

<!-- MDOC !-->

Brings an extensible SQL parser and sigil to Elixir, confidently write SQL with automatic parameterized queries.

- Lower the barrier for DBAs to contribute in your codebase, without having to translate SQL to Ecto.Query.
- Composable queries, no need for you to remember, when to start with select or from.
- Interpolation-al queries, don't fiddle with fragments and `?`.

## Examples

```elixir
iex(1)> email = "john@example.com"
"john@example.com"
iex(2)> select = ~SQL"select id, email"
"select id, email"
iex(3)> ~SQL[from users] |> ~SQL[where email = #{email}] |> select
"select id, email from users where email = \"john@example.com\""
iex(4)> sql = ~SQL[from users where email = #{email} select id, email]
"select id, email from users where email = \"john@example.com\""
iex(5)> to_sql(sql)
{"select id, email from users where email = $0", ["john@example.com"]}
iex(6)> to_string(sql)
"select id, email from users where email = $0"
iex(7)> inspect(sql)
"select id, email from users where email = \"john@example.com\""
```

### Extend the SQL AST or raise on unimplemented features with ease
```elixir
defmodule SQL.Adapters.TDS do
  use SQL

  @impl true
  def token_to_sql({:binding, _, [value]}), do: "@#{value}"

  # keywords not yet tokenized by the parser will end up as ident and passed through
  # as illustrated below, but in our specific example we use it to raise an error.
  # iex(1)> ~SQL[select count(*)]
  # "select count (*)"
  def token_to_sql({:ident, _, [~c"count"] = value}) do
    raise "#{value} is not implemented for #{__MODULE__}"
  end

  # handle conversion from postgresql "users"."id" and users.id to [users].[id]
  def token_to_sql({:. = tag, _, [{:"", _, [{:ident, _, _} = left]} , {:"", _, [{:ident, _, _} = right]}]}) do
    "[#{token_to_sql(left)}]#{token_to_sql(tag)}[#{token_to_sql(right)}]"
  end
  def token_to_sql({:. = tag, _, [{:ident, _, _} = left, {:ident, _, _} = right]}) do
    "[#{token_to_sql(left)}]#{token_to_sql(tag)}[#{token_to_sql(right)}]"
  end
  def token_to_sql({:. = tag, _, [{:"", _, [{:ident, _, _} = left]}, right]}) do
    "[#{token_to_sql(left)}]#{token_to_sql(tag)}#{token_to_sql(right)}"
  end
  def token_to_sql({:. = tag, _, [{:ident, _, _} = left, right]}) do
    "[#{token_to_sql(left)}]#{token_to_sql(tag)}#{token_to_sql(right)}"
  end
  def token_to_sql({:. = tag, _, [left, {:"", _, [{:ident, _, _} = right]}]}) do
    "#{token_to_sql(left)}#{token_to_sql(tag)}[#{token_to_sql(right)}]"
  end
  def token_to_sql({:. = tag, _, [left, {:ident, _, _} = right]}) do
    "#{token_to_sql(left)}#{token_to_sql(tag)}[#{token_to_sql(right)}]"
  end

  # fallback
  def token_to_sql(token) do
    IO.inspect token, label: :token_to_sql
    SQL.String.token_to_sql(token, __MODULE__)
  end
end

iex(8)> to_sql(~SQL[from db.users where "db"."users"."email" = #{email} select db.users.id, db.users.email])
{"select [db].[users].[id], [db].[users].[email] from [db].[users] where [db].[users].[email] = @0", ["john@example.com"]}

iex(9)> to_sql(~SQL[from db.users where "db"."users"."email" = #{email} select count(*)])
** (RuntimeError) count is not implemented for Elixir.SQL.Adapters.TDS
    iex:11: SQL.Adapters.TDS.token_to_sql/1
    (elixir 1.18.0) lib/enum.ex:1815: anonymous fn/2 in Enum.map_join/3
    (elixir 1.18.0) lib/enum.ex:4496: Enum.map_intersperse_list/3
    (elixir 1.18.0) lib/enum.ex:1815: Enum.map_join/3
    (sql 0.1.0) lib/string.ex:54: SQL.String.token_to_sql/2
    (elixir 1.18.0) lib/enum.ex:1815: anonymous fn/2 in Enum.map_join/3
    (elixir 1.18.0) lib/enum.ex:4496: Enum.map_intersperse_list/3
    iex:9: (file)
```

### Leverage the Enumerable protocol in your repository

```elixir
  defmodule MyApp.Repo do
    use Ecto.Repo, otp_app: :myapp, adapter: Ecto.Adapters.Postgres
    use SQL

    defimpl Enumerable, for: SQL do
      def count(_enumerable) do
        {:error, __MODULE__}
      end
      def member?(_enumerable, _element) do
        {:error, __MODULE__}
      end
      def reduce(%SQL{} = enumerable, _acc, _fun) do
        {sql, params} = SQL.to_sql(enumerable)
        result = __MODULE__.query!(sql, params)
        {:done, Enum.map(result.rows, &Map.new(Enum.zip(result.columns, &1)))}
      end
      def slice(_enumerable) do
        {:error, __MODULE__}
      end
    end
  end

  iex(1)> Enum.map(~SQL[from users select *], &IO.inspect/1)
  %{"id" => 1, "email" => "john@example.com"}
  %{"id" => 2, "email" => "jane@example.com"}
  [%{"id" => 1, "email" => "john@example.com"}, %{"id" => 2, "email" => "jane@example.com"}]
```


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `sql` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sql, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/sql>.
