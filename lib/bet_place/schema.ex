defmodule BetPlace.Schema do
  @moduledoc "Base schema macro — sets binary_id primary key and foreign key type."
  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
    end
  end
end
