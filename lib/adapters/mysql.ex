# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 DBVisor

defmodule SQL.Adapters.MySQL do
  @moduledoc """
    A SQL adapter for [MySQL](https://www.mysql.com).
  """
  @moduledoc since: "0.2.0"

  use SQL.Token

  def token_to_string(value, mod \\ __MODULE__)
  def token_to_string(token, mod), do: SQL.Adapters.ANSI.token_to_string(token, mod)
end
