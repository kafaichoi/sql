# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 DBVisor

defmodule SQL.ParserTest do
  use ExUnit.Case
  require SQL.Parser

  test "is_ident/1" do
    # defguard is_ident(value) when elem(value, 0) in [:., :ident, :"", :"''", :"[]"]
    assert SQL.Parser.is_ident({:ident, [], []})
    assert SQL.Parser.is_ident({:., [], [{:ident, [], []}, {:ident, [], []}]})
    assert SQL.Parser.is_ident({:., [], [{:., [], [{:ident, [], []}, {:ident, [], []}]}, {:ident, [], []}]})
    assert SQL.Parser.is_ident({:"", [], [{:ident, [], []}]})
    assert SQL.Parser.is_ident({:'', [], [{:ident, [], []}]})
    assert SQL.Parser.is_ident({:"[]", [], [{:ident, [], []}]})
  end
  test "is_bool/1" do
    assert SQL.Parser.is_bool({:null, [], []})
    assert SQL.Parser.is_bool({:true, [], []})
    assert SQL.Parser.is_bool({:false, [], []})
    assert SQL.Parser.is_bool({:unknown, [], []})
  end
  test "is_bool_op/1" do
    assert SQL.Parser.is_bool_op({:<>, [], []})
    assert SQL.Parser.is_bool_op({:<=, [], []})
    assert SQL.Parser.is_bool_op({:>=, [], []})
    assert SQL.Parser.is_bool_op({:!=, [], []})
    assert SQL.Parser.is_bool_op({:<, [], []})
    assert SQL.Parser.is_bool_op({:>, [], []})
    assert SQL.Parser.is_bool_op({:=, [], []})
    assert SQL.Parser.is_bool_op({:like, [], []})
    assert SQL.Parser.is_bool_op({:ilike, [], []})
    assert SQL.Parser.is_bool_op({:is, [], []})
    assert SQL.Parser.is_bool_op({:in, [], []})
  end
  test "is_op/1" do
    assert SQL.Parser.is_op({:"::", [], []})
    assert SQL.Parser.is_op({:||, [], []})
    assert SQL.Parser.is_op({:+, [], []})
    assert SQL.Parser.is_op({:-, [], []})
    assert SQL.Parser.is_op({:^, [], []})
    assert SQL.Parser.is_op({:*, [], []})
    assert SQL.Parser.is_op({:/, [], []})
    assert SQL.Parser.is_op({:%, [], []})
    assert SQL.Parser.is_op({:as, [], []})
    assert SQL.Parser.is_op({:from, [], []})
  end
  test "is_lop/1" do
    assert SQL.Parser.is_lop({:and, [], []})
    assert SQL.Parser.is_lop({:or, [], []})
  end
  test "is_numeric/1" do
    assert SQL.Parser.is_numeric({:float, [], []})
    assert SQL.Parser.is_numeric({:integer, [], []})
  end
  test "is_expr/1" do
    assert SQL.Parser.is_expr({:"()", [], []})
    assert SQL.Parser.is_expr({:"\#{}", [], []})

  end
  test "is_datatype/1" do
    assert SQL.Parser.is_datatype({:ident, [], []})
  end
  test "is_operator/1" do
    assert SQL.Parser.is_operator({:ilike, [], []})
    assert SQL.Parser.is_operator({:as, [], []})
  end
end
