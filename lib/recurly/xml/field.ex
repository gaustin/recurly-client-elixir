defmodule Recurly.XML.Field do
  @moduledoc """
  Represents a schema field
  """
  defstruct [:name, :type, :opts]

  def read_only?(field) do
    case Keyword.get(field.opts, :read_only) do
      true -> true
      _ -> false
    end
  end

  def array?(field) do
    case Keyword.get(field.opts, :array) do
      true -> true
      _ -> false
    end
  end

  def pageable?(field) do
    case Keyword.get(field.opts, :paginate) do
      true -> true
      _ -> false
    end
  end
end
