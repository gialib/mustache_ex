defmodule Mustache do
  @moduledoc """
  Mustache is a logic-less templates.
  See [mustache(5) -- Logic-less templates.](http://mustache.github.io/mustache.5.html) for more details
  """

  def render(source, bindings \\ [], options \\ []) do
    render_string(source, bindings, options)
  end

  def render_string(source, bindings \\ [], options \\ []) do
    compile_string(source, bindings, options)
  end

  def render_file(filename, bindings \\ [], options \\ []) do
    compile_string(File.read!(filename), bindings, options)
  end

  def compile_string(source, bindings, options \\ []) do
    Mustache.Compiler.compile(source, bindings, options)
  end

  def render_view(view, filename, bindings \\ [], options \\ []) do
    {:safe, template} = view.render filename

    render_string(IO.iodata_to_binary(template), bindings, options)
  end
end
