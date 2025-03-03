import SQL
range = 1..10_000
Benchee.run(
  %{
    "to_stirng" => fn -> for _ <- range, do: to_string(~SQL[with recursive temp (n, fact) as (select 0, 1 union all select n+1, (n+1)*fact from temp where n < 9)]) end,
    "to_sql" => fn -> for _ <- range, do: SQL.to_sql(~SQL[with recursive temp (n, fact) as (select 0, 1 union all select n+1, (n+1)*fact from temp where n < 9)]) end,
    "inspect" => fn -> for _ <- range, do: inspect(~SQL[with recursive temp (n, fact) as (select 0, 1 union all select n+1, (n+1)*fact from temp where n < 9)]) end
  },
  time: 10,
  memory_time: 2
)
