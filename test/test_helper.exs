# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 DBVisor

defmodule SQL.Repo do
  use Ecto.Repo, otp_app: :sql, adapter: Ecto.Adapters.Postgres
end

ExUnit.start()
