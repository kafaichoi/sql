# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 DBVisor

defmodule SQL.CompilerTest do
  use ExUnit.Case

  test "generate/2" do
    assert {{:<<>>, [], [{:b1, [], Elixir}, {:b2, [], Elixir}, {:next, [], Elixir}, {:"::", [], [{:rest, [], Elixir}, {:binary, [], Elixir}]}]}, {:and, [context: Elixir, imports: [{2, Kernel}]], [{:and, [context: Elixir, imports: [{2, Kernel}]], [{:in, [context: Elixir, imports: [{2, Kernel}]], [{:b1, [], Elixir}, ~c"oO"]}, {:in, [context: Elixir, imports: [{2, Kernel}]], [{:b2, [], Elixir}, ~c"nN"]}]}, {:in, [context: Elixir, imports: [{2, Kernel}]], [{:next, [], Elixir}, [32, 9, 13, 10, 12, 194, 160]]}]}, {:<<>>, [], [{:next, [], Elixir}, {:"::", [], [{:rest, [], Elixir}, {:binary, [], Elixir}]}]}, 2, :on} == SQL.Compiler.generate("On")

    assert {{:<<>>, [], [{:b1, [], Elixir}, {:b2, [], Elixir}, {:"::", [], [{:rest, [], Elixir}, {:binary, [], Elixir}]}]}, {:and, [context: Elixir, imports: [{2, Kernel}]], [{:and, [context: Elixir, imports: [{2, Kernel}]], [{:in, [context: Elixir, imports: [{2, Kernel}]], [{:b1, [], Elixir}, ~c"oO"]}, {:in, [context: Elixir, imports: [{2, Kernel}]], [{:b2, [], Elixir}, ~c"nN"]}]}, {:==, [context: Elixir, imports: [{2, Kernel}]], [{:rest, [], Elixir}, ""]}]}, {:rest, [], Elixir}, 2, :on} == SQL.Compiler.generate("On", eos: true)

    assert  {{:<<>>, [], [{:b1, [], Elixir}, {:b2, [], Elixir}, {:"::", [], [{:rest, [], Elixir}, {:binary, [], Elixir}]}]}, {:and, [context: Elixir, imports: [{2, Kernel}]], [{:in, [context: Elixir, imports: [{2, Kernel}]], [{:b1, [], Elixir}, ~c"oO"]}, {:in, [context: Elixir, imports: [{2, Kernel}]], [{:b2, [], Elixir}, ~c"nN"]}]}, {:rest, [], Elixir}, 2, :on} == SQL.Compiler.generate("On", next: false)
  end
end
