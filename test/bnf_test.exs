# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 DBVisor

defmodule SQL.BNFTest do
  use ExUnit.Case, async: true

  test "parse/1" do
    assert %{"<SQL terminal character>" => "<SQL language character>"} ==
             SQL.BNF.parse("""
               <SQL terminal character> ::=
                   <SQL language character>
             """)
  end
end
