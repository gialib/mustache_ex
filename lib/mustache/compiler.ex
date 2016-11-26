defmodule Mustache.Compiler do

  def compile(source, bindings, options) do
    tokens = Mustache.Tokenizer.tokenize(source)
    partials = options[:partials] || []
    partials = Enum.map partials, fn({ k,partial}) -> { k, Mustache.Tokenizer.tokenize(partial) } end
    build(tokens, bindings, [partials: partials, root: bindings]) |> List.flatten |> Enum.join
  end

  def escape(value) do
    value |> Mustache.Utils.to_binary |> Mustache.Utils.escape_html
  end

  def get_value(nil, _, _ ), do: nil
  def get_value(val, :., _) when is_bitstring(val), do: val
  def get_value(bindings, name, root) when is_map(bindings) and is_atom(name) do
    cond do
      bindings[name] != nil ->
        bindings[name] 
      bindings[Atom.to_string(name)] == nil and root != nil ->
        get_value(root, name, nil)
      true ->
        bindings[name] 
    end
  end
  def get_value(bindings, name, root) when is_map(bindings) and is_list(name) do
    Enum.reduce(name, bindings, fn(name, acc) ->
                  get_value(acc, name, root)
                end)
  end

  def get_value(bindings, name, _root) when is_list(bindings) and is_atom(name), do: bindings[name]
  def get_value(bindings, name, root) when is_list(bindings) and is_list(name) do
    Enum.reduce(name, bindings, fn(name, acc) ->
                  get_value(acc, name, root)
                end)
  end

  def get_value(bindings, name, root) when is_tuple(bindings) and is_atom(name), do: get_value(Keyword.new([bindings]), name, root)
  def get_value(_bindings, name, root) when is_atom(name) do
    get_value(root, name, nil)
  end

  def check_lambda(val) when is_function(val), do: val.()
  def check_lambda(val), do: val

  def build([{:text,val}|rest], bindings, opts), do: [val] ++ build(rest, bindings, opts)

  def build([{tag,name}|rest], bindings, opts) when tag in [:variable, :dot, :dotted_name] do
    [get_value(bindings, name, opts[:root]) |> check_lambda |> escape] ++ build(rest, bindings, opts)
  end

  def build([{tag,name}|rest], bindings, opts) when tag in [:unescaped_variable, :unescaped_dot, :unescaped_dotted_name] do
    [get_value(bindings, name, opts[:root]) |> check_lambda |> to_string] ++ build(rest, bindings, opts)
  end

  def build([{tag,name}|rest], bindings, opts) when tag in [:section, :dotted_name_section] do
    bind = get_value(bindings, name, opts[:root])
    idx = Enum.find_index(rest, fn(e) -> {:end_section, name} == e end)
    elements = Enum.take(rest, idx)

    ret = if is_list(bind) do
      Enum.map(bind, fn(b) ->
                       build(elements, b, opts)
                     end)
    else
      if bind != nil and bind != false do
        build(elements, bind, opts)
      else
        ""
      end
    end

    rest = Enum.drop(rest, idx+1)
    [ret] ++ build(rest, bindings, opts)
  end

  def build([{tag,name}|rest], bindings, opts) when tag in [:inverted_section, :dotted_name_inverted_section] do
    bind = get_value(bindings, name, opts[:root])
    idx = Enum.find_index(rest, fn(e) -> {:end_section, name} == e end)
    elements = Enum.take(rest, idx)
    ret = if bind == nil or bind == [] or bind == false do
      build(elements, bind, opts)
    else
      ""
    end
    [ret] ++ build(Enum.drop(rest, idx+1), bindings, opts)
  end

  def build([{:partial,name, _}|rest], bindings, opts) do
    partial = opts[:partials][name]
    ret = if partial != nil do
      build(partial, bindings, opts)
    else
      ""
    end
    [ret] ++ build(rest, bindings, opts)
  end

  def build([{}|rest], bindings, opts) do
    [] ++ build(rest, bindings, opts)
  end

  def build([token|rest], bindings, opts) do
    [inspect(token)] ++ build(rest, bindings, opts)
  end

  def build([], _bindings, _opts) do
    []
  end
end
