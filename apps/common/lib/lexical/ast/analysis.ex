defmodule Lexical.Ast.Analysis do
  @moduledoc """
  A data structure representing an analyzed AST.

  See `Lexical.Ast.analyze/1`.
  """

  alias Lexical.Ast.Analysis.Analyzer
  alias Lexical.Document
  alias Lexical.Document.Position
  alias Lexical.Document.Range

  defstruct [:ast, :document, :parse_error, :scopes]

  @type t :: %__MODULE__{}

  @doc false
  def new(parse_result, document)

  def new({:ok, ast}, %Document{} = document) do
    scopes = Analyzer.traverse(ast, document)

    %__MODULE__{
      ast: ast,
      document: document,
      scopes: scopes
    }
  end

  def new(error, document) do
    %__MODULE__{
      document: document,
      parse_error: error
    }
  end

  @doc false
  def aliases_at(%__MODULE__{} = analysis, %Position{} = position) do
    case scopes_at(analysis, position) do
      [%Analyzer.Scope{} = scope | _] ->
        scope
        |> Analyzer.Scope.alias_map()
        |> Stream.filter(fn {_, %Analyzer.Alias{} = alias} ->
          alias.line <= position.line and Enum.all?(alias.module, &is_atom/1)
        end)
        |> Map.new(fn {as, %Analyzer.Alias{module: module}} ->
          {as, Module.concat(module)}
        end)

      [] ->
        %{}
    end
  end

  defp scopes_at(%__MODULE__{scopes: scopes}, %Position{} = position) do
    scopes
    |> Stream.filter(fn %Analyzer.Scope{range: range} = scope ->
      scope.id == :global or Range.contains?(range, position)
    end)
    |> Enum.sort_by(
      fn
        %Analyzer.Scope{id: :global} -> 0
        %Analyzer.Scope{range: range} -> {range.start.line, range.start.character}
      end,
      :desc
    )
  end
end
