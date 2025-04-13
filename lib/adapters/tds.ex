# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 DBVisor

defmodule SQL.Adapters.TDS do
  @moduledoc """
    A SQL adapter for [TDS](https://www.microsoft.com/en-ca/sql-server).
  """
  @moduledoc since: "0.2.0"

  use SQL.Token

  def token_to_string(value, mod \\ __MODULE__)
  def token_to_string({:binding, _, [idx]}, _mod) when is_integer(idx), do: "@#{idx}"
  def token_to_string(token, mod), do: SQL.Adapters.ANSI.token_to_string(token, mod)
end
